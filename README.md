# DevOps Platform - AWS Edition

A simple CI/CD pipeline for deploying containerized Go and Python apps to AWS EKS.

## What's in here?

- **app-go/** - Go API (endpoints: /, /health, /version)
- **app-python/** - Python worker (monitors Go API health)
- **docker/** - Dockerfiles for both apps
- **k8s/aws/** - Kubernetes manifests for AWS EKS deployment
- **terraform/aws/** - Infrastructure as code for AWS (VPC, EKS cluster)
- **Jenkinsfile** - CI/CD pipeline (build → push → deploy)

## Prerequisites

```bash
aws configure          # Set up AWS credentials
kubectl installed      # Kubernetes CLI
docker installed       # For local testing
terraform installed    # For IaC
```

## Quick Start

### 1. Create AWS EKS Cluster

```bash
cd terraform/aws
terraform init
terraform apply
```

### 2. Configure kubectl

```bash
aws eks update-kubeconfig --name devops-platform-cluster --region ap-southeast-2
kubectl cluster-info
```

### 3. Deploy Applications

```bash
kubectl apply -f ../../k8s/aws/
kubectl get pods -n devops
```

### 4. Access Go API

```bash
kubectl get svc go-api-service -n devops
# Use the EXTERNAL-IP from output
```

## Jenkins Pipeline

Triggers automatically on push to `main` branch:
1. **Build** - Docker images
2. **Push** - To Docker Hub
3. **Deploy** - Update EKS
4. **Health Check** - Verify pods running

## Local Testing

```bash
docker build -t devops-go-app app-go/
docker build -t devops-python-worker app-python/
docker-compose up
```

## Cleanup

```bash
kubectl delete namespace devops
cd terraform/aws && terraform destroy
```
