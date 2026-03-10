# Architecture

## Summary

The platform uses AWS for infrastructure, Jenkins for CI/CD, EKS for runtime, and Prometheus/Grafana for observability.

## Infrastructure

Region: `ap-southeast-2`

Main components:

- VPC and subnets managed by Terraform
- Jenkins EC2 instance for CI/CD
- EKS cluster and managed node group for workloads
- IAM roles for Jenkins and Kubernetes access

## Applications

Namespace: `devops`

Workloads:

- `go-api`
- `python-worker`

Services:

- `go-api-service` as `LoadBalancer`
- `python-worker-service` as `ClusterIP`

Scaling:

- `go-api-hpa`
- `python-worker-hpa`
- metrics served by `metrics-server`

## Delivery Model

1. Terraform creates the AWS resources.
2. Ansible configures Jenkins on the EC2 instance.
3. Jenkins builds and pushes container images.
4. Jenkins applies and updates Kubernetes resources in EKS.
5. Kubernetes handles rollout and autoscaling.

## Observability

Namespace: `monitoring`

Components:

- Prometheus via `kube-prometheus-stack`
- Grafana
- Alertmanager

Application metrics are exposed on `/metrics` and scraped through ServiceMonitors.

## Key Files

- `terraform/aws/`
- `ansible/playbook.yml`
- `Jenkinsfile`
- `k8s/aws/`
- `monitoring/prometheus/values.yaml`
- `monitoring/prometheus/service-monitor.yaml`
- `monitoring/grafana/values.yaml`
- `monitoring/alertmanager/values.yaml`
