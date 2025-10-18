#!/bin/bash
# Script to build all model images

# Set variables
REGION=europe-west1
GAR_NAME=gpu-demos

# Model variables
MODEL_FAMILY="gemma3"
MODEL_PARAMS_LIST=("270m" "1b" "4b" "12b" "27b")

for MODEL_PARAMS in "${MODEL_PARAMS_LIST[@]}"
do
  MODEL_ID="$MODEL_FAMILY:$MODEL_PARAMS"
  MODEL_NAME="$MODEL_FAMILY-$MODEL_PARAMS"

  echo "Building model image for $MODEL_NAME:$MODEL_PARAMS"
  gcloud builds submit \
      --config="cloudbuild.yaml" \
      --substitutions=_MODEL_NAME="$MODEL_NAME",_MODEL_ID="$MODEL_ID",_REGION="$REGION",_GAR_NAME="$GAR_NAME" \
      --async
done
