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
$attempts = 30

for ($i = 1; $i -le $attempts; $i++) {
    try {
        $response = Invoke-WebRequest -Uri $url -UseBasicParsing
        if ($response.StatusCode -eq 200) {
            Write-Host "Application responded with HTTP 200."
            break
        }
    }
    catch {
        if ($i -eq $attempts) {
            throw "Application did not return HTTP 200 after $attempts attempts."
        }
    }

    Start-Sleep -Seconds 10
}

try {
    $metricsResponse = Invoke-WebRequest -Uri "$url/metrics" -UseBasicParsing
    if ($metricsResponse.StatusCode -ne 200) {
        throw "Metrics endpoint returned status $($metricsResponse.StatusCode)."
    }
    Write-Host "Metrics endpoint is reachable."
}
catch {
    throw "Metrics endpoint validation failed.`n$($_.Exception.Message)"
}

if ($metricsAvailable) {
    Write-Host "ServiceMonitor is present."
}

if ($backupAvailable) {
    Write-Host "Backup CronJob is present."
}