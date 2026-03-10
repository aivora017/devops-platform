# Project Flow

## 1. Infrastructure Bootstrap

Run the bootstrap script:

```bash
bash scripts/deploy-complete.sh
```

That step:

- applies Terraform in `terraform/aws`
- creates the Jenkins host and EKS resources
- updates the Ansible inventory
- configures Jenkins with Ansible

## 2. Jenkins Bootstrap

After the script finishes:

1. open Jenkins
2. complete the initial login flow
3. create the pipeline job
4. point the job to this repository and `Jenkinsfile`
5. add required credentials

## 3. First Deployment

Run the Jenkins job once.

The pipeline:

- checks out the repository
- builds the Go and Python images
- pushes the images to Docker Hub
- applies the Kubernetes manifests
- updates the image tags in EKS

## 4. Regular Delivery

Once the Jenkins job exists, normal pushes can trigger the same pipeline automatically.

## 5. Monitoring

Deploy monitoring separately:

```bash
bash scripts/deploy-monitoring.sh
```

This installs Prometheus, Grafana, Alertmanager, and the ServiceMonitor resources used to scrape the app metrics.

## 6. Load Validation

Run the load test with:

```bash
bash scripts/load-test.sh
```

During a test, watch:

```bash
kubectl get hpa -n devops -w
kubectl get pods -n devops -o wide
kubectl top pods -n devops
```
