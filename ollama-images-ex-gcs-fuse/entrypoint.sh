#!/bin/sh
set -e

# Set the Ollama models directory
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
MODEL_NAME=$(echo "$MODEL_ID" | tr ':' '-')

# The GCS bucket is mounted at /gcs-models via Cloud Run FUSE
GCS_MOUNT_PATH="/gcs-models/models/${MODEL_NAME}"

echo "Starting Ollama with GCS FUSE-mounted models..."
echo "Model ID: ${MODEL_ID}"
echo "Model Name: ${MODEL_NAME}"
echo "GCS Mount Path: ${GCS_MOUNT_PATH}"

# Verify the GCS mount path exists
if [ ! -d "$GCS_MOUNT_PATH" ]; then
    echo "Error: Model path does not exist in GCS mount: ${GCS_MOUNT_PATH}"
    echo "Available models:"
    ls -la /gcs-models/models/ || echo "No models found in /gcs-models/models/"
    exit 1
fi

# Create a symlink from Ollama's expected models directory to the GCS FUSE mount
# This allows Ollama to access models directly from GCS without copying
echo "Creating symlink from ${OLLAMA_MODELS} to ${GCS_MOUNT_PATH}"

# Remove any existing models directory and create the parent
rm -rf "${OLLAMA_MODELS}"
mkdir -p "$(dirname ${OLLAMA_MODELS})"

# Create the symlink to the specific model in the GCS mount
ln -sf "${GCS_MOUNT_PATH}" "${OLLAMA_MODELS}"

echo "Symlink created successfully"
echo "Model files are now accessible via FUSE from: ${OLLAMA_MODELS}"

# Verify the symlink works
echo "Verifying model files are accessible:"
ls -la "${OLLAMA_MODELS}/" || echo "Warning: Could not list model files"

# Start Ollama server
echo "Starting Ollama server..."
echo "Ollama will access model files directly from GCS via FUSE mount"
exec ollama serve
