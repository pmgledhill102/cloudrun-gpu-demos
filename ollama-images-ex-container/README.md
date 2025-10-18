# Cloud Run, Ollama and Models

These are demos of how you can containerize Ollama and model, and then host this using
Cloud Run.

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

## Choose a Model

You just need to run one of these, depending on the model you want to use

## Gemma 3

Models:

| Model name  | Build time | Cold Start Time |
|-------------|------------|-----------------|
| gemma3-270m | 1m 37s     | TBD |
| gemma3-1b   | 2m 38s     | TBD |
| gemma3-4b   | 4m 24s     | TBD |
| gemma3-12b  | 11m 36s    | TBD |
| gemma3-27b  | 17m 44s    | TBD |

Build machine is a `E2_HIGHCPU_32` - for speed and advanced networking.

```sh
MODEL_NAME="gemma3"
MODEL_ID="gemma3:270m"
MODEL_ID="gemma3:1b"
MODEL_ID="gemma3:4b"
MODEL_ID="gemma3:12b"
MODEL_ID="gemma3:27b"
```

## Build

Uses Cloud Build to create the container image

```sh
gcloud builds submit \
    --config="cloudbuild.yaml" \
    --substitutions=_MODEL_NAME="$MODEL_NAME",_MODEL_ID="$MODEL_ID",_REGION="$REGION",_GAR_NAME="$GAR_NAME" \
    --async
```

## Deploy

```sh
RUN_ID="${MODEL_ID/:/-}"
gcloud beta run deploy $RUN_ID$ \
  --image $REGION-docker.pkg.dev/$PROJECT_ID/$GAR_NAME/ollama-$MODEL_NAME \
  --concurrency 1 \
  --cpu 8 \
  --set-env-vars OLLAMA_NUM_PARALLEL=1 \
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
