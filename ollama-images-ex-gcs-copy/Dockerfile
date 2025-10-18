# Stage 1: Get gcloud CLI
FROM google/cloud-sdk:alpine as gcloud

# Stage 2: Build the final image
FROM ollama/ollama:0.12.6

# Copy gcloud CLI from the first stage
COPY --from=gcloud /google-cloud-sdk /google-cloud-sdk

# Add gcloud to the PATH
ENV PATH="/google-cloud-sdk/bin:${PATH}"

# Set up environment variables for Ollama
ENV OLLAMA_HOST=0.0.0.0:8080
ENV OLLAMA_MODELS=/models
ENV OLLAMA_DEBUG=false
ENV OLLAMA_KEEP_ALIVE=-1

# Copy and set up the entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Set the entrypoint
ENTRYPOINT ["/entrypoint.sh"]
