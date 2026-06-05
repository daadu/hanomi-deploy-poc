####
## Deploy script for worker service.
##
## Usage:
##   .\deploy.ps1 <release-id>
####

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

function Switch-ToRelease {
    param(
        [string]$RelId
    )

    $CurrentRelease = Join-Path $ServiceReleasesDir "current"
    $TargetRelease = Join-Path $ServiceReleasesDir $RelId

    if (!(Test-Path $TargetRelease)) {
        throw "Release does not exist: $TargetRelease"
    }

    if (Test-Path $CurrentRelease) {
        Remove-Item $CurrentRelease -Force -ErrorAction Stop
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

    for ($i = 0; $i -lt 5; $i++) {
        $svc = Get-Service $ServiceFullName

        if ($svc.Status -eq "Running") {
            return $true
        }

        Start-Sleep -Seconds 1
    }

    return $false
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

Write-Host "No specific pre-deploy steps for worker"

##################################################
# 3. Switch to new release
##################################################

Write-Host "Switching to new release..."
Switch-ToRelease $ReleaseId

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

Write-Host "No specific rollback steps for worker"

##################################################
# 6. Revert to previous release
##################################################

if ([string]::IsNullOrWhiteSpace($PreDeployId)) {
    Write-Error "No previous release to revert to"
    exit 1
}

Write-Host "Reverting to previous release: $PreDeployId"

Switch-ToRelease $PreDeployId

##################################################
# 7. Post rollback probe
##################################################

if (Probe) {
    Write-Host "==== Rollback successful ===="
    exit 0
}

Write-Error "==== CRITICAL: Rollback failed ===="
exit 1