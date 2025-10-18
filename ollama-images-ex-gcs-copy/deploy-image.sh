#!/bin/bash
# Deploy the Ollama image with GCS model copy

# Set variables
REGION=europe-west1
GAR_NAME=gpu-demos
SERVICE_ACCOUNT=ollama-identity
PROJECT_ID=$(gcloud config get-value project)
GCS_BUCKET_NAME=ollama-models-${PROJECT_ID}
RUN_SERVICE_NAME=ollama-gcs

echo "Starting deployment of Ollama with GCS model copy..."
echo "Service Name: ${RUN_SERVICE_NAME}"
echo "GCS Bucket: ${GCS_BUCKET_NAME}"

  gcloud beta run deploy ${RUN_SERVICE_NAME} \
    --image $REGION-docker.pkg.dev/$PROJECT_ID/$GAR_NAME/ollama-gcs-runtime \
    --concurrency 1 \
    --cpu 8 \
    --set-env-vars OLLAMA_NUM_PARALLEL=1,GCS_BUCKET_NAME="${GCS_BUCKET_NAME}" \
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
echo "Service: ${RUN_SERVICE_NAME}"
echo ""
echo "To use a specific model, update the service with:"
echo "gcloud run services update ${RUN_SERVICE_NAME} --region=${REGION} --update-env-vars MODEL_ID=gemma3:270m"

