# Troubleshooting Guide - Issues & Solutions

Complete documentation of problems encountered during development and their solutions. This guide has been built from real deployment experience.

---

## 🎯 Quick Issue Finder

| Issue | Symptom | Section |
|-------|---------|---------|
| IAM Permission Denied | `AccessDenied: User is not authorized` | [IAM Permissions](#iam-permissions-errors) |
| EKS K8s Version Mismatch | `error validating data: unknown field "maxSurge"` | [Kubernetes Version](#kubernetes-version-incompatibility) |
| Jenkins kubeconfig Permission | `permission denied` on `/root/.kube/config` | [kubeconfig Path Issues](#kubeconfig-path-issues) |
| kubectl Access Denied | `error: User: arn:aws:iam::...` | [RBAC Configuration](#eks-rbac-configuration) |
| Pods Stuck Pending | Pods never transition to Running | [Resource Constraints](#insufficient-node-resources) |
| Docker Pull from Docker Hub | `ImagePullBackOff` in Kubernetes | [Docker Registry Auth](#docker-registry-authentication) |
| Jenkins Docker Build Fails | `cannot find app-go directory` | [Build Context Issues](#build-context-errors) |
| ALB Health Checks Failing | `Target marked unhealthy` | [LoadBalancer Issues](#loadbalancer-health-check-failures) |
| HPA Not Scaling | Pods not scaling despite high CPU | [HPA Issues](#hpa-not-scaling) |
| GitHub Webhook Not Triggering | Jenkins never builds on push | [Jenkins Integration](#github-webhook-issues) |

---

## 🔴 Critical Issues Encountered

### Issue #1: IAM Permissions Errors

**Error Message:**
```
AccessDenied: User: arn:aws:iam::579813049088:user/terraform-user is not 
authorized to perform: eks:CreateCluster on resource: 
arn:aws:eks:ap-southeast-2:579813049088:cluster/*
```

**What was happening:**
- Terraform tried to create EKS cluster
- IAM user `terraform-user` lacked permissions
- Terraform apply failed at first resource

**Root Cause:**
- New AWS account → minimal IAM permissions by default
- `terraform-user` had only basic policies
- EKS, EC2, IAM operations require specific policies

**Solution:**
Added 8 IAM policies to `terraform-user`:

```bash
1. AmazonEC2FullAccess
2. AmazonECS_TaskExecutionRolePolicy
3. AmazonEKS_CNI_Policy
4. AmazonEKSFullAccess
5. AmazonECRFullAccess
6. IAMFullAccess
7. CloudFormationFullAccess
8. VPCFullAccess
```

**Steps taken:**
1. AWS Console → IAM → Users
2. Select `terraform-user`
3. Add permissions → Attach policies
4. Attach each policy above
5. Wait 1-2 minutes for propagation
6. Retry `terraform apply`

**Result:** ✅ All resources created successfully

**Lessons learned:**
- AWS follows principle of least privilege by default
- Different services require different policies
- Policy names don't always match service names
- Wait time needed after policy attach

---

### Issue #2: Kubernetes Version Incompatibility

**Error Message:**
```
error validating data: unknown field "maxSurge" in 
io.k8s.api.apps.v1.RollingUpdateDeploymentStrategy
```

**What was happening:**
- Terraform created EKS cluster with default K8s version
- Kubernetes manifest had rolling update strategy
- API Server couldn't parse the field

**Root Cause:**
- Terraform defaulted to older K8s version (1.28.x)
- Manifest used newer API format (for 1.30+)
- Version mismatch → unknown field error

**Evidence:**
```bash
$ kubectl version
Server Version: version.Info{GitVersion:"v1.28.0", ...}

$ cat k8s/aws/go-api-deployment.yaml | grep -A5 "strategy:"
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1  # ← Unknown in v1.28
    maxUnavailable: 0
```

**Solution:**
Updated Terraform variable to specify K8s version explicitly:

```hcl
# File: terraform/aws/variable.tf
variable "kubernetes_version" {
  default = "1.30"  # Explicitly set to 1.30.14
}

# File: terraform/aws/modules/cluster/main.tf
resource "aws_eks_cluster" "main" {
  name               = var.cluster_name
  role_arn          = aws_iam_role.eks_role.arn
  version            = var.kubernetes_version  # ← Now uses 1.30
  
  vpc_config {
    subnet_ids = var.subnet_ids
  }
}
```

**Steps taken:**
1. Checked current cluster version: `kubectl version --short`
2. Identified version mismatch  
3. Updated terraform/aws/variable.tf
4. `terraform destroy` → `terraform apply` (recreate cluster)
5. Verified new version: `kubectl version`

**Wait time:** ~15 minutes for EKS cluster recreation

**Result:** ✅ Manifests now compatible with K8s v1.30

**Lessons learned:**
- Always verify K8s version matches manifest API
- Version compatibility increases with newer releases
- maxSurge/maxUnavailable added in K8s 1.25+
- AWS EKS supports multiple versions (update schedule)

---

### Issue #3: Terraform Applier IAM Conflicts

**Error Message:**
```
Error: Error creating IAM policy version: MalformedPolicyDocument: 
The policy contains invalid JSON
```

Followed by:
```
AccessDenied: User is not authorized to perform: iam:CreatePolicyVersion
```

**What was happening:**
- Terraform tried to create IAM policy
- Policy JSON syntax was invalid
- IAM also denied the operation

**Root Cause:**
- Terraform code had syntax error in policy JSON
- Used wrong quote characters or unescaped strings
- IAM required both syntactically valid JSON AND permission

**Solution:**
Fixed multiple issues in Terraform code:

```hcl
# BEFORE (Wrong)
policy = jsonencode({
  Version = "2012-10-17"
  Statement = [
    {
      Effect   = "Allow"
      Action   = "eks:*" # ← Missing array syntax
      Resource = "*"
    }
  ]
})

# AFTER (Correct)
policy = jsonencode({
  Version = "2012-10-17"
  Statement = [
    {
      Effect   = "Allow"
      Action   = ["eks:*"]  # ← Array syntax
      Resource = "*"
    }
  ]
})
```

**Steps taken:**
1. Reviewed error message and line number
2. Found invalid JSON in policy
3. Fixed quote characters and array syntax
4. Validated JSON: `terraform plan`
5. Checked Policy Simulator in AWS Console
6. Re-ran `terraform apply`

**Result:** ✅ Policy created successfully

**Lessons learned:**
- Terraform `jsonencode()` helps with syntax
- AWS IAM policies are complex JSON
- Test with `terraform plan` before apply
- Use AWS Policy Simulator for validation

---

### Issue #4: Jenkins kubeconfig Path Error

**Error Message:**
```
error: error loading config file "/root/.kube/config": 
permission denied
```

**What was happening:**
- Jenkins tried to run `kubectl` commands
- Looked for kubeconfig at `/root/.kube/config`
- Permission denied (Jenkins runs as `jenkins` user, not root)

**Root Cause:**
- kubeconfig created by root user
- Jenkins container user: `jenkins` (UID 1000)
- Jenkins user cannot read root's home files
- Jenkinsfile hardcoded `/root/.kube/config`

**Why this happened:**
```bash
# When creating kubeconfig:
$ aws eks update-kubeconfig ... 
# This ran as root user
# Created: /root/.kube/config
# Owner: root:root
# Permissions: 644 (not readable by jenkins)

# When Jenkins runs kubectl:
$ docker exec jenkins kubectl get pods
# Runs as jenkins container user
# Tries to read /root/.kube/config
# ✗ Permission denied
```

**Solution:**
Changed kubeconfig path in Jenkinsfile:

```groovy
# BEFORE
stage('Deploy to EKS') {
    environment {
        KUBECONFIG = '/root/.kube/config'  # ✗ Wrong
    }
}

# AFTER
stage('Deploy to EKS') {
    environment {
        KUBECONFIG = '/var/lib/jenkins/.kube/config'  # ✓ Correct
    }
    steps {
        sh '''
            aws eks update-kubeconfig \
              --name devops-platform-cluster \
              --region ap-southeast-2
            # Now creates kubeconfig in Jenkins home directory
            
            kubectl get pods -n devops
        '''
    }
}
```

**Steps taken:**
1. Identified error: `permission denied` on `/root/.kube/config`
2. Checked kubeconfig ownership: `ls -la /root/.kube/config`
3. Found: owned by root, not readable by jenkins user
4. Changed path to Jenkins home: `/var/lib/jenkins/.kube/config`
5. Regenerated kubeconfig: `aws eks update-kubeconfig`
6. Verified permissions: `ls -la /var/lib/jenkins/.kube/config`
7. Reran Jenkins build

**Verification:**
```bash
# Check Jenkins home
$ echo $HOME
/var/lib/jenkins

# Verify kubeconfig location and permissions
$ ls -la /var/lib/jenkins/.kube/
drwxr-xr-x jenkins jenkins config

# Test kubectl access
$ docker exec jenkins kubectl get pods -n devops
NAME                          READY  STATUS
go-api-abc123                 1/1    Running
python-worker-def456          1/1    Running
```

**Result:** ✅ Jenkins can now access Kubernetes cluster

**Lessons learned:**
- Container users don't always run as root
- Home directories are user-specific (`/root` vs `/var/lib/jenkins`)
- kubeconfig paths matter (user-home based)
- Always check file ownership and permissions
- Jenkins best practice: use jenkins user home for config

---

### Issue #5: kubectl RBAC "User not in ConfigMap"

**Error Message:**
```
error: unable to upgrade connection: pod does not allow privilege escalation
error: User: arn:aws:iam::579813049088:role/jenkins-role 
is not authorized to perform: eks:* on resource: arn:aws:eks:...

UnrecognizedClientException: The security token included in the 
request is invalid
```

**What was happening:**
- Jenkins had kubeconfig set up correctly
- But kubectl commands were being denied
- EKS didn't recognize the IAM role

**Root Cause:**
- Jenkins EC2 instance had IAM role: `jenkins-role`
- kubeconfig used `aws-iam-authenticator` for authentication
- EKS ConfigMap `aws-auth` had NO entry for `jenkins-role`
- EKS rejected the request because role wasn't authorized

**How EKS Authentication Works:**
```
kubectl command
    ↓
Read kubeconfig
    ↓
Find user section (aws-iam-authenticator)
    ↓
Run: aws-iam-authenticator token ...
    ↓
Gets EC2 instance IAM role: arn:aws:iam::579813049088:role/jenkins-role
    ↓
EKS API receives token
    ↓
EKS checks: Is jenkins-role in aws-auth ConfigMap?
    ↓
No entry found → ✗ DENY
```

**Solution:**
Added Jenkins role to EKS ConfigMap:

```bash
# Get the Jenkins IAM role ARN
terraform output jenkins_role_arn
# Output: arn:aws:iam::579813049088:role/jenkins-role

# Edit aws-auth ConfigMap
kubectl edit configmap aws-auth -n kube-system

# Add Jenkins role mapping:
```

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - rolearn: arn:aws:iam::579813049088:role/eks-nodegroup-role
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
    - rolearn: arn:aws:iam::579813049088:role/jenkins-role  # ← Added
      username: jenkins-user
      groups:
        - system:masters  # ← Full cluster access
```

**Verification:**
```bash
# Check ConfigMap was updated
kubectl get configmap aws-auth -n kube-system -o yaml | grep jenkins

# Test Jenkins role access
$ docker exec jenkins kubectl get pods --all-namespaces
# Should now work ✓

# View in Jenkins build log
kubectl get pods -n devops  ✓ Success
```

**How Authorization Now Works:**
```
Jenkins kubectl command
    ↓
aws-iam-authenticator token (using EC2 role)
    ↓
EKS receives token signed by jenkins-role
    ↓
EKS checks aws-auth ConfigMap
    ↓
Finds: jenkins-role → system:masters ✓
    ↓
Request allowed with full cluster access
```

**Result:** ✅ Jenkins can now access EKS cluster

**Lessons learned:**
- EKS uses aws-auth ConfigMap for RBAC
- IAM role ARN must be in ConfigMap exactly
- system:masters group = full cluster admin access
- Need both kubeconfig (authentication) AND aws-auth (authorization)
- Use kubectl edit to modify critical ConfigMaps

---

### Issue #6: insufficient Node Resources (Pods Pending)

**Error Message:**
```
$ kubectl get pods -n devops

NAME                          READY  STATUS      RESTARTS
go-api-abc123                 0/1    Pending     0
go-api-def456                 0/1    Pending     0
python-worker-ghi789          0/1    Pending     0
```

Pods never transition to Running state.

**What was happening:**
- Pods were created and scheduled
- But nodes had insufficient resources (CPU/memory)
- Kubernetes couldn't place pods on available nodes

**Root Cause Investigation:**
```bash
# Check node resources
$ kubectl describe nodes
Name: ip-10-0-11-50.ap-southeast-2.compute.internal
  Allocatable:
    cpu:     1000m        # ← Only 1 CPU available
    memory:  512Mi        # ← Only 512MB available!
  
# Check pod requests
$ kubectl describe pod go-api-abc123 -n devops
  Requests:
    cpu:      100m
    memory:   256Mi
  Limits:
    cpu:      500m
    memory:   512Mi        # ← Needs 512MB!
```

**The Problem:**
- Node: t3.micro (1 vCPU, 1GB RAM, EC2 overhead)
- Available: ~1000m CPU, 512MB RAM (after OS)
- Pod 1 requests: 256Mi → Fits
- Pod 2 requests: 256Mi → No room left (512Mi total used)
- Pod 3 onwards: Can't fit
- Result: Pods stuck Pending

**Scaling Scenario that Exposed Issue:**
```
Nodes: 2x t3.micro
Available per node: ~500MB RAM

Pod 1: 256Mi scheduled to Node 1
Node 1 remaining: 244Mi

Pod 2: 256Mi scheduled to Node 1... wait, only 244Mi left!
Status: Pending (can't schedule)

Pod 3: Also Pending
Pod 4: Also Pending

All future pods: Pending
  ↓
Application can't scale
  ↓
HPA can't add replicas because no resources!
```

**Solution:**
Upgraded instance type from t3.micro to t3.small:

```hcl
# File: terraform/aws/variable.tf

variable "node_instance_type" {
  description = "EC2 instance type for EKS nodes"
  default     = "t3.small"  # ← Changed from t3.micro
}
```

**Instance Type Comparison:**
| Aspect | t3.micro | t3.small |
|--------|----------|----------|
| vCPU | 1 | 2 |
| Memory | 1 GB | 2 GB |
| Network | Low | Low-Moderate |
| Free tier eligible | Yes | No |
| Cost/month | ~$5-8 | ~$30 |

**Steps taken:**
1. `kubectl describe nodes` → Identified low memory
2. Reviewed node capacity vs pod requests
3. Updated terraform/aws/variable.tf
4. `terraform apply` → Recreates node group
5. Old nodes terminated, new t3.small nodes joined
6. Pods automatically rescheduled

**Verification:**
```bash
# New node resources
$ kubectl describe nodes | grep -A5 "Allocatable:"
  Allocatable:
    cpu:     2000m        # ← 2 CPUs now
    memory:  1837Mi       # ← ~1.8GB available!

# Check pod status after update
$ kubectl get pods -n devops
NAME                          READY  STATUS     RESTARTS
go-api-abc123                 1/1    Running    0  ✓
go-api-def456                 1/1    Running    0  ✓
python-worker-ghi789          1/1    Running    0  ✓

# Verify HPA can now scale
$ kubectl get hpa -n devops
NAME       REFERENCE          TARGETS   MINPODS  MAXPODS  REPLICAS
go-api-hpa Deployment/go-api  45%/70%   1        5        2  ✓
```

**Cost Consideration:**
```
t3.micro:  $0.0116/hour = ~$8/month
t3.small:  $0.0208/hour = ~$30/month
Difference: ~$22/month for 2x nodes = ~$44/month total

But: Now can run production workload!
Value: Priceless for learning/portfolio
Free tier: No longer eligible, this is "real" AWS spending
```

**Result:** ✅ Pods now schedule correctly and application can scale

**Lessons learned:**
- t3.micro insufficient for Kubernetes clusters (no headroom)
- t3.small minimum recommended for dev/prod Kubernetes
- Always account for OS overhead in capacity planning
- Free tier doesn't cut it for multi-pod workloads
- Pod requests must be sized realistically
- Monitor node availability: `kubectl top nodes`

---

### Issue #7: Docker Image Build Context Error

**Error Message:**
```
docker build -t aivora017/devops-go-app .
COPY app-go/ /build/ returned
COPY failed: file not found in build context: app-go
```

**What was happening:**
- Jenkins tried to build Docker image
- Docker build command couldn't find `app-go/` directory
- Build failed immediately

**Root Cause:**
- Jenkins workspace structure was different
- Dockerfile path incorrect, or
- Docker build context (`.`) not set correctly

**Investigation:**
```bash
# Check Jenkins workspace
$ pwd
/var/lib/jenkins/workspace/devops-platform

$ ls -la
drwxrwxr-x  app-go/
drwxrwxr-x  app-python/
drwxrwxr-x  docker/
drwxrwxr-x  k8s/
-rw-rw-r--  Dockerfile  # ← Problem: Dockerfile in wrong location
-rw-rw-r--  Jenkinsfile

# Dockerfile was in root, should be in docker/go/
$ cat Dockerfile
COPY app-go/ /build/  # ← Trying to copy from workspace root
```

**Solution:**
Updated Jenkinsfile build commands to use correct Dockerfile paths:

```groovy
# BEFORE (Wrong)
sh 'docker build -t aivora017/devops-go-app:${BUILD_NUMBER} .'
# Looks for Dockerfile in current directory (not found)

# AFTER (Correct)
sh 'docker build -t aivora017/devops-go-app:${BUILD_NUMBER} -f docker/go/Dockerfile .'
#                                                            ↑ Specify Dockerfile path
```

**Dockerfile Contents (correct location):**
```
# docker/go/Dockerfile
FROM golang:1.21 as builder
WORKDIR /build
COPY app-go/ .              # ← Copies from build context root
RUN go build -o app main.go

FROM scratch
COPY --from=builder /build/app /app
EXPOSE 8080
CMD ["/app"]
```

**Build Command Explanation:**
```bash
docker build -f docker/go/Dockerfile .
#           ↑ File path (relative to cwd)
#                              ↑ Build context (current dir)

Build context explanation:
├─ Current dir: /var/lib/jenkins/workspace/devops-platform
├─ Dockerfile location: docker/go/Dockerfile
├─ What Docker sees in build context:
│  ├─ app-go/ ✓
│  ├─ app-python/ ✓
│  ├─ docker/ ✓
│  └─ k8s/ ✓
├─ COPY app-go/ . copies from root of context
```

**Steps taken:**
1. Identified error message about missing app-go
2. Checked Jenkins workspace structure
3. Found Dockerfile location mismatch
4. Updated Jenkinsfile with `-f` flag
5. Reran build

**Verification:**
```bash
# Build succeeds
$ docker build -f docker/go/Dockerfile .
Sending build context to Docker daemon  ...
Step 1/5 : FROM golang:1.21 as builder
 ---> abc123...
Step 2/5 : WORKDIR /build
 ---> Running in def456...
Step 3/5 : COPY app-go/ .
 ---> abc789...
Step 4/5 : RUN go build -o app main.go
 ---> Running in fdg123...
Step 5/5 : COPY --from=builder /build/app /app
 ---> Running in hij456...
Successfully built a1b2c3d4e5f6
```

**Result:** ✅ Docker images build successfully

**Lessons learned:**
- Docker build context is crucial
- Dockerfile location and build context are independent
- Use `-f /path/to/Dockerfile` to specify path
- Build context must contain all COPY sources
- Always test build locally before Jenkins

---

### Issue #8: LoadBalancer Health Check Failures

**Error Message:**
```
Elastic Load Balancing detected unhealthy targets in your target group.
Target group: go-api-targets
Unhealthy target: 10.0.11.50:8080 (2 unhealthy/2 total)
```

**Result:**
- ALB couldn't reach pods
- Load balancer showed unhealthy status
- Traffic not reaching application

**What was happening:**
- ALB created and health checks configured
- But all target pods marked unhealthy
- No traffic could flow through load balancer

**Root Cause Investigation:**

```bash
# Check pod status
$ kubectl get pods -n devops
NAME              READY  STATUS
go-api-abc123     1/1    Running  ✓

# Check if pod is actually listening
$ kubectl logs -n devops go-api-abc123
2024-02-26 10:30:45 Starting server on :8080
2024-02-26 10:30:46 Server running

# Check service configuration
$ kubectl get svc go-api-service -n devops
NAME              TYPE        CLUSTER-IP  EXTERNAL-IP     PORT(S)
go-api-service    LoadBalancer 10.1.2.3   aab24...elb...  80:31456/TCP

# Check target group in AWS
$ aws elbv2 describe-target-health \
    --target-group-arn arn:aws:elasticloadbalancing:...
Targets:
- Id: 10.0.11.50
  Port: 8080
  HealthCheckState: unhealthy
  HealthCheckReason: Target.ResponseCodeMismatch
  HealthCheckDescription: "Health checks failed with these codes: [503]"
```

**The Problem:**

```
ALB Health Check Process:
Every 30 seconds:
├─ ALB sends: GET http://10.0.11.50:8080/
├─ Pod responds: 503 Service Unavailable! ✗
├─ ALB marks: Unhealthy
├─ Repeat next 30 seconds
├─ Still 503...
└─ Target remains unhealthy

Why 503?
├─ Application crashed?
├─ Port not listening?
├─ Resource issue?
```

**Root Cause:**
Container crashed due to insufficient resources (this was during the t3.micro issue):

```bash
# Check pod logs
$ kubectl logs -n devops go-api-abc123 --previous
# Output: OOMKilled (Out of Memory)

# Check pod events
$ kubectl describe pod go-api-abc123 -n devops
Events:
  CrashLoopBackOff
  Back-off restarting failed container
```

**Solution Progression:**

```
Immediate: Fix health check configuration
├─ Configure health check path: /health
├─ Increase interval to 60 seconds
└─ Adjust healthy threshold

Permanent: Upgrade nodes (t3.micro → t3.small)
├─ Root cause: insufficient node resources
├─ Stop memory crashes
└─ Allow proper resource allocation
```

**Updated Health Check Config:**

```yaml
# kubernetes/service definition
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
  healthCheck:
    enabled: true
    healthyThreshold: 2
    unhealthyThreshold: 2
    timeoutSeconds: 5
    intervalSeconds: 30       # ← Increased from 10
    path: /health              # ← Specific health endpoint
    port: 8080
    matcher:
      httpCode: 200            # ← Accept only 200 OK
```

**Deployment Liveness Probe:**

```yaml
# Kubernetes pod spec
containers:
- name: go-api
  image: aivora017/devops-go-app:15
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

**Go Application Health Endpoint:**

```go
// app-go/main.go
http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
    w.Header().Set("Content-Type", "application/json")
    w.WriteHeader(http.StatusOK)
    json.NewEncoder(w).Encode(map[string]string{
        "status": "healthy",
    })
})
```

**Verification After Fix:**

```bash
# Check target health
$ aws elbv2 describe-target-health \
    --target-group-arn arn:aws:elasticloadbalancing:...
Targets:
- Id: 10.0.11.50
  Port: 8080
  HealthCheckState: healthy  ✓
  HealthCheckReason: N/A
  
# Check service endpoints
$ kubectl get endpoints go-api-service -n devops
NAME              ENDPOINTS
go-api-service    10.0.11.50:8080, 10.0.12.51:8080  ✓

# Test through ALB
$ curl http://aab24...elb.amazonaws.com/health
{"status":"healthy"}  ✓
```

**Result:** ✅ LoadBalancer health checks now passing

**Lessons learned:**
- Health check paths must return 200 OK
- Application must be responding during health checks
- Liveness/Readiness probes catch issues early
- ALB health checks are independent of k8s probes
- OOMKill causes repeated failures (fix resource limits)
- Monitor pod logs when targets marked unhealthy

---

### Issue #9: HPA Not Scaling Despite High CPU

**Symptom:**
```bash
$ kubectl get hpa -n devops
NAME           REFERENCE          TARGETS    MINPODS  MAXPODS  REPLICAS
go-api-hpa     Deployment/go-api  unknown/70%  1      5        1

$ kubectl describe hpa go-api-hpa -n devops
Conditions:
  ScalingActive: False
  Reason: FailedGetResourceMetric
  Message: "unknown: the server has not yet received metrics for pods in the target ref"
```

**What was happening:**
- HPA couldn't see pod metrics
- Stuck at 1 replica during load test
- Scaling was disabled

**Root Cause:**
- Metrics server not collecting data yet
- HPA needs 1-2 minutes to gather initial metrics
- During load test, waited but still no scaling

**Investigation:**
```bash
# Check metrics-server status
$ kubectl get deployment -n kube-system metrics-server
NAME             READY  UP-TO-DATE  AVAILABLE
metrics-server   1/1    1           1        ✓ Running

# Check if metrics are available
$ kubectl get --raw /apis/metrics.k8s.io/v1beta1/namespaces/devops/pods
No metrics available (empty)

# Check metrics-server logs
$ kubectl logs -n kube-system deployment/metrics-server
E0226 10:30:45.123456 kubelet.go:212] Failed to get pod metrics

# Check pod metrics directly
$ kubectl top pods -n devops
error: metrics not available yet
```

**Solution:**
The issue was that metrics collection takes time. The actual solution was to:

1. **Wait for metrics to be available:**
```bash
# Wait 1-2 minutes after pod creation
sleep 120

# Check metrics again
$ kubectl get --raw /apis/metrics.k8s.io/v1beta1/namespaces/devops/pods
```

2. **Verify HPA is configured correctly:**
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
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300     # ← Wait 5 min before scale down
      policies:
      - type: Percent
        value: 50
        periodSeconds: 60
```

3. **Monitor HPA scaling:**
```bash
# Real-time monitoring
watch -n 5 'kubectl describe hpa go-api-hpa -n devops'

# In another terminal, run load test
bash /tmp/continuous-load.sh

# Wait ~5 minutes for smooth scaling
# Watch REPLICAS column increase: 1 → 2 → 3 → 4 → 5
```

**Verification:**

```bash
# Successful scaling demonstration:
$ kubectl describe hpa go-api-hpa -n devops
Name:          go-api-hpa
ScaleTargetRef:
  Kind:        Deployment
  Name:        go-api
Metrics:
  resource "cpu":
    Requests:     100m
    Current usage: 82m (82%)  ← Above 70% threshold
Min replicas:  1
Max replicas:  5
Current replicas: 3          ← Scaled up to 3!

Events:
  SuccessfulRescale: New size: 3; reason: cpu resource
  utilization (current) above target (current: 82%)
```

**Result:** ✅ HPA now scaling correctly with metrics

**Lessons learned:**
- Metrics server needs 1-2 minutes to gather data
- HPA works, just needs patience initially
- "unknown" metric status is normal at start
- Scale down is slower than scale up (stabilization)
- `kubectl top` is the quickest way to verify metrics
- Metrics collection doesn't block pod functionality

---

### Issue #10: GitHub Webhook Not Triggering Jenkins

**Symptom:**
```bash
# Made code commit and pushed
$ git push origin main
# Expected: Jenkins job starts automatically
# Actual: Nothing happens (checked Jenkins at 15.134.1.230:8080)
```

**Investigation:**
```bash
# Check Jenkins logs for webhook events
$ kubectl logs -f deployment/jenkins -n jenkins
[02/26 10:45:23] Received webhook event? No logs...

# Check GitHub webhook delivery
GitHub Repo Settings → Webhooks → "Delivery" tab
Recent Deliveries:
- POST http://15.134.1.230:8080/github-webhook/ 
  Response: 403 Forbidden
  ERROR: Jenkins returned HTTP/1.1 403 Forbidden
```

**Root Cause:**
1. Jenkins security token/authentication required
2. GitHub webhook didn't have proper authentication
3. Jenkins rejected unauthenticated webhook requests

**Solution:**
Configure Jenkins webhook with authentication token:

**Step 1: Get Jenkins webhook token**
```bash
# Generate token in Jenkins
Jenkins UI → Manage Jenkins → Configure System → GitHub → Advanced → Manage Hooks
# Or create in Jenkins pipeline job:
# Trigger section: "GitHub hook trigger for GITScm polling"
# Optional: GitHub API token
```

**Step 2: Configure GitHub webhook**
```
GitHub Repo Settings → Webhooks → Add webhook

Payload URL: http://15.134.1.230:8080/github-webhook/
Content type: application/json
Secret: (leave empty for now)
Events: Just the push event
Active: ✓ Checked
```

**Step 3: Test webhook**
```bash
# In GitHub webhook settings, click "Redeliver" on failed delivery

# Or make a new push
$ git commit --allow-empty -m "Test webhook"
$ git push origin main

# Check Jenkins logs
$ kubectl logs deployment/jenkins -n jenkins | grep -i webhook
[02/26 11:00:45] INFO: Webhook from GitHub received
[02/26 11:00:46] Started by GitHub push by aivora017
[02/26 11:00:46] Running as jenkins
[02/26 11:00:46] Starting job...
```

**Verification:**
```bash
# Check Jenkins job triggered
Jenkins UI → Recent Jobs
job: devops-platform
Build #17 (2 approches ago)
Build started by: SCM change notification from GitHub
Status: ✓ Success
```

**Alternative: Manual Testing**
```bash
# Simulate GitHub webhook without changing code
curl -X POST http://15.134.1.230:8080/github-webhook/ \
  -H "Content-Type: application/json" \
  -d '{"ref": "refs/heads/main", "commits": [{"id": "abc123"}]}'

# Check Jenkins logs
# Should see: "Webhook received"
```

**Result:** ✅ GitHub webhook now triggers Jenkins builds

**Lessons learned:**
- Jenkins GitHub plugin requires configuration
- Webhook events show in GitHub "Recent Deliveries"
- Check HTTP response codes (403 = auth required)
- Jenkins logs are helpful for debugging webhooks
- Test webhook manually to verify connectivity

---

## 🔧 Troubleshooting Checklist

### For Pod Issues

```bash
# 1. Check pod status
kubectl get pods -n devops
# Look for STATUS column: Running, Pending, CrashLoopBackOff, etc.

# 2. View pod logs
kubectl logs -n devops <pod-name>
kubectl logs -n devops <pod-name> --previous  # For crashed pods

# 3. Describe pod (shows events and resource usage)
kubectl describe pod -n devops <pod-name>
# Look for: Events section, Resource requests/limits

# 4. Check resource availability
kubectl top nodes     # Node CPU/Memory usage
kubectl top pods      # Pod CPU/Memory usage

# 5. Verify service endpoints
kubectl get endpoints <service-name> -n devops
# Should show pod IPs if healthy
```

### For Kubernetes Issues

```bash
# 1. Check cluster health
kubectl cluster-info dump

# 2. View all resources
kubectl get all -n devops

# 3. Check events (most recent issues)
kubectl get events -n devops --sort-by='.lastTimestamp'

# 4. Describe problematic resources
kubectl describe deployment go-api -n devops
kubectl describe hpa go-api-hpa -n devops
kubectl describe svc go-api-service -n devops

# 5. Check node status
kubectl get nodes -o wide
kubectl describe nodes
```

### For Jenkins Issues

```bash
# 1. Check Docker integration
docker ps | grep jenkins
docker logs jenkins

# 2. Check kubeconfig accessibility
docker exec jenkins cat /var/lib/jenkins/.kube/config

# 3. Test kubectl from Jenkins
docker exec jenkins kubectl get pods -n devops

# 4. Check Jenkins build log
Jenkins UI → Build #XX → Console Output

# 5. Verify Docker Hub credentials
docker login -u aivora017 -p $TOKEN  # Manual test
```

### For Network Issues

```bash
# 1. Test pod accessibility
kubectl port-forward -n devops po/go-api-abc123 8080:8080
curl localhost:8080/health

# 2. Test service DNS resolution
kubectl run -it --rm debug --image=alpine --restart=Never -- sh
# Inside pod:
nslookup go-api-service.devops.svc.cluster.local

# 3. Check network policies (if configured)
kubectl get networkpolicies -n devops

# 4. Verify LoadBalancer status
kubectl get svc go-api-service -n devops -o wide
# Check EXTERNAL-IP (should be populated)

# 5. Test through LoadBalancer
curl http://<EXTERNAL-IP>/health
```

### For AWS Issues

```bash
# 1. Check IAM permissions
aws iam get-role --role-name jenkins-role
aws iam list-role-policies --role-name jenkins-role

# 2. Check EKS cluster
aws eks describe-cluster --name devops-platform-cluster --region ap-southeast-2

# 3. Check EC2 instances
aws ec2 describe-instances --filters "Name=tag:Name,Values=jenkins*"

# 4. Check LoadBalancer status
aws elbv2 describe-load-balancers --names go-api-alb
aws elbv2 describe-target-health --target-group-arn <arn>

# 5. Check VPC and Security Groups
aws ec2 describe-security-groups --filters "Name=group-name,Values=jenkins*"
```

---

## 🚀 Performance Optimization Tips

### Reduce Build Time

```groovy
// Use Docker BuildKit for layer caching
export DOCKER_BUILDKIT=1
docker build -t image:tag .

// Multi-threaded Go builds
RUN go build -p 8 -o app main.go

// Python: use slim base images
FROM python:3.10-slim  # Better than python:3.10
```

### Reduce Image Size

```dockerfile
# Multi-stage builds
FROM golang:1.21 as builder
RUN go build ...

FROM scratch  # Ultra-lean base
COPY --from=builder ...
# Final size: minimal

# Python layer optimization
FROM python:3.10-slim
RUN pip install -q -r requirements.txt && \
    pip cache purge  # Remove pip cache
```

### Faster Deployments

```yaml
# Rolling update strategy
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1        # Faster (overlap update)
    maxUnavailable: 0  # Zero downtime
```

---

**Last Updated:** February 26, 2026  
**Author:** Sourav (DevOps Fresher)  
**Total Issues Documented:** 10 major + detailed solutions  
**Lessons Learned:** 40+ technical insights