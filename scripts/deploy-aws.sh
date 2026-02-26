#!/bin/bash

# Fast deploy script for AWS EKS
# Usage: ./scripts/deploy-aws.sh

set -e

echo "========================================="
echo "DevOps Platform - AWS EKS Deployment"
echo "========================================="

# Check prerequisites
echo "🔍 Checking prerequisites..."
for tool in aws kubectl docker terraform; do
    if ! command -v $tool &>/dev/null; then
        echo "❌ Required tool not found: $tool"
        exit 1
    fi
done
echo "✅ All tools found"

# AWS configuration
echo ""
echo "📋 Checking AWS configuration..."
if ! aws sts get-caller-identity &>/dev/null; then
    echo "❌ AWS credentials not configured"
    echo "Run: aws configure"
    exit 1
fi
echo "✅ AWS credentials valid"

# Create cluster
echo ""
echo "🔨 Creating EKS cluster..."
cd terraform/aws
terraform init
terraform apply -auto-approve
cd ../..

# Get cluster info
echo ""
echo "📡 Updating kubeconfig..."
CLUSTER_NAME=$(terraform output -raw cluster_name 2>/dev/null || echo "devops-platform-cluster")
aws eks update-kubeconfig --name $CLUSTER_NAME --region ap-southeast-2

echo "✅ Cluster ready"

# Deploy apps
echo ""
echo "🚀 Deploying applications..."
kubectl apply -f k8s/aws/

echo ""
echo "⏳ Waiting for deployments..."
sleep 5

# Show status
echo ""
echo "📊 Deployment Status:"
echo "---"
kubectl get pods -n devops
echo ""
kubectl get svc -n devops

# Get endpoint
echo ""
echo "========================================="
echo "✅ Deployment Complete!"
echo "========================================="
echo ""
echo "Access Go API:"
LB_IP=$(kubectl get svc go-api-service -n devops -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "EXTERNAL-IP-PENDING")
if [ "$LB_IP" != "EXTERNAL-IP-PENDING" ]; then
    echo "  http://$LB_IP/"
    echo "  http://$LB_IP/health"
else
    echo "  Waiting for LoadBalancer IP (may take 1-2 minutes)..."
    echo "  Run: kubectl get svc go-api-service -n devops"
fi

echo ""
echo "View logs:"
echo "  kubectl logs -n devops -f deployment/python-worker"
