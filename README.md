# DevOps Platform - Complete CI/CD with Kubernetes & Jenkins

A production-ready DevOps platform demonstrating end-to-end cloud infrastructure, containerization, and automated deployment pipelines.

## 🎯 Overview

This project showcases a complete DevOps workflow from code commit to production deployment on AWS. It combines multiple technologies to create a scalable, automated platform that can handle real-world scenarios.

**Key Achievement:** Automated CI/CD pipeline that builds, tests, and deploys containerized applications to Kubernetes with automatic scaling - **31,400+ requests handled during load testing without failure** ✅

---

## ✨ Key Features

✅ **Infrastructure as Code** - Complete AWS infrastructure automated with Terraform  
✅ **Containerization** - Multi-stage Docker builds for Go and Python applications  
✅ **CI/CD Pipeline** - Jenkins with GitHub webhook integration for automatic deployments  
✅ **Kubernetes Orchestration** - AWS EKS with rolling updates and zero-downtime deployments  
✅ **Auto-Scaling** - Horizontal Pod Autoscaler for dynamic resource management  
✅ **Load Balancing** - AWS LoadBalancer distributing traffic across pods  
✅ **Security** - IAM roles, VPC isolation, and secure credential management  

---

## 🛠️ Tech Stack

| Component | Technology | Details |
|-----------|-----------|---------|
| Cloud Platform | AWS | EKS, EC2, VPC, IAM, ALB |
| Infrastructure | Terraform | Modular, version controlled |
| Orchestration | Kubernetes | EKS v1.30.14, 2x t3.small nodes |
| Backend | Go 1.21 | API server with health endpoints |
| Worker | Python 3.10 | Background job processing |
| Containers | Docker | Multi-stage builds, Docker Hub registry |
| CI/CD | Jenkins 2.x | Declarative pipeline, GitHub webhook |
| Auto-Scaling | Kubernetes HPA | CPU-based scaling 1-5 replicas |

---

## 📊 Project Structure

```
devops-platform/
├── terraform/           # Infrastructure as Code
│   └── aws/
│       ├── main.tf, network.tf, output.tf, variable.tf
│       └── modules/     # VPC, EKS, EC2, Security Groups, Node Groups
├── app-go/              # Go API Application
├── app-python/          # Python Worker Application
├── docker/              # Container definitions
│   ├── go/Dockerfile    # Multi-stage Go build
│   └── python/Dockerfile
├── k8s/aws/             # Kubernetes manifests
│   ├── deployments
│   ├── services
│   └── hpa.yaml         # Auto-scaling config
├── scripts/             # Deployment automation
├── Jenkinsfile          # CI/CD pipeline definition
├── docs/                # Documentation
│   ├── ARCHITECTURE.md  # System design
│   ├── PROJECT_FLOW.md  # Workflow details
│   └── TROUBLESHOOTING.md # Issues & solutions
└── README.md            # This file
```

---

## 🚀 Quick Start

### Prerequisites
```bash
✓ AWS Account with credentials configured
✓ Terraform installed
✓ kubectl installed
✓ Docker installed (optional, for local testing)
✓ Ansible installed (if using complete deployment script)
```

### Option 1: Automated Deployment (Recommended)

We provide shell scripts to automate the entire deployment process.

**Fast Deploy (EKS Only):**
```bash
git clone https://github.com/aivora017/devops-platform.git
cd devops-platform
aws configure  # Set your AWS credentials
bash scripts/deploy-aws.sh
```

**Complete Deploy (Everything including Jenkins):**
```bash
git clone https://github.com/aivora017/devops-platform.git
cd devops-platform
aws configure  # Set your AWS credentials
bash scripts/deploy-complete.sh
```

The complete deployment script handles:
- ✅ Terraform infrastructure provisioning
- ✅ Jenkins EC2 instance setup
- ✅ Ansible configuration of Jenkins
- ✅ EKS cluster creation
- ✅ Application deployment to Kubernetes
- ✅ Auto-scaling configuration

### Option 2: Manual Deployment (Step-by-Step)

**Step 1: Clone & Configure**
```bash
git clone https://github.com/aivora017/devops-platform.git
cd devops-platform
aws configure  # Set your AWS credentials
```

**Step 2: Deploy Infrastructure**
```bash
cd terraform/aws
terraform init
terraform plan   # Review changes
terraform apply  # Deploy (takes ~15-20 min)
```

**Step 3: Verify & Access**
```bash
# Check cluster
kubectl get nodes

# View applications
kubectl get pods -n devops

# Get LoadBalancer endpoint
kubectl get svc go-api-service -n devops
```

---

## 🔄 How CI/CD Works

The pipeline automatically triggers when you push code to GitHub:

```
1. Developer pushes code → GitHub
                ↓
2. GitHub webhook → Jenkins
                ↓
3. Jenkins Build Stage
   • Checkbox: Git checkout
   • Build Go & Python Docker images
   • Push to Docker Hub (aivora017/* with version tags)
                ↓
4. Jenkins Deploy Stage
   • kubectl updates Kubernetes deployments
   • Pulls new images from Docker Hub
   • Rolling update strategy (zero downtime)
                ↓
5. Kubernetes takes over
   • New pods spin up with updated code
   • Old pods gracefully terminated
   • HPA monitors and scales as needed
                ↓
6. Result
   • Production updated automatically
   • No manual intervention needed
   • Users experience zero downtime
```

### Example Commit Flow
```bash
$ git commit -am "Add new API endpoint"
$ git push origin main

Jenkins Build #15 starts automatically ⚡
├─ Clones repo ✓
├─ Builds Docker images ✓
├─ Pushes to Docker Hub ✓
└─ Deploys to EKS ✓

Users can access new endpoint immediately!
```

---

## 📈 Performance & Testing

**Load Test Results (Continuous 390 seconds):**
- Total Requests: 31,400+
- Throughput: 80 requests/sec
- Pod Scaling: Auto-scaled to handle load
- Failures: **0**
- Downtime: **0**

```bash
# Run load test yourself
bash /tmp/continuous-load.sh  # Ctrl+C to stop
```

---

## 🏗️ Architecture

```
┌─────────────────── AWS ──────────────────┐
│                                           │
│  VPC (10.0.0.0/16)                       │
│  ├── Public Subnet: Jenkins EC2          │
│  └── Private Subnets: EKS Cluster        │
│      ├── 2x t3.small Nodes               │
│      └── Kubernetes Services             │
│          ├── go-api (2/2 pods)           │
│          ├── python-worker (1/1 pod)     │
│          ├── HPA (1-5 replicas)          │
│          └── LoadBalancer (AWS ALB)      │
│              └── External IP (auto DNS)  │
│                                           │
└───────────────────────────────────────────┘
```

**Detailed architecture diagram in [docs/ARCHITECTURE.md](./docs/ARCHITECTURE.md)**

---

## 🐛 Troubleshooting

**Having issues?** Check the [TROUBLESHOOTING.md](./docs/TROUBLESHOOTING.md) guide which includes:
- Common errors and solutions
- Debugging commands
- Performance optimization tips
- Jenkins configuration issues
- Kubernetes networking problems

Quick diagnostics:
```bash
# Check pod status
kubectl get pods -n devops -o wide

# View pod logs
kubectl logs -n devops deployment/go-api

# Check service details
kubectl describe svc go-api-service -n devops

# Monitor HPA
kubectl describe hpa go-api-hpa -n devops
```

---

## 📚 Complete Documentation

1. **[ARCHITECTURE.md](./docs/ARCHITECTURE.md)** - Detailed system design and components
2. **[PROJECT_FLOW.md](./docs/PROJECT_FLOW.md)** - Step-by-step workflow explanation
3. **[TROUBLESHOOTING.md](./docs/TROUBLESHOOTING.md)** - Problems faced and solutions
4. **[docs/SETUP.md](./docs/SETUP.md)** - Detailed setup instructions

---

## 🔐 Security Features

- **IAM Roles**: Jenkins uses EC2 instance role (no credentials stored on disk)
- **kubeconfig**: Secure Kubernetes access via AWS exec plugin
- **VPC Isolation**: Applications in private subnets
- **Security Groups**: Restrictive ingress/egress rules
- **Secret Management**: Docker Hub credentials stored securely in Jenkins

---

## 🚀 What I Learned

This project involved learning and implementing:
- ✅ Infrastructure as Code with Terraform (modular design)
- ✅ Kubernetes concepts (deployments, services, HPA, namespaces)
- ✅ CI/CD pipeline design and automation
- ✅ Container orchestration and scaling
- ✅ AWS services (EKS, EC2, VPC, IAM, ALB)
- ✅ Jenkins pipeline scripting
- ✅ Docker image optimization
- ✅ Load testing and performance monitoring
- ✅ Troubleshooting and debugging production issues

---

## 🎯 Interview Talking Points

1. **Infrastructure Automation**: "I used Terraform modules to make the infrastructure reusable and maintainable"
2. **CI/CD Pipeline**: "The entire process from code push to production is automated with Jenkins and GitHub webhooks"
3. **Scalability**: "HPA automatically scales pods based on CPU metrics, tested with 31,400+ concurrent requests"
4. **Zero-Downtime Deployments**: "Kubernetes rolling updates ensure users never experience downtime"
5. **Multi-Service Architecture**: "Project demonstrates polyglot microservices with Go and Python"
6. **Cloud-Native**: "Fully cloud-native design using AWS services and Kubernetes"
7. **Problem Solving**: "Documented and solved multiple integration challenges (Jenkins kubectl auth, kubeconfig permissions, etc.)"

---

## 🔗 Useful Commands

```bash
# Development
docker-compose up                           # Local testing
docker build -t app-name app-dir/           # Build locally

# Deployment
terraform apply -auto-approve               # Deploy changes
kubectl apply -f k8s/aws/                   # Deploy manually

# Monitoring
kubectl get all -n devops                   # All resources
kubectl top pods -n devops                  # Resource usage
watch -n 2 'kubectl get pods -n devops'     # Watch pods

# Cleanup
kubectl delete namespace devops             # Delete app
terraform destroy                           # Delete infrastructure
```

---

## 📞 Support & Questions

- 📖 Check [TROUBLESHOOTING.md](./docs/TROUBLESHOOTING.md) for common issues
- 🏗️ Review [ARCHITECTURE.md](./docs/ARCHITECTURE.md) for system design details
- 🔄 See [PROJECT_FLOW.md](./docs/PROJECT_FLOW.md) for workflow explanation

---

## 📝 License

Open source - feel free to use for learning and development

---

**Status**: Production Ready ✅  
**Last Updated**: February 27, 2026  
**Author**: Sourav (DevOps Fresher)
