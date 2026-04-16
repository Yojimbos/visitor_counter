# Visitor Counter Demo

A .NET 8 Razor Pages application that increments a visit counter in Azure Database for PostgreSQL and demonstrates a small but production-shaped Azure platform around it.

## Architecture

- Application: ASP.NET Core Razor Pages
- Database: Azure Database for PostgreSQL Flexible Server
- Containers: Docker multi-stage build
- Registry: Azure Container Registry
- Orchestration: Azure Kubernetes Service
- Secrets: Azure Key Vault
- Infrastructure as Code: Terraform
- Ingress: `ingress-nginx` with cert-manager and Let's Encrypt
- Monitoring: Prometheus, Grafana, Loki, and Promtail on AKS
- Backups: Azure native PostgreSQL retention plus weekly logical dumps to Blob Storage

## Current Platform Baseline

- AKS runs a 2-node default pool as the cheapest reasonable HA baseline.
- `ingress-nginx` runs with 2 controller replicas, pod spread, anti-affinity, and a health probe path tuned for Azure Load Balancer.
- PostgreSQL native backup retention is explicitly set to 7 days.
- Weekly logical PostgreSQL backups are exported every Sunday at 03:00 UTC to geo-redundant Blob Storage.
- Key Vault purge protection is enabled.
- PostgreSQL private networking is prepared in Terraform behind a feature flag, but it is not enabled in the current environment.

## CI/CD Workflows

- [terraform.yaml](/c:/repositories/visitor_counter/.github/workflows/terraform.yaml:1): validates, imports existing Azure resources into local CI state when needed, plans Terraform changes, and applies infrastructure updates on push.
- [build-and-push.yml](/c:/repositories/visitor_counter/.github/workflows/build-and-push.yml:1): runs unit tests, builds the app image, and pushes it to ACR.
- [deploy.yml](/c:/repositories/visitor_counter/.github/workflows/deploy.yml:1): installs or updates ingress and cert-manager, deploys the app to AKS, applies backup and monitoring resources when available, and runs deployment verification.
- [monitoring.yml](/c:/repositories/visitor_counter/.github/workflows/monitoring.yml:1): installs `kube-prometheus-stack`, Loki, and Promtail into the `monitoring` namespace.

## Tests

- Unit tests live in [tests/VisitorCounter.Tests](/c:/repositories/visitor_counter/tests/VisitorCounter.Tests/VisitorCounter.Tests.csproj:1).
- The build workflow runs `dotnet test visitor_counter.sln --configuration Release`.
- Deployment verification is implemented in [scripts/Test-Deployment.ps1](/c:/repositories/visitor_counter/scripts/Test-Deployment.ps1:1).
- The smoke test checks the public app URL and verifies `/metrics` from inside the cluster through the app service.

## Required GitHub Secrets

- `AZURE_CREDENTIALS`
- `AZURE_SUBSCRIPTION_ID`
- `AZURE_CLIENT_ID`
- `GRAFANA_ADMIN_PASSWORD`
- `LETSENCRYPT_EMAIL`

## Secrets Currently Used By Workflows

- `AZURE_CREDENTIALS`: used by `build-and-push.yml`, `deploy.yml`, `monitoring.yml`, and `terraform.yaml`
- `AZURE_SUBSCRIPTION_ID`: used by `build-and-push.yml`, `deploy.yml`, and `monitoring.yml`
- `AZURE_CLIENT_ID`: used by `terraform.yaml` during import of the current Key Vault access policy
- `GRAFANA_ADMIN_PASSWORD`: used by `monitoring.yml`
- `LETSENCRYPT_EMAIL`: used by `deploy.yml`

## Legacy Or Possibly Redundant Secrets

- `AZURE_TENANT_ID`: not referenced directly by the current workflows
- `AZURE_CLIENT_SECRET`: not referenced directly by the current workflows

Those two may still be present because they are often embedded inside `AZURE_CREDENTIALS`, but as standalone secrets they are currently not required by the repository workflows.

## Local Development

1. Install the .NET 8 SDK.
2. Provide a PostgreSQL connection string through configuration or secrets.
3. Run the app from `src/VisitorCounter` with `dotnet run`.
4. Run tests from the repository root with `dotnet test visitor_counter.sln`.

## Operations

- Monitoring setup and access: [docs/MONITORING.md](/c:/repositories/visitor_counter/docs/MONITORING.md:1)
- Build and deployment flow: [docs/BUILD_AND_DEPLOYMENT.md](/c:/repositories/visitor_counter/docs/BUILD_AND_DEPLOYMENT.md:1)
- Terraform bootstrap and backend setup: [docs/TERRAFORM_BOOTSTRAP.md](/c:/repositories/visitor_counter/docs/TERRAFORM_BOOTSTRAP.md:1)