# Troubleshooting

## Jenkins cannot deploy to EKS

Check on the Jenkins host:

```bash
aws sts get-caller-identity
aws eks update-kubeconfig --name devops-platform-cluster --region ap-southeast-2
kubectl get ns
```

Common causes:

- missing EC2 instance profile
- Jenkins role not mapped in `aws-auth`
- outdated AWS CLI on the Jenkins host

## Docker permission errors in Jenkins

If the pipeline cannot access Docker:

```bash
sudo usermod -aG docker jenkins
sudo systemctl restart jenkins
```

## Pods stuck in Pending

Check:

```bash
kubectl get pods -n devops
kubectl get pods -n monitoring
kubectl describe pod <pod-name> -n <namespace>
```

Typical causes:

- insufficient cluster resources
- storage-related scheduling issues
- invalid image or image pull failure

## App metrics not visible in Prometheus

Check:

```bash
kubectl get servicemonitors -A
kubectl get svc -n devops --show-labels
kubectl get endpoints -n devops
```

Verify:

- service labels match the ServiceMonitor selectors
- the worker service exposes the `metrics` port
- `/metrics` is reachable inside the cluster

## Port-forward fails

If local port-forwarding fails, use a different local port:

```bash
kubectl -n monitoring port-forward svc/prometheus-kube-prometheus-prometheus 19090:9090
```

Then query:

```bash
curl -sG 'http://127.0.0.1:19090/api/v1/query' --data-urlencode 'query=up'
```

## HPA does not scale

Check:

```bash
kubectl get apiservices | grep metrics
kubectl top pods -n devops
kubectl describe hpa go-api-hpa -n devops
```

Verify:

- metrics-server is healthy
- load is sustained long enough to trigger scaling
- requests and limits are set correctly

## Useful commands

```bash
kubectl get deploy,svc,hpa -n devops
kubectl logs -n devops deployment/go-api --tail=100
kubectl logs -n devops deployment/python-worker --tail=100
kubectl get all -n monitoring
kubectl get events -n devops --sort-by=.metadata.creationTimestamp | tail -20
kubectl get events -n monitoring --sort-by=.metadata.creationTimestamp | tail -20
```
