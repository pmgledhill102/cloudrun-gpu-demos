# Use a CUDA runtime image as the base image.
FROM nvidia/cuda:11.8.0-runtime-ubuntu20.04

# Install system dependencies.
RUN apt-get update && \
    apt-get install -y python3 python3-pip git && \
    rm -rf /var/lib/apt/lists/*

# Upgrade pip and install Python dependencies from requirements.txt.
COPY requirements.txt /app/requirements.txt
RUN pip3 install --upgrade pip
RUN pip3 install -r /app/requirements.txt

# Copy your application code into the container.
WORKDIR /app
COPY . /app

# Expose the port Cloud Run expects.
EXPOSE 8080

# Start the app using Gunicorn.
CMD ["gunicorn", "--bind", "0.0.0.0:8080", "app:app"]
