#!/bin/bash
# Script to check cold start times for GCS FUSE mounted models
# Measures time from service update until model is fully loaded and available

# Set variables
REGION=europe-west1
PROJECT_ID=$(gcloud config get-value project)
RUN_SERVICE_NAME=ollama-gcs-fuse

# Model variables
MODEL_FAMILY="gemma3"
MODEL_PARAMS_LIST=( "270m" "1b" "4b" "12b" "27b" )
PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format="value(projectNumber)")
TOKEN=$(gcloud auth print-identity-token)
GCS_BUCKET_NAME=ollama-models-${PROJECT_ID}

# Arrays to store results for summary
declare -a SUMMARY_MODELS
declare -a SUMMARY_TIMES
declare -a SUMMARY_STATUS

echo "==================================================================="
echo "Model Cold Start Times with GCS FUSE Mount"
echo "==================================================================="
echo ""

for MODEL_PARAMS in "${MODEL_PARAMS_LIST[@]}"
do
  # Model Vars
  MODEL_NAME="$MODEL_FAMILY-$MODEL_PARAMS"
  MODEL_ID="$MODEL_FAMILY:$MODEL_PARAMS"

  echo "Testing ${MODEL_NAME}..."
  echo "  Updating Cloud Run service with MODEL_ID=${MODEL_ID}..."
  
  # Update service with new model
  # Start timing from this point
  START_TIME=$(date +%s)
  
  gcloud run services update ${RUN_SERVICE_NAME} \
    --set-env-vars=MODEL_ID="$MODEL_ID",GCS_BUCKET_NAME="$GCS_BUCKET_NAME" \
    --max-instances=1 \
    --region=$REGION \
    --quiet

  # Construct the tags URL
  RUN_URL=https://${RUN_SERVICE_NAME}-${PROJECT_NUMBER}.${REGION}.run.app
  TAGS_URL="${RUN_URL}/api/tags"

  echo "  Service updated. Making first request to trigger cold start..."
  
  # Poll the tags endpoint until it returns a non-empty model list
  echo "  Polling ${TAGS_URL} until model is loaded..."
  ATTEMPT=0
  MAX_ATTEMPTS=600  # 10 minutes max (1 second intervals)
  
  while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    ATTEMPT=$((ATTEMPT + 1))
    
    # Call the tags endpoint
    RESPONSE=$(curl -s -H "Authorization: Bearer $TOKEN" "$TAGS_URL" 2>/dev/null)
    
    # Check if we got a valid response and it's not empty
    if [ -n "$RESPONSE" ]; then
      # Check if the models array is not empty (more than just {"models":[]})
      MODEL_COUNT=$(echo "$RESPONSE" | jq -r '.models | length' 2>/dev/null)
      
      if [ "$MODEL_COUNT" != "null" ] && [ "$MODEL_COUNT" -gt 0 ]; then
        # Model appears in tags, now verify it can actually generate
        echo "  ✓ Model listed in tags, verifying generation capability..."
        
        GENERATE_URL="${RUN_URL}/api/generate"
        GENERATE_RESPONSE=$(curl -s -H "Authorization: Bearer $TOKEN" \
          -H "Content-Type: application/json" \
          -d "{\"model\":\"${MODEL_ID}\",\"prompt\":\"Hi\",\"stream\":false}" \
          "$GENERATE_URL" 2>/dev/null)
        
        # Check if generation was successful
        GENERATE_SUCCESS=$(echo "$GENERATE_RESPONSE" | jq -r '.response' 2>/dev/null)
        
        if [ -n "$GENERATE_SUCCESS" ] && [ "$GENERATE_SUCCESS" != "null" ]; then
          # Model is fully working!
          END_TIME=$(date +%s)
          COLD_START_TIME=$((END_TIME - START_TIME))
          
          echo "  ✓ Model is fully operational and responding to prompts!"
          echo ""
          echo "  ${MODEL_NAME}: ${COLD_START_TIME}s"
          echo ""
          
          # Store results for summary
          SUMMARY_MODELS+=("$MODEL_NAME")
          SUMMARY_TIMES+=("${COLD_START_TIME}s")
          SUMMARY_STATUS+=("✓ Success")
          break
        else
          # Only output every 5 seconds
          if [ $((ATTEMPT % 5)) -eq 0 ]; then
            echo "    ${ATTEMPT}s elapsed: Model listed but not yet responding to generation requests..."
          fi
        fi
      else
        # Only output every 10 seconds for initial loading
        if [ $((ATTEMPT % 10)) -eq 0 ]; then
          echo "    ${ATTEMPT}s elapsed: Waiting for model to appear in tags..."
        fi
      fi
    else
      # Only output every 10 seconds
      if [ $((ATTEMPT % 10)) -eq 0 ]; then
        echo "    ${ATTEMPT}s elapsed: Waiting for service to respond..."
      fi
    fi
    
    sleep 1
  done
  
  # Check if we timed out
  if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
    echo "  ✗ Timeout: Model did not become available within 10 minutes"
    echo ""
    
    # Store timeout result
    SUMMARY_MODELS+=("$MODEL_NAME")
    SUMMARY_TIMES+=("Timeout")
    SUMMARY_STATUS+=("✗ Failed")
  fi
  
  # Optional: Scale down to 0 between tests to ensure fresh cold start
  # Uncomment the following lines if you want to test from complete cold start each time
  # echo "  Scaling down to 0 for next test..."
  # gcloud run services update ${RUN_SERVICE_NAME} \
  #   --max-instances=0 \
  #   --region=$REGION \
  #   --quiet
  # sleep 5
done

# Print summary
echo "==================================================================="
echo "SUMMARY - GCS FUSE Mount Cold Start Times"
echo "==================================================================="
echo ""
printf "%-15s %-15s %-15s\n" "Model" "Cold Start" "Status"
printf "%-15s %-15s %-15s\n" "-----" "----------" "------"

for i in "${!SUMMARY_MODELS[@]}"; do
  printf "%-15s %-15s %-15s\n" "${SUMMARY_MODELS[$i]}" "${SUMMARY_TIMES[$i]}" "${SUMMARY_STATUS[$i]}"
done

echo ""
echo "==================================================================="
echo "Test completed!"
echo "==================================================================="
