#!/bin/bash
set -e

# Start Ollama in the background
ollama serve &
OLLAMA_PID=$!

# Wait for Ollama to be ready
echo "Waiting for Ollama to start..."
sleep 5

# Pull the model if MODEL_ID is set
if [ -n "$MODEL_ID" ]; then
    echo "Pulling model: $MODEL_ID"
    ollama pull "$MODEL_ID"
    echo "Model pulled successfully"
else
    echo "Warning: MODEL_ID not set, no model will be pulled"
fi

# Wait for the Ollama server process
wait $OLLAMA_PID
