# ── Base: Miniconda for pycolmap (requires COLMAP libraries via conda-forge) ──
FROM continuumio/miniconda3:24.9.2-0

WORKDIR /app

# System libs needed by OpenCV headless
RUN apt-get update && apt-get install -y --no-install-recommends \
        libgl1-mesa-glx \
        libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# Install pycolmap (pulls COLMAP C++ libs automatically via conda-forge)
RUN conda install -y -c conda-forge pycolmap \
    && conda clean -afy

# Python dependencies (CPU-only torch for portability)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Application code
COPY app/ ./app/

EXPOSE 8000
