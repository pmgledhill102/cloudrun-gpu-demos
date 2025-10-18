#!/bin/bash
# Deploy a generic runtime image

# Set variables
REGION=europe-west1
GAR_NAME=gpu-demos
SERVICE_ACCOUNT=ollama-identity
PROJECT_ID=$(gcloud config get-value project)
RUN_SERVICE_NAME=ollama-generic

echo "Starting deployment of generic runtime image..."

  gcloud beta run deploy ${RUN_SERVICE_NAME} \
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
  

echo ""
echo "Deployment completed!"

