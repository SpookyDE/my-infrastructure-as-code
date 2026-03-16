#!/bin/bash
# Called by setup-wsl.ps1 as root.
# Expects environment variables: WSL_USER, WSL_PASS
set -euo pipefail

: "${WSL_USER:?Environment variable WSL_USER is required}"
: "${WSL_PASS:?Environment variable WSL_PASS is required}"

echo "[1/4] Creating user '$WSL_USER' ..."
if id "$WSL_USER" &>/dev/null; then
    echo "      User already exists, skipping."
else
    useradd -m -s /bin/bash "$WSL_USER"
fi

echo "[2/4] Setting password ..."
printf "%s:%s\n" "$WSL_USER" "$WSL_PASS" | chpasswd

echo "[3/4] Setting up sudo rights ..."
usermod -aG sudo "$WSL_USER"
echo "$WSL_USER ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/"$WSL_USER"
chmod 0440 /etc/sudoers.d/"$WSL_USER"

echo "[4/4] Writing configuration (/etc/wsl.conf) ..."
cat > /etc/wsl.conf << WSLCONF
[user]
default=$WSL_USER

[boot]
systemd=true
WSLCONF

echo "Done."