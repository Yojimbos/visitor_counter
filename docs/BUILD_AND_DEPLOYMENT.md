# Build and Deployment Pipeline

## Overview

The project uses GitHub Actions for automated building and deployment:

1. **Build Stage** (`build-and-push.yml`): Builds Docker image and pushes to Azure Container Registry
2. **Deploy Stage** (`deploy.yml`): Deploys the latest image to AKS
3. **Monitoring Stage** (`monitoring.yml`): Installs Prometheus, Grafana, Loki, and Promtail into AKS

## Image Tagging Strategy

**Best Practice: Timestamp + Short Commit Hash**

- Each image is tagged with timestamp + 7-character commit hash
- Example: `visitorcounteracr.azurecr.io/visitor-counter:20260410-143022-7a85828`
- Benefits:
  - ✅ Shows build time (when image was created)
  - ✅ Includes commit reference for traceability
  - ✅ Easy to identify newer versions by timestamp
  - ✅ Safe alternative to `latest` tag in production
  - ✅ Works perfectly with CI/CD

**Why NOT use full commit hash:**
- ❌ Too long and hard to read
- ❌ No indication of build time
- ❌ Difficult to compare versions

**Why NOT use `latest` tag:**
- ❌ No version tracking
- ❌ Risky in production (unpredictable rollouts)
- ❌ Hard to debug issues
- ❌ Can cause race conditions in deployments

## Setup Instructions

### 1. Configure GitHub Secrets

Add the following secrets to your GitHub repository:

```
AZURE_SUBSCRIPTION_ID    - Your Azure subscription ID
AZURE_TENANT_ID          - Your Azure tenant ID  
AZURE_CLIENT_ID          - Service principal client ID
AZURE_CLIENT_SECRET      - Service principal client secret
AZURE_CREDENTIALS        - Full credentials JSON for Azure/login action
GRAFANA_ADMIN_PASSWORD   - Admin password for Grafana
```

**Generate `AZURE_CREDENTIALS`:**
```bash
az ad sp create-for-rbac \
  --name "github-actions" \
  --role Contributor \
  --scopes /subscriptions/{SUBSCRIPTION_ID} \
  --json-auth
```

### 2. Infrastructure Setup (Terraform)

```bash
cd infra/terraform
terraform init
terraform plan
terraform apply
```

Terraform creates:
- ✅ Azure Container Registry (ACR)
- ✅ Azure Kubernetes Service (AKS)
- ✅ Azure Key Vault
- ✅ PostgreSQL Flexible Server
- ✅ RBAC: AKS can pull images from ACR (AcrPull role)

### CI/CD Terraform Configuration

For CI/CD pipelines, use the local backend to avoid authentication issues:

1. **Copy the local backend file:**
   ```bash
   cp infra/terraform/backend.local.tf infra/terraform/backend.tf
   ```

2. **Run Terraform in CI/CD:**
   ```bash
   cd infra/terraform
   terraform init
   terraform plan -out=tfplan
   terraform apply tfplan
   ```

3. **For production deployments**, switch back to Azure backend:
   ```bash
   git checkout infra/terraform/backend.tf  # Restore original
   terraform init -reconfigure  # Reinitialize with Azure backend
   ```

**Note**: The `backend.local.tf` file is configured for CI/CD use with managed identity.

### 3. Kubernetes Configuration

Secret values are stored in `k8s/secret.yaml`:
```yaml
DB_HOST: visitor-counter-postgres.postgres.database.azure.com
DB_USER: postgresadmin
DB_PASSWORD: <from-terraform-output>
```

## Image Deployment Workflow

### Manual Push (Testing)

Build locally:
```bash
# Build image with git commit hash
GIT_HASH=$(git rev-parse --short HEAD)
docker build -t visitorcounteracr.azurecr.io/visitor-counter:${TIMESTAMP}-${SHORT_COMMIT} \
  ./src/VisitorCounter

# Push to ACR
az acr login --name visitorcounteracr
docker push visitorcounteracr.azurecr.io/visitor-counter:${TIMESTAMP}-${SHORT_COMMIT}
```

Update deployment:
```bash
# Replace placeholder in deployment.yaml
sed -i "s/\$(GIT_COMMIT_HASH)/${GIT_HASH}/g" k8s/deployment.yaml

# Deploy to AKS
kubectl apply -f k8s/
```

### Automated Deployment (GitHub Actions)

1. **Trigger**: Push to `main` or `develop` branch
2. **Build**: GitHub Actions builds and pushes image to ACR with git commit hash tag
3. **Deploy**: Automatically or on-demand, pulls latest image and deploys to AKS
4. **Verify**: Rollout status is monitored, pods verified

### Monitoring Installation

Run the monitoring workflow after the AKS cluster is available:

1. Open the `Install Monitoring Stack` workflow in GitHub Actions
2. Start it manually, or let it run on changes under `infra/monitoring/**`
3. The workflow installs:
   - `kube-prometheus-stack`
   - `Loki`
   - `Promtail`

After the monitoring stack is installed, the app deployment workflow automatically applies `k8s/servicemonitor.yaml` if the `ServiceMonitor` CRD exists.

## Monitoring Deployment

```bash
# Get AKS credentials
az aks get-credentials \
  --resource-group visitor-counter-rg \
  --name visitor-counter-aks

# Install the monitoring stack from GitHub Actions first

# Confirm the ServiceMonitor CRD exists
kubectl get crd servicemonitors.monitoring.coreos.com

# Check deployment status
kubectl rollout status deployment/visitor-counter

# Check that Prometheus can discover the app metrics
kubectl get servicemonitor visitor-counter

# Access Grafana locally
kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80

# View logs
kubectl logs -l app=visitor-counter --tail=100 -f

# Check image version
kubectl get deployment visitor-counter -o jsonpath='{.spec.template.spec.containers[0].image}'
```

## Security Considerations

- ✅ AKS has `AcrPull` role for ACR access (RBAC)
- ✅ No hardcoded credentials in images
- ✅ Secrets stored in Azure Key Vault
- ✅ Container runs as non-root user
- ✅ Resource limits enforced

## Troubleshooting

**Issue**: Image pull fails
```bash
# Solution: Verify AKS RBAC to ACR
az role assignment list \
  --scope /subscriptions/{ID}/resourceGroups/visitor-counter-rg/providers/Microsoft.ContainerRegistry/registries/visitorcounteracr
```

**Issue**: latest tag not updating
```bash
# Solution: Use specific git commit hash in deployment.yaml
# GitHub Actions automatically updates this
```

**Issue**: Deployment stuck in ImagePullBackOff
```bash
# Check ACR connectivity from AKS node pool
kubectl run -it --image=mcr.microsoft.com/azure-cli:latest debug --restart=Never -- bash
```

## Environment Variables

The deployment uses `imagePullPolicy: Always` to ensure:
- Fresh image pull on every restart
- Correct version deployed
- No stale images in node cache
