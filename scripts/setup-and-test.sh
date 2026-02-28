#!/bin/bash

##############################################################################
# Infrastructure Setup & Load Test
#
# Complete workflow to:
# 1. Bring up AWS infrastructure (EKS cluster, load balancer, etc.)
# 2. Deploy applications
# 3. Run load test
# 4. Save results to GitHub
#
# Usage:
#   ./scripts/setup-and-test.sh
#
# Prerequisites:
#   - AWS credentials configured: aws configure
#   - kubectl installed
#   - Terraform installed
#   - Docker installed
#
##############################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
TERRAFORM_DIR="terraform/aws"
K8S_DIR="k8s/aws"
NAMESPACE="devops"
LOAD_TEST_SCRIPT="scripts/load-test.sh"
RESULTS_DIR="load-test-results"

# Functions
print_header() {
    echo -e "\n${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}\n"
}

print_status() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"
    
    local tools=("aws" "kubectl" "terraform" "docker")
    for tool in "${tools[@]}"; do
        if command -v "$tool" &>/dev/null; then
            print_status "$tool installed"
        else
            print_error "$tool not found. Please install it first."
            exit 1
        fi
    done
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &>/dev/null; then
        print_error "AWS credentials not configured"
        echo "Run: aws configure"
        exit 1
    fi
    print_status "AWS credentials configured"
}

# Bring up infrastructure
bring_up_infrastructure() {
    print_header "Bringing Up AWS Infrastructure"
    
    cd "$TERRAFORM_DIR"
    
    print_status "Initializing Terraform..."
    terraform init
    
    print_status "Applying Terraform configuration..."
    echo "This may take 10-15 minutes..."
    terraform apply -auto-approve
    
    cd ../..
    print_status "Infrastructure provisioning complete"
}

# Configure kubectl
configure_kubectl() {
    print_header "Configuring kubectl"
    
    # Try to get cluster name from terraform output
    CLUSTER_NAME=$(cd "$TERRAFORM_DIR" && terraform output -raw eks_cluster_name 2>/dev/null) || CLUSTER_NAME="devops-platform-cluster"
    
    print_status "Updating kubeconfig for cluster: $CLUSTER_NAME"
    aws eks update-kubeconfig --name "$CLUSTER_NAME" --region ap-southeast-2
    
    # Verify connection
    if kubectl cluster-info &>/dev/null; then
        print_status "kubectl successfully connected to cluster"
    else
        print_error "Failed to connect to cluster"
        exit 1
    fi
}

# Deploy applications
deploy_applications() {
    print_header "Deploying Applications"
    
    print_status "Creating devops namespace..."
    kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
    
    print_status "Deploying Kubernetes resources..."
    kubectl apply -f "$K8S_DIR/"
    
    print_status "Waiting for deployments to be ready..."
    local max_attempts=60
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if kubectl rollout status deployment/go-api -n "$NAMESPACE" --timeout=30s 2>/dev/null; then
            print_status "Deployments are ready"
            break
        fi
        
        echo "⏳ Waiting for deployments... (attempt $attempt/$max_attempts)"
        ((attempt++))
        sleep 5
    done
    
    if [ $attempt -gt $max_attempts ]; then
        print_warning "Deployment timeout. Check status with: kubectl get pods -n $NAMESPACE"
    fi
}

# Wait for load balancer
wait_for_loadbalancer() {
    print_header "Waiting for Load Balancer"
    
    print_status "Fetching LoadBalancer endpoint..."
    local max_attempts=60
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        LB_ENDPOINT=$(kubectl get svc go-api-service -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
        
        if [ -n "$LB_ENDPOINT" ] && [ "$LB_ENDPOINT" != "null" ]; then
            print_status "LoadBalancer Endpoint: $LB_ENDPOINT"
            echo "$LB_ENDPOINT" > /tmp/lb-endpoint.txt
            return 0
        fi
        
        echo "⏳ Waiting for LoadBalancer IP... (attempt $attempt/$max_attempts)"
        ((attempt++))
        sleep 5
    done
    
    print_error "LoadBalancer IP not available after waiting"
    return 1
}

# Display status
show_status() {
    print_header "Cluster Status"
    
    echo "Pods:"
    kubectl get pods -n "$NAMESPACE"
    
    echo ""
    echo "Services:"
    kubectl get svc -n "$NAMESPACE"
    
    echo ""
    echo "HPA Status:"
    kubectl describe hpa go-api-hpa -n "$NAMESPACE" 2>/dev/null || echo "HPA not yet available"
}

# Quick health check
health_check() {
    print_header "Health Check"
    
    LB_ENDPOINT=$(cat /tmp/lb-endpoint.txt 2>/dev/null)
    
    if [ -z "$LB_ENDPOINT" ]; then
        print_warning "Could not retrieve LoadBalancer endpoint"
        return 1
    fi
    
    print_status "Testing endpoint: http://$LB_ENDPOINT/health"
    
    if curl -s -f "http://$LB_ENDPOINT/health" &>/dev/null; then
        print_status "Endpoint is healthy and responding"
        return 0
    else
        print_warning "Endpoint not responding yet. May need more time."
        return 1
    fi
}

# Main flow
main() {
    print_header "Infrastructure Setup & Load Test Workflow"
    
    check_prerequisites
    bring_up_infrastructure
    configure_kubectl
    deploy_applications
    wait_for_loadbalancer
    show_status
    
    # Try health check
    if health_check; then
        print_header "Ready to Run Load Test"
        echo "Infrastructure is ready!"
        echo ""
        echo "Run the load test:"
        echo "  bash $LOAD_TEST_SCRIPT"
        echo ""
        echo "Or both together:"
        echo "  bash $LOAD_TEST_SCRIPT && mkdir -p $RESULTS_DIR && mv /tmp/load-test-results-*.txt $RESULTS_DIR/"
    else
        print_warning "Infrastructure is up but endpoint may not be ready yet"
        echo ""
        echo "Check status:"
        echo "  kubectl get pods -n $NAMESPACE"
        echo "  kubectl get svc -n $NAMESPACE"
        echo ""
        echo "When ready, run:"
        echo "  bash $LOAD_TEST_SCRIPT"
    fi
}

main
