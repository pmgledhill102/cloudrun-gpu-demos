# Cloud Run, Ollama and Models - Runtime Model Loading

This demo shows how to containerize Ollama with **runtime model loading**. Unlike the ex-container approach,
this builds a single generic container image that pulls the model when the container starts up,
based on the `MODEL_ID` environment variable.

**Benefits:**

- Single container image for all model types and sizes
- Faster build times (no model download during build)
- More flexible - change models without rebuilding
- Smaller container image storage

**Trade-offs:**

- Longer cold start time (model downloaded on first request)
- Requires internet access from Cloud Run

It requires the `gcloud` CLI to be installed, authenticated to your account, and for a project
to be active with the relevant APIs enabled. To see API errors remove any output piping such as
`| jq -r ".response"` - as this assumes a success response.

It also requires that you have requested an increase to your `Total Nvidia L4 GPU allocation, per project per region` quota for region `europe-west1` (or whichever region you are running the demos)

## Common Vars

```sh
REGION=europe-west1
PROJECT_ID=$(gcloud config get-value project)
GAR_NAME=gpu-demos
SERVICE_ACCOUNT=ollama-identity
```

## Common Artifact Registry

```sh
gcloud artifacts repositories create $GAR_NAME \
  --repository-format=docker \
  --location=$REGION
```

## Common Service Account

With no permissions

```sh
gcloud iam service-accounts create $SERVICE_ACCOUNT \
  --display-name="Service Account for Ollama Cloud Run service"
```

## Build

Build the **single generic runtime image** that can be used for all models:

```sh
# Option 1: Use the build script
./build-all.sh

# Option 2: Manual build
gcloud builds submit \
    --config="cloudbuild.yaml" \
    --substitutions=_REGION="$REGION",_GAR_NAME="$GAR_NAME"
```

Build time: ~1-2 minutes (much faster since no model download!)

## Gemma 3 Models

Supported models (all use the same container image):

| Model ID    | Model Size | Build Time | Runtime Pull Time (est) |
|-------------|------------|------------|-------------------------|
| gemma3:270m | Small      | 1m 3s      | 6s |
| gemma3:1b   | Small      | 1m 3s      | 22s |
| gemma3:4b   | Medium     | 1m 3s      | 1m 19s |
| gemma3:12b  | Large      | 1m 3s      | 3m 55s | ** ESTIMATED **
| gemma3:27b  | X-Large    | 1m 3s      | 6m 20s |

## Deploy

Deploy services for all models (or choose specific ones):

```sh
# Option 1: Deploy all models
./deploy-all.sh

# Option 2: Deploy a specific model manually
MODEL_ID="gemma3:270m"
RUN_ID="${MODEL_ID/:/-}"

gcloud beta run deploy $RUN_ID \
  --image $REGION-docker.pkg.dev/$PROJECT_ID/$GAR_NAME/ollama-runtime \
  --concurrency 1 \
  --cpu 8 \
  --set-env-vars OLLAMA_NUM_PARALLEL=1,MODEL_ID="$MODEL_ID" \
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

**Note:** The `MODEL_ID` environment variable tells the container which model to pull at startup.

## Test Model

The Ollama model takes a number of different endpoints you can call - see the docs for more details: <https://github.com/ollama/ollama/blob/main/docs/api.md>

```sh
# Generate URL
# E.g. https://gemma3-270m-632128810163.europe-west1.run.app

PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format="value(projectNumber)")
RUN_URL=https://gemma3-270m-${PROJECT_NUMBER}.${REGION}.run.app

# Version check call to the API
curl http://localhost:9090/api/version

# Basic call to the API
curl http://localhost:9090/api/generate -d '{
  "model": "'"${MODEL_ID}"'",
  "prompt": "can you plan a wedding?",
  "stream": false
}'

# Extract the text out of the JSON body
curl http://localhost:9090/api/generate -d '{
  "model": "'"${MODEL_ID}"'",
  "prompt": "can you plan a wedding?",
  "stream": false
}' | jq -r ".response"

# Streamed basic response
curl http://localhost:9090/api/generate -d '{
  "model": "'"${MODEL_ID}"'",
  "prompt": "can you plan a wedding?",
  "stream": true
}'

# Streamed simplified response
curl -N -s http://localhost:9090/api/generate -d '{
  "model": "'"${MODEL_ID}"'",
  "prompt": "can you plan a holiday to Milan?",
  "stream": true
}' | jq --unbuffered -j ".response"

```
