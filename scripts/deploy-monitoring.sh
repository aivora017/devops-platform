#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
MONITORING_DIR="$PROJECT_ROOT/monitoring"

cd "$MONITORING_DIR"

NAMESPACE="monitoring"
PROMETHEUS_RELEASE="prometheus"
GRAFANA_RELEASE="grafana"
ALERTMANAGER_RELEASE="alertmanager"

log_info() {
    echo "[INFO] $1"
}

log_success() {
    echo "[SUCCESS] $1"
}

log_error() {
    echo "[ERROR] $1" >&2
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl not found"
        exit 1
    fi
    
    if ! command -v helm &> /dev/null; then
        log_error "helm not found"
        exit 1
    fi
    
    kubectl cluster-info &> /dev/null || {
        log_error "Cannot connect to Kubernetes cluster"
        exit 1
    }
    
    log_success "Prerequisites check passed"
}

create_namespace() {
    log_info "Creating monitoring namespace..."
    
    kubectl apply -f k8s-setup.yaml
    
    log_success "Namespace and RBAC created"
}

add_helm_repos() {
    log_info "Adding Helm repositories..."
    
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo add grafana https://grafana.github.io/helm-charts
    helm repo update
    
    log_success "Helm repositories added"
}

deploy_prometheus() {
    log_info "Deploying Prometheus..."
    
    helm upgrade --install $PROMETHEUS_RELEASE prometheus-community/kube-prometheus-stack \
        --namespace $NAMESPACE \
        --values prometheus/values.yaml \
        --wait \
        --timeout 10m
    
    log_success "Prometheus deployed"
}

deploy_grafana() {
    log_info "Deploying Grafana..."
    
    helm upgrade --install $GRAFANA_RELEASE grafana/grafana \
        --namespace $NAMESPACE \
        --values grafana/values.yaml \
        --wait \
        --timeout 5m
    
    log_success "Grafana deployed"
}

deploy_alertmanager() {
    log_info "Deploying AlertManager..."
    
    kubectl create configmap alertmanager-config \
        --from-file=alertmanager/alertmanager.yaml \
        --namespace $NAMESPACE \
        --dry-run=client -o yaml | kubectl apply -f -
    
    helm upgrade --install $ALERTMANAGER_RELEASE prometheus-community/alertmanager \
        --namespace $NAMESPACE \
        --values alertmanager/values.yaml \
        --set config.alertmanager=$(cat alertmanager/alertmanager.yaml | base64 -w 0) \
        --wait \
        --timeout 5m
    
    log_success "AlertManager deployed"
}

apply_service_monitors() {
    log_info "Applying ServiceMonitors..."
    
    kubectl apply -f prometheus/service-monitor.yaml
    
    log_success "ServiceMonitors applied"
}

configure_grafana_dashboards() {
    log_info "Configuring Grafana dashboards..."
    
    kubectl create configmap grafana-dashboards \
        --from-file=dashboards/ \
        --namespace $NAMESPACE \
        --dry-run=client -o yaml | kubectl apply -f -
    
    log_success "Grafana dashboards configured"
}

get_service_info() {
    log_info "Getting service information..."
    
    echo ""
    echo "Service Status:"
    kubectl get svc -n $NAMESPACE
    
    echo ""
    echo "Pod Status:"
    kubectl get pods -n $NAMESPACE
    
    echo ""
    echo "Accessing Services:"
    echo "Prometheus: kubectl port-forward -n $NAMESPACE svc/prometheus-kube-prometheus-prometheus 19090:9090"
    echo "Grafana: kubectl port-forward -n $NAMESPACE svc/$GRAFANA_RELEASE 3000:80"
    echo "AlertManager: kubectl port-forward -n $NAMESPACE svc/alertmanager-operated 9093:9093"
}

main() {
    log_info "Starting monitoring stack deployment..."
    
    check_prerequisites
    create_namespace
    add_helm_repos
    deploy_prometheus
    deploy_alertmanager
    deploy_grafana
    apply_service_monitors
    configure_grafana_dashboards
    get_service_info
    
    log_success "Monitoring stack deployed successfully"
}

main "$@"
