"""
VARI – Visible Atmospherically Resistant Index
  VARI = (G - R) / (G + R - B)

Input: calibrated field images directory.
Output: statistics dict + colorized VARI map image.
"""
from pathlib import Path
from typing import Any, Dict

import numpy as np
from loguru import logger
from PIL import Image, ImageDraw

IMAGE_EXTS = {".jpg", ".jpeg", ".png", ".tif", ".tiff"}
STEP = 4       # pixel subsampling for statistics
THUMB_W = 300  # thumbnail width for VARI map mosaic
COLS = 3       # columns in mosaic


def _apply_colormap(vari: np.ndarray) -> np.ndarray:
    """Map VARI [-1,1] to RGB: red → yellow → green."""
    t = np.clip((vari + 1.0) / 2.0, 0.0, 1.0)
    rgb = np.zeros((*vari.shape, 3), dtype=np.uint8)
    lo = t <= 0.5
    t1 = t[lo] / 0.5
    rgb[lo, 0] = 255
    rgb[lo, 1] = (t1 * 255).astype(np.uint8)
    hi = ~lo
    t2 = (t[hi] - 0.5) / 0.5
    rgb[hi, 0] = ((1 - t2) * 255).astype(np.uint8)
    rgb[hi, 1] = 255
    return rgb


def _make_colorbar(width: int) -> np.ndarray:
    """Return a (70, width, 3) uint8 colorbar with labels."""
    bar_h, label_h = 30, 40
    total_h = bar_h + label_h
    bar = np.zeros((total_h, width, 3), dtype=np.uint8)
    # gradient
    xs = np.linspace(0, 1, width)
    lo = xs <= 0.5
    bar[:bar_h, lo, 0] = 255
    bar[:bar_h, lo, 1] = (xs[lo] / 0.5 * 255).astype(np.uint8)
    hi = ~lo
    bar[:bar_h, hi, 0] = ((1 - (xs[hi] - 0.5) / 0.5) * 255).astype(np.uint8)
    bar[:bar_h, hi, 1] = 255
    # white label area
    bar[bar_h:, :] = 255
    pil = Image.fromarray(bar)
    draw = ImageDraw.Draw(pil)
    font = None  # use PIL default
    labels = [("-1.0", 0.0), ("-0.5", 0.125), ("0.0", 0.5), ("+0.5", 0.875), ("+1.0", 1.0)]
    for text, pos in labels:
        x = max(0, min(width - 20, int(pos * (width - 1)) - 10))
        draw.text((x, bar_h + 5), text, fill=(40, 40, 40), font=font)
    return np.array(pil)


def generate_vari_map(
    calibrated_dir: Path,
    correction_factors: Dict[str, float],
    output_dir: Path,
) -> Path:
    """Generate colorized VARI mosaic PNG with colorbar."""
    image_files = [
        f for f in sorted(calibrated_dir.iterdir())
        if f.suffix.lower() in IMAGE_EXTS
    ]
    if not image_files:
        raise ValueError(f"Nenhuma imagem em {calibrated_dir}")

    thumbs: list[np.ndarray] = []
    thumb_h = None

    for img_path in image_files:
        try:
            arr = np.array(Image.open(img_path).convert("RGB"), dtype=np.float32)
        except Exception as e:
            logger.warning(f"Ignorando {img_path.name}: {e}")
            continue
        h, w = arr.shape[:2]
        r = np.clip(arr[:, :, 0] * correction_factors.get("R", 1.0), 0, 255) / 255.0
        g = np.clip(arr[:, :, 1] * correction_factors.get("G", 1.0), 0, 255) / 255.0
        b = np.clip(arr[:, :, 2] * correction_factors.get("B", 1.0), 0, 255) / 255.0
        denom = g + r - b
        vari = np.where(np.abs(denom) > 1e-6, (g - r) / denom, 0.0)
        colored = _apply_colormap(np.clip(vari, -1.0, 1.0))
        ratio = THUMB_W / w
        th = max(1, int(h * ratio))
        pil = Image.fromarray(colored).resize((THUMB_W, th), Image.LANCZOS)
        if thumb_h is None:
            thumb_h = th
        thumbs.append(np.array(pil.resize((THUMB_W, thumb_h), Image.LANCZOS)))

    if not thumbs:
        raise ValueError("Nenhuma imagem VARI gerada")

    # Build mosaic
    blank = np.zeros((thumb_h, THUMB_W, 3), dtype=np.uint8)
    rows = []
    for i in range(0, len(thumbs), COLS):
        row = thumbs[i:i + COLS]
        while len(row) < COLS:
            row.append(blank)
        rows.append(np.concatenate(row, axis=1))
    mosaic = np.concatenate(rows, axis=0)

    # Append colorbar
    colorbar = _make_colorbar(mosaic.shape[1])
    final = np.concatenate([mosaic, colorbar], axis=0)

    out_path = output_dir / "vari_map.png"
    Image.fromarray(final).save(out_path, optimize=True)
    logger.info(f"Mapa VARI salvo: {out_path} ({final.shape[1]}×{final.shape[0]}px)")
    return out_path


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
            arr = np.array(Image.open(img_path).convert("RGB"), dtype=np.float32)
        except Exception as e:
            logger.warning(f"Ignorando {img_path.name}: {e}")
            continue
        r = np.clip(arr[::STEP, ::STEP, 0] * correction_factors.get("R", 1.0), 0, 255) / 255.0
        g = np.clip(arr[::STEP, ::STEP, 1] * correction_factors.get("G", 1.0), 0, 255) / 255.0
        b = np.clip(arr[::STEP, ::STEP, 2] * correction_factors.get("B", 1.0), 0, 255) / 255.0
        denom = g + r - b
        vari = np.where(np.abs(denom) > 1e-6, (g - r) / denom, 0.0)
        valid = (vari >= -1.0) & (vari <= 1.0)
        all_vari.append(vari[valid].ravel())
        logger.info(f"  {img_path.name}: {valid.sum():,} pixels VARI válidos")

    if not all_vari:
        raise ValueError("Nenhum pixel VARI válido nas imagens calibradas")

    v = np.concatenate(all_vari)
    result: Dict[str, Any] = {
        "mean": float(np.mean(v)),
        "median": float(np.median(v)),
        "std_dev": float(np.std(v)),
        "min": float(np.min(v)),
        "max": float(np.max(v)),
        "point_count": int(v.size),
        "stratified_by_height": {},
    }
    logger.info(f"VARI: mean={result['mean']:.3f}  n={result['point_count']:,}")
    return result
