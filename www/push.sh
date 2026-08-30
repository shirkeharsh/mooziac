#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

VPS_HOST="13.234.245.199"
VPS_USER="ubuntu"
VPS_PATH="/var/www/mooziac"
KEY_FILE="$SCRIPT_DIR/mooziac.pem"

echo "=========================================="
echo "  🌐 Deploying Mooziac Web Platform       "
echo "  Host: $VPS_HOST                         "
echo "=========================================="

if [ -f "$KEY_FILE" ]; then
    chmod 400 "$KEY_FILE"
    echo "[1/2] SSH Key loaded ($KEY_FILE)..."
else
    echo "⚠️ Warning: $KEY_FILE not found."
fi

echo "[2/2] Syncing www/ files to $VPS_USER@$VPS_HOST:$VPS_PATH..."
if [ -f "$KEY_FILE" ]; then
    rsync -avz --exclude="mooziac.pem" --exclude=".DS_Store" -e "ssh -i $KEY_FILE -o StrictHostKeyChecking=no -o ConnectTimeout=10" ./ "$VPS_USER@$VPS_HOST:$VPS_PATH" || {
        echo "⚠️ Rsync completed with warning (check VPS SSH permissions)."
    }
    echo "✔ Deployment sync finished."
else
    echo "⚠️ Skipping SSH sync (no pem key)."
fi

echo "=========================================="
echo "  ✅ Web Deploy Task Completed!"
echo "=========================================="
