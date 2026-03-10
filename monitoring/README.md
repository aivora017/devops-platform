# Monitoring

The monitoring stack is deployed into the `monitoring` namespace.

## Components

- Prometheus
- Grafana
- Alertmanager
- ServiceMonitors and PrometheusRule resources

## Deploy

```bash
bash scripts/deploy-monitoring.sh
```

## Verify

```bash
kubectl get pods -n monitoring
kubectl get svc -n monitoring
kubectl get prometheus -n monitoring
kubectl get servicemonitors -A
```

## Access

```bash
kubectl -n monitoring port-forward svc/prometheus-kube-prometheus-prometheus 19090:9090
kubectl -n monitoring port-forward svc/grafana 3000:80
kubectl -n monitoring port-forward svc/alertmanager-operated 9093:9093
```

Grafana defaults:

- username: `admin`
- password: `admin123`

## Application Metrics

The applications expose `/metrics` and are scraped through `monitoring/prometheus/service-monitor.yaml`.

Main metrics include:

- `http_requests_total`
- `http_request_duration_seconds`
- `worker_health_checks_total`
- `worker_health_check_duration_seconds`

## Dashboard

The custom dashboard in this repository is:

- `monitoring/dashboards/hpa-load-test-observability.json`
