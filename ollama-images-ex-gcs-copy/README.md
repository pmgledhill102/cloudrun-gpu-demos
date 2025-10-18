# Cloud Run, Ollama and Models - GCS Copy at Runtime

This demo shows how to run Ollama on Cloud Run by copying model files from a Google Cloud Storage (GCS) bucket when the container starts.

This approach aims to achieve faster cold starts than pulling from the internet by leveraging high-speed networking between GCS and Cloud Run within the same region.

## Workflow Overview

1. **Pre-populate GCS**: A one-time Cloud Build job downloads an Ollama model and copies its files into a specified GCS bucket.
2. **Build Generic Image**: A separate Cloud Build job builds a single, generic container image that contains the `gcloud` CLI but no models.
3. **Deploy**: Deploy the generic image to Cloud Run, providing an environment variable (`GCS_BUCKET_PATH`) that points to the model's location in GCS. On startup, the container copies the model files from GCS into its local filesystem and then starts Ollama.

**Benefits:**

- Potentially faster cold starts than internet downloads (same-region GCS transfer)
- Single container image for all model types and sizes
- Faster build times (no model download during build)
- Models stored centrally in GCS for reuse

**Trade-offs:**

- Requires GCS bucket setup and storage costs
- Initial model upload time to GCS
- Cold start still includes file copy operation

## Prerequisites

- `gcloud` CLI installed and authenticated
- A GCP project with Cloud Run, Cloud Build, and Artifact Registry APIs enabled
- GPU quota for `Nvidia L4` in your chosen region

## Common Vars

```sh
REGION=europe-west1
PROJECT_ID=$(gcloud config get-value project)
GAR_NAME=gpu-demos
SERVICE_ACCOUNT=ollama-identity
GCS_BUCKET_NAME=ollama-models-${PROJECT_ID}  # Must be globally unique
```

## Step 1: Create GCS Bucket

Create a GCS bucket in the same region as your Cloud Run services for optimal performance:

```sh
# Create a new bucket
gcloud storage buckets create gs://${GCS_BUCKET_NAME} \
  --location=${REGION} \
  --uniform-bucket-level-access

# Or reuse an existing bucket from another stream
# Just set GCS_BUCKET_NAME to your existing bucket name
```

## Step 2: Grant Service Account Permissions

### Cloud Run Service Account (for reading models)

The Cloud Run service account needs permission to read from the GCS bucket:

```sh
# Create the service account if it doesn't exist
gcloud iam service-accounts create $SERVICE_ACCOUNT \
  --display-name="Service Account for Ollama Cloud Run service"

# Grant Storage Object Viewer role to read from the bucket
gcloud storage buckets add-iam-policy-binding gs://${GCS_BUCKET_NAME} \
  --member="serviceAccount:${SERVICE_ACCOUNT}@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/storage.objectViewer"
```

### Cloud Build Service Account (for uploading models)

The Cloud Build service account needs permission to write to the GCS bucket:

```sh
# Get the Cloud Build service account email
PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format="value(projectNumber)")
CLOUDBUILD_SA="${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com"

# Grant Storage Object Admin role to write to the bucket
gcloud storage buckets add-iam-policy-binding gs://${GCS_BUCKET_NAME} \
  --member="serviceAccount:${CLOUDBUILD_SA}" \
  --role="roles/storage.objectAdmin"
```

## Step 3: Pre-populate GCS with Models

Run a Cloud Build job to download models from Ollama and upload them to GCS. This avoids downloading large models to your laptop.

### Upload a Single Model

```sh
# Choose your model
MODEL_ID="gemma3:270m"

# Run the GCS populate build job (runs in the same region as the bucket)
gcloud builds submit \
    --config="cloudbuild-gcs-populate.yaml" \
    --region="${REGION}" \
    --substitutions=_MODEL_ID="${MODEL_ID}",_GCS_BUCKET_NAME="${GCS_BUCKET_NAME}"
```

**Note:** Each model will be stored in its own subfolder based on the model ID:

- `gemma3:270m` → `gs://your-bucket/models/gemma3-270m/`
- `gemma3:1b` → `gs://your-bucket/models/gemma3-1b/`
- etc.

### Supported Models

Run the above command for each model you want to make available:

| Model ID    | Model Size | Upload Time |
|-------------|------------|-------------|
| gemma3:270m | Small      | 2m 4s       |
| gemma3:1b   | Small      | 2m 6s       |
| gemma3:4b   | Medium     | 2m 26s      |
| gemma3:12b  | Large      | 3m 52s      |
| gemma3:27b  | X-Large    | 7m 13s      |

Common image build time: 2m 9s

Model           | Cold Start Time | GCS Copy Time | Status
----------------+-----------------+---------------+--------------
gemma3-270m     | 37s             | 9s            | ✓ Success
gemma3-1b       | 47s             | 17s           | ✓ Success
gemma3-4b       | 82s             | 58s           | ✓ Success
gemma3-12b      | 193s            | 136s          | ✓ Success
gemma3-27b      | TIMEOUT         | ??            | ✗ Failed

## Step 4: Common Artifact Registry

Create the Artifact Registry repository if it doesn't exist:

```sh
gcloud artifacts repositories create $GAR_NAME \
  --repository-format=docker \
  --location=$REGION
```

## Step 5: Build the Generic Runtime Image

Build the single, reusable container image that will be used for all deployments:

```sh
# Option 1: Use the build script
./build-image.sh

# Option 2: Manual build
gcloud builds submit \
    --config="cloudbuild.yaml" \
    --substitutions=_REGION="$REGION",_GAR_NAME="$GAR_NAME"
```

This only needs to be done once. The resulting image, `ollama-gcs-runtime`, can be used for any model stored in your GCS bucket.

Build time: ~2-3 minutes

## Step 6: Deploy to Cloud Run

Deploy a service that will copy the model from GCS at startup:

```sh
# Set the model you want to deploy
MODEL_ID="gemma3:270m"
RUN_ID="${MODEL_ID/:/-}"
MODEL_PATH="${MODEL_ID/:/-}"

# Construct the GCS path where the model is stored (in its own subfolder)
GCS_PATH="gs://${GCS_BUCKET_NAME}/models/${MODEL_PATH}"

# Deploy the service
gcloud beta run deploy $RUN_ID \
  --image $REGION-docker.pkg.dev/$PROJECT_ID/$GAR_NAME/ollama-gcs-runtime \
  --concurrency 1 \
  --cpu 8 \
  --set-env-vars "GCS_BUCKET_PATH=${GCS_PATH}" \
  --gpu 1 \
  --gpu-type nvidia-l4 \
  --max-instances 1 \
  --memory 32Gi \
  --no-allow-unauthenticated \
  --no-cpu-throttling \
  --service-account $SERVICE_ACCOUNT@$PROJECT_ID.iam.gserviceaccount.com \
  --timeout=600 \
  --region=$REGION \
  --no-gpu-zonal-redundancy
```

**Note:**

- Each model is stored in its own subfolder: `gs://bucket/models/gemma3-270m/`, `gs://bucket/models/gemma3-1b/`, etc.
- The `GCS_BUCKET_PATH` environment variable tells the container where to copy the model files from.

## Test Model

The Ollama model takes a number of different endpoints you can call - see the docs for more details: <https://github.com/ollama/ollama/blob/main/docs/api.md>

```sh
# Generate URL
PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format="value(projectNumber)")
RUN_URL=https://${RUN_ID}-${PROJECT_NUMBER}.${REGION}.run.app
TOKEN=$(gcloud auth print-identity-token)

# Version check call to the API
curl -H "Authorization: Bearer $TOKEN" ${RUN_URL}/api/version

# Basic call to the API
curl -H "Authorization: Bearer $TOKEN" ${RUN_URL}/api/generate -d '{
  "model": "'"${MODEL_ID}"'",
  "prompt": "Tell me a joke",
  "stream": false
}' | jq -r ".response"

# Streamed response
curl -N -s -H "Authorization: Bearer $TOKEN" ${RUN_URL}/api/generate -d '{
  "model": "'"${MODEL_ID}"'",
  "prompt": "Tell me a short story",
  "stream": true
}' | jq --unbuffered -j ".response"
```
