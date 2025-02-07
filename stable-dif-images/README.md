# Stable Diffusion Images

These are demos of how you can containerize the Stable Diffusion model, and then host this using
Cloud Run.

It requires the `gcloud` CLI to be installed, authenticated to your account, and for a project
to be active with the relevant APIs enabled. To see API errors remove any output piping such as
`| jq -r ".response"` - as this assumes a success response.

It also requires that you have requested an increase to your `Total Nvidia L4 GPU allocation, per project per region` quota for region `europe-west4` (or whichever region you are running the demos)

## Set Vars

REGION=europe-west4
PROJECT_ID=$(gcloud config get-value project)
GAR_NAME=gpu-demos
SERVICE_ACCOUNT=sd-identity

## Common Service Account

With no permissions

```sh
gcloud iam service-accounts create $SERVICE_ACCOUNT \
  --display-name="Service Account for Service Diffusion Cloud Run service"
```

## Build Image

```sh
gcloud builds submit \
    --config="cloudbuild.yaml" \
    --substitutions=_REGION="$REGION",_GAR_NAME="$GAR_NAME"
```

## Run Container

```sh
gcloud beta run deploy stable-diffusion-service \
    --image $REGION-docker.pkg.dev/$PROJECT_ID/$GAR_NAME/stable-d \
    --concurrency 1 \
    --cpu 8 \
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

```sh
gcloud run services proxy stable-diffusion-service --port=9090 --region=$REGION
```

## Hit with browser

The code converts hyphens to space characters, to make it easier to write and read in the
browser address bar.

```sh
host:9090/generate?prompt=angry-scary-dog-chasing-a-postman
```
