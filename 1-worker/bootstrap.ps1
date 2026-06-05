<#
Bootstrap VM for worker service

- Must be executed by the service account user (hanomi)
- Assumes:
  - Python already installed
  - NSSM already installed and available in PATH
  - OpenSSH access already configured
  - User already has Administrator privileges
#>

$ErrorActionPreference = "Stop"

# configuration
$SERVICE_USER      = "hanomi"
$SERVICE_NAME      = "worker"
$SERVICE_FULL_NAME = "hanomi-worker"

$SERVICE_DIR = Join-Path $HOME "hanomi\$SERVICE_NAME"

# validate
$currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name.Split('\')[-1]

if ($currentUser -ne $SERVICE_USER) {
    Write-Error "This script must be run as '$SERVICE_USER'"
    exit 1
}

# validate admin privileges
$principal = New-Object Security.Principal.WindowsPrincipal(
    [Security.Principal.WindowsIdentity]::GetCurrent()
)

if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "This script must be run from an elevated PowerShell session"
    exit 1
}

Write-Host "Configuring worker service..."

# verify required tools
if (-not (Get-Command nssm -ErrorAction SilentlyContinue)) {
    throw "NSSM is not installed or not available in PATH"
}

# tmp dir (to put thing while scp-ing later)
New-Item -ItemType Directory -Force -Path "C:\tmp" | Out-Null

# service setup
Write-Host "Setting up service directory..."

New-Item -ItemType Directory -Force -Path $SERVICE_DIR | Out-Null
New-Item -ItemType Directory -Force -Path "$SERVICE_DIR\releases" | Out-Null
New-Item -ItemType Directory -Force -Path "$SERVICE_DIR\config" | Out-Null
New-Item -ItemType Directory -Force -Path "$SERVICE_DIR\scripts" | Out-Null

if (-not (Test-Path "$SERVICE_DIR\config\.env")) {
    New-Item -ItemType File -Path "$SERVICE_DIR\config\.env" | Out-Null
}

# configure NSSM service
Write-Host "Configuring NSSM service..."

$nssmServiceExists = $null -ne (
    Get-Service -Name $SERVICE_FULL_NAME -ErrorAction SilentlyContinue
)

if (-not $nssmServiceExists) {
    nssm install `
        $SERVICE_FULL_NAME `
        "python" `
        "worker.py"
}
nssm set $SERVICE_FULL_NAME AppEnvironmentExtra `
    "SERVICE_DIR=$SERVICE_DIR" `
    "SERVICE_DOTENV_FILES=$SERVICE_DIR\config\.env"
nssm set $SERVICE_FULL_NAME AppDirectory "$SERVICE_DIR\releases\current"
nssm set $SERVICE_FULL_NAME Start SERVICE_AUTO_START

# restart service if it crashes
nssm set $SERVICE_FULL_NAME AppThrottle 5000
nssm set $SERVICE_FULL_NAME AppExit Default Restart

# not started yet; first deployment will do that
Set-Service -Name $SERVICE_FULL_NAME -StartupType Automatic

Write-Host ""
Write-Host "===== Bootstraping completed successfully ====="