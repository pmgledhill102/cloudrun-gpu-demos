# Demo 2

```sh

mkdir demo
cd demo

nano Dockerfile
```

```Dockerfile
FROM ollama/ollama:0.12.6

ENV OLLAMA_HOST 0.0.0.0:8080

ENV OLLAMA_MODELS /models

ENV OLLAMA_KEEP_ALIVE -1

RUN ollama serve & sleep 5 && ollama pull gemma3:270m
```

```sh
gcloud artifacts repositories create gpu-demo \
  --repository-format=docker \
  --location=europe-west1
```

```sh
PROJECT_ID=$(gcloud config get-value project)

gcloud builds submit . \
    --region=europe-west1 \
    --tag europe-west1-docker.pkg.dev/$PROJECT_ID/gpu-demo/ollama:latest
```
