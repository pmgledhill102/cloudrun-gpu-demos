#!/bin/bash
# Download the model files into GCS

REGION=europe-west1
PROJECT_ID=$(gcloud config get-value project)
GCS_BUCKET_NAME=ollama-models-${PROJECT_ID}  # Must be globally 

# Model variables
MODEL_FAMILY="gemma3"
MODEL_PARAMS_LIST=("270m" "1b" "4b" "12b" "27b")

for MODEL_PARAMS in "${MODEL_PARAMS_LIST[@]}"
do
  # Model Vars
  MODEL_NAME="$MODEL_FAMILY-$MODEL_PARAMS"
  MODEL_ID="$MODEL_FAMILY:$MODEL_PARAMS"

  echo "Starting download job for ${MODEL_NAME}..."

    gcloud builds submit \
        --config="cloudbuild-gcs-populate.yaml" \
        --region="${REGION}" \
        --substitutions=_MODEL_ID="${MODEL_ID}",_MODEL_NAME="${MODEL_NAME}",_GCS_BUCKET_NAME="${GCS_BUCKET_NAME}" \
        --async
done
