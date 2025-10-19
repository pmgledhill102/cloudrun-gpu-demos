#!/bin/bash
# Script to check cold start times for all model images

# Set variables
REGION=europe-west1
PROJECT_ID=$(gcloud config get-value project)

# Model variables
MODEL_FAMILY="gemma3"
MODEL_PARAMS_LIST=("270m" "1b" "4b" "12b" "27b")
PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format="value(projectNumber)")
TOKEN=$(gcloud auth print-identity-token)

# Arrays to store results
declare -a RESULTS_MODEL
declare -a RESULTS_VERSION_TIME
declare -a RESULTS_GENERATE_TIME
declare -a RESULTS_STATUS

echo "Testing models..."
echo ""

for MODEL_PARAMS in "${MODEL_PARAMS_LIST[@]}"
do
  # Model Vars
  MODEL_NAME="$MODEL_FAMILY-$MODEL_PARAMS"
  MODEL_ID="$MODEL_FAMILY:$MODEL_PARAMS"
  BASE_URL=https://${MODEL_NAME}-${PROJECT_NUMBER}.${REGION}.run.app
  VERSION_URL="${BASE_URL}/api/version"
  GENERATE_URL="${BASE_URL}/api/generate"

  echo "Testing ${MODEL_NAME}..."
  
  # Start timer at the beginning for both endpoints
  ITERATION_START=$(date +%s.%N)
  
  # Test 1: Version endpoint (cold start)
  VERSION_TIME=$(curl -s -o /dev/null -w "%{time_total}" -H "Authorization: Bearer $TOKEN" "$VERSION_URL")
  VERSION_CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $TOKEN" "$VERSION_URL")
  
  # Test 2: Generate endpoint (time includes version endpoint time)
  GENERATE_RESPONSE=$(curl -s -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"${MODEL_ID}\",\"prompt\":\"Hi\",\"stream\":false}" \
    "$GENERATE_URL" 2>/dev/null)
  GENERATE_END=$(date +%s.%N)
  GENERATE_TIME=$(echo "$GENERATE_END - $ITERATION_START" | bc)
  
  # Check if generation was successful
  GENERATE_SUCCESS=$(echo "$GENERATE_RESPONSE" | jq -r '.response' 2>/dev/null)
  
  if [ -n "$GENERATE_SUCCESS" ] && [ "$GENERATE_SUCCESS" != "null" ]; then
    STATUS="✓"
  else
    STATUS="✗"
  fi
  
  # Store results
  RESULTS_MODEL+=("$MODEL_NAME")
  RESULTS_VERSION_TIME+=("${VERSION_TIME}s")
  RESULTS_GENERATE_TIME+=("${GENERATE_TIME}s")
  RESULTS_STATUS+=("$STATUS")
done

echo ""
echo "## Model Cold Start Times"
echo ""
echo "| Model | Version Time | Generate Time | Status |"
echo "|-------|--------------|---------------|--------|"

for i in "${!RESULTS_MODEL[@]}"; do
  printf "| %-13s | %12s | %13s | %6s |\n" \
    "${RESULTS_MODEL[$i]}" \
    "${RESULTS_VERSION_TIME[$i]}" \
    "${RESULTS_GENERATE_TIME[$i]}" \
    "${RESULTS_STATUS[$i]}"
done

echo ""
echo "Testing complete!"
