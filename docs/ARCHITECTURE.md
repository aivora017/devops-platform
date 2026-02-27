# System Architecture - DevOps Platform

## Overview

This document explains the complete architecture of the DevOps Platform, how all components interact, and the design decisions behind each choice.

---

## 🏗️ High-Level Architecture

```
┌────────────────────────────────── AWS ACCOUNT (ap-southeast-2) ──────────────────────────────────┐
│                                                                                                    │
│  ┌─────────────────── VPC (10.0.0.0/16) ───────────────────┐                                   │
│  │                                                           │                                   │
│  │  ┌──────────────────── Public Subnet ────────────────┐  │                                   │
│  │  │                                                    │  │                                   │
│  │  │  ┌─────────── Jenkins EC2 (t3.small) ──────┐     │  │                                   │
│  │  │  │ • Java 21, Docker installed              │     │  │                                   │
│  │  │  │ • Pipeline CI/CD                         │     │  │                                   │
│  │  │  │ • IAM Role: jenkins-role                 │     │  │                                   │
│  │  │  │ • Security Group: Jenkins ports 8080,22  │     │  │                                   │
│  │  │  │ • IP: 15.134.1.230                       │     │  │                                   │
│  │  │  └─────────────────────────────────────────┘     │  │                                   │
│  │  │         ⬆                                          │  │                                   │
│  │  │         │ GitHub Webhook (push events)            │  │                                   │
│  │  │         │                                          │  │                                   │
│  │  └─────────┼──────────────────────────────────────────┘  │                                   │
│  │            │                                              │                                   │
│  │  ┌─────────┼────────── Private Subnet #1 ─────────────┐  │                                   │
│  │  │         │                                           │  │                                   │
│  │  │  ┌──────▼────── EKS Control Plane ─────────┐       │  │                                   │
│  │  │  │ • Managed Kubernetes v1.30.14            │       │  │                                   │
│  │  │  │ • AWS-managed (no nodes to manage)       │       │  │                                   │
│  │  │  │ • Auto-patching & updates                │       │  │                                   │
│  │  │  │ • Integrated with VPC & Security Groups  │       │  │                                   │
│  │  │  └───────────────────────────────────────────┘       │  │                                   │
│  │  │           ⬆                                          │  │                                   │
│  │  │           │ kubectl apply                           │  │                                   │
│  │  │           │                                          │  │                                   │
│  │  └───────────┼──────────────────────────────────────────┘  │                                   │
│  │              │                                              │                                   │
│  │  ┌───────────┼─── Private Subnet #2 (Worker Nodes) ──┐     │                                   │
│  │  │           │                                       │     │                                   │
│  │  │  ┌────────▼──────────┐    ┌──────────────────┐   │     │                                   │
│  │  │  │ Node #1           │    │ Node #2          │   │     │                                   │
│  │  │  │ (t3.small)        │    │ (t3.small)       │   │     │                                   │
│  │  │  │                   │    │                  │   │     │                                   │
│  │  │  │ ┌───────────────┐ │    │ ┌──────────────┐ │   │     │                                   │
│  │  │  │ │ go-api pod #1 │ │    │ │ go-api pod#2 │ │   │     │                                   │
│  │  │  │ │ (1024Mi RAM)  │ │    │ │ (1024Mi RAM) │ │   │     │                                   │
│  │  │  │ └───────────────┘ │    │ └──────────────┘ │   │     │                                   │
│  │  │  │                   │    │ ┌──────────────┐ │   │     │                                   │
│  │  │                   │    │ │ python-     │ │   │     │                                   │
│  │  │                   │    │ │ worker pod  │ │   │     │                                   │
│  │  │                   │    │ │ (512Mi RAM) │ │   │     │                                   │
│  │  │                   │    │ └──────────────┘ │   │     │                                   │
│  │  │  │                   │    │                  │   │     │                                   │
│  │  │  └───────────────────┘    └──────────────────┘   │     │                                   │
│  │  │           ⬆                      ⬆               │     │                                   │
│  │  └───────────┼──────────────────────┬───────────────┘     │                                   │
│  │              │                      │                     │                                   │
│  │  ┌───────────┴──────────────────────▼──── Services ────┐  │                                   │
│  │  │                                                      │  │                                   │
│  │  │  • go-api-service (LoadBalancer)                   │  │                                   │
│  │  │  • python-worker-service (ClusterIP)              │  │                                   │
│  │  │  • metrics-server (ClusterIP)                     │  │                                   │
│  │  │                                                      │  │                                   │
│  │  └──────────────────────────────────────────────────────┘  │                                   │
│  │                                                            │                                   │
│  │  ┌────── HPA (Horizontal Pod Autoscaler) ───────────────┐  │                                   │
│  │  │                                                       │  │                                   │
│  │  │  go-api-hpa                                          │  │                                   │
│  │  │  • Min replicas: 1, Max: 5                          │  │                                   │
│  │  │  • Target CPU: 70%                                 │  │                                   │
│  │  │  • Metrics: From Kubernetes metrics-server (30s)   │  │                                   │
│  │  │                                                       │  │                                   │
│  │  │  python-worker-hpa                                  │  │                                   │
│  │  │  • Min replicas: 1, Max: 3                          │  │                                   │
│  │  │  • Target CPU: 75%                                 │  │                                   │
│  │  │                                                       │  │                                   │
│  │  └───────────────────────────────────────────────────────┘  │                                   │
│  │                                                            │                                   │
│  │  ┌────── AWS LoadBalancer (ALB) ────────────────────────┐  │                                   │
│  │  │                                                       │  │                                   │
│  │  │  EXTERNAL-IP:                                        │  │                                   │
│  │  │  aab24d51321ae480b9702f42280dd802-980280726.       │  │                                   │
│  │  │  ap-southeast-2.elb.amazonaws.com                   │  │                                   │
│  │  │                                                       │  │                                   │
│  │  │  Port mapping:                                       │  │                                   │
│  │  │  • LoadBalancer Service (port 80) →                │  │                                   │
│  │  │  • Target Group → go-api pods (port 8080)         │  │                                   │
│  │  │                                                       │  │                                   │
│  │  └───────────────────────────────────────────────────────┘  │                                   │
│  │                                                            │                                   │
│  └────────────────────────────────────────────────────────────┘                                   │
│                                                                                                    │
│  ┌──────────── IAM Roles & Policies ──────────┐                                                  │
│  │                                             │                                                  │
│  │  jenkins-role (EC2 Instance Role)          │                                                  │
│  │  • AmazonEKS_CNI_Policy                    │                                                  │
│  │  • AmazonECS_TaskExecutionRolePolicy       │                                                  │
│  │  • AmazonEC2FullAccess                     │                                                  │
│  │  • AmazonECRFullAccess                     │                                                  │
│  │  • EKS management permissions              │                                                  │
│  │                                             │                                                  │
│  │  EKS Node Role                             │                                                  │
│  │  • AmazonEKSWorkerNodePolicy               │                                                  │
│  │  • AmazonEKS_CNI_Policy                    │                                                  │
│  │  • AmazonEC2ContainerRegistryReadOnly      │                                                  │
│  │                                             │                                                  │
│  └─────────────────────────────────────────────┘                                                  │
│                                                                                                    │
└────────────────────────────────────────────────────────────────────────────────────────────────────┘

                                    ⬇
                    ┌─────────────────────────────┐
                    │  Docker Hub Registry        │
                    │  aivora017/* images         │
                    │  • devops-go-app:v15        │
                    │  • devops-python-worker:v15 │
                    └─────────────────────────────┘

                                    ⬇
                    ┌─────────────────────────────┐
                    │  GitHub Repository          │
                    │  (Source Code + Manifests)  │
                    │  Triggers: push to main     │
                    └─────────────────────────────┘
```

---

## 🔗 Component Interactions

### Data Flow

```
Developer
   ├─ Commits code to GitHub
   │
   ├─ Webhook triggers Jenkins
   │
   ├─ Jenkins clones repo
   │
   ├─ Builds Docker images
   │     ├─ Go API server
   │     └─ Python worker
   │
   ├─ Pushes to Docker Hub
   │
   ├─ Updates Kubernetes
   │     ├─ kubectl set image
   │     └─ Pulls new images
   │
   ├─ Kubernetes deploys
   │     ├─ Rolling update
   │     ├─ Health checks
   │     └─ Zero downtime
   │
   └─ Users access via ALB
        └─ LoadBalancer DNS
            └─ Routes to go-api pods
```

### Request Flow

```
User Request
   ⬇
AWS ALB (Load Balancer)
   ├─ Distributes traffic
   ├─ Health checks pods
   └─ Connection management
   ⬇
Target Group (go-api pods)
   ├─ Node #1: go-api pod #1
   └─ Node #2: go-api pod #2
   ⬇
Go API Server (8080)
   ├─ GET / → "Hello World"
   ├─ GET /health → {"status": "healthy"}
   └─ GET /version → {"version": "v15"}
   ⬇
Response back to User
```

---

## 📊 Infrastructure Components

### AWS VPC
- **CIDR Block**: 10.0.0.0/16
- **Subnets**:
  - Public #1: 10.0.1.0/24 (Jenkins, NAT Gateway)
  - Public #2: 10.0.2.0/24 (Backup public)
  - Private #1: 10.0.10.0/24 (EKS Control Plane)
  - Private #2: 10.0.11.0/24 (Worker Nodes)
  - Private #3: 10.0.12.0/24 (Additional nodes)

### Security Groups

**Jenkins Security Group:**
- Inbound: 8080 (Jenkins UI), 22 (SSH), 443 (HTTPS)
- Outbound: All traffic
- Purpose: Allow web access & cluster communication

**EKS Cluster Security Group:**
- Inbound: All from VPC CIDR
- Inbound: 443 from Jenkins (API access)
- Outbound: All traffic
- Purpose: Pod communication & external APIs

---

## 🎯 Kubernetes Architecture

### Namespace: `devops`

All applications run in the `devops` namespace for isolation.

### Go API Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: go-api
  namespace: devops
spec:
  replicas: 2  # Can scale 1-5 via HPA
  selector:
    matchLabels:
      app: go-api
  template:
    metadata:
      labels:
        app: go-api
    spec:
      containers:
      - name: go-api
        image: aivora017/devops-go-app:v15  # Pulled from Docker Hub
        ports:
        - containerPort: 8080
        resources:
          requests:
            cpu: 100m
            memory: 256Mi
          limits:
            cpu: 500m
            memory: 512Mi
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 30
        readinessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 10
```

**Key Features:**
- 2 replicas (minimum) for high availability
- CPU requests: 100m, limits: 500m per pod
- Memory requests: 256Mi, limits: 512Mi per pod
- Liveness probe: Restart if `/health` fails after 10s
- Readiness probe: Remove from service if unhealthy
- Image pulled from Docker Hub (ImagePullPolicy: Always)

### Python Worker Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: python-worker
  namespace: devops
spec:
  replicas: 1
  selector:
    matchLabels:
      app: python-worker
  template:
    metadata:
      labels:
        app: python-worker
    spec:
      containers:
      - name: worker
        image: aivora017/devops-python-worker:v15
        resources:
          requests:
            cpu: 50m
            memory: 128Mi
          limits:
            cpu: 200m
            memory: 256Mi
        env:
        - name: GO_API_URL
          value: "http://go-api-service:8080"
```

**Key Features:**
- 1 replica (can scale 1-3 via HPA)
- Minimal resources (background worker)
- Environment variable for service discovery
- Monitors go-api health via HTTP calls

### Services

**go-api-service (LoadBalancer)**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: go-api-service
spec:
  type: LoadBalancer
  selector:
    app: go-api
  ports:
  - protocol: TCP
    port: 80
    targetPort: 8080
```

- Type: LoadBalancer (AWS ALB created automatically)
- Maps port 80 → 8080
- External IP assigned by AWS
- Used by python-worker for health checks

**python-worker-service (ClusterIP)**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: python-worker-service
spec:
  type: ClusterIP
  selector:
    app: python-worker
  ports:
  - port: 5000
    targetPort: 5000
```

- Type: ClusterIP (internal only)
- No external IP
- Used only within cluster if needed

### Horizontal Pod Autoscaler (HPA)

**go-api-hpa**
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: go-api-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: go-api
  minReplicas: 1
  maxReplicas: 5
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

**Scaling Logic:**
- Monitors CPU usage every 30 seconds
- If avg CPU > 70%, scale up (add pod)
- If avg CPU < 70%, wait 3 min then scale down
- Example: 4 pods at 90% CPU → scales to 5

**How it works in practice:**
```
Time    Pods   CPU Usage   Action
0:00    2      20%         Stable
2:30    2      45%         Stable
5:00    2      72%         CPU > 70%
5:30    3      65%         Pending metric update
6:00    3      68%         Still > threshold
6:30    4      71%         CPU > 70%
9:00    3      65%         Wait 3 min done, scale down
```

---

## 🔐 Security & IAM

### IAM Role: jenkins-role

Allows Jenkins EC2 instance to:

1. **EKS Management**
   - `eks:*` - Full EKS access
   - `ec2:DescribeInstances`, `ec2:DescribeTags` - Node info

2. **Docker Hub Authentication**
   - Credentials stored in Jenkins (not in code)
   - Docker agent uses Jenkins secrets

3. **Kubernetes Access**
   - EC2 instance role → AWS credentials
   - EKS adds role to ConfigMap (aws-auth)
   - kubectl uses exec plugin for credentials
   - No stored kubeconfig needed (more secure)

### EKS RBAC Configuration

Jenkins role added to aws-auth ConfigMap:
```yaml
mapRoles: |
  - rolearn: arn:aws:iam::579813049088:role/jenkins-role
    username: jenkins-user
    groups:
      - system:masters
```

This grants Jenkins full cluster access after EC2 instance assumes the role.

---

## 🔄 Deployment Process

### Trigger: GitHub Push

```
1. Developer commits code
2. GitHub webhook sends POST to Jenkins: http://15.134.1.230:8080/github-webhook/
3. Jenkins receives event
```

### Build Stage

```groovy
stages {
    stage('Build') {
        steps {
            // Checkout code
            git branch: 'main', url: 'https://github.com/user/devops-platform.git'
            
            // Build Go image
            sh 'docker build -t aivora017/devops-go-app:${BUILD_NUMBER} -f docker/go/Dockerfile .'
            
            // Build Python image  
            sh 'docker build -t aivora017/devops-python-worker:${BUILD_NUMBER} -f docker/python/Dockerfile .'
        }
    }
}
```

- BUILD_NUMBER: Jenkins auto-incrementing number
- Both images tagged with build number
- Docker BuildKit used for efficiency

### Push Stage

```groovy
stages {
    stage('Push to Docker Hub') {
        steps {
            // Credentials: docker_credentials (Jenkins secret)
            withCredentials([usernamePassword(credentialsId: 'docker_credentials', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                sh '''
                    docker login -u $DOCKER_USER -p $DOCKER_PASS
                    docker push aivora017/devops-go-app:${BUILD_NUMBER}
                    docker push aivora017/devops-python-worker:${BUILD_NUMBER}
                    docker push aivora017/devops-go-app:latest
                    docker push aivora017/devops-python-worker:latest
                '''
            }
        }
    }
}
```

- Docker Hub credentials from Jenkins secrets
- Images pushed with version tag AND :latest
- :latest always points to newest build

### Deploy Stage

```groovy
stages {
    stage('Deploy to EKS') {
        steps {
            sh '''
                export KUBECONFIG=/var/lib/jenkins/.kube/config
                kubectl set image deployment/go-api go-api=aivora017/devops-go-app:${BUILD_NUMBER} -n devops
                kubectl set image deployment/python-worker worker=aivora017/devops-python-worker:${BUILD_NUMBER} -n devops
            '''
        }
    }
}
```

**Key Points:**
- KUBECONFIG: Jenkins user home (not root!)
- kubectl auth: IAM role via exec plugin
- kubectl set image: Updates deployment (rolling update)
- Kubernetes pulls images from Docker Hub

### Kubernetes Rolling Update Process

After `kubectl set image`:

```
Time 0:00
├─ Current: go-api pod #1, go-api pod #2 (old image v14)

Time 0:30
├─ New: go-api pod #3 starts (new image v15)
├─ Status: Running, waiting for readiness

Time 1:00
├─ New: go-api pod #3 ready (passed readiness check)
├─ Old: go-api pod #1 terminates (graceful, 30s timeout)

Time 1:30
├─ New: go-api pod #4 starts (new image v15)
├─ Current: go-api pod #2 (v14), pod #3, #4 (v15)

Time 2:00
├─ New: go-api pod #4 ready
├─ Old: go-api pod #2 terminates

Time 2:30
├─ Result: All pods v15
├─ Total downtime: 0 seconds
└─ Users never noticed
```

---

## 📈 Scaling Scenario

When traffic increases during load test:

```
Minute 0: 2 pods, 1000 req/min
├─ CPU: 60% average
├─ Stable, no action

Minute 3: 5000 req/min
├─ CPU: 75% average
├─ Exceeds 70% threshold
├─ HPA detects at 3:30

Minute 4: HPA adds pod #3
├─ Metric server collects new data
├─ CPU now: 65% (load distributed)
├─ Stable again

Minute 6: 10000 req/min
├─ CPU: 80% average
├─ HPA adds pod #4

Minute 8: Peak load 15000 req/min
├─ CPU: 85% average
├─ HPA adds pod #5 (max reached)

Minute 10: Traffic drops
├─ 5000 req/min
├─ CPU: 45%
├─ HPA waits 3 minutes

Minute 13: HPA scales down to 4 pods
├─ Traffic stable at 5000 req/min
```

---

## 🔧 Configuration Files

### Docker Build Context

Go Dockerfile uses build context from project root:
```dockerfile
COPY app-go/ /build/
WORKDIR /build
```

Python Dockerfile:
```dockerfile
COPY app-python/ /build/
WORKDIR /build
```

Build commands:
```bash
# From project root
docker build -f docker/go/Dockerfile .
docker build -f docker/python/Dockerfile .
```

### Terraform Modules

**VPC Module:**
- Creates VPC with CIDR 10.0.0.0/16
- 6 subnets (3 public, 3 private)
- Internet Gateway, NAT Gateway
- Route tables and associations

**EKS Module:**
- EKS cluster (managed Kubernetes)
- Attaches to VPC
- Uses subnets from VPC module
- Creates service role (IAM)

**EC2 Module:**
- Jenkins instance (t3.small)
- Inside public subnet
- Elastic IP for consistent access
- Jenkins IAM role attached

**Security Group Module:**
- For Jenkins (ports 8080, 22, 443)
- For EKS (pod communication)
- For node communication

---

## 🚀 Performance Metrics

### Hardware

| Component | Specs | Cost/month |
|-----------|-------|-----------|
| EKS Cluster | Managed, v1.30.14 | $0.10/hour = $73 |
| 2x t3.small nodes | 2 vCPU, 2GB RAM each | $0.0208/hour = ~$30 |
| Jenkins EC2 | t3.small, 2 vCPU, 2GB RAM | $0.0208/hour = ~$30 |
| ALB | Application Load Balancer | ~$16 + data transfer |
| VPC & Networking | NAT Gateway, Volumes | ~$40 |
| **Total Estimate** | | **~$190-200/month** |

### Load Test Results

Executed continuous load test for 390 seconds:
```
Total Requests: 31,400+
Duration: 390 seconds
Throughput: 80 requests/sec
Peak Concurrent Connections: 50 per batch

Pod Scaling:
├─ Initial: 2 go-api pods
├─ CPU exceeded 70% threshold
├─ Scaled to 3 pods at 5:00
├─ Reached 4 pods at 7:30
├─ Maxed at 5 pods (HPA limit)
└─ All remained healthy

Results:
├─ Failed Requests: 0
├─ Downtime: 0
├─ Largest Response Time: <50ms
└─ Average Response Time: <20ms
```

---

## 🎓 Design Decisions

### Why AWS EKS over self-managed Kubernetes?

✅ Managed control plane (AWS handles upgrades)  
✅ Integrated with AWS services (IAM, VPC, ALB)  
✅ Built-in security (encryption at rest/transit)  
✅ No control plane to maintain  
❌ Less control over cluster configuration  

### Why Terraform for IaC?

✅ Multi-cloud support (AWS, GCP, Azure)  
✅ Modular design (reusable components)  
✅ State management (tracks infrastructure)  
✅ Plan before apply (preview changes)  
✅ Version control friendly  

### Why Jenkins for CI/CD?

✅ Kubernetes-native with plugins  
✅ Declarative pipelines (Jenkinsfile)  
✅ GitHub webhook integration  
✅ Easy Docker integration  
✅ Free and open source  

### Why Rolling Updates?

✅ Zero downtime  
✅ Easy rollback  
✅ Gradual traffic shift  
✅ Built into Kubernetes  

### Why HPA?

✅ Automatic scaling (respond to demand)  
✅ Cost efficient (scale down during low traffic)  
✅ Improves availability  
✅ No manual intervention  

---

## 🔍 Monitoring & Observability

### Kubernetes Metrics

```bash
# Check pod resource usage
kubectl top pods -n devops

# Monitor HPA
kubectl describe hpa go-api-hpa -n devops

# View events
kubectl get events -n devops --sort-by='.lastTimestamp'
```

### Jenkins Logs

```bash
# SSH into Jenkins
ssh ubuntu@15.134.1.230

# View build logs
/var/log/jenkins/jenkins.log

# Docker daemon logs
docker logs jenkins
```

### Kubernetes Health Checks

- **Liveness Probe**: Restarts unhealthy pods
- **Readiness Probe**: Removes unhealthy pods from service
- **Service**: Monitors endpoint health
- **ALB**: Health checks pods every 30s

---

## 🛣️ Future Enhancements

1. **Monitoring Stack**
   - Prometheus for metrics collection
   - Grafana for visualization
   - AlertManager for notifications

2. **Logging Stack**
   - ELK Stack or Datadog
   - Centralized log aggregation
   - Log retention policies

3. **Advanced Networking**
   - Ingress controller (nginx/ALB)
   - Network policies
   - Service mesh (Istio/Linkerd)

4. **Security Enhancements**
   - Pod security policies
   - Network policies
   - Secrets management (AWS Secrets Manager)
   - Image scanning

5. **CI/CD Improvements**
   - Automated testing stage
   - Code scanning (Sonarqube)
   - Artifact scanning
   - Canary deployments

6. **Database**
   - RDS for persistent storage
   - ElastiCache for caching
   - Data backup strategies

---

**Last Updated:** February 27, 2026  
**Author:** Sourav (DevOps Fresher)