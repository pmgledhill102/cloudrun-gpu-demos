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

| Model name  | Build time | Cold Start Time | Warm Start Time |
|-------------|------------|-----------------|-----------------|
| gemma3-270m | 1m 37s     | 6.0s            | 0.111s          |
| gemma3-1b   | 2m 38s     | 5.7s            | 0.117s          |
| gemma3-4b   | 4m 24s     | 8.3s            | 0.107s          |
| gemma3-12b  | 11m 36s    | 6.0s            | 0.113s          |
| gemma3-27b  | 17m 44s    | 5.6s            | 0.111s          |

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

Extended set of cold start data:

```text
- gemma3-270m - 200 - 5.978177s
- gemma3-1b - 200 - 5.741190s
- gemma3-4b - 200 - 8.348615s
- gemma3-12b - 200 - 6.045743s
- gemma3-27b - 200 - 5.644753s

- gemma3-270m - 200 - 5.727374s
- gemma3-1b - 200 - 8.862012s
- gemma3-4b - 200 - 6.568702s
- gemma3-12b - 200 - 6.094985s
- gemma3-27b - 200 - 5.848404s

- gemma3-270m - 200 - 8.959601s
- gemma3-1b - 200 - 11.279547s
- gemma3-4b - 200 - 5.926045s
- gemma3-12b - 200 - 5.780353s
- gemma3-27b - 200 - 5.680110s

WARM...

Testing gemma3-270m...
  Version endpoint: 0.181069s (HTTP 200)
  Generate endpoint: 5.378158000s ✓

Testing gemma3-1b...
  Version endpoint: 0.193504s (HTTP 200)
  Generate endpoint: 8.463188000s ✓

Testing gemma3-4b...
  Version endpoint: 0.976115s (HTTP 200)
  Generate endpoint: 9.398451000s ✓

Testing gemma3-12b...
  Version endpoint: 1.197687s (HTTP 200)
  Generate endpoint: 24.126324000s ✓

Testing gemma3-27b...
  Version endpoint: 0.183514s (HTTP 200)
  Generate endpoint: 47.024360000s ✓

| Model | Version Time | Generate Time | Status |
|-------|--------------|---------------|--------|
| gemma3-270m   |    8.566034s | 13.598222000s |    ✓ |
| gemma3-1b     |    5.771914s | 11.236318000s |    ✓ |
| gemma3-4b     |    8.802512s | 17.284595000s |    ✓ |
| gemma3-12b    |    5.649461s | 18.923648000s |    ✓ |
| gemma3-27b    |    5.619452s | 54.226750000s |    ✓ |


| gemma3-270m   |    8.567257s | 13.628222000s |    ✓ |
| gemma3-1b     |    9.765963s | 15.579632000s |    ✓ |
| gemma3-4b     |    9.068436s | 18.393505000s |    ✓ |
| gemma3-12b    |    1.494764s | 81.229782000s |    ✓ |
| gemma3-27b    |   10.395295s | 60.321539000s |    ✓ |

|-------|--------------|---------------|--------|
| gemma3-270m   |    0.184210s |   .671633000s |    ✓ |
| gemma3-1b     |    0.149980s |  1.434653000s |    ✓ |
| gemma3-4b     |    0.177169s |  1.495820000s |    ✓ |
| gemma3-12b    |    0.126604s |  1.574567000s |    ✓ |
| gemma3-27b    |    0.198150s |  8.788281000s |    ✓ |

| Model | Version Time | Generate Time | Status |
|-------|--------------|---------------|--------|
| gemma3-270m   |    8.562621s | 13.534883000s |    ✓ |
| gemma3-1b     |    8.511597s | 14.416468000s |    ✓ |
| gemma3-4b     |    8.921779s | 17.507510000s |    ✓ |
| gemma3-12b    |    5.882471s | 18.485919000s |    ✓ |
| gemma3-27b    |    6.340132s | 59.064566000s |    ✓ |
```
