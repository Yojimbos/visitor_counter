# Monitoring Stack

This directory contains Helm values and deployment guidance for the cluster-level monitoring stack running in AKS.

## Components

- `kube-prometheus-stack` for Prometheus, Grafana, kube-state-metrics, and node exporter
- `loki` for log storage
- `promtail` for shipping pod logs to Loki

## Layout

- `kube-prometheus-stack-values.yaml` configures Prometheus and Grafana
- `loki-values.yaml` configures Loki in single-binary mode for a small production cluster
- `promtail-values.yaml` configures log collection

## Install

The recommended path is the GitHub Actions workflow in `.github/workflows/monitoring.yml`.

Required GitHub secrets:

- `AZURE_CREDENTIALS`
- `AZURE_SUBSCRIPTION_ID`
- `GRAFANA_ADMIN_PASSWORD`

## Access

Grafana is installed as a `ClusterIP` service by default.

To access it locally:

```bash
kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80
```

Then open `http://localhost:3000` and sign in with:

- user: `admin`
- password: the value of `GRAFANA_ADMIN_PASSWORD`

To verify Loki is connected, open Grafana and check the `Loki` datasource.

## App Metrics Next Step

The application is prepared to expose Prometheus metrics at `/metrics`.

After the monitoring stack is installed and the application is redeployed:

```bash
kubectl apply -f k8s/servicemonitor.yaml
```

That manifest is kept separate from the main app deploy because it depends on CRDs provided by `kube-prometheus-stack`.
