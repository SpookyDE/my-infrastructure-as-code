#Requires -RunAsAdministrator

<#
.SYNOPSIS
    WSL kickstart script – installs a WSL distro and configures a user.
.PARAMETER Distro
    Name of the distro to install (default: Ubuntu)
.EXAMPLE
    .\wsl-kickstart.ps1
    .\wsl-kickstart.ps1 -Distro "Debian"
#>

[CmdletBinding()]
param(
    [string]$Distro = "Ubuntu"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ── Helper functions ───────────────────────────────────────────────────────────

function Write-Step {
    param([string]$Message)
    Write-Host "`n[*] $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "[+] $Message" -ForegroundColor Green
}

function Write-Fail {
    param([string]$Message)
    Write-Host "[!] $Message" -ForegroundColor Red
}

# ── Read credentials from environment variables ─────────────────────────────────

$Username = $env:WSL_USERNAME
$Password = $env:WSL_PASSWORD

if (-not $Username -or -not $Password) {
    Write-Fail "WSL_USERNAME or WSL_PASSWORD is not set."
    Write-Host "  Example: `$env:WSL_USERNAME = 'myuser'; `$env:WSL_PASSWORD = 'secret'"
    exit 1
}

# ── Install WSL ───────────────────────────────────────────────────────────

Write-Step "Installing WSL distro: $Distro"

try {
    wsl --install -d $Distro
} catch {
    Write-Fail "WSL installation failed: $_"
    exit 1
}

Write-Step "Waiting for WSL initialization (30 s)..."
Start-Sleep -Seconds 30

# ── Check if distro is running ─────────────────────────────────────────────────

Write-Step "Checking if distro is reachable..."
$wslCheck = wsl -d $Distro -- bash -c "echo ok" 2>&1
if ($wslCheck -ne "ok") {
    Write-Fail "Distro '$Distro' is not reachable. Please check manually."
    exit 1
}

# ── Create user ──────────────────────────────────────────────────────────

Write-Step "Creating user '$Username' in WSL..."

# Pass password as variable; never embed it directly in the bash command line
$linuxCmd = @'
set -euo pipefail

USERNAME="$1"
PASSWORD="$2"

if id "$USERNAME" &>/dev/null; then
    echo "User $USERNAME already exists - skipping useradd."
else
    useradd -m -s /bin/bash "$USERNAME"
fi

echo "$USERNAME:$PASSWORD" | chpasswd

usermod -aG sudo "$USERNAME"

SUDOERS_FILE="/etc/sudoers.d/$USERNAME"
echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > "$SUDOERS_FILE"
chmod 440 "$SUDOERS_FILE"

echo "ok"
'@

$result = wsl -d $Distro -- bash -c "$linuxCmd" -- "$Username" "$Password" 2>&1

if ($LASTEXITCODE -ne 0 -or $result -notcontains "ok") {
    Write-Fail "User creation failed:`n$result"
    exit 1
}

# ── Set default UID ───────────────────────────────────────────────────────

Write-Step "Setting default user to '$Username'..."

$uid = (wsl -d $Distro -- bash -c "id -u `"$Username`"").Trim()

if ($uid -notmatch '^\d+$') {
    Write-Fail "Could not retrieve UID: '$uid'"
    exit 1
}

$regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss"

$distroKey = Get-ChildItem $regPath | Where-Object {
    (Get-ItemProperty $_.PsPath -ErrorAction SilentlyContinue).DistributionName -eq $Distro
}

if (-not $distroKey) {
    Write-Fail "Registry key for '$Distro' not found."
    exit 1
}

Set-ItemProperty -Path $distroKey.PSPath -Name "DefaultUid" -Value ([int]$uid)

# ── Done ────────────────────────────────────────────────────────────────────

Write-Success "WSL setup completed!"
Write-Host "  Distro   : $Distro"
Write-Host "  User     : $Username"
Write-Host "  UID      : $uid"
Write-Host "`nStart with: wsl -d $Distro`n"