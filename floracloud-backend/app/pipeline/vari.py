"""
VARI – Visible Atmospherically Resistant Index
  VARI = (G - R) / (G + R - B)

Input: (N, 6) float32 array [X, Y, Z, R, G, B].
Output: statistics dict ready to populate VARIResult.
"""
from typing import Any, Dict

import numpy as np
from loguru import logger


def compute_vari(
    points: np.ndarray,
    correction_factors: Dict[str, float],
) -> Dict[str, Any]:
    if points.shape[0] == 0:
        raise ValueError("Nenhum ponto para calcular VARI")

    xyz = points[:, :3]
    rgb = points[:, 3:6].astype(np.float32).copy()

    # Apply radiometric correction (factors already applied to saved JPEGs,
    # but we keep this as a second-pass safeguard for any residual bias)
    rgb[:, 0] *= correction_factors.get("R", 1.0)
    rgb[:, 1] *= correction_factors.get("G", 1.0)
    rgb[:, 2] *= correction_factors.get("B", 1.0)
    rgb = np.clip(rgb, 0, 255)

    # Normalize to [0, 1]
    r = rgb[:, 0] / 255.0
    g = rgb[:, 1] / 255.0
    b = rgb[:, 2] / 255.0

    # VARI
    denom = g + r - b
    vari = np.where(np.abs(denom) > 1e-6, (g - r) / denom, 0.0)

    # Remove outliers (sky, sensor noise)
    valid = (vari >= -1.0) & (vari <= 1.0)
    vari = vari[valid]
    xyz_valid = xyz[valid]

    if vari.size == 0:
        raise ValueError("Todos os pontos VARI estão fora do intervalo válido [-1, 1]")

    result: Dict[str, Any] = {
        "mean": float(np.mean(vari)),
        "median": float(np.median(vari)),
        "std_dev": float(np.std(vari)),
        "min": float(np.min(vari)),
        "max": float(np.max(vari)),
        "point_count": int(vari.size),
        "stratified_by_height": _stratify(xyz_valid[:, 2], vari),
        # Private fields used by export.py (not serialized to VARIResult)
        "_vari_values": vari,
        "_valid_mask": valid,
    }

    logger.info(
        f"VARI: mean={result['mean']:.3f}  median={result['median']:.3f}  "
        f"n={result['point_count']:,}"
    )
    return result


def _stratify(z: np.ndarray, vari: np.ndarray, n_bins: int = 5) -> Dict[str, float]:
    z_min, z_max = float(z.min()), float(z.max())
    z_range = z_max - z_min

    if z_range < 0.01:
        return {"total": float(np.mean(vari))}

    bin_size = z_range / n_bins
    strat: Dict[str, float] = {}
    for i in range(n_bins):
        lo = z_min + i * bin_size
        hi = lo + bin_size
        label = f"{lo:.1f}m-{hi:.1f}m"
        mask = (z >= lo) & (z < hi)
        strat[label] = float(np.mean(vari[mask])) if mask.any() else 0.0

    return strat
