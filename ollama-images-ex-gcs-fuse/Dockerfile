# Build the Ollama image with GCS FUSE mounting capability
FROM ollama/ollama:0.12.6

# Set up environment variables for Ollama
ENV OLLAMA_HOST=0.0.0.0:8080
ENV OLLAMA_MODELS=/root/.ollama/models
ENV OLLAMA_DEBUG=false
ENV OLLAMA_KEEP_ALIVE=-1

# Copy and set up the entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Set the entrypoint
ENTRYPOINT ["/entrypoint.sh"]
