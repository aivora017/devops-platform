#!/bin/bash

# Complete deployment script for fresh environment
# Sets up: Terraform → Jenkins EC2 → Ansible Configuration → EKS Cluster → App Deployment
# Usage: ./scripts/deploy-complete.sh

set -e

BOLD='\033[1m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_section() {
    echo -e "\n${BOLD}${BLUE}=========================================${NC}"
    echo -e "${BOLD}${BLUE}$1${NC}"
    echo -e "${BOLD}${BLUE}=========================================${NC}\n"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Check prerequisites
log_section "Checking Prerequisites"

for tool in aws kubectl docker terraform ansible; do
    if ! command -v $tool &>/dev/null; then
        echo -e "${RED}❌ Required tool not found: $tool${NC}"
        exit 1
    fi
done
log_success "All required tools found"

# Verify AWS credentials
log_info "Verifying AWS credentials..."
if ! aws sts get-caller-identity &>/dev/null; then
    echo "❌ AWS credentials not configured. Run: aws configure"
    exit 1
fi
log_success "AWS credentials valid"

# Step 1: Create Terraform infrastructure (Jenkins EC2 + EKS)
log_section "Step 1: Creating Infrastructure with Terraform"

cd terraform/aws

log_info "Initializing Terraform..."
terraform init

log_info "Applying Terraform configuration..."
terraform apply -auto-approve

# Capture outputs
log_info "Retrieving deployment outputs..."
JENKINS_IP=$(terraform output -raw jenkins_public_ip)
JENKINS_INSTANCE_ID=$(terraform output -raw jenkins_instance_id)
CLUSTER_NAME=$(terraform output -raw eks_cluster_name)
CONFIGURE_KUBECTL=$(terraform output -raw configure_kubectl)

log_success "Infrastructure created"
log_info "Jenkins IP: $JENKINS_IP"
log_info "Jenkins Instance ID: $JENKINS_INSTANCE_ID"
log_info "EKS Cluster: $CLUSTER_NAME"

cd ../..

# Step 2: Wait for Jenkins instance to be ready
log_section "Step 2: Waiting for Jenkins EC2 Instance"

log_info "Waiting for SSH to be available on Jenkins instance..."
max_retries=30
retry_count=0

while ! nc -z $JENKINS_IP 22 2>/dev/null; do
    retry_count=$((retry_count + 1))
    if [ $retry_count -ge $max_retries ]; then
        echo "❌ Timeout waiting for Jenkins SSH"
        exit 1
    fi
    echo -ne "Waiting... ${retry_count}/${max_retries}\r"
    sleep 5
done
log_success "Jenkins instance is reachable via SSH"

sleep 10  # Additional wait for services to start

# Step 3: Configure Ansible and run playbook
log_section "Step 3: Configuring Jenkins with Ansible"

# Update Ansible inventory with Jenkins IP
log_info "Updating Ansible inventory with Jenkins IP: $JENKINS_IP"
cat > ansible/inventory.ini <<EOF
[jenkins]
$JENKINS_IP ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/devops-platform ansible_ssh_common_args='-o StrictHostKeyChecking=no'

[jenkins:vars]
ansible_python_interpreter=/usr/bin/python3
EOF
log_success "Ansible inventory updated"

# Run Ansible playbook
log_info "Running Ansible playbook to configure Jenkins..."
if ansible-playbook -i ansible/inventory.ini ansible/playbook.yml; then
    log_success "Ansible configuration completed"
else
    log_warning "Ansible encountered some issues, but continuing..."
fi

# Wait for Jenkins to be fully up
log_info "Waiting for Jenkins to start..."
sleep 30

max_jenkins_retries=10
jenkins_retry=0
while ! curl -s -o /dev/null -w "%{http_code}" http://$JENKINS_IP:8080 | grep -q "200\|403"; do
    jenkins_retry=$((jenkins_retry + 1))
    if [ $jenkins_retry -ge $max_jenkins_retries ]; then
        log_warning "Jenkins may still be starting. You can check: http://$JENKINS_IP:8080"
        break
    fi
    echo -ne "Waiting for Jenkins... ${jenkins_retry}/${max_jenkins_retries}\r"
    sleep 10
done

log_success "Jenkins is configured and accessible"

# Step 4: Configure EKS access
log_section "Step 4: Configuring EKS Access"

log_info "Running: $CONFIGURE_KUBECTL"
eval "$CONFIGURE_KUBECTL"
log_success "kubectl configured for EKS cluster"

# Step 5: Deploy to EKS
log_section "Step 5: Deploying Applications to EKS"

log_info "Creating devops namespace..."
kubectl create namespace devops --dry-run=client -o yaml | kubectl apply -f -

log_info "Deploying applications from k8s/aws/..."
kubectl apply -f k8s/aws/namespace.yaml
kubectl apply -f k8s/aws/go-api-deployment.yaml
kubectl apply -f k8s/aws/python-worker-deployment.yaml

log_info "Waiting for deployments to be ready..."
kubectl rollout status deployment/go-api -n devops --timeout=5m || true
kubectl rollout status deployment/python-worker -n devops --timeout=5m || true

log_success "Applications deployed to EKS"

# Final Summary
log_section "🎉 Deployment Complete!"

cat << EOF
${BOLD}Infrastructure Summary:${NC}

${BOLD}Jenkins:${NC}
  URL: http://$JENKINS_IP:8080
  IP: $JENKINS_IP
  Instance ID: $JENKINS_INSTANCE_ID
  SSH: ssh -i ~/.ssh/devops-platform ubuntu@$JENKINS_IP

${BOLD}EKS Cluster:${NC}
  Name: $CLUSTER_NAME
  Region: ap-southeast-2

${BOLD}Next Steps:${NC}
  1. Access Jenkins: http://$JENKINS_IP:8080
     - Get initial password with: ssh -i ~/.ssh/devops-platform ubuntu@$JENKINS_IP
     - Then: sudo cat /var/lib/jenkins/secrets/initialAdminPassword
  
  2. Check application deployments:
     kubectl get deployments -n devops
     kubectl get pods -n devops
     kubectl get svc -n devops
  
  3. View logs:
     kubectl logs -f deployment/go-api -n devops
     kubectl logs -f deployment/python-worker -n devops

${BOLD}To destroy all infrastructure:${NC}
  cd terraform/aws && terraform destroy -auto-approve && cd ../..

${BOLD}Terraform outputs:${NC}
  cd terraform/aws && terraform output

EOF

log_success "Deployment script completed successfully!"
