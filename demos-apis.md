# API Demos

A variety of Model APIs that can be called from the terminal. These were tested on a zsh terminal on a MacOS
device.

The OpenAI ChatGPT example needs an OpenAI API key.

The Google examples required the `gcloud` CLI to be installed, authenticated to your account, and for a project
to be active with the relevant APIs enabled. To see API errors remove any output piping such as
`| jq -r '.candidates[0].content.parts[0].text'` - as this assumes a success response.

## Call OpenAI

```sh
OPEN_AI_KEY=NEEDS A KEY FROM THE OPENAI WEBSITE
```

```sh
curl https://api.openai.com/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $OPEN_AI_KEY" \
  -d '{
     "model": "gpt-4o-mini",
     "messages": [{"role": "user", "content": "How many pizzas should you buy when running a meetup where 80 people have accepted!"}],
     "temperature": 0.7
   }'
```

## VertexAI Studio

VertexAI Studio console is a great place to play with the Google hosted models:
<https://console.cloud.google.com/vertex-ai/studio?project=play-pen-pup&inv=1&invt=Abo2jA>

## VertexAI

```sh
MODEL_ID="gemini-2.5-flash-lite"
PROJECT_ID=$(gcloud config get-value project)
REGION="europe-west4"
```

```sh
curl --no-buffer \
-H "Authorization: Bearer $(gcloud auth print-access-token)" \
-H "Content-Type: application/json" \
https://$REGION-aiplatform.googleapis.com/v1/projects/${PROJECT_ID}/locations/$REGION/publishers/google/models/${MODEL_ID}:streamGenerateContent \
-d \
$'{
  "contents": {
    "role": "user",
    "parts": [
      {
        "text": "Help me plan a romantic 4 day holiday to Milan with my wife. Create a detailed itinerary that includes some down time."
      }
    ]
  }
}' \
| jq -r -c '.[] | .candidates[0].content.parts[0].text'
```

## gemini-2.0-pro-exp-02-05

The Experimental Models change frequently, so best to see which are the latest ones:
<https://cloud.google.com/vertex-ai/generative-ai/docs/multimodal/gemini-experimental>

```sh
MODEL_ID="gemini-2.0-pro-exp-02-05"
REGION=us-central1
```

```sh
curl -X POST \
-H "Authorization: Bearer $(gcloud auth print-access-token)" \
-H "Content-Type: application/json" \
https://$REGION-aiplatform.googleapis.com/v1/projects/${PROJECT_ID}/locations/$REGION/publishers/google/models/${MODEL_ID}:generateContent -d \
$'{
  "contents": {
    "role": "user",
    "parts": [
      {
        "text": "What\'s a good name for a flower shop that specializes in selling bouquets of dried flowers?"
      }
    ]
  }
}' \
| jq -r '.candidates[0].content.parts[0].text'
```

## Generate Images

```sh
REGION=europe-west4
PROJECT_ID=$(gcloud config get-value project)
GAR_NAME=gpu-demos
SERVICE_ACCOUNT=sd-identity
TOKEN=$(gcloud auth application-default print-access-token)
```

```sh
curl -X POST \
-H "Authorization: Bearer $TOKEN" \
-H "Content-Type: application/json" \
-d '{
  "instances": [
    {
      "prompt": "A beautiful vibrant flower blooming in a mystical garden, ultra-detailed, 4K"
    }
  ],
  "parameters": {
    "sampleCount": 1,
    "width": 1024,
    "height": 1024
  }
}' \
"https://$REGION-aiplatform.googleapis.com/v1/projects/$PROJECT_ID/locations/$REGION/publishers/google/models/imagegeneration:predict" \
| jq -r '.predictions[0].bytesBase64Encoded' | base64 --decode > flower.png

curl -X POST \
-H "Authorization: Bearer $TOKEN" \
-H "Content-Type: application/json" \
-d '{
  "instances": [
    {
      "prompt": "A room full of geeks at a Google Cloud conference watching a presentation on GenAI, ultra-detailed, 4K"
    }
  ],
  "parameters": {
    "sampleCount": 1,
    "width": 1024,
    "height": 1024
  }
}' \
"https://$REGION-aiplatform.googleapis.com/v1/projects/$PROJECT_ID/locations/$REGION/publishers/google/models/imagegeneration:predict" \
| jq -r '.predictions[0].bytesBase64Encoded' | base64 --decode > geeks.png
```
