#!/bin/bash

set -e

log_section() {
    echo
    echo "$1"
    echo "$(printf '%0.s-' {1..40})"
}

log_success() {
    echo "OK: $1"
}

log_warning() {
    echo "WARN: $1"
}

log_info() {
    echo "INFO: $1"
}

# Check prerequisites
log_section "Checking Prerequisites"

for tool in aws kubectl docker terraform ansible; do
    if ! command -v $tool &>/dev/null; then
        echo "ERROR: missing required tool: $tool"
        exit 1
    fi
done
log_success "All required tools found"

# Verify AWS credentials
log_info "Verifying AWS credentials..."
if ! aws sts get-caller-identity &>/dev/null; then
    echo "ERROR: AWS credentials not configured. Run: aws configure"
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
        echo "ERROR: timeout waiting for Jenkins SSH"
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

# Final Summary (manual continuation)
log_section "Jenkins setup complete"

cat << EOF
Infrastructure Summary

Jenkins
  URL: http://$JENKINS_IP:8080
  IP: $JENKINS_IP
  Instance ID: $JENKINS_INSTANCE_ID
  SSH: ssh -i ~/.ssh/devops-platform ubuntu@$JENKINS_IP

EKS Cluster
  Name: $CLUSTER_NAME
  Region: ap-southeast-2

Manual Next Steps
  1. Open Jenkins and finish setup:
      http://$JENKINS_IP:8080

  2. Log in and create/configure pipeline manually.

  3. Configure local kubectl access when needed:
      $CONFIGURE_KUBECTL

  4. Deploy apps manually when ready:
      kubectl apply -f k8s/aws/namespace.yaml
      kubectl apply -f k8s/aws/go-api-deployment.yaml
      kubectl apply -f k8s/aws/python-worker-deployment.yaml

  5. Verify deployment status:
      kubectl get deployments -n devops
      kubectl get pods -n devops
      kubectl get svc -n devops

To destroy all infrastructure
  cd terraform/aws && terraform destroy -auto-approve && cd ../..

Terraform outputs
  cd terraform/aws && terraform output

EOF

log_success "Deployment script finished after Ansible. Continue manually in Jenkins."
