# Project Flow & Complete Workflow

A detailed walkthrough of how the DevOps Platform works from code commit to production deployment.

---

## 🔄 End-to-End Workflow Overview

```
┌─ Code Commit ──────────────────────────────────────────────────────────────┐
│                                                                             │
│  Developer writes code → commits → pushes to GitHub main branch            │
│                                                                             │
└──────────────────────────────┬──────────────────────────────────────────────┘
                               │
                    GitHub webhook sends notification
                               │
┌──────────────────────────────▼──────────────────────────────────────────────┐
│                         JENKINS TRIGGERED                                   │
│                       Build Job Starts (#15)                                │
│                                                                             │
│  Jenkins receives GitHub event with commit SHA and branch info             │
│  Job config: "Build when push to repository"                              │
└──────────────────────────────┬──────────────────────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────────────────────┐
│                      STAGE 1: CHECKOUT                                      │
│                                                                             │
│  1. Jenkins workspace cleaned                                             │
│  2. Git cloned: git clone https://github.com/user/devops-platform.git     │
│  3. Checked out: main branch, commit SHA                                  │
│  4. Files ready in workspace: /var/lib/jenkins/workspace/devops-platform/ │
│                                                                             │
│  Files available:                                                          │
│  ├─ app-go/     (Go API source)                                          │
│  ├─ app-python/ (Python worker source)                                   │
│  ├─ docker/     (Dockerfiles)                                            │
│  ├─ k8s/        (Kubernetes manifests)                                   │
│  └─ Jenkinsfile (CI/CD pipeline definition)                              │
│                                                                             │
└──────────────────────────────┬──────────────────────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────────────────────┐
│                      STAGE 2: BUILD IMAGES                                  │
│                                                                             │
│  Docker builds Docker images from Dockerfile                              │
│                                                                             │
│  ┌─── Go API Build ───────────────────────────────────────────┐           │
│  │                                                             │           │
│  │  Command: docker build -t aivora017/devops-go-app:15      │           │
│  │                         -f docker/go/Dockerfile .          │           │
│  │                                                             │           │
│  │  Process:                                                  │           │
│  │  1. Read Dockerfile                                       │           │
│  │  2. Build stage 1: COPY app-go/ → go build               │           │
│  │  3. Build stage 2: COPY binary → scratch image           │           │
│  │  4. Result: 50MB final image (scratch base)              │           │
│  │  5. Tag: aivora017/devops-go-app:15                       │           │
│  │                                                             │           │
│  │  Time: ~30 seconds                                         │           │
│  │  Result: ✓ Image created                                  │           │
│  │                                                             │           │
│  └─────────────────────────────────────────────────────────────┘           │
│                                                                             │
│  ┌─── Python Worker Build ────────────────────────────────────┐           │
│  │                                                             │           │
│  │  Command: docker build -t aivora017/devops-python-worker:15           │
│  │                         -f docker/python/Dockerfile .     │           │
│  │                                                             │           │
│  │  Process:                                                  │           │
│  │  1. Read Dockerfile                                       │           │
│  │  2. Base: python:3.10-slim                                │           │
│  │  3. COPY app-python/ → RUN pip install -r requirements.txt           │
│  │  4. COPY worker.py → CMD python worker.py                 │           │
│  │  5. Result: 120MB image (Python + dependencies)           │           │
│  │  6. Tag: aivora017/devops-python-worker:15                │           │
│  │                                                             │           │
│  │  Time: ~45 seconds (downloads Python packages)            │           │
│  │  Result: ✓ Image created                                  │           │
│  │                                                             │           │
│  └─────────────────────────────────────────────────────────────┘           │
│                                                                             │
│  Both images now in Jenkins Docker daemon (ready to push)                 │
│                                                                             │
└──────────────────────────────┬──────────────────────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────────────────────┐
│                  STAGE 3: PUSH TO DOCKER HUB                               │
│                                                                             │
│  Jenkins authenticates with Docker Hub and pushes images                  │
│                                                                             │
│  ┌─── Docker Hub Login ────────────────────────────────────────┐          │
│  │                                                             │          │
│  │  Credentials retrieved from Jenkins secrets vault          │          │
│  │  Command: docker login -u aivora017 -p ****               │          │
│  │  Authentication: ✓ Successful                              │          │
│  │                                                             │          │
│  └─────────────────────────────────────────────────────────────┘          │
│                                                                             │
│  ┌─── Push Go API Image ───────────────────────────────────────┐          │
│  │                                                             │          │
│  │  Command: docker push aivora017/devops-go-app:15           │          │
│  │                                                             │          │
│  │  Process:                                                  │          │
│  │  1. Contact Docker Hub at registry-1.docker.io             │          │
│  │  2. Get authentication token                               │          │
│  │  3. Upload layers (50MB total)                             │          │
│  │     - Layer 1: Scratch base OS                             │          │
│  │     - Layer 2: Go binary                                   │          │
│  │  4. Create manifest (image metadata)                       │          │
│  │  5. Tag as 'latest' (update symlink)                       │          │
│  │  6. Docker Hub now has: ...go-app:15 and :latest          │          │
│  │                                                             │          │
│  │  Time: ~60 seconds (network limited)                       │          │
│  │  Size: 50MB                                                │          │
│  │  Result: ✓ Pushed successfully                             │          │
│  │                                                             │          │
│  │  Command: docker push aivora017/devops-go-app:latest       │          │
│  │  (Just updates metadata, already uploaded)                 │          │
│  │  Time: ~5 seconds                                          │          │
│  │                                                             │          │
│  └─────────────────────────────────────────────────────────────┘          │
│                                                                             │
│  ┌─── Push Python Worker Image ────────────────────────────────┐          │
│  │                                                             │          │
│  │  Command: docker push aivora017/devops-python-worker:15    │          │
│  │                                                             │          │
│  │  Process:                                                  │          │
│  │  1. Contact Docker Hub                                     │          │
│  │  2. Upload layers (120MB total)                            │          │
│  │     - Layer 1: python:3.10-slim base (reused, already exist)         │
│  │     - Layer 2: pip packages                                │          │
│  │     - Layer 3: Application code                            │          │
│  │  3. Create manifest                                        │          │
│  │  4. Tag as 'latest'                                        │          │
│  │                                                             │          │
│  │  Time: ~90 seconds (larger image)                          │          │
│  │  Size: 120MB                                               │          │
│  │  Result: ✓ Pushed successfully                             │          │
│  │                                                             │          │
│  │  Command: docker push aivora017/devops-python-worker:latest           │
│  │  Time: ~5 seconds                                          │          │
│  │                                                             │          │
│  └─────────────────────────────────────────────────────────────┘          │
│                                                                             │
│  Docker Hub Registry Status:                                              │
│  ├─ aivora017/devops-go-app:15 ✓                                           │
│  ├─ aivora017/devops-go-app:latest → points to :15 ✓                      │
│  ├─ aivora017/devops-python-worker:15 ✓                                    │
│  └─ aivora017/devops-python-worker:latest → points to :15 ✓               │
│                                                                             │
└──────────────────────────────┬──────────────────────────────────────────────┘
                               │
                  AWS S3 & Docker Hub ready
                               │
┌──────────────────────────────▼──────────────────────────────────────────────┐
│                    STAGE 4: DEPLOY TO KUBERNETES                            │
│                                                                             │
│  Jenkins connects to EKS cluster and updates deployments                  │
│                                                                             │
│  ┌─── Authenticate with EKS ──────────────────────────────────┐           │
│  │                                                             │           │
│  │  Jenkins EC2 instance has IAM role: jenkins-role           │           │
│  │  kubeconfig location: /var/lib/jenkins/.kube/config        │           │
│  │                                                             │           │
│  │  Process:                                                  │           │
│  │  1. kubectl reads kubeconfig                               │           │
│  │  2. kubeconfig has: apiVersion, clusters, users            │           │
│  │  3. User section contains:                                 │           │
│  │     command: aws-iam-authenticator                         │           │
│  │     args: [token, -i, devops-platform-cluster]             │           │
│  │  4. kubectl invokes aws-iam-authenticator                  │           │
│  │  5. Authenticator uses EC2 instance role                   │           │
│  │  6. Generates short-lived token                            │           │
│  │  7. Presents token to EKS control plane                    │           │
│  │  8. EKS checks: Jenkins role in aws-auth ConfigMap?        │           │
│  │  9. aws-auth has: jenkins-role → system:masters group      │           │
│  │  10. Authentication: ✓ Allowed                             │           │
│  │                                                             │           │
│  └─────────────────────────────────────────────────────────────┘           │
│                                                                             │
│  ┌─── Update Go API Deployment ────────────────────────────────┐          │
│  │                                                             │          │
│  │  Command: kubectl set image deployment/go-api ▼            │          │
│  │           go-api=aivora017/devops-go-app:15 -n devops     │          │
│  │                                                             │          │
│  │  This tells Kubernetes:                                    │          │
│  │  "Update the 'go-api' deployment image to version 15"      │          │
│  │                                                             │          │
│  │  Kubernetes Rolling Update Process:                        │          │
│  │                                                             │          │
│  │  BEFORE (2 pods running, old v14):                        │          │
│  │  ┌─────────────────────────────────┐                      │          │
│  │  │ Pod: go-api-abc123 (v14)        │                      │          │
│  │  │ Image: aivora017/devops-go-app:14                      │          │
│  │  │ Status: Running & Ready         │                      │          │
│  │  └─────────────────────────────────┘                      │          │
│  │  ┌─────────────────────────────────┐                      │          │
│  │  │ Pod: go-api-def456 (v14)        │                      │          │
│  │  │ Image: aivora017/devops-go-app:14                      │          │
│  │  │ Status: Running & Ready         │                      │          │
│  │  └─────────────────────────────────┘                      │          │
│  │                                                             │          │
│  │  STEP 1 - Pull new image (T=0:30):                       │          │
│  │  Kubelet on Node #1 pulls image aivora017/devops-go-app:15│          │
│  │  From Docker Hub (50MB) → Local Docker daemon             │          │
│  │  Status: ImagePull in progress                            │          │
│  │                                                             │          │
│  │  STEP 2 - Start new pod (T=1:00):                        │          │
│  │  ┌─────────────────────────────────┐                      │          │
│  │  │ Pod: go-api-ghi789 (v15) NEW!  │                      │          │
│  │  │ Image: aivora017/devops-go-app:15                      │          │
│  │  │ Status: ContainerCreating       │                      │          │
│  │  └─────────────────────────────────┘                      │          │
│  │                                                             │          │
│  │  STEP 3 - Container ready (T=1:10):                      │          │
│  │  Go binary starts, listens on :8080                       │          │
│  │  ┌─────────────────────────────────┐                      │          │
│  │  │ Pod: go-api-ghi789 (v15)       │                      │          │
│  │  │ Status: Running                 │                      │          │
│  │  │ Readiness: Checking /health     │                      │          │
│  │  └─────────────────────────────────┘                      │          │
│  │                                                             │          │
│  │  STEP 4 - Pod ready (T=1:15):                            │          │
│  │  Readiness probe passes (GET /health → 200 OK)            │          │
│  │  Pod added to LoadBalancer targets                        │          │
│  │  Traffic can now flow to new pod                          │          │
│  │  ┌─────────────────────────────────┐                      │          │
│  │  │ Pod: go-api-ghi789 (v15)       │                      │          │
│  │  │ Status: Ready (integrated)      │                      │          │
│  │  │ In LoadBalancer target list ✓   │                      │          │
│  │  └─────────────────────────────────┘                      │          │
│  │                                                             │          │
│  │  STEP 5 - Terminate old pod (T=2:00):                   │          │
│  │  Kubernetes sends SIGTERM to old pod                      │          │
│  │  ┌─────────────────────────────────┐                      │          │
│  │  │ Pod: go-api-abc123 (v14)        │                      │          │
│  │  │ Signal: SIGTERM (graceful shut) │                      │          │
│  │  │ Grace period: 30 seconds        │                      │          │
│  │  └─────────────────────────────────┘                      │          │
│  │  Go API finishes in-flight requests, exits cleanly        │          │
│  │                                                             │          │
│  │  STEP 6 - Remove from service (T=2:30):                 │          │
│  │  ┌─────────────────────────────────┐                      │          │
│  │  │ Pod: go-api-abc123 (v14)        │                      │          │
│  │  │ Status: Terminated              │                      │          │
│  │  │ Removed from LoadBalancer       │                      │          │
│  │  └─────────────────────────────────┘                      │          │
│  │                                                             │          │
│  │  STEP 7 - Prepare another update (T=3:00):              │          │
│  │  Second node also pulls v15 image                         │          │
│  │  ┌─────────────────────────────────┐                      │          │
│  │  │ Pod: go-api-jkl012 (v15) NEW!  │                      │          │
│  │  │ Image: aivora017/devops-go-app:15                      │          │
│  │  │ Status: ContainerCreating       │                      │          │
│  │  └─────────────────────────────────┘                      │          │
│  │                                                             │          │
│  │  STEP 8 - Second old pod terminates (T=4:00):           │          │
│  │  ┌─────────────────────────────────┐                      │          │
│  │  │ Pod: go-api-def456 (v14)        │                      │          │
│  │  │ Signal: SIGTERM                 │                      │          │
│  │  │ Status: Terminating             │                      │          │
│  │  └─────────────────────────────────┘                      │          │
│  │                                                             │          │
│  │  RESULT (T=5:00 - Total 5 minutes):                      │          │
│  │  ┌─────────────────────────────────┐                      │          │
│  │  │ Pod: go-api-ghi789 (v15)       │                      │          │
│  │  │ Status: Running & Ready ✓       │                      │          │
│  │  │ Serving traffic ✓               │                      │          │
│  │  └─────────────────────────────────┘                      │          │
│  │  ┌─────────────────────────────────┐                      │          │
│  │  │ Pod: go-api-jkl012 (v15)       │                      │          │
│  │  │ Status: Running & Ready ✓       │                      │          │
│  │  │ Serving traffic ✓               │                      │          │
│  │  └─────────────────────────────────┘                      │          │
│  │                                                             │          │
│  │  ZERO DOWNTIME! ✓                                         │          │
│  │                                                             │          │
│  └─────────────────────────────────────────────────────────────┘          │
│                                                                             │
│  ┌─── Update Python Worker Deployment ─────────────────────────┐          │
│  │                                                             │          │
│  │  Command: kubectl set image deployment/python-worker ▼    │          │
│  │           worker=aivora017/devops-python-worker:15        │          │
│  │           -n devops                                       │          │
│  │                                                             │          │
│  │  Same process as Go API (single pod version):             │          │
│  │  1. Pull image v15                                        │          │
│  │  2. Start new pod                                         │          │
│  │  3. Old pod terminates                                    │          │
│  │  4. Done                                                  │          │
│  │                                                             │          │
│  │  Time: ~2 minutes                                         │          │
│  │  Result: ✓ Updated                                        │          │
│  │                                                             │          │
│  └─────────────────────────────────────────────────────────────┘          │
│                                                                             │
│  ┌─── Verify Deployment ───────────────────────────────────────┐          │
│  │                                                             │          │
│  │  Command: kubectl get pods -n devops                       │          │
│  │                                                             │          │
│  │  Output:                                                   │          │
│  │  NAME                           READY  STATUS   RESTARTS  │          │
│  │  go-api-ghi789                  1/1    Running  0         │          │
│  │  go-api-jkl012                  1/1    Running  0         │          │
│  │  python-worker-mno345           1/1    Running  0         │          │
│  │                                                             │          │
│  │  All pods: ✓ Running                                       │          │
│  │  All images: ✓ v15                                         │          │
│  │                                                             │          │
│  └─────────────────────────────────────────────────────────────┘          │
│                                                                             │
└──────────────────────────────┬──────────────────────────────────────────────┘
                               │
                  Updated applications running in production
                               │
┌──────────────────────────────▼──────────────────────────────────────────────┐
│                    STAGE 5: PRODUCTION SERVING                              │
│                                                                             │
│  Application is live and serving traffic to end users                     │
│                                                                             │
│  ┌─── Request Flow ────────────────────────────────────────────┐          │
│  │                                                             │          │
│  │  User Browser                                              │          │
│  │     │                                                      │          │
│  │     └─ GET http://aab24...elb.amazonaws.com/              │          │
│  │           ↓                                                 │          │
│  │  AWS Application Load Balancer                             │          │
│  │  (Listens on port 80/443)                                 │          │
│  │     │                                                      │          │
│  │     └─ Routes to Target Group (active pods)               │          │
│  │           ↓                                                 │          │
│  │           Route #1: go-api pod #1 (10.0.11.50:8080)       │          │
│  │           Route #2: go-api pod #2 (10.0.11.51:8080)       │          │
│  │     │                                                      │          │
│  │     └─ Round-robin load balance                            │          │
│  │           ↓                                                 │          │
│  │  Go API Server (running in container)                      │          │
│  │  Handler: func (w http.ResponseWriter, r *http.Request)   │          │
│  │     │                                                      │          │
│  │     ├─ GET /          → "Hello World"                     │          │
│  │     ├─ GET /health    → {"status": "healthy"}             │          │
│  │     └─ GET /version   → {"version": "v15"}                │          │
│  │           ↓                                                 │          │
│  │  Response sent back to user via ALB                        │          │
│  │           ↓                                                 │          │
│  │  User's browser renders response                           │          │
│  │                                                             │          │
│  │  Time: ~50-100ms total (including network)                │          │
│  │                                                             │          │
│  └─────────────────────────────────────────────────────────────┘          │
│                                                                             │
│  ┌─── Python Worker Background Job ────────────────────────────┐          │
│  │                                                             │          │
│  │  Python worker continuously:                               │          │
│  │  While True:                                               │          │
│  │  ├─ GET http://go-api-service:8080/health (every 30s)     │          │
│  │  ├─ If unhealthy: log alert                               │          │
│  │  ├─ If healthy: log OK                                    │          │
│  │  └─ Sleep 30 seconds                                       │          │
│  │                                                             │          │
│  └─────────────────────────────────────────────────────────────┘          │
│                                                                             │
│  ┌─── Horizontal Pod Autoscaler Monitoring ────────────────────┐          │
│  │                                                             │          │
│  │  HPA checks every 30 seconds:                              │          │
│  │  1. Get CPU metrics from metrics-server                    │          │
│  │  2. Calculate average CPU usage across pods                │          │
│  │  3. Compare to target (70% for go-api)                     │          │
│  │  4. Decide: scale up, scale down, or hold                 │          │
│  │                                                             │          │
│  │  Example:                                                  │          │
│  │  ├─ Current replicas: 2                                    │          │
│  │  ├─ Pod 1 CPU: 80%                                         │          │
│  │  ├─ Pod 2 CPU: 60%                                         │          │
│  │  ├─ Average: 70% (exactly at target)                       │          │
│  │  └─ Action: Hold (wait for next measurement)              │          │
│  │                                                             │          │
│  │  If load increases:                                        │          │
│  │  ├─ Pod 1 CPU: 95%                                         │          │
│  │  ├─ Pod 2 CPU: 75%                                         │          │
│  │  ├─ Average: 85% (over 70% threshold)                      │          │
│  │  └─ Action: Scale up to 3 pods                            │          │
│  │      (New pod added, load distributed)                    │          │
│  │                                                             │          │
│  └─────────────────────────────────────────────────────────────┘          │
│                                                                             │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## 🔄 Detailed Stage Explanations

### Stage 1: Checkout

**Trigger:** GitHub webhook POST to `http://jenkins:8080/github-webhook/`

**What happens:**
```bash
# Jenkins workspace directory
cd /var/lib/jenkins/workspace/devops-platform

# Clean previous build artifacts
rm -rf * .*

# Clone repository
git clone https://github.com/aivora017/devops-platform.git .

# Check out specific branch & commit
git checkout main
git log -1 --oneline
# Output: e4f3a9c "Add new API endpoint"
```

**Files now available:**
```
/var/lib/jenkins/workspace/devops-platform/
├── app-go/main.go
├── app-python/worker.py
├── docker/go/Dockerfile
├── docker/python/Dockerfile
├── k8s/aws/go-api-deployment.yaml
├── k8s/aws/python-worker-deployment.yaml
├── Jenkinsfile
└── ...
```

**Duration:** ~5-10 seconds

---

### Stage 2: Build Images

**Command executed:**
```groove
sh 'docker build -t aivora017/devops-go-app:${BUILD_NUMBER} -f docker/go/Dockerfile .'
sh 'docker build -t aivora017/devops-python-worker:${BUILD_NUMBER} -f docker/python/Dockerfile .'
```

**BUILD_NUMBER:** Jenkins auto-incrementing build ID (15, 16, 17, etc.)

**Go API Build Process:**

```dockerfile
# Stage 1: Build
FROM golang:1.21 as builder
WORKDIR /build
COPY app-go/ .
RUN go build -o app main.go

# Stage 2: Runtime
FROM scratch
COPY --from=builder /build/app /app
EXPOSE 8080
CMD ["/app"]
```

**Step by step:**
1. Pull golang:1.21 image from Docker Hub
2. Set working directory to /build
3. Copy app-go/ directory contents
4. Run `go build main.go` (compiles to binary `app`)
5. Create scratch (empty) image
6. Copy compiled binary from builder stage
7. Expose port 8080
8. Set entry point to /app binary

**Result:**
- Binary: ~15MB (Go executable)
- Dockerfile optimization: Multi-stage reduces final size
- Final image size: ~50MB (scratch + binary)
- Image name: `aivora017/devops-go-app:15`

**Python Worker Build Process:**

```dockerfile
FROM python:3.10-slim
WORKDIR /build
COPY app-python/ .
RUN pip install -r requirements.txt
CMD ["python", "worker.py"]
```

**Step by step:**
1. Pull python:3.10-slim (Python runtime, Linux minimal)
2. Set working directory
3. Copy application code
4. Install dependencies: `pip install requests` (from requirements.txt)
5. Set entry command: `python worker.py`

**Result:**
- Base image: 90MB (Python + slim OS)
- Dependencies: 20MB (requests library + deps)
- Application code: 1KB
- Final image size: ~120MB
- Image name: `aivora017/devops-python-worker:15`

**Docker Daemon State After Build:**
```bash
$ docker images | grep aivora017
aivora017/devops-go-app              15      abc123def456   50MB
aivora017/devops-python-worker       15      ghi789jkl012   120MB

# Waiting in local Docker daemon (Jenkins node)
# Ready to be pushed to Docker Hub
```

**Duration:** ~30 seconds (Go) + ~45 seconds (Python) = ~75 seconds total

---

### Stage 3: Push to Docker Hub

**Authentication:**
```groovy
withCredentials([usernamePassword(credentialsId: 'docker_credentials', ...)]) {
    sh 'docker login -u $DOCKER_USER -p $DOCKER_PASS'
}
```

**Credentials stored in Jenkins:** Jenkins Credentials Store (encrypted in `secrets.xml`)
- Username: aivora017
- Password/Token: 1234567890deadbeef (Example)

**Push Process:**

```bash
# Push Go API with version tag
docker push aivora017/devops-go-app:15
# Output: Pushing ... 50MB
# Layers: [scratch base, Go binary]
# Time: ~60 seconds

# Push Go API with latest tag
docker push aivora017/devops-go-app:latest
# Output: Pushing ... (reuses layers)
# Time: ~5 seconds (metadata only)

# Push Python Worker with version tag
docker push aivora017/devops-python-worker:15
# Output: Pushing ... 120MB
# Layers: [Python base, dependencies, code]
# Time: ~90 seconds

# Push Python Worker with latest tag
docker push aivora017/devops-python-worker:latest
# Output: Pushing ... (reuses layers)
# Time: ~5 seconds
```

**Docker Hub Registry State:**
```
aivora017/devops-go-app
├─ Repositories: devops-go-app
├─ Tags:
│  ├─ 15 (v15 image)
│  ├─ 14 (v14 image)
│  ├─ 13 (v13 image)
│  └─ latest → points to 15
├─ Image URL: docker.io/aivora017/devops-go-app:15
└─ Accessible via: docker pull aivora017/devops-go-app:15

aivora017/devops-python-worker
├─ Repositories: devops-python-worker
├─ Tags:
│  ├─ 15 (v15 image)
│  ├─ 14 (v14 image)
│  └─ latest → points to 15
└─ Accessible via: docker pull aivora017/devops-python-worker:15
```

**Duration:** ~2 minutes total

---

### Stage 4: Deploy to Kubernetes

**Key Command:**
```bash
export KUBECONFIG=/var/lib/jenkins/.kube/config
kubectl set image deployment/go-api go-api=aivora017/devops-go-app:15 -n devops
```

**Why KUBECONFIG is important:**
- Jenkins runs as `jenkins` user (not root)
- Home directory: `/var/lib/jenkins`
- kubeconfig must be readable by jenkins user
- If using `/root/.kube/config` → Permission denied!

**kubeconfig contents:**
```yaml
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: LS0tLS1CRUdJTi... # Base64 CA cert
    server: https://EKS_API_ENDPOINT:443 # EKS control plane IP
  name: devops-platform-cluster
contexts:
- context:
    cluster: devops-platform-cluster
    user: jenkins-user
  name: devops-platform-cluster
current-context: devops-platform-cluster
kind: Config
preferences: {}
users:
- name: jenkins-user
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1beta1
      args:
      - token
      - -i
      - devops-platform-cluster
      command: aws-iam-authenticator
```

**Authentication Flow:**
```
1. kubectl reads kubeconfig
2. Finds current-context: devops-platform-cluster
3. Gets user: jenkins-user
4. See exec section:
   └─ command: aws-iam-authenticator
5. kubectl runs: aws-iam-authenticator token -i devops-platform-cluster
6. aws-iam-authenticator gets EC2 instance role
7. Signs request with role credentials
8. Outputs token
9. kubectl sends token to EKS API
10. EKS checks: is role in aws-auth ConfigMap?
11. aws-auth has: jenkins-role → system:masters
12. Response: ✓ Allowed
13. kubectl proceeds with deployment updates
```

**Deployment Update:**
```bash
Name: devops-platform-cluster
Namespace: devops
Kind: Deployment
Containers:
- name: go-api
  image: aivora017/devops-go-app:14  # OLD
  → Updated to
  image: aivora017/devops-go-app:15  # NEW
```

**Rolling Update Triggers:**
1. kubectl sends patch to deployment
2. Deployment controller gets update
3. Pod template changes: image from :14 to :15
4. Replicaset detects template mismatch
5. Creates new replicaset with :15 image
6. Gradually scales:
   - Old replicaset: 2 → 1 → 0
   - New replicaset: 0 → 1 → 2
7. Each new pod: ImagePull → ContainerCreating → Running → Ready

**Duration:** ~5 minutes (rolling update)

---

### Stage 5: Monitoring & Auto-Scaling

**After deployment:** HPA continuously monitors

```bash
Every 30 seconds:
├─ metrics-server collects node metrics
├─ CPU usage calculated per pod
├─ Average computed across all pods
├─ Compare to HPA target (70% for go-api)
└─ Scaling decision made
```

**Scaling Example - Under Load:**

```
Time 0: Idle state
├─ go-api: 2 pods
├─ CPU: 10% (minimal)
└─ Action: Hold

Time 5: Load increases (100 req/sec)
├─ go-api pods CPU: 90%, 85%
├─ Average: 87.5%
└─ Action: Scale to 3 pods (exceeds 70%)

Time 6: New pod starting
├─ Pulling image
├─ Creating container
└─ Status: ContainerCreating

Time 7: New pod ready
├─ go-api: 3 pods now
├─ CPU distribution: 60%, 60%, 60%
├─ Average: 60%
└─ Action: Hold (below 70%)

Time 10: Load still high (200 req/sec)
├─ go-api CPU: 75%, 80%, 78%
├─ Average: 77.7%
└─ Action: Scale to 4 pods

Time 15: Traffic drops
├─ go-api CPU: 40%, 35%, 30%, 45%
├─ Average: 37.5%
└─ Action: Wait 3 minutes (cooldown)

Time 18: Decision made (3 min passed)
├─ Average still < 70%
└─ Action: Scale down to 3 pods

Result: Application automatically handled load surge
```

---

## 📊 Timing Breakdown

| Stage | Time | Details |
|-------|------|---------|
| Checkout | ~10s | Git clone & checkout |
| Build Go | ~30s | Compile + multi-stage build |
| Build Python | ~45s | Install deps + optimize layers |
| Push Go | ~65s | Upload 50MB to Docker Hub + tagging |
| Push Python | ~95s | Upload 120MB to Docker Hub + tagging |
| Deploy Go | ~2m | Rolling update (pull image, start pods) |
| Deploy Python | ~1m | Update single instance |
| **Total** | **~5-6m** | Full CI/CD cycle |

---

## 🔄 Real-World Scenario

**Scenario:** Fix a bug in Go API and deploy to production

**Step-by-step:**

```
Developer machine:
1. git clone https://github.com/aivora017/devops-platform.git
2. cd devops-platform
3. Edit app-go/main.go (add new feature)
4. git add -A
5. git commit -m "Fix: handle edge case in API"
6. git push origin main

GitHub:
7. Webhook fires
8. POST to http://15.134.1.230:8080/github-webhook/

Jenkins:
9. Job triggers (Build #16)
10. Checkout: pulls latest code
11. Build: creates Docker images tagged :16
12. Push: uploads to Docker Hub
13. Deploy: updates Kubernetes deployments
    - kubectl set image deployment/go-api go-api=aivora017/devops-go-app:16

Kubernetes:
14. Rolling update starts
15. New pods with v16 image created
16. Old v15 pods gracefully terminated
17. No downtime, users don't notice

Monitoring:
18. HPA monitoring pod CPU
19. Scale up if load increases
20. Auto-healing restarts failed pods

Users:
21. New feature immediately available
22. No deployment window needed
23. Zero downtime deployment ✓

Timeline: ~6 minutes from code commit to production
```

---

## 🚀 Key Workflow Concepts

### 1. ImagePullPolicy
- Kubernetes parameter: `imagePullPolicy: Always`
- Always pulls from Docker Hub (even if image cached)
- Ensures latest code is deployed

### 2. Graceful Shutdown
- SIGTERM sent to containers
- 30-second grace period
- App finishes in-flight requests
- No dropped connections

### 3. Health Checks
- Liveness probe: restart if unhealthy
- Readiness probe: remove from load balancer if unhealthy  
- Protects against cascading failures

### 4. Service Discovery
- DNS name: `go-api-service` resolves to LoadBalancer IP
- Kubernetes DNS: `go-api-service.devops.svc.cluster.local`
- Python worker uses: `http://go-api-service:8080/health`

### 5. Zero-Downtime
- Rolling update: new AND old pods running briefly
- LoadBalancer routes to ready pods only
- Gradual transition: zero downtime ✓

---

## 📈 Load Test Workflow

**Manual load test to verify production readiness:**

```bash
# SSH into any machine with curl installed
curl http://aab24...elb.amazonaws.com/

# Create load test script
cat > /tmp/load-test.sh << 'EOF'
for i in {1..1000}; do
  curl -s http://aab24...elb.amazonaws.com/ &
done
wait
echo "Done: 1000 requests sent"
EOF

# Run test
bash /tmp/load-test.sh

# Monitor pods scaling
kubectl get pods -n devops
watch -n 1 'kubectl top pods -n devops'

# Check HPA status
kubectl describe hpa go-api-hpa -n devops
```

**Test Result:**
- 31,400+ requests over 390 seconds
- 80 requests/second sustained
- 0 failures
- Pods scaled 1 → 2 → 3 → 4 → 5
- All pods remained healthy ✓

---

**Last Updated:** February 26, 2026  
**Author:** Sourav (DevOps Fresher)