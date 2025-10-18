#!/bin/bash
# Deploy all models

# Set variables
REGION=europe-west1
GAR_NAME=gpu-demos
SERVICE_ACCOUNT=ollama-identity
PROJECT_ID=$(gcloud config get-value project)

# Model variables
MODEL_FAMILY="gemma3"
MODEL_PARAMS_LIST=("270m" "1b" "4b" "12b" "27b")

# Array to track deployed services
DEPLOYED_SERVICES=()

echo "Starting deployment of all model images..."

for MODEL_PARAMS in "${MODEL_PARAMS_LIST[@]}"
do
  MODEL_ID="$MODEL_FAMILY:$MODEL_PARAMS"
  MODEL_NAME="$MODEL_FAMILY-$MODEL_PARAMS"

  echo "- $MODEL_NAME:$MODEL_PARAMS"
  RUN_ID="${MODEL_ID/:/-}"
  gcloud beta run deploy $RUN_ID \
    --image $REGION-docker.pkg.dev/$PROJECT_ID/$GAR_NAME/ollama-$RUN_ID \
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
    --no-gpu-zonal-redundancy \
    --async
  
  # Track the deployed service
  DEPLOYED_SERVICES+=("$RUN_ID")
done

echo ""
echo "Waiting for deployments to complete..."

for SERVICE in "${DEPLOYED_SERVICES[@]}"
do
  echo "- $SERVICE"
  
  DEPLOYMENT_FAILED=false
  while true; do
    STATUS=$(gcloud beta run services describe $SERVICE \
      --region=$REGION \
      --format="value(status.conditions[0].status)" 2>/dev/null)
    
    READY=$(gcloud beta run services describe $SERVICE \
      --region=$REGION \
      --format="value(status.conditions[0].type)" 2>/dev/null)
    
    if [[ "$READY" == "Ready" && "$STATUS" == "True" ]]; then
      break
    elif [[ "$STATUS" == "False" ]]; then
      DEPLOYMENT_FAILED=true
      MESSAGE=$(gcloud beta run services describe $SERVICE \
        --region=$REGION \
        --format="value(status.conditions[0].message)" 2>/dev/null)
      echo "  Error: $MESSAGE"
      break
    else
      echo "- Waiting..."
      sleep 10
    fi
  done
  
  # Output result after checking
  if [[ "$DEPLOYMENT_FAILED" == "true" ]]; then
    echo "✗ Service failed"
  else
    echo "✓ Service ready"
  fi
done

echo ""
echo "All deployments completed!"

