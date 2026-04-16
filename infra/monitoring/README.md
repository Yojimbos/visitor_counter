# Monitoring Stack

This directory contains Helm values for the AKS monitoring stack.

## Components

- `kube-prometheus-stack` for Prometheus and Grafana
- `loki` for log storage
- `promtail` for pod log shipping

## Files

- [kube-prometheus-stack-values.yaml](/c:/repositories/visitor_counter/infra/monitoring/kube-prometheus-stack-values.yaml:1)
- [loki-values.yaml](/c:/repositories/visitor_counter/infra/monitoring/loki-values.yaml:1)
- [promtail-values.yaml](/c:/repositories/visitor_counter/infra/monitoring/promtail-values.yaml:1)

## Installation

Use [monitoring.yml](/c:/repositories/visitor_counter/.github/workflows/monitoring.yml:1).

Required GitHub secrets:

- `AZURE_CREDENTIALS`
- `AZURE_SUBSCRIPTION_ID`
- `GRAFANA_ADMIN_PASSWORD`

The workflow installs the stack into the `monitoring` namespace.

## Access

Grafana is exposed as a `ClusterIP` service.

Run:

```bash
kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80
```

Then open `http://localhost:3000`.

Credentials:

- user: `admin`
- password: the value of `GRAFANA_ADMIN_PASSWORD`

## Application Metrics

The app exposes Prometheus metrics at `/metrics`, but they are scraped internally through the Kubernetes service, not through the public ingress hostname.

[k8s/servicemonitor.yaml](/c:/repositories/visitor_counter/k8s/servicemonitor.yaml:1) is applied automatically by [deploy.yml](/c:/repositories/visitor_counter/.github/workflows/deploy.yml:1) when the `ServiceMonitor` CRD exists.

## What To Check

- `kubectl get servicemonitor visitor-counter -n default`
- `kubectl get pods -n monitoring`
- `kubectl get svc kube-prometheus-stack-grafana -n monitoring`
- In Grafana, verify both `Prometheus` and `Loki` datasources
