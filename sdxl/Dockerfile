# SDXL + LCM on CUDA 12.9.1 runtime (cuDNN)
FROM nvidia/cuda:12.9.1-cudnn-runtime-ubuntu24.04

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    HF_HUB_ENABLE_HF_TRANSFER=1 \
    HUGGINGFACE_HUB_CACHE=/root/.cache/huggingface \
    TRANSFORMERS_CACHE=/root/.cache/huggingface \
    HF_HOME=/root/.cache/huggingface

# System deps and UV installation
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 python3-venv git libgl1 libglib2.0-0 curl apt-transport-https ca-certificates gnupg \
 && echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list \
 && curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key --keyring /usr/share/keyrings/cloud.google.gpg add - \
 && apt-get update && apt-get install -y google-cloud-cli \
 && rm -rf /var/lib/apt/lists/* \
 && curl -LsSf https://astral.sh/uv/install.sh | sh

# Add uv to PATH
ENV PATH="/root/.local/bin:$PATH"

WORKDIR /app

# App files
COPY requirements.txt /app/
RUN uv pip install --system --break-system-packages --index-strategy unsafe-best-match -r requirements.txt

COPY server.py /app/server.py

# For Cloud Run
ENV PORT=8080 \
    MODEL_ID=stabilityai/stable-diffusion-xl-base-1.0 \
    LCM_LORA_ID=latent-consistency/lcm-lora-sdxl \
    DEFAULT_STEPS=30 \
    DEFAULT_WIDTH=1024 \
    DEFAULT_HEIGHT=1024 \
    DEFAULT_GUIDANCE=6.0

# If you need to access gated models or higher rate limits, set HF token at deploy time:
# ENV HF_TOKEN=hf_...

EXPOSE 8080
CMD exec uvicorn server:app --host 0.0.0.0 --port ${PORT}
