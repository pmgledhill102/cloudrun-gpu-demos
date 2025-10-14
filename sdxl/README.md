# SDXL Container

## Initial Setup

### 1. Create GCS bucket for models (europe-west1)

```sh
gcloud storage buckets create gs://ai-labs-474813-models --location=europe-west1
```

### 2. Create Artifact Registry repository (europe-west1)

```sh
gcloud artifacts repositories create cloudrun-demos \
  --repository-format=docker \
  --location=europe-west1 \
  --description="Container images for Cloud Run GPU demos in EU"
```

### 3. Grant Cloud Run permission to Artifact Registry

```sh
# Get Cloud Run service account
gcloud projects get-iam-policy ai-labs-474813 --flatten="bindings[].members" --filter="bindings.role:roles/run.serviceAgent" --format="value(bindings.members)"

# Grant permission
gcloud artifacts repositories add-iam-policy-binding cloudrun-demos \
  --location=europe-west1 \
  --member=serviceAccount:service-632128810163@serverless-robot-prod.iam.gserviceaccount.com \
  --role=roles/artifactregistry.reader
```

## Model Management

### Download models from Hugging Face (locally)

```sh
# Set your Hugging Face token (optional but recommended for higher rate limits)
export HF_TOKEN=hf_your_token_here

# Download optimized fp16 models (~8GB instead of 64GB)
cd sdxl
python3 download_models.py
```

### Upload models to GCS

```sh
# Upload to GCS bucket in europe-west1
gsutil -m cp -r ./models gs://ai-labs-474813-models/
```

**Note:** Models are downloaded once and stored in GCS. The Cloud Run service will download them from GCS on startup, avoiding Hugging Face rate limits.

## Build and Deploy

### Build container image

```sh
cd sdxl
gcloud builds submit --config=cloudbuild.yaml --region=europe-west1
```

### Deploy to Cloud Run

```sh
gcloud run deploy sdxl-lcm \
  --image europe-west1-docker.pkg.dev/$PROJECT_ID/cloudrun-demos/sdxl-lcm:latest \
  --region europe-west1 \
  --gpu=1 \
  --gpu-type=nvidia-l4 \
  --memory=16Gi \
  --cpu=4 \
  --concurrency=1 \
  --port=8080 \
  --max-instances=1 \
  --allow-unauthenticated \
  --no-gpu-zonal-redundancy
```

## Run Demos

``` sh
curl -s -X POST $SERVICE_URL/generate \
  -H "Content-Type: application/json" \
  -d '{
    "prompt":"ultra-detailed photo of a yellow car with a black stripe on a mountain road at sunrise",
    "negative_prompt":"blurry, lowres, watermark",
    "width":1024,
    "height":1024,
    "steps":28,
    "guidance":6.5,
    "seed":12345,
    "use_lcm":false,
    "scheduler":"dpmpp2m"
  }' | jq -r '.image_base64' | base64 --decode > out.png
```

## Notes

### Supported GPU types

- `nvidia-l4` (24GB VRAM) - Recommended
- `nvidia-a100-80gb`
- `nvidia-h100-80gb`
- `nvidia-rtx-pro-6000-96gb`

### Architecture

- Models are stored in GCS (`gs://ai-labs-474813-models/`)
- Container downloads models from GCS on startup (fast, no rate limits)
- Models are cached in `/tmp/models` for faster subsequent cold starts
- Using fp16 precision for optimal L4 GPU memory usage (~8GB model size)
