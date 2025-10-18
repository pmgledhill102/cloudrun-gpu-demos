#!/bin/sh
set -e

# Set the Ollama models directory
# This tells Ollama where to find models
export OLLAMA_MODELS=/root/.ollama/models

# Check if required environment variables are set
if [ -z "$GCS_BUCKET_NAME" ]; then
    echo "Error: GCS_BUCKET_NAME environment variable is not set."
    exit 1
fi

if [ -z "$MODEL_ID" ]; then
    echo "Error: MODEL_ID environment variable is not set."
    exit 1
fi

# Convert MODEL_ID (e.g., "gemma3:270m") to MODEL_NAME (e.g., "gemma3-270m")
# This matches the naming convention used in download-models-into-gcs.sh
MODEL_NAME=$(echo "$MODEL_ID" | tr ':' '-')

# Construct the GCS path following the structure: gs://bucket/models/model-name
GCS_BUCKET_PATH="gs://${GCS_BUCKET_NAME}/models/${MODEL_NAME}"

echo "Starting model copy from GCS..."
echo "Model ID: ${MODEL_ID}"
echo "Model Name: ${MODEL_NAME}"
echo "Source: ${GCS_BUCKET_PATH}"
echo "Destination: ${OLLAMA_MODELS}"

# Create the destination directory
mkdir -p "${OLLAMA_MODELS}"

# Use gsutil to copy the model files from GCS to the Ollama models directory
# The -m flag enables parallel copying for speed
gsutil -m rsync -r "${GCS_BUCKET_PATH}" "${OLLAMA_MODELS}"

echo "Model copy complete."
echo "Models available in: ${OLLAMA_MODELS}"

# Start Ollama server in the background
echo "Starting Ollama server..."
ollama serve &
OLLAMA_PID=$!

# Wait for the Ollama server process to exit
wait $OLLAMA_PID
