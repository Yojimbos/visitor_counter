param(
    [Parameter(Mandatory = $true)]
    [string]$Namespace,

    [Parameter(Mandatory = $true)]
    [string]$HostName,

    [string]$DeploymentName = "visitor-counter",
    [string]$IngressName = "visitor-counter-ingress",
    [string]$ServiceName = "visitor-counter-service",
    [string]$TlsSecretName = "visitor-counter-tls",
    [string]$CronJobName = "visitor-counter-db-backup",
    [string]$ServiceMonitorName = "visitor-counter"
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$attempts = 12
$requestTimeoutSeconds = 15

function Get-RequestErrorMessage {
    param([System.Management.Automation.ErrorRecord]$ErrorRecord)

    if ($null -ne $ErrorRecord.Exception.InnerException) {
        return $ErrorRecord.Exception.InnerException.Message
    }

    return $ErrorRecord.Exception.Message
}

function Assert-CommandSucceeded {
    param(
        [scriptblock]$Script,
        [string]$Message
    )

    try {
        & $Script
    }
    catch {
        throw "$Message`n$($_.Exception.Message)"
    }
}

Assert-CommandSucceeded {
    kubectl get deployment $DeploymentName -n $Namespace | Out-Null
} "Deployment was not found."

Assert-CommandSucceeded {
    kubectl get service $ServiceName -n $Namespace | Out-Null
} "Service was not found."

Assert-CommandSucceeded {
    kubectl get ingress $IngressName -n $Namespace | Out-Null
} "Ingress was not found."

Assert-CommandSucceeded {
    kubectl get secret $TlsSecretName -n $Namespace | Out-Null
} "TLS secret was not found."

$metricsAvailable = $false
try {
    kubectl get servicemonitor $ServiceMonitorName -n $Namespace | Out-Null
    $metricsAvailable = $true
}
catch {
    Write-Host "ServiceMonitor not present, continuing because monitoring may not be installed yet."
}

$backupAvailable = $false
try {
    kubectl get cronjob $CronJobName -n $Namespace | Out-Null
    $backupAvailable = $true
}
catch {
    Write-Host "Backup CronJob not present, continuing because backup storage may not be configured yet."
}

$url = "https://$HostName"
$applicationReachable = $false

for ($i = 1; $i -le $attempts; $i++) {
    try {
        $response = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec $requestTimeoutSeconds
        if ($response.StatusCode -eq 200) {
            Write-Host "Application responded with HTTP 200."
            $applicationReachable = $true
            break
        }
    }
    catch {
        Write-Host "Attempt $i/$attempts to reach $url failed: $(Get-RequestErrorMessage $_)"
    }

    Start-Sleep -Seconds 5
}

if (-not $applicationReachable) {
    kubectl get ingress $IngressName -n $Namespace -o wide
    kubectl get service $ServiceName -n $Namespace -o wide
    kubectl get service ingress-nginx-controller -n ingress-nginx -o wide
    throw "Application did not return HTTP 200 after $attempts attempts."
}

try {
    $metricsUrl = "http://$ServiceName.$Namespace.svc.cluster.local/metrics"
    $metricsProbeName = "metrics-check-" + ([guid]::NewGuid().ToString("N").Substring(0, 8))

    kubectl delete pod $metricsProbeName -n $Namespace --ignore-not-found=true | Out-Null

    kubectl run $metricsProbeName `
        --restart=Never `
        --image=curlimages/curl:8.8.0 `
        -n $Namespace `
        -- `
        curl `
        --silent `
        --show-error `
        --fail `
        --max-time $requestTimeoutSeconds `
        $metricsUrl | Out-Null

    kubectl wait --for=condition=Ready "pod/$metricsProbeName" -n $Namespace --timeout=30s | Out-Null
    kubectl wait --for=jsonpath='{.status.phase}'=Succeeded "pod/$metricsProbeName" -n $Namespace --timeout=30s | Out-Null

    Write-Host "Metrics endpoint is reachable inside the cluster."
}
catch {
    kubectl logs $metricsProbeName -n $Namespace --tail=100 2>$null
    throw "Metrics endpoint validation failed.`n$($_.Exception.Message)"
}
finally {
    kubectl delete pod $metricsProbeName -n $Namespace --ignore-not-found=true | Out-Null
}

if ($metricsAvailable) {
    Write-Host "ServiceMonitor is present."
}

if ($backupAvailable) {
    Write-Host "Backup CronJob is present."
}
