"""
Export pipeline outputs:
  • point_cloud.ply  – ASCII PLY with XYZ, RGB, and VARI scalar per point
  • report.json      – VARI statistics + session metadata
"""
import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, Tuple

import numpy as np
from loguru import logger


def export_results(
    points: np.ndarray,
    vari_data: Dict[str, Any],
    output_dir: Path,
    session_id: str,
) -> Tuple[Path, Path]:
    ply_path = _write_ply(points, vari_data, output_dir)
    report_path = _write_report(vari_data, session_id, output_dir)
    return ply_path, report_path


def _write_ply(points: np.ndarray, vari_data: Dict[str, Any], output_dir: Path) -> Path:
    valid_mask: np.ndarray = vari_data.get("_valid_mask", np.ones(len(points), dtype=bool))
    vari_vals: np.ndarray = vari_data.get("_vari_values", np.zeros(int(valid_mask.sum())))

    pts = points[valid_mask]
    n = len(pts)
    xyz = pts[:, :3]
    rgb = pts[:, 3:6].clip(0, 255).astype(np.uint8)

    ply_path = output_dir / "point_cloud.ply"
    with open(ply_path, "w", encoding="ascii") as f:
        f.write("ply\n")
        f.write("format ascii 1.0\n")
        f.write(f"element vertex {n}\n")
        f.write("property float x\n")
        f.write("property float y\n")
        f.write("property float z\n")
        f.write("property uchar red\n")
        f.write("property uchar green\n")
        f.write("property uchar blue\n")
        f.write("property float vari\n")
        f.write("end_header\n")
        for i in range(n):
            x, y, z = xyz[i]
            r, g, b = rgb[i]
            v = vari_vals[i]
            f.write(f"{x:.4f} {y:.4f} {z:.4f} {r} {g} {b} {v:.6f}\n")

    logger.info(f"PLY exportado: {ply_path} ({n:,} pontos)")
    return ply_path


def _write_report(vari_data: Dict[str, Any], session_id: str, output_dir: Path) -> Path:
    report = {
        "session_id": session_id,
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "vari_statistics": {
            "mean": vari_data["mean"],
            "median": vari_data["median"],
            "std_dev": vari_data["std_dev"],
            "min": vari_data["min"],
            "max": vari_data["max"],
            "point_count": vari_data["point_count"],
        },
        "stratified_by_height": vari_data["stratified_by_height"],
    }

    report_path = output_dir / "report.json"
    report_path.write_text(json.dumps(report, indent=2, ensure_ascii=False))
    logger.info(f"Relatório exportado: {report_path}")
    return report_path
