#!/bin/bash
# Deploy the Ollama image with GCS FUSE mount

# Set variables
REGION=europe-west1
GAR_NAME=gpu-demos
SERVICE_ACCOUNT=ollama-identity
PROJECT_ID=$(gcloud config get-value project)
GCS_BUCKET_NAME=ollama-models-${PROJECT_ID}
RUN_SERVICE_NAME=ollama-gcs-fuse
MODEL_ID=${1:-"gemma3:270m"}  # Default to gemma3:270m if not specified

echo "Starting deployment of Ollama with GCS FUSE mount..."
echo "Service Name: ${RUN_SERVICE_NAME}"
echo "GCS Bucket: ${GCS_BUCKET_NAME}"
echo "Model ID: ${MODEL_ID}"

gcloud beta run deploy ${RUN_SERVICE_NAME} \
  --image $REGION-docker.pkg.dev/$PROJECT_ID/$GAR_NAME/ollama-gcs-fuse-runtime \
  --concurrency 1 \
  --cpu 8 \
  --set-env-vars OLLAMA_NUM_PARALLEL=1,MODEL_ID="${MODEL_ID}",GCS_BUCKET_NAME="${GCS_BUCKET_NAME}" \
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

echo ""
echo "Deployment completed!"
echo "Service: ${RUN_SERVICE_NAME}"
echo ""
echo "To test the service:"
echo "PROJECT_NUMBER=\$(gcloud projects describe $PROJECT_ID --format=\"value(projectNumber)\")"
echo "RUN_URL=https://${RUN_SERVICE_NAME}-\${PROJECT_NUMBER}.${REGION}.run.app"
echo "TOKEN=\$(gcloud auth print-identity-token)"
echo ""
echo "curl -H \"Authorization: Bearer \$TOKEN\" \\"
echo "  -H \"Content-Type: application/json\" \\"
echo "  -d '{\"model\":\"${MODEL_ID}\",\"prompt\":\"Say hello\",\"stream\":false}' \\"
echo "  \${RUN_URL}/api/generate | jq -r \".response\""
