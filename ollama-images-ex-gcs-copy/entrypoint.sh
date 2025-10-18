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

echo "Starting Ollama server first to satisfy Cloud Run startup probe..."
echo "Model ID: ${MODEL_ID}"
echo "Model Name: ${MODEL_NAME}"

# Create the destination directory
mkdir -p "${OLLAMA_MODELS}"

# Start Ollama server in the background
echo "Starting Ollama server..."
ollama serve &
OLLAMA_PID=$!

# Give Ollama a moment to start
sleep 5
echo "Ollama server started (PID: ${OLLAMA_PID}). Cloud Run startup probe should now pass."

# Now copy the model files in the background while Ollama is running
echo "Starting model copy from GCS in parallel..."
echo "Source: ${GCS_BUCKET_PATH}"
echo "Temporary destination: /root/.ollama/models-temp"

TEMP_MODELS_DIR="/root/.ollama/models-temp"
mkdir -p "${TEMP_MODELS_DIR}"

# Use gsutil to copy the model files to temporary location
echo "Starting gsutil rsync..."
SYNC_START=$(date +%s)

gsutil -m rsync -r "${GCS_BUCKET_PATH}" "${TEMP_MODELS_DIR}"

SYNC_END=$(date +%s)
SYNC_DURATION=$((SYNC_END - SYNC_START))

echo "Model copy complete in ${SYNC_DURATION} seconds."

# Now stop Ollama, swap the directories, and restart
echo "Stopping Ollama to swap model directories..."
kill $OLLAMA_PID || true
wait $OLLAMA_PID 2>/dev/null || true

echo "Swapping model directories..."
# Rename old models folder (if it has anything)
if [ -d "${OLLAMA_MODELS}" ] && [ "$(ls -A ${OLLAMA_MODELS})" ]; then
    mv "${OLLAMA_MODELS}" "${OLLAMA_MODELS}.old"
fi

# Move the new models into place
mv "${TEMP_MODELS_DIR}" "${OLLAMA_MODELS}"

echo "Models now available in: ${OLLAMA_MODELS}"

# Restart Ollama server
echo "Restarting Ollama server with new models..."
ollama serve &
OLLAMA_PID=$!

# Wait for the Ollama server process to exit
wait $OLLAMA_PID
