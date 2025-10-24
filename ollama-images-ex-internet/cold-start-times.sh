#!/bin/bash
# Script to check cold start times for all model images
# Measures time from service update until model is fully loaded and available

# Set variables
REGION=europe-west1
PROJECT_ID=$(gcloud config get-value project)
RUN_SERVICE_NAME=ollama-generic

# Model variables
MODEL_FAMILY="gemma3"
MODEL_PARAMS_LIST=("270m" "1b" "4b" "12b" "27b")
PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format="value(projectNumber)")
TOKEN=$(gcloud auth print-identity-token)

# Arrays to store results for summary
declare -a SUMMARY_MODELS
declare -a SUMMARY_TIMES
declare -a SUMMARY_STATUS

echo "Model Cold Start Times (measuring until model is fully loaded):"
echo ""

for MODEL_PARAMS in "${MODEL_PARAMS_LIST[@]}"
do
  # Model Vars
  MODEL_NAME="$MODEL_FAMILY-$MODEL_PARAMS"
  MODEL_ID="$MODEL_FAMILY:$MODEL_PARAMS"

  echo "Testing ${MODEL_NAME}..."
  echo "  Updating Cloud Run service with MODEL_ID=${MODEL_ID}..."
  
  # Start timing before the service update
  echo "  Starting timer..."
  START_TIME=$(date +%s)

  # Update the service
  gcloud run services update ${RUN_SERVICE_NAME} \
    --set-env-vars=MODEL_ID="$MODEL_ID" \
    --region=$REGION \
    --quiet

  # Construct the tags URL
  RUN_URL=https://${RUN_SERVICE_NAME}-${PROJECT_NUMBER}.${REGION}.run.app
  TAGS_URL="${RUN_URL}/api/tags"

  echo "  Waiting 2 seconds for Cloud Run to process the update..."
  sleep 2
    
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
          echo "- ${MODEL_NAME} - Cold Start Time: ${COLD_START_TIME}s"
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
      fi
    fi
    
    # Only output status every 5 seconds
    if [ $ATTEMPT -lt $MAX_ATTEMPTS ]; then
      if [ $((ATTEMPT % 5)) -eq 0 ]; then
        echo "    ${ATTEMPT}s elapsed: Model not yet loaded (empty model list)..."
      fi
      sleep 1
    fi
  done
  
  if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
    echo "  ✗ Timeout: Model did not load within the maximum time limit"
    echo ""
    
    # Store timeout result for summary
    SUMMARY_MODELS+=("$MODEL_NAME")
    SUMMARY_TIMES+=("TIMEOUT")
    SUMMARY_STATUS+=("✗ Failed")
  fi
done

echo "All cold start tests completed!"
echo ""
echo "==============================================="
echo "                   SUMMARY                     "
echo "==============================================="
echo ""
printf "%-15s | %-15s | %s\n" "Model" "Cold Start Time" "Status"
printf "%-15s-+-%-15s-+-%s\n" "---------------" "---------------" "-------------"

for i in "${!SUMMARY_MODELS[@]}"; do
  printf "%-15s | %-15s | %s\n" "${SUMMARY_MODELS[$i]}" "${SUMMARY_TIMES[$i]}" "${SUMMARY_STATUS[$i]}"
done

echo ""
echo "==============================================="
