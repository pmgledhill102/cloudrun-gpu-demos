from flask import Flask, request, jsonify, send_file
from diffusers import StableDiffusionPipeline
import torch
import io, base64

app = Flask(__name__)

# Load the Stable Diffusion model (this may take a minute).
MODEL_ID = "CompVis/stable-diffusion-v1-4"
device = "cuda"
pipe = StableDiffusionPipeline.from_pretrained(MODEL_ID, torch_dtype=torch.float16)
pipe = pipe.to(device)

@app.route("/generate", methods=["GET"])
def generate():
    # Get the prompt from the POSTed JSON.
    # data = request.get_json()
    # prompt = data.get("prompt", "A beautiful landscape")
    
    prompt = request.args.get("prompt", "A beautiful landscape").replace("-", " ")

    # Generate the image.
    image = pipe(prompt).images[0]

    # Encode image to PNG.
    buffer = io.BytesIO()
    image.save(buffer, format="PNG")
    buffer.seek(0)
    
    return send_file(buffer, mimetype='image/png')

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
