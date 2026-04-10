# Visitor Counter Demo

A .NET 8 web application demonstrating DevOps practices with Azure cloud services.

## Architecture

The application is a simple visitor counter that increments a counter in Azure Database for PostgreSQL on each page visit and displays the total count with a message.

### Components

- **Application**: ASP.NET Core Razor Pages app
- **Database**: Azure Database for PostgreSQL Flexible Server
- **Containerization**: Docker with multi-stage build
- **Registry**: Azure Container Registry (ACR)
- **Orchestration**: Azure Kubernetes Service (AKS)
- **Secrets**: Azure Key Vault
- **CI/CD**: GitHub Actions
- **IaC**: Terraform
- **Ingress**: NGINX Ingress Controller with TLS
- **Monitoring**: Application Insights

## Prerequisites

- Azure subscription
- Azure CLI
- Terraform
- Docker
- kubectl
- .NET 8 SDK

## Setup Instructions

### 1. Infrastructure Provisioning

1. Create a storage account for Terraform state:
   ```bash
   az group create --name tfstate --location eastus
   az storage account create --name tfstate1234 --resource-group tfstate --location eastus --sku Standard_LRS
   az storage container create --name tfstate --account-name tfstate1234
   ```

2. Update `infra/terraform/main.tf` backend configuration with your storage account details.

3. Run Terraform:
   ```bash
   cd infra/terraform
   terraform init
   terraform plan
   terraform apply
   ```

### 2. Configure Secrets

1. Add secrets to Azure Key Vault (done via Terraform).

2. For GitHub Actions, add the following secrets to your repository:
   - `AZURE_SUBSCRIPTION_ID`: Your Azure subscription ID
   - `AZURE_TENANT_ID`: Your Azure tenant ID
   - `AZURE_CLIENT_ID`: Service principal client ID
   - `AZURE_CLIENT_SECRET`: Service principal client secret
   - `AZURE_CREDENTIALS`: Service principal credentials (JSON format)

   Generate credentials:
   ```bash
   az ad sp create-for-rbac --name "github-actions" \
     --role Contributor \
     --scopes /subscriptions/{SUBSCRIPTION_ID} \
     --json-auth
   ```

### 3. Build and Deploy

**Automated via GitHub Actions:**
- Push to `main` or `develop` branch triggers build pipeline
- Image is tagged with **git commit hash** (e.g., `a1b2c3d`)
- Pipeline automatically deploys to AKS

**Manual deployment instructions:** See [BUILD_AND_DEPLOYMENT.md](docs/BUILD_AND_DEPLOYMENT.md)

### 4. Image Tagging Strategy

- **Production**: Git commit hash (e.g., `visitorcounteracr.azurecr.io/visitor-counter:a1b2c3d`)
- ✅ Traceable, immutable, safe for production
- ✅ NO `latest` tag to prevent unpredictable rollouts
- ✅ Full deployment history in git commits

### 5. DNS and TLS


1. Update `k8s/ingress.yaml` with your domain.
2. Install cert-manager and NGINX Ingress Controller on AKS.
3. Configure DNS to point to the ingress IP.

## Local Development

1. Install PostgreSQL locally or use a container.
2. Update `appsettings.json` with connection string.
3. Run the app:
   ```bash
   cd src/VisitorCounter
   dotnet run
   ```

## Security Notes

- Non-root containers
- RBAC for cluster access
- Secrets stored in Key Vault
- Image vulnerability scanning (add to pipeline)

## Monitoring

- Application Insights for telemetry
- stdout logs collected by AKS
- Health checks and probes configured

## Scaling

- HPA configured for CPU/memory scaling
- Can scale from 1 to 10 replicas