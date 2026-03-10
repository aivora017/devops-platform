#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
RESULTS_DIR="$PROJECT_ROOT/load-test-results"

NAMESPACE="devops"
SERVICE_NAME="go-api-service"
NUM_REQUESTS=1000
CONCURRENT_BATCH=10
RESULTS_FILE="$RESULTS_DIR/load-test-results-$(date +%Y%m%d-%H%M%S).txt"
STATUS_FILE="/tmp/load-test-status-$(date +%Y%m%d-%H%M%S).txt"

print_header() {
    echo
    echo "$1"
    echo "$(printf '%0.s-' {1..40})"
}

print_status() {
    echo "$1"
}

print_error() {
    echo "$1" >&2
}

print_warning() {
    echo "$1"
}

cleanup() {
    print_header "Load Test Complete"
    echo "Results saved to: $RESULTS_FILE"
    rm -f "$STATUS_FILE"
    echo ""
    echo "To view results:"
    echo "  cat $RESULTS_FILE"
}

trap cleanup EXIT

mkdir -p "$RESULTS_DIR"

print_header "DevOps Platform - Load Test"

print_status "Fetching LoadBalancer endpoint..."
LB_ENDPOINT=$(kubectl get svc "$SERVICE_NAME" -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)

if [ -z "$LB_ENDPOINT" ]; then
    print_error "Could not get LoadBalancer endpoint. Make sure service is deployed and has external IP/hostname."
    echo ""
    echo "Try checking service status:"
    echo "  kubectl get svc -n $NAMESPACE"
    exit 1
fi

print_status "LoadBalancer Endpoint: $LB_ENDPOINT"

print_status "Checking initial pod count..."
INITIAL_PODS=$(kubectl get pods -n $NAMESPACE -l app=go-api --no-headers | wc -l)
print_status "Initial replica count: $INITIAL_PODS"

print_header "Sending Load"

echo "Test Configuration:" | tee -a "$RESULTS_FILE"
echo "  Total Requests: $NUM_REQUESTS" | tee -a "$RESULTS_FILE"
echo "  Concurrent Batch Size: $CONCURRENT_BATCH" | tee -a "$RESULTS_FILE"
echo "  Target: http://$LB_ENDPOINT/" | tee -a "$RESULTS_FILE"
echo "  Test Duration: ~$(($NUM_REQUESTS / $CONCURRENT_BATCH)) seconds" | tee -a "$RESULTS_FILE"
echo "" | tee -a "$RESULTS_FILE"
echo "Starting load test at $(date '+%Y-%m-%d %H:%M:%S')" | tee -a "$RESULTS_FILE"
echo "" | tee -a "$RESULTS_FILE"

START_TIME=$(date +%s%N)

: > "$STATUS_FILE"

for ((i=1; i<=$NUM_REQUESTS; i+=$CONCURRENT_BATCH)); do
    for ((j=0; j<$CONCURRENT_BATCH && (i+j)<=$NUM_REQUESTS; j++)); do
        (
            RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -m 10 "http://$LB_ENDPOINT/" 2>/dev/null || echo "000")
            echo "$RESPONSE" >> "$STATUS_FILE"
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

SUCCESS=$(grep -c '^200$' "$STATUS_FILE" || true)
FAILED=$((NUM_REQUESTS - SUCCESS))

FINAL_PODS=$(kubectl get pods -n $NAMESPACE -l app=go-api --no-headers | wc -l)

print_header "Load Test Results"

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

print_status "HPA Status:"
kubectl describe hpa go-api-hpa -n $NAMESPACE 2>/dev/null | tail -10 | tee -a "$RESULTS_FILE" || print_warning "HPA not found or error retrieving status"

echo "" | tee -a "$RESULTS_FILE"
echo "Final Pod Status:" | tee -a "$RESULTS_FILE"
kubectl get pods -n $NAMESPACE -l app=go-api --no-headers | tee -a "$RESULTS_FILE"

echo "" | tee -a "$RESULTS_FILE"
if [ $FAILED -eq 0 ]; then
    print_status "All requests successful"
    echo "Status: PASSED" | tee -a "$RESULTS_FILE"
else
    print_warning "Some requests failed"
    echo "Status: WARNING - $FAILED failures" | tee -a "$RESULTS_FILE"
fi

print_status "Full results written to: $RESULTS_FILE"
