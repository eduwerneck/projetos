"""
Dense depth estimation with Depth Anything V2 (HuggingFace Transformers).

For each image registered by SfM:
  1. Predict a relative depth map (monocular).
  2. Scale it to metric depth using sparse SfM points visible in that image.
  3. Back-project every pixel to 3D camera space using pinhole intrinsics.
  4. Transform to world space using the camera pose from SfM.

Returns an (N, 6) float32 array: [X, Y, Z, R, G, B].
"""
from pathlib import Path
from typing import Dict, Optional, Tuple

import numpy as np
import pycolmap
import torch
from loguru import logger
from PIL import Image

from ..config import settings

_depth_pipe = None  # lazily loaded


def _load_depth_pipeline():
    global _depth_pipe
    if _depth_pipe is None:
        from transformers import pipeline as hf_pipeline

        device = "cuda" if torch.cuda.is_available() else "cpu"
        logger.info(f"Carregando modelo de profundidade '{settings.depth_model_name}' em {device}…")
        _depth_pipe = hf_pipeline(
            "depth-estimation",
            model=settings.depth_model_name,
            device=device,
        )
        logger.info("Modelo carregado.")
    return _depth_pipe


def _predict_depth(image_path: Path) -> np.ndarray:
    """Returns a (H, W) float32 relative depth map."""
    pipe = _load_depth_pipeline()
    pil = Image.open(image_path).convert("RGB")
    out = pipe(pil)
    depth = np.array(out["depth"], dtype=np.float32)
    return depth


def _get_intrinsics(camera: pycolmap.Camera) -> Tuple[float, float, float, float]:
    """Extract (fx, fy, cx, cy) from a pycolmap Camera, handling common models."""
    params = camera.params
    w, h = camera.width, camera.height
    if len(params) >= 4:
        return float(params[0]), float(params[1]), float(params[2]), float(params[3])
    if len(params) == 3:
        f, cx, cy = float(params[0]), float(params[1]), float(params[2])
        return f, f, cx, cy
    f = float(params[0]) if params else float(max(w, h)) * 1.2
    return f, f, w / 2.0, h / 2.0


def _get_pose(image: pycolmap.Image):
    """Get (R, t) from pycolmap Image, compatible with multiple API versions."""
    try:
        pose = image.cam_from_world
        if callable(pose):
            pose = pose()
        return np.array(pose.rotation.matrix()), np.array(pose.translation)
    except AttributeError:
        pass
    # Fallback: older pycolmap uses qvec/tvec directly
    try:
        R = pycolmap.qvec_to_rotmat(image.qvec)
        return R, np.array(image.tvec)
    except Exception:
        pass
    # Last resort: rotation_matrix() method
    R = np.array(image.rotation_matrix())
    t = np.array(image.tvec)
    return R, t


def _scale_depth(
    depth_rel: np.ndarray,
    image: pycolmap.Image,
    reconstruction: pycolmap.Reconstruction,
    img_w: int,
    img_h: int,
) -> np.ndarray:
    """Scale relative depth to metric using visible SfM sparse points."""
    R, t = _get_pose(image)

    sfm_d, pred_d = [], []
    for point2D in image.points2D:
        if not point2D.has_point3D():
            continue
        p3d = reconstruction.points3D[point2D.point3D_id].xyz
        cam_pt = R @ p3d + t
        if cam_pt[2] <= 0:
            continue
        u, v = point2D.xy
        pi, pj = int(round(v)), int(round(u))
        if 0 <= pi < img_h and 0 <= pj < img_w:
            pd = float(depth_rel[pi, pj])
            if pd > 0:
                sfm_d.append(cam_pt[2])
                pred_d.append(pd)

    if len(sfm_d) < 3:
        logger.warning("Pontos SfM insuficientes para escala métrica; usando escala relativa.")
        scale = 1.0
    else:
        scale = float(np.median(np.array(sfm_d) / np.array(pred_d)))

    return depth_rel * scale


def estimate_depth_and_fuse(
    reconstruction: pycolmap.Reconstruction,
    image_dir: Path,
    output_dir: Path,  # unused but kept for future caching
) -> np.ndarray:
    """
    Returns (N, 6) float32 array: [X, Y, Z, R, G, B] in world coordinates.
    Subsamples every 4th pixel for tractable point counts.
    """
    all_pts: list[np.ndarray] = []
    STEP = 4  # pixel subsampling step

    for image in sorted(reconstruction.images.values(), key=lambda i: i.name):
        img_path = image_dir / image.name
        if not img_path.exists():
            logger.warning(f"Imagem não encontrada: {img_path}")
            continue

        pil_img = Image.open(img_path).convert("RGB")
        np_img = np.array(pil_img, dtype=np.float32)
        h, w = np_img.shape[:2]

        # Depth prediction
        depth_rel = _predict_depth(img_path)
        # Resize depth to image resolution
        depth_pil = Image.fromarray(depth_rel).resize((w, h), Image.BILINEAR)
        depth_rel = np.array(depth_pil, dtype=np.float32)

        # Metric scale
        depth = _scale_depth(depth_rel, image, reconstruction, w, h)

        # Intrinsics
        camera = reconstruction.cameras[image.camera_id]
        fx, fy, cx, cy = _get_intrinsics(camera)

        # Pose: cam_from_world  →  R, t  →  R_inv (= R^T), t_inv
        R, t = _get_pose(image)
        R_inv = R.T
        t_inv = -(R_inv @ t)

        # Subsampled pixel grid (flat)
        us = np.arange(0, w, STEP)
        vs = np.arange(0, h, STEP)
        ug, vg = np.meshgrid(us, vs)
        uf = ug.ravel()
        vf = vg.ravel()
        df = depth[vf, uf]

        valid = df > 0
        uf, vf, df = uf[valid], vf[valid], df[valid]

        # Back-project to camera space
        X = (uf - cx) * df / fx
        Y = (vf - cy) * df / fy
        Z = df
        pts_cam = np.stack([X, Y, Z], axis=1)  # (N, 3)

        # Transform to world space
        pts_world = (R_inv @ pts_cam.T).T + t_inv  # (N, 3)

        # Colors (RGB)
        colors = np_img[vf, uf]  # (N, 3)

        all_pts.append(np.concatenate([pts_world, colors], axis=1))
        logger.info(f"  {image.name}: {len(pts_world):,} pontos fundidos")

    if not all_pts:
        raise RuntimeError(
            "Nenhum ponto 3D gerado. Verifique a reconstrução SfM e as imagens de campo."
        )

    return np.concatenate(all_pts, axis=0).astype(np.float32)
