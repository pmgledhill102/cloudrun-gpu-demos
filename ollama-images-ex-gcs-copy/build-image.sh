#!/bin/bash
# Script to build the generic Ollama runtime image
# This single image can be used for all model types and sizes

# Set variables
REGION=europe-west1
GAR_NAME=gpu-demos

echo "Building generic Ollama runtime image..."
gcloud builds submit \
    --config="cloudbuild.yaml" \
    --substitutions=_REGION="$REGION",_GAR_NAME="$GAR_NAME"

echo ""
echo ""
echo "Build complete! The image 'ollama-gcs-runtime' is ready."
echo "You can now deploy this image with different GCS_BUCKET_PATH environment variables."
