#!/usr/bin/env bash
# ==============================================================================
# Script: deploy-debian.sh
# Purpose: Quick installer and config deployer for BIND 9 on Debian VMs
# Usage: sudo ./deploy-debian.sh [root|tld|authoritative|geodns|resolver]
# ==============================================================================

set -e

ROLE="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"

if [[ -z "$ROLE" ]]; then
    echo "Usage: sudo $0 [root | tld | authoritative | geodns | resolver]"
    exit 1
fi

if [[ $EUID -ne 0 ]]; then
   echo "Error: This script must be run as root (use sudo)." 
   exit 1
fi

echo "=========================================================="
echo " Deploying BIND 9 role: $ROLE on Debian"
echo "=========================================================="

echo "[1/4] Installing BIND 9 packages..."
apt-get update -y
apt-get install -y bind9 bind9utils dnsutils

echo "[2/4] Backing up existing /etc/bind configuration..."
mkdir -p /etc/bind/backup_$(date +%s)
cp -r /etc/bind/* /etc/bind/backup_$(date +%s)/ 2>/dev/null || true

echo "[3/4] Copying role configuration files..."
ROLE_DIR="$BASE_DIR/bind9/$ROLE"

if [[ ! -d "$ROLE_DIR" ]]; then
    echo "Error: Role configuration directory '$ROLE_DIR' does not exist."
    exit 1
fi

cp "$ROLE_DIR"/named.conf.* /etc/bind/ 2>/dev/null || true
cp "$ROLE_DIR"/db.* /etc/bind/ 2>/dev/null || true
cp "$ROLE_DIR"/root.hints /etc/bind/ 2>/dev/null || true

chown -R bind:bind /etc/bind/
chmod -R 644 /etc/bind/*
chmod 755 /etc/bind

echo "[4/4] Validating BIND configuration..."
named-checkconf /etc/bind/named.conf

echo "Restarting BIND 9 service..."
systemctl restart named || systemctl restart bind9
systemctl status named --no-pager || systemctl status bind9 --no-pager

echo "=========================================================="
echo " Successfully deployed role '$ROLE' on this Debian VM!"
echo "=========================================================="
