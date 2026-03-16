# Variablen
$Distro = "Ubuntu"
$Username = $env:WSL_USERNAME
$Password = $env:WSL_PASSWORD

Write-Host "Installing WSL..."
wsl --install -d $Distro

Write-Host "Waiting for WSL initialization..."
Start-Sleep -Seconds 20

Write-Host "Creating user inside WSL..."

$linuxCmd = @"
useradd -m -s /bin/bash $Username
echo '$Username:$Password' | chpasswd
usermod -aG sudo $Username

echo '$Username ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/$Username
chmod 440 /etc/sudoers.d/$Username
"@

wsl -d $Distro -- bash -c "$linuxCmd"

Write-Host "Setting default user..."

# UID des Users holen
$uid = wsl -d $Distro -- bash -c "id -u $Username"
$uid = $uid.Trim()

$regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss"
$guid = (Get-ChildItem $regPath | Where-Object {
    (Get-ItemProperty $_.PsPath).DistributionName -eq $Distro
}).PSChildName

Set-ItemProperty "$regPath\$guid" DefaultUid $uid

Write-Host "WSL setup complete."
Write-Host "User: $Username"