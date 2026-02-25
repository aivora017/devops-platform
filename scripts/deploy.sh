#!/bin/bash

# DevOps Platform Deployment Script
# Checks if Minikube is running, starts it if not, and deploys the applications.

set -e  # Exit on any error

echo "🚀 Starting DevOps Platform Deployment..."

# ─── Preflight Check ──────────────────────────────────────────────────────────
check_requirements() {
    echo "🔍 Checking required tools..."
    for tool in minikube kubectl docker; do
        if ! command -v $tool &>/dev/null; then
            echo "❌ Required tool not found: $tool"
            exit 1
        fi
    done
    echo "✅ All required tools found"
}

# ─── Minikube Check ───────────────────────────────────────────────────────────
check_minikube() {
    local status
    status=$(minikube status --format='{{.Host}}' 2>/dev/null)
    if [ "$status" = "Running" ]; then
        echo "✅ Minikube is already running"
        return 0
    else
        echo "❌ Minikube is not running (status: ${status:-unknown})"
        return 1
    fi
}

# ─── Start Minikube ───────────────────────────────────────────────────────────
start_minikube() {
    echo "🔄 Starting Minikube..."
    minikube start --driver=docker --memory=2048mb --cpus=2
    echo "✅ Minikube started successfully"
}

# ─── Deploy Applications ──────────────────────────────────────────────────────
deploy_apps() {
    echo "📦 Deploying applications to Kubernetes..."
    kubectl apply -f k8s/
    echo "✅ Applications deployed"

    echo "⏳ Waiting for deployments to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/go-api-deployment
    kubectl wait --for=condition=available --timeout=300s deployment/python-worker-deployment
    echo "✅ All deployments are ready"
}

# ─── Main ─────────────────────────────────────────────────────────────────────
check_requirements

echo "🔍 Checking Minikube status..."
if ! check_minikube; then
    start_minikube
else
    echo "🎯 Proceeding with existing Minikube cluster..."
fi

# Verify kubectl connection
echo "🔗 Verifying kubectl connection..."
kubectl get nodes
echo "✅ Connected to Kubernetes cluster"

# Deploy
deploy_apps

# ─── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo "🎉 Deployment completed successfully!"
echo ""
echo "📊 Current status:"
kubectl get pods
kubectl get services
echo ""
echo "🌐 To access the Go API:"
echo "   kubectl port-forward service/go-api-service 8080:80"
echo "   Then visit: http://localhost:8080/health"
echo ""
echo "📝 To check logs:"
echo "   kubectl logs -f deployment/go-api-deployment"
echo "   kubectl logs -f deployment/python-worker-deployment"