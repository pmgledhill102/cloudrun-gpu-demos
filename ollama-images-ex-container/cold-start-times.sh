#!/bin/bash
# Script to check cold start times for all model images

# Set variables
REGION=europe-west1
PROJECT_ID=$(gcloud config get-value project)

# Model variables
MODEL_FAMILY="gemma3"
MODEL_PARAMS_LIST=("270m" "1b" "4b" "12b" "27b")
PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format="value(projectNumber)")
TOKEN=$(gcloud auth print-identity-token)

echo "Model Cold Start Times:"

for MODEL_PARAMS in "${MODEL_PARAMS_LIST[@]}"
do
  # Model Vars
  MODEL_NAME="$MODEL_FAMILY-$MODEL_PARAMS"
  RUN_URL=https://${MODEL_NAME}-${PROJECT_NUMBER}.${REGION}.run.app/api/version

  # Call the model, and measure cold start time
  curl -s -o /dev/null -w "- ${MODEL_NAME} - %{http_code} - %{time_total}s\n" -H "Authorization: Bearer $TOKEN" "$RUN_URL"
done
