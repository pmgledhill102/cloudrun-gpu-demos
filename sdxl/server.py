# server.py
import io
import base64
import os
import torch
import subprocess
from pathlib import Path
from fastapi import FastAPI
from pydantic import BaseModel, Field
from typing import Optional
from diffusers import (
    StableDiffusionXLPipeline,
    EulerAncestralDiscreteScheduler,
    DPMSolverMultistepScheduler,
    LCMScheduler,
)

# GCS bucket for models
GCS_BUCKET = os.environ.get("GCS_BUCKET", "gs://ai-labs-474813-models")
LOCAL_MODEL_DIR = "/tmp/models"

# Model paths
MODEL_ID = os.environ.get("MODEL_ID", "stabilityai/stable-diffusion-xl-base-1.0")
LCM_LORA_ID = os.environ.get("LCM_LORA_ID", "latent-consistency/lcm-lora-sdxl")
DEFAULT_STEPS = int(os.environ.get("DEFAULT_STEPS", "30"))
DEFAULT_WIDTH = int(os.environ.get("DEFAULT_WIDTH", "1024"))
DEFAULT_HEIGHT = int(os.environ.get("DEFAULT_HEIGHT", "1024"))
DEFAULT_GUIDANCE = float(os.environ.get("DEFAULT_GUIDANCE", "6.0"))

app = FastAPI(title="SDXL + LCM", version="1.0")

# --------- Download models from GCS on startup ----------
def download_models_from_gcs():
    """Download models from GCS to local storage if not already present."""
    local_model_path = Path(LOCAL_MODEL_DIR) / MODEL_ID
    local_lcm_path = Path(LOCAL_MODEL_DIR) / LCM_LORA_ID
    
    if not local_model_path.exists():
        print(f"Downloading SDXL model from GCS to {local_model_path}...")
        local_model_path.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run([
            "gsutil", "-m", "cp", "-r",
            f"{GCS_BUCKET}/models/{MODEL_ID}",
            str(local_model_path.parent) + "/"
        ], check=True)
        print("✓ SDXL model downloaded")
    else:
        print("✓ SDXL model already cached locally")
    
    if not local_lcm_path.exists():
        print(f"Downloading LCM LoRA from GCS to {local_lcm_path}...")
        local_lcm_path.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run([
            "gsutil", "-m", "cp", "-r",
            f"{GCS_BUCKET}/models/{LCM_LORA_ID}",
            str(local_lcm_path.parent) + "/"
        ], check=True)
        print("✓ LCM LoRA downloaded")
    else:
        print("✓ LCM LoRA already cached locally")
    
    return str(local_model_path), str(local_lcm_path)

print("Downloading models from GCS...")
local_model_path, local_lcm_path = download_models_from_gcs()

# --------- Model load (on startup) ----------
print("Loading SDXL from local cache…")
pipe = StableDiffusionXLPipeline.from_pretrained(
    local_model_path,
    torch_dtype=torch.float16,
    use_safetensors=True,
    variant="fp16",
)
pipe.to("cuda")

# Perf toggles
torch.backends.cuda.matmul.allow_tf32 = True
try:
    pipe.enable_vae_tiling()
    pipe.enable_vae_slicing()
except Exception:
    pass

# Default "quality" scheduler for SDXL (good balance)
pipe.scheduler = DPMSolverMultistepScheduler.from_config(pipe.scheduler.config)

# LCM state
lcm_loaded = False

def ensure_lcm_loaded():
    global lcm_loaded, local_lcm_path
    if not lcm_loaded:
        pipe.load_lora_weights(local_lcm_path, use_safetensors=True, weight_name=None)
        lcm_loaded = True
pipe.to("cuda")

# Perf toggles
torch.backends.cuda.matmul.allow_tf32 = True
try:
    pipe.enable_vae_tiling()
    pipe.enable_vae_slicing()
except Exception:
    pass

# Default “quality” scheduler for SDXL (good balance)
# Default "quality" scheduler for SDXL (good balance)
pipe.scheduler = DPMSolverMultistepScheduler.from_config(pipe.scheduler.config)

# LCM state
lcm_loaded = False

def ensure_lcm_loaded():
    global lcm_loaded, local_lcm_path
    if not lcm_loaded:
        pipe.load_lora_weights(local_lcm_path, use_safetensors=True, weight_name=None)
        lcm_loaded = True

def png_bytes_to_b64(img):
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return base64.b64encode(buf.getvalue()).decode("utf-8")

class GenerateRequest(BaseModel):
    prompt: str
    negative_prompt: Optional[str] = Field(default=None)
    width: int = Field(default=DEFAULT_WIDTH, ge=256, le=1536)
    height: int = Field(default=DEFAULT_HEIGHT, ge=256, le=1536)
    steps: int = Field(default=DEFAULT_STEPS, ge=1, le=50)
    guidance: float = Field(default=DEFAULT_GUIDANCE, ge=0.0, le=15.0)
    seed: Optional[int] = None
    use_lcm: bool = Field(default=False)
    scheduler: Optional[str] = Field(
        default=None,
        description="Optional override: one of ['dpmpp2m','euler_a','lcm']"
    )

@app.get("/healthz")
def healthz():
    return {"status": "ok"}

@app.post("/generate")
def generate(req: GenerateRequest):
    # Scheduler / LCM selection
    if req.use_lcm or (req.scheduler and req.scheduler.lower() == "lcm"):
        ensure_lcm_loaded()
        pipe.scheduler = LCMScheduler.from_config(pipe.scheduler.config)
        steps = min(req.steps, 8)  # LCM shines at 2–8 steps
        guidance = 1.0             # LCM expects low/no CFG
    else:
        # Non-LCM schedulers
        if req.scheduler:
            s = req.scheduler.lower()
            if s == "euler_a":
                pipe.scheduler = EulerAncestralDiscreteScheduler.from_config(pipe.scheduler.config)
            elif s == "dpmpp2m":
                pipe.scheduler = DPMSolverMultistepScheduler.from_config(pipe.scheduler.config)
        steps = req.steps
        guidance = req.guidance

    generator = None
    if req.seed is not None:
        generator = torch.Generator(device="cuda").manual_seed(req.seed)

    with torch.inference_mode():
        image = pipe(
            prompt=req.prompt,
            negative_prompt=req.negative_prompt,
            width=req.width,
            height=req.height,
            num_inference_steps=steps,
            guidance_scale=guidance,
            generator=generator,
        ).images[0]

    return {
        "image_base64": png_bytes_to_b64(image),
        "width": req.width,
        "height": req.height,
        "steps": steps,
        "guidance": guidance,
        "scheduler": "lcm" if (req.use_lcm or (req.scheduler and req.scheduler.lower()=="lcm")) else (req.scheduler or "dpmpp2m"),
        "seed": req.seed,
    }
