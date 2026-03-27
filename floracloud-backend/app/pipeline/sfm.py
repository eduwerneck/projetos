"""
Structure from Motion via pycolmap.

Steps:
  1. Feature extraction (SIFT, up to 8 192 features/image)
  2. Exhaustive feature matching
  3. Incremental mapping
  4. Return the reconstruction with the most registered images
"""
from pathlib import Path

import pycolmap
from loguru import logger


def run_sfm(image_dir: Path, output_dir: Path) -> pycolmap.Reconstruction:
    db_path = output_dir / "database.db"
    sparse_dir = output_dir / "sparse"
    sparse_dir.mkdir(exist_ok=True)

    logger.info(f"SfM – extração de features: {image_dir}")
    pycolmap.extract_features(
        database_path=db_path,
        image_path=image_dir,
        sift_options={"max_num_features": 8192},
    )

    logger.info("SfM – matching exaustivo...")
    pycolmap.match_exhaustive(database_path=db_path)

    logger.info("SfM – mapeamento incremental...")
    reconstructions = pycolmap.incremental_mapping(
        database_path=db_path,
        image_path=image_dir,
        output_path=sparse_dir,
    )

    if not reconstructions:
        raise RuntimeError(
            "SfM falhou: nenhuma reconstrução gerada. "
            "Verifique se as fotos têm sobreposição suficiente (≥60%) e "
            "se foram tiradas seguindo o protocolo de campo."
        )

    best = max(reconstructions.values(), key=lambda r: r.num_reg_images())
    logger.info(
        f"Melhor reconstrução: {best.num_reg_images()} imagens registradas, "
        f"{best.num_points3D()} pontos 3D"
    )
    return best
