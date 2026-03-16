#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Create ready-to-use WSL installation.

.PARAMETER Distro
    Installed distribution (Alias: -d).
    Standard: Ubuntu-24.04
    Show available: wsl --list --online

.EXAMPLE
    .\setup-wsl.ps1 -d Ubuntu-24.04

.EXAMPLE
    $env:WSL_USER = "max"
    $env:WSL_PASS = "geheim"
    .\setup-wsl.ps1 -d Debian
#>
param(
    [Alias("d")]
    [string]$Distro = "Ubuntu-24.04"
)

$ErrorActionPreference = "Stop"

# --- Credentials from env vars or interactive prompt ---
$WslUser = if ($env:WSL_USER) { $env:WSL_USER } else { Read-Host "WSL username" }
$WslPass = if ($env:WSL_PASS) { $env:WSL_PASS } else { Read-Host "WSL password" }

if ($WslUser -notmatch '^[a-z_][a-z0-9_-]{0,31}$') {
    throw "Invalid username '$WslUser' (lowercase letters, digits, _ and - only)"
}
if ($WslPass.Length -lt 6) {
    throw "Password too short (at least 6 characters)"
}

# --- Enable WSL feature (one-time, may require reboot) ---
$feature = Get-WindowsOptionalFeature -Online -FeatureName "Microsoft-Windows-Subsystem-Linux"
if ($feature.State -ne "Enabled") {
    Write-Host "Enabling WSL feature (reboot may be required) ..."
    Enable-WindowsOptionalFeature -Online -FeatureName "Microsoft-Windows-Subsystem-Linux" -NoRestart
    Enable-WindowsOptionalFeature -Online -FeatureName "VirtualMachinePlatform"            -NoRestart
    Write-Warning "Please reboot and run this script again after reboot."
    exit 0
}

# --- WSL2 + Kernel updated ---
wsl --set-default-version 2 | Out-Null
wsl --update              | Out-Null

# --- Install distribution if not already installed ---
$installed = wsl --list --quiet 2>$null
if ($installed -notcontains $Distro) {
    Write-Host "Installing $Distro ..."
    wsl --install -d $Distro --no-launch
}

# --- Pass setup script to WSL ---
# Credentials via env vars, never as args (would be visible in ps aux)
Write-Host "Configuring user '$WslUser' ..."
$bashScript = Join-Path $PSScriptRoot "standard_setup.sh"
$wslPath    = wsl -d $Distro -- wslpath -u ($bashScript -replace "\\", "/")

wsl -d $Distro -u root -- env WSL_USER="$WslUser" WSL_PASS="$WslPass" bash "$wslPath"

if ($LASTEXITCODE -ne 0) { throw "Bash setup failed (Exit-Code $LASTEXITCODE)" }

# --- Restart WSL so wsl.conf (default user) takes effect ---
wsl --shutdown
Start-Sleep -Seconds 2

Write-Host ""
Write-Host "Done! Start WSL with:  wsl -d $Distro" -ForegroundColor Green
wsl -d $Distro