####
## Deploy script for <my-service>.
##
## Usage:
##   .\deploy.ps1 <release-id>
####

# TODO: Remove after copying template
Write-Host "This is a template file. Please copy it to deploy.ps1 and modify it for your service."
Write-Host "cp deploy.template.ps1 <my-service-dir>\deploy.ps1"
exit 1

$ErrorActionPreference = "Stop"

# config
$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$ServiceDir = Resolve-Path (Join-Path $ScriptPath "..")
$ServiceDir = $ServiceDir.Path

$ServiceReleasesDir = Join-Path $ServiceDir "releases"
$ServiceName = Split-Path $ServiceDir -Leaf
$ServiceFullName = "hanomi-$ServiceName"

# arg parse
$ReleaseId = $args[0]

if ([string]::IsNullOrWhiteSpace($ReleaseId)) {
    Write-Error "Release ID is required"
    exit 1
}

##################################################
# Helper functions
##################################################

function Switch-And-Release {
    param(
        [string]$RelId
    )

    $CurrentRelease = Join-Path $ServiceReleasesDir "current"
    $TargetRelease = Join-Path $ServiceReleasesDir $RelId

    if (!(Test-Path $TargetRelease)) {
        throw "Release does not exist: $TargetRelease"
    }

    if (Test-Path $CurrentRelease) {
        Remove-Item $CurrentRelease -Force
    }

    New-Item `
        -ItemType Junction `
        -Path $CurrentRelease `
        -Target $TargetRelease | Out-Null

    Write-Host "Switched to release: $RelId"

    Write-Host "Restarting service..."
    nssm restart $ServiceFullName
    Start-Sleep -Seconds 1
}

function Probe {
    Write-Host "Probing service..."

    $svc = Get-Service $ServiceFullName

    if ($svc.Status -ne "Running") {
        return $false
    }

    # Optional HTTP check:
    # try {
    #     Invoke-WebRequest `
    #         -Uri "http://localhost:8000/health" `
    #         -UseBasicParsing `
    #         -TimeoutSec 5 | Out-Null
    # }
    # catch {
    #     return $false
    # }

    return $true
}

#############################
# 1. Read current release id
#############################

$CurrentRelease = Join-Path $ServiceReleasesDir "current"

if (Test-Path $CurrentRelease) {
    $PreDeployDir = (Resolve-Path $CurrentRelease).Path
    $PreDeployId = Split-Path $PreDeployDir -Leaf
}
else {
    $PreDeployDir = "Not found"
    $PreDeployId = ""
}

Write-Host "Pre-deploy release id: $PreDeployId [$PreDeployDir]"

#############################
# 2. Pre-deploy steps
#############################

Write-Host "TODO: Add service-specific pre-deploy steps"
exit 1

##################################################
# 3. Switch to new release
##################################################

Write-Host "Switching to new release..."
Switch-And-Release $ReleaseId

##################################################
# 4. Probe
##################################################

if (Probe) {
    Write-Host "==== Deployment successful ===="
    exit 0
}

##########################################
# 5. Additional rollback steps
##########################################

Write-Host "TODO: Add rollback steps"
exit 1

##################################################
# 6. Revert to previous release
##################################################

if ([string]::IsNullOrWhiteSpace($PreDeployId)) {
    Write-Error "No previous release to revert to"
    exit 1
}

Write-Host "Reverting to previous release: $PreDeployId"

Switch-And-Release $PreDeployId

##################################################
# 7. Post rollback probe
##################################################

if (Probe) {
    Write-Host "==== Rollback successful ===="
    exit 0
}

Write-Error "==== CRITICAL: Rollback failed ===="
exit 1