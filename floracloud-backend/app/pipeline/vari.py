"""
VARI – Visible Atmospherically Resistant Index
  VARI = (G - R) / (G + R - B)

Input: calibrated field images directory.
Output: statistics dict ready to populate VARIResult.
"""
from pathlib import Path
from typing import Any, Dict

import numpy as np
from loguru import logger
from PIL import Image

IMAGE_EXTS = {".jpg", ".jpeg", ".png", ".tif", ".tiff"}
STEP = 4  # pixel subsampling step (every 4th pixel)


def compute_vari_from_images(
    calibrated_dir: Path,
    correction_factors: Dict[str, float],
) -> Dict[str, Any]:
    """Compute VARI statistics from all calibrated field images."""
    image_files = [
        f for f in sorted(calibrated_dir.iterdir())
        if f.suffix.lower() in IMAGE_EXTS
    ]
    if not image_files:
        raise ValueError(f"Nenhuma imagem encontrada em {calibrated_dir}")

    all_vari: list[np.ndarray] = []

    for img_path in image_files:
        try:
            pil = Image.open(img_path).convert("RGB")
            arr = np.array(pil, dtype=np.float32)
        except Exception as e:
            logger.warning(f"Ignorando {img_path.name}: {e}")
            continue

        # Subsample pixels
        r = arr[::STEP, ::STEP, 0]
        g = arr[::STEP, ::STEP, 1]
        b = arr[::STEP, ::STEP, 2]

        # Apply radiometric correction factors
        r = np.clip(r * correction_factors.get("R", 1.0), 0, 255)
        g = np.clip(g * correction_factors.get("G", 1.0), 0, 255)
        b = np.clip(b * correction_factors.get("B", 1.0), 0, 255)

        # Normalize to [0, 1]
        r /= 255.0
        g /= 255.0
        b /= 255.0

        # VARI = (G - R) / (G + R - B)
        denom = g + r - b
        vari = np.where(np.abs(denom) > 1e-6, (g - r) / denom, 0.0)

        # Keep valid range
        valid = (vari >= -1.0) & (vari <= 1.0)
        all_vari.append(vari[valid].ravel())
        logger.info(f"  {img_path.name}: {valid.sum():,} pixels VARI válidos")

    if not all_vari:
        raise ValueError("Nenhum pixel VARI válido nas imagens calibradas")

    vari_all = np.concatenate(all_vari)

    result: Dict[str, Any] = {
        "mean": float(np.mean(vari_all)),
        "median": float(np.median(vari_all)),
        "std_dev": float(np.std(vari_all)),
        "min": float(np.min(vari_all)),
        "max": float(np.max(vari_all)),
        "point_count": int(vari_all.size),
        "stratified_by_height": {},  # sem 3D por enquanto
    }

    logger.info(
        f"VARI: mean={result['mean']:.3f}  median={result['median']:.3f}  "
        f"n={result['point_count']:,}"
    )
    return result
