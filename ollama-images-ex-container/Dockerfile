FROM ollama/ollama:0.12.6

# Listen on all interfaces, port 8080
ENV OLLAMA_HOST 0.0.0.0:8080

# Store model weight files in /models
ENV OLLAMA_MODELS /models

# Reduce logging verbosity
ENV OLLAMA_DEBUG false

# Never unload model weights from the GPU
ENV OLLAMA_KEEP_ALIVE -1 

# Define build argument for the model
ARG _MODEL

# Store the model weights in the container image
#
# You could push this command into the ENTRYPOINT, which would reduce container image and build time,
# but will significantly increase the start-up time
RUN ollama serve & sleep 5 && ollama pull ${_MODEL}

# Start Ollama
ENTRYPOINT ["ollama", "serve"]
