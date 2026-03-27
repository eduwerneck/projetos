"""
Radiometric calibration using a reflectance panel marked with ArUco markers.

Protocol:
  - Calibration entry photos: panel photographed before fieldwork
  - Calibration exit photos: panel photographed after fieldwork
  - Per-channel correction factors are derived from the mean of both sets
  - Factors are applied to all field photos before SfM
"""
from pathlib import Path
from typing import Dict, List, Optional

import cv2
import numpy as np
from loguru import logger

from ..config import settings

_ARUCO_DICT_IDS = {
    "DICT_4X4_50": cv2.aruco.DICT_4X4_50,
    "DICT_4X4_100": cv2.aruco.DICT_4X4_100,
    "DICT_5X5_50": cv2.aruco.DICT_5X5_50,
    "DICT_5X5_100": cv2.aruco.DICT_5X5_100,
}

_IMG_EXTS = {".jpg", ".jpeg", ".png", ".tif", ".tiff"}


def _glob_images(directory: Path) -> List[Path]:
    return [p for p in directory.iterdir() if p.suffix.lower() in _IMG_EXTS]


def _detect_panel_mask(image: np.ndarray) -> Optional[np.ndarray]:
    """Return a mask covering the reflectance panel interior, or None."""
    dict_id = _ARUCO_DICT_IDS.get(settings.aruco_dict if hasattr(settings, "aruco_dict") else "DICT_4X4_50",
                                   cv2.aruco.DICT_4X4_50)
    aruco_dict = cv2.aruco.getPredefinedDictionary(dict_id)
    detector = cv2.aruco.ArucoDetector(aruco_dict, cv2.aruco.DetectorParameters())

    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    corners, ids, _ = detector.detectMarkers(gray)

    if ids is None or len(ids) < 4:
        n = 0 if ids is None else len(ids)
        logger.warning(f"ArUco: encontrou {n} marcadores (esperado ≥4). Usando centro da imagem.")
        return None

    all_corners = np.concatenate([c.reshape(-1, 2) for c in corners])
    hull = cv2.convexHull(all_corners.astype(np.int32))
    mask = np.zeros(gray.shape, dtype=np.uint8)
    cv2.fillConvexPoly(mask, hull, 255)
    # Erode border to avoid marker pixels contaminating panel reading
    kernel = np.ones((15, 15), np.uint8)
    mask = cv2.erode(mask, kernel)
    return mask


def _fallback_center_mask(image: np.ndarray) -> np.ndarray:
    """Center 50% × 50% crop as fallback when ArUco detection fails."""
    h, w = image.shape[:2]
    mask = np.zeros((h, w), dtype=np.uint8)
    cv2.rectangle(mask, (w // 4, h // 4), (3 * w // 4, 3 * h // 4), 255, -1)
    return mask


def _measure_panel(image_paths: List[Path]) -> Dict[str, List[float]]:
    channel_samples: Dict[str, List[float]] = {"B": [], "G": [], "R": []}
    for path in image_paths:
        img = cv2.imread(str(path))
        if img is None:
            logger.warning(f"Não foi possível ler: {path}")
            continue
        mask = _detect_panel_mask(img) or _fallback_center_mask(img)
        for i, ch in enumerate(["B", "G", "R"]):
            pixels = img[:, :, i][mask > 0].astype(np.float64)
            if pixels.size:
                channel_samples[ch].append(float(np.mean(pixels)))
    return channel_samples


def _derive_factors(channel_samples: Dict[str, List[float]]) -> Dict[str, float]:
    """
    Correction factor maps sensor DN to reflectance-corrected DN.
    factor_ch = (255 × known_reflectance) / mean_panel_DN_ch
    """
    known = settings.panel_reflectance
    factors: Dict[str, float] = {}
    for ch, samples in channel_samples.items():
        if samples:
            mean_dn = float(np.mean(samples))
            factors[ch] = (255.0 * known) / mean_dn if mean_dn > 1 else 1.0
        else:
            factors[ch] = 1.0
    logger.info(f"Fatores de correção radiométrica: {factors}")
    return factors


def _apply_correction(image: np.ndarray, factors: Dict[str, float]) -> np.ndarray:
    out = image.astype(np.float32)
    out[:, :, 0] *= factors["B"]
    out[:, :, 1] *= factors["G"]
    out[:, :, 2] *= factors["R"]
    return np.clip(out, 0, 255).astype(np.uint8)


def calibrate_photos(
    cal_entry_dir: Path,
    cal_exit_dir: Path,
    output_dir: Path,
    field_dir: Path,
) -> Dict[str, float]:
    """
    1. Compute correction factors from calibration panels (entry + exit).
    2. Apply correction to every field photo → output_dir.
    3. Return the factors dict {"B": f, "G": f, "R": f}.
    """
    cal_images = _glob_images(cal_entry_dir) + _glob_images(cal_exit_dir)

    if not cal_images:
        logger.warning("Nenhuma foto de calibração encontrada. Aplicando correção identidade.")
        factors: Dict[str, float] = {"B": 1.0, "G": 1.0, "R": 1.0}
    else:
        samples = _measure_panel(cal_images)
        factors = _derive_factors(samples)

    field_images = _glob_images(field_dir)
    if not field_images:
        raise ValueError("Nenhuma foto de campo encontrada em: " + str(field_dir))

    for path in field_images:
        img = cv2.imread(str(path))
        if img is None:
            logger.warning(f"Ignorando imagem ilegível: {path}")
            continue
        corrected = _apply_correction(img, factors)
        cv2.imwrite(str(output_dir / path.name), corrected)

    logger.info(f"{len(field_images)} fotos calibradas → {output_dir}")
    return factors
