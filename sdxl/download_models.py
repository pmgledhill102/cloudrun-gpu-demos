#!/usr/bin/env python3
"""
Download SDXL models to local cache, then upload to GCS.
Only downloads fp16 safetensors - optimized for L4 GPU (24GB).
"""
import os
from huggingface_hub import snapshot_download

# Set your HF token if needed
HF_TOKEN = os.environ.get("HF_TOKEN")

print("Downloading SDXL base model (fp16 only)...")
snapshot_download(
    repo_id="stabilityai/stable-diffusion-xl-base-1.0",
    local_dir="./models/stabilityai/stable-diffusion-xl-base-1.0",
    token=HF_TOKEN,
    allow_patterns=[
        "*.json",
        "*.txt",
        "**/*.fp16.safetensors",  # ONLY fp16 safetensors
        "tokenizer/*",
    ],
    ignore_patterns=[
        "*.onnx*",                # No ONNX
        "*openvino*",             # No OpenVINO
        "*.bin",                  # No old PyTorch format
        "*.msgpack",
        "*.h5",
        "*.ckpt",
        "**/diffusion_pytorch_model.safetensors",  # Skip full precision VAE/UNet
        "**/model.safetensors",                     # Skip full precision text encoders
    ],
)

print("✓ SDXL base downloaded")

print("\nDownloading LCM LoRA...")
snapshot_download(
    repo_id="latent-consistency/lcm-lora-sdxl",
    local_dir="./models/latent-consistency/lcm-lora-sdxl",
    token=HF_TOKEN,
    allow_patterns=[
        "*.json",
        "*.txt", 
        "*.safetensors",
    ],
    ignore_patterns=[
        "*.bin",
        "*.onnx*",
    ],
)

print("✓ LCM LoRA downloaded")

print("\n✓ All models downloaded!")
print(f"\nTotal size: ~7-8GB (fp16 only)")
print("\nNext steps:")
print("1. Upload to GCS: gsutil -m cp -r ./models gs://ai-labs-474813-models/")
print("2. Update server.py to load from GCS")
