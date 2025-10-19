# Cloud Run, Ollama and Models - GCS FUSE Mount

This demo shows how to run Ollama on Cloud Run by mounting a Google Cloud Storage (GCS) bucket directly using Cloud Storage FUSE. This approach eliminates the need to copy model files, providing instant access to models stored in GCS.

This approach aims to achieve the fastest cold starts by leveraging Cloud Run's native GCS FUSE mounting capability, which makes GCS buckets available as a local filesystem without any copy operation.

## Workflow Overview

1. **Pre-populate GCS**: Use the existing model files in GCS (can reuse from gcs-copy pattern)
2. **Build Generic Image**: Build a container image that mounts GCS bucket via FUSE
3. **Deploy**: Deploy to Cloud Run with volume mount configuration pointing to the GCS bucket

**Benefits:**

- **Fastest cold starts** - no file copying required
- Model files are accessed on-demand from GCS
- Single container image for all model types and sizes
- No local storage duplication
- Automatic updates when models change in GCS

**Trade-offs:**

- Requires Cloud Run GCS FUSE support
- Potential latency for first-time file access (cached afterward)
- GCS storage and egress costs

## Prerequisites

- `gcloud` CLI installed and authenticated
- A GCP project with Cloud Run, Cloud Build, and Artifact Registry APIs enabled
- GPU quota for `Nvidia L4` in your chosen region
- GCS bucket with models already populated (can reuse from gcs-copy pattern)

## Common Vars

```sh
REGION=europe-west1
PROJECT_ID=$(gcloud config get-value project)
GAR_NAME=gpu-demos
SERVICE_ACCOUNT=ollama-identity
GCS_BUCKET_NAME=ollama-models-${PROJECT_ID}  # Must match existing bucket with models
```

## Step 1: Verify GCS Bucket with Models

This pattern reuses the GCS bucket from the `ollama-images-ex-gcs-copy` pattern. If you haven't set it up yet, follow the instructions in that folder's README to:

1. Create the GCS bucket
2. Grant permissions to service accounts
3. Pre-populate the bucket with models using `download-models-into-gcs.sh`

To verify your bucket has models:

```sh
# List models in bucket
gcloud storage ls gs://${GCS_BUCKET_NAME}/models/
```

You should see folders like `gemma3-270m`, `gemma3-1b`, etc.

## Step 2: Build the Image

Build the generic FUSE-enabled runtime image:

```sh
# Option 1: Use the build script
./build-image.sh

# Option 2: Manual build
gcloud builds submit \
    --config="cloudbuild.yaml" \
    --substitutions=_REGION="$REGION",_GAR_NAME="$GAR_NAME"
```

Build time: ~1-2 minutes

## Step 3: Deploy with GCS FUSE Mount

Deploy the service with GCS bucket mounted via FUSE:

```sh
# Option 1: Use the deploy script
./deploy-image.sh

# Option 2: Manual deploy with specific model
MODEL_ID="gemma3:270m"

gcloud beta run deploy ollama-gcs-fuse \
  --image $REGION-docker.pkg.dev/$PROJECT_ID/$GAR_NAME/ollama-gcs-fuse-runtime \
  --concurrency 1 \
  --cpu 8 \
  --set-env-vars OLLAMA_NUM_PARALLEL=1,MODEL_ID="$MODEL_ID",GCS_BUCKET_NAME="${GCS_BUCKET_NAME}" \
  --gpu 1 \
  --gpu-type nvidia-l4 \
  --max-instances 1 \
  --memory 32Gi \
  --no-allow-unauthenticated \
  --no-cpu-throttling \
  --service-account $SERVICE_ACCOUNT@$PROJECT_ID.iam.gserviceaccount.com \
  --timeout=600 \
  --region=$REGION \
  --no-gpu-zonal-redundancy \
  --add-volume=name=gcs-models,type=cloud-storage,bucket=${GCS_BUCKET_NAME} \
  --add-volume-mount=volume=gcs-models,mount-path=/gcs-models
```

**Key differences from gcs-copy pattern:**
- Added `--add-volume` flag to create a GCS FUSE volume
- Added `--add-volume-mount` flag to mount it at `/gcs-models`
- No file copying in entrypoint - direct symlink to mounted path

## Step 4: Test the Service

```sh
PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format="value(projectNumber)")
RUN_URL=https://ollama-gcs-fuse-${PROJECT_NUMBER}.${REGION}.run.app
TOKEN=$(gcloud auth print-identity-token)

# Test with a simple prompt
curl -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"model":"gemma3:270m","prompt":"Say hello","stream":false}' \
  ${RUN_URL}/api/generate | jq -r ".response"
```

## Step 5: Measure Cold Start Times

Run the cold start test script to measure performance:

```sh
./cold-start-times.sh
```

This will:
1. Scale the service down to 0
2. Update the service with a new MODEL_ID
3. Make the first request and measure time until the model responds
4. Repeat for multiple model sizes

## Supported Models

All models stored in your GCS bucket can be used with the same container image:

| Model ID    | Model Size | Cold Start |
|-------------|------------|------------|
| gemma3:270m | Small      | 26s        |
| gemma3:1b   | Small      | 37s        |
| gemma3:4b   | Medium     | 81s        |
| gemma3:12b  | Large      | 167s       |
| gemma3:27b  | X-Large    | 340s       |

Image build time: 1m 1s

## How It Works

1. **Container Build**: Creates an image with Ollama (no models included)
2. **Cloud Run Deploy**: Mounts GCS bucket at `/gcs-models` via FUSE
3. **Container Start**: 
   - Ollama starts immediately
   - Symlinks `/root/.ollama/models` to `/gcs-models/models/${MODEL_NAME}`
   - Models are accessed directly from GCS as if they were local files
4. **First Request**: Model files are read on-demand from GCS via FUSE (cached for subsequent requests)

## Cost Considerations

- **GCS Storage**: Standard storage costs for model files
- **GCS Operations**: Read operations when accessing model files
- **Cloud Run**: Same compute costs as other patterns
- **Egress**: Within-region access is free; cross-region would incur egress charges

## Cleanup

```sh
# Delete the Cloud Run service
gcloud run services delete ollama-gcs-fuse --region=$REGION

# Optionally delete the container image
gcloud artifacts docker images delete \
  $REGION-docker.pkg.dev/$PROJECT_ID/$GAR_NAME/ollama-gcs-fuse-runtime

# Note: Keep the GCS bucket if using other patterns
```

## Troubleshooting

**Model not found:**
- Verify the model exists in GCS: `gcloud storage ls gs://${GCS_BUCKET_NAME}/models/`
- Check that MODEL_ID matches the folder name (e.g., `gemma3:270m` → `gemma3-270m`)

**Permission errors:**
- Verify service account has `roles/storage.objectViewer` on the bucket
- Check that the bucket name is correct in environment variables

**Slow performance:**
- Ensure bucket and Cloud Run service are in the same region
- Check Cloud Run logs for FUSE-related errors
- Verify network connectivity between Cloud Run and GCS
