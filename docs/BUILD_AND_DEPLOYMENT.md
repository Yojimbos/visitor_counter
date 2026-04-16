# Build and Deployment Pipeline

## Overview

The repository uses three GitHub Actions workflows:

1. [build-and-push.yml](/c:/repositories/visitor_counter/.github/workflows/build-and-push.yml:1) builds the image and pushes it to ACR.
2. [deploy.yml](/c:/repositories/visitor_counter/.github/workflows/deploy.yml:1) deploys the latest image to AKS and verifies the rollout.
3. [monitoring.yml](/c:/repositories/visitor_counter/.github/workflows/monitoring.yml:1) installs the cluster monitoring stack.

## Build Workflow

The build workflow triggers on pushes to `main` or `develop` when application code or the workflow itself changes.

It performs these steps:

1. Restore and run `dotnet test visitor_counter.sln --configuration Release`.
2. Generate an image tag from the current UTC timestamp.
3. Log in to Azure and ACR.
4. Build and push two tags:
   - timestamp tag, for example `visitorcounteracr.azurecr.io/visitor-counter:20260416-101530`
   - `latest`

The deployment workflow selects the newest repository tag by push time.

## Deploy Workflow

The deploy workflow runs manually or after a successful build workflow on `main`.

It performs these steps:

1. Log in to Azure and fetch AKS credentials.
2. Install or update `ingress-nginx` using [infra/ingress/ingress-nginx-values.yaml](/c:/repositories/visitor_counter/infra/ingress/ingress-nginx-values.yaml:1).
3. Install or update cert-manager.
4. Read the latest app image tag from ACR.
5. Read database and backup settings from Key Vault.
6. Render and apply the Kubernetes manifests.
7. Apply [k8s/backup-cronjob.yaml](/c:/repositories/visitor_counter/k8s/backup-cronjob.yaml:1) when backup storage is configured.
8. Apply [k8s/servicemonitor.yaml](/c:/repositories/visitor_counter/k8s/servicemonitor.yaml:1) when the `ServiceMonitor` CRD is present.
9. Wait for the app rollout and TLS secret.
10. Run [scripts/Test-Deployment.ps1](/c:/repositories/visitor_counter/scripts/Test-Deployment.ps1:1).

## Deployment Verification

The deployment smoke test validates:

- deployment, service, ingress, and TLS secret exist
- the public site returns HTTP 200
- `/metrics` is reachable inside the cluster through `visitor-counter-service.default.svc.cluster.local`
- `ServiceMonitor` exists when monitoring is installed
- the weekly backup `CronJob` exists when backup storage is configured

## Monitoring Workflow

The monitoring workflow runs manually or on pushes to `main` when files under `infra/monitoring/**` or the workflow file itself change.

It installs:

- `kube-prometheus-stack`
- `loki`
- `promtail`

Grafana stays internal as a `ClusterIP` service. Access it locally with:

```bash
kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80
```

Then open `http://localhost:3000` and sign in with:

- user: `admin`
- password: the value of `GRAFANA_ADMIN_PASSWORD`

## Required GitHub Secrets

- `AZURE_CREDENTIALS`
- `AZURE_SUBSCRIPTION_ID`
- `GRAFANA_ADMIN_PASSWORD`
- `LETSENCRYPT_EMAIL`

## Manual Verification Commands

```bash
kubectl get nodes -o wide
kubectl get pods -n ingress-nginx -o wide
kubectl get ingress,certificate,servicemonitor,cronjob -A
kubectl get deployment visitor-counter -n default -o jsonpath='{.spec.template.spec.containers[0].image}'
```

## Troubleshooting

If deployment verification fails:

1. Check ingress and certificate state.
2. Check `ingress-nginx` controller health and external IP.
3. Check whether the app service resolves and responds inside the cluster.
4. Review the `Smoke test` step output from the deploy workflow, because it now prints targeted diagnostics instead of silently waiting.
