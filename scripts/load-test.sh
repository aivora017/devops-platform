#!/bin/bash

##############################################################################
# Load Test Script for DevOps Platform
# 
# Purpose: Validate system can handle concurrent load and auto-scaling
# 
# Usage: 
#   ./scripts/load-test.sh
# 
# Prerequisites:
#   - kubectl configured and connected to EKS cluster
#   - go-api service deployed with LoadBalancer in devops namespace
#   - jq installed for JSON parsing (optional, for formatting)
##############################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="devops"
SERVICE_NAME="go-api-service"
NUM_REQUESTS=1000
CONCURRENT_BATCH=10
TIMEOUT=300  # 5 minutes
RESULTS_FILE="/tmp/load-test-results-$(date +%Y%m%d-%H%M%S).txt"

# Function to print section headers
print_header() {
    echo -e "\n${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}\n"
}

# Function to print status
print_status() {
    echo -e "${GREEN}✓${NC} $1"
}

# Function to print error
print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Function to print warning
print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Cleanup function
cleanup() {
    print_header "Load Test Complete"
    echo "Results saved to: $RESULTS_FILE"
    echo ""
    echo "To view results:"
    echo "  cat $RESULTS_FILE"
}

trap cleanup EXIT

# Start test
print_header "DevOps Platform - Load Test"

# Get load balancer endpoint
print_status "Fetching LoadBalancer endpoint..."
LB_ENDPOINT=$(kubectl get svc $SERVICE_NAME -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)

if [ -z "$LB_ENDPOINT" ]; then
    print_error "Could not get LoadBalancer endpoint. Make sure service is deployed and has external IP/hostname."
    echo ""
    echo "Try checking service status:"
    echo "  kubectl get svc -n $NAMESPACE"
    exit 1
fi

print_status "LoadBalancer Endpoint: $LB_ENDPOINT"

# Get current pod count before test
print_status "Checking initial pod count..."
INITIAL_PODS=$(kubectl get pods -n $NAMESPACE -l app=go-api --no-headers | wc -l)
print_status "Initial replica count: $INITIAL_PODS"

# Start test
print_header "Sending Load"

echo "Test Configuration:" | tee -a "$RESULTS_FILE"
echo "  Total Requests: $NUM_REQUESTS" | tee -a "$RESULTS_FILE"
echo "  Concurrent Batch Size: $CONCURRENT_BATCH" | tee -a "$RESULTS_FILE"
echo "  Target: http://$LB_ENDPOINT/" | tee -a "$RESULTS_FILE"
echo "  Test Duration: ~$(($NUM_REQUESTS / $CONCURRENT_BATCH)) seconds" | tee -a "$RESULTS_FILE"
echo "" | tee -a "$RESULTS_FILE"
echo "Starting load test at $(date '+%Y-%m-%d %H:%M:%S')" | tee -a "$RESULTS_FILE"
echo "" | tee -a "$RESULTS_FILE"

# Counters
SUCCESS=0
FAILED=0
START_TIME=$(date +%s%N)

# Send requests in batches
for ((i=1; i<=$NUM_REQUESTS; i+=$CONCURRENT_BATCH)); do
    for ((j=0; j<$CONCURRENT_BATCH && (i+j)<=$NUM_REQUESTS; j++)); do
        (
            RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -m 10 "http://$LB_ENDPOINT/" 2>/dev/null || echo "000")
            if [ "$RESPONSE" = "200" ]; then
                ((SUCCESS++))
            else
                ((FAILED++))
            fi
        ) &
    done
    wait
    
    CURRENT=$((i + CONCURRENT_BATCH - 1))
    if [ $CURRENT -gt $NUM_REQUESTS ]; then
        CURRENT=$NUM_REQUESTS
    fi
    echo "Progress: $CURRENT/$NUM_REQUESTS requests sent" >&2
done

END_TIME=$(date +%s%N)
DURATION_NS=$((END_TIME - START_TIME))
DURATION_S=$(echo "scale=2; $DURATION_NS / 1000000000" | bc)

# Get pod count after test
FINAL_PODS=$(kubectl get pods -n $NAMESPACE -l app=go-api --no-headers | wc -l)

print_header "Load Test Results"

# Display results
echo "Test Summary:" | tee -a "$RESULTS_FILE"
echo "  Timestamp: $(date '+%Y-%m-%d %H:%M:%S')" | tee -a "$RESULTS_FILE"
echo "  Total Requests Sent: $NUM_REQUESTS" | tee -a "$RESULTS_FILE"
echo "  Successful (HTTP 200): $SUCCESS" | tee -a "$RESULTS_FILE"
echo "  Failed: $FAILED" | tee -a "$RESULTS_FILE"
echo "  Success Rate: $(echo "scale=2; ($SUCCESS * 100) / $NUM_REQUESTS" | bc)%" | tee -a "$RESULTS_FILE"
echo "  Test Duration: ${DURATION_S}s" | tee -a "$RESULTS_FILE"
echo "  Requests/Second: $(echo "scale=2; $NUM_REQUESTS / $DURATION_S" | bc)" | tee -a "$RESULTS_FILE"
echo "" | tee -a "$RESULTS_FILE"

echo "Scaling Results:" | tee -a "$RESULTS_FILE"
echo "  Initial Pods: $INITIAL_PODS" | tee -a "$RESULTS_FILE"
echo "  Final Pods: $FINAL_PODS" | tee -a "$RESULTS_FILE"
echo "  Pods Scaled: $((FINAL_PODS - INITIAL_PODS)) (from $INITIAL_PODS to $FINAL_PODS)" | tee -a "$RESULTS_FILE"
echo "" | tee -a "$RESULTS_FILE"

# HPA Status
print_status "HPA Status:"
kubectl describe hpa go-api-hpa -n $NAMESPACE 2>/dev/null | tail -10 | tee -a "$RESULTS_FILE" || print_warning "HPA not found or error retrieving status"

# Pod Status
echo "" | tee -a "$RESULTS_FILE"
echo "Final Pod Status:" | tee -a "$RESULTS_FILE"
kubectl get pods -n $NAMESPACE -l app=go-api --no-headers | tee -a "$RESULTS_FILE"

# Final assessment
echo "" | tee -a "$RESULTS_FILE"
if [ $FAILED -eq 0 ]; then
    print_status "All requests successful! ✓"
    echo "Status: PASSED ✓" | tee -a "$RESULTS_FILE"
else
    print_warning "Some requests failed"
    echo "Status: WARNING - $FAILED failures" | tee -a "$RESULTS_FILE"
fi

print_status "Full results written to: $RESULTS_FILE"
