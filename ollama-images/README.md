# Cloud Run, Ollama and Models

These are demos of how you can containerize Ollama and model, and then host this using
Cloud Run.

It requires the `gcloud` CLI to be installed, authenticated to your account, and for a project
to be active with the relevant APIs enabled. To see API errors remove any output piping such as
`| jq -r ".response"` - as this assumes a success response.

It also requires that you have requested an increase to your `Total Nvidia L4 GPU allocation, per project per region` quota for region `europe-west4` (or whichever region you are running the demos)

## Common Vars

```sh
REGION=europe-west4
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

### Gemma 2

```sh
MODEL_ID="gemma2:9b"
MODEL_NAME="gemma2"
```

### DeepSeek R1 14B Distill

```sh
MODEL_ID="hf.co/bartowski/DeepSeek-R1-Distill-Qwen-14B-GGUF:Q4_K_M"
MODEL_NAME="deepseek"
```

### DeepSeek R1 32B

```sh
MODEL_ID="hf.co/bartowski/DeepSeek-R1-Distill-Qwen-32B-GGUF"
MODEL_NAME="deepseek32b"
```

## Build

Uses Cloud Build to create the container image

```sh
gcloud builds submit \
    --config="cloudbuild.yaml" \
    --substitutions=_MODEL_NAME="$MODEL_NAME",_MODEL_ID="$MODEL_ID",_REGION="$REGION",_GAR_NAME="$GAR_NAME"
```

## Deploy

```sh
gcloud beta run deploy ollama-$MODEL_NAME \
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
  --region=$REGION
```

## Run Proxy

The proxy allows you to have a local port you can call from the CLI or browser, but uses gcloud
authentication so that an unauthenticated endpoint isn't opened to the internet.

```sh
gcloud run services proxy ollama-$MODEL_NAME --port=9090 --region=$REGION
```

## Test Model

The Ollama model takes a number of different endpoints you can call - see the docs for more details: <https://github.com/ollama/ollama/blob/main/docs/api.md>

```sh
curl http://localhost:9090/api/generate -d '{
  "model": "'"${MODEL_ID}"'",
  "prompt": "Why is the sky blue?",
  "stream": false
}' | jq -r ".response"

curl http://localhost:9090/api/generate -d '{
  "model": "'"${MODEL_ID}"'",
  "prompt": "can you plan a wedding?",
  "stream": false
}' | jq -r ".response"

```
