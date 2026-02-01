#!/bin/bash
# Sync project files to VPS via rsync (excludes workflows - those use API)
# Usage: ./sync-to-vps.sh

set -e

VPS_HOST="${VPS_HOST:-root@instance1.duckdns.org}"
VPS_DIR="/opt/vorzimmerdrache"
LOCAL_DIR="$(dirname "$0")/.."

echo "🔄 Syncing project files to VPS..."
echo "   Host: $VPS_HOST"
echo "   Target: $VPS_DIR"

# Create target directory if not exists
ssh "$VPS_HOST" "mkdir -p $VPS_DIR/{scripts,docs,workflows}"

# Rsync with delete (except workflows - managed via API)
rsync -avz --delete \
    --exclude='.git' \
    --exclude='.env' \
    --exclude='node_modules' \
    --exclude='*.log' \
    "$LOCAL_DIR/scripts/" "$VPS_HOST:$VPS_DIR/scripts/"

rsync -avz --delete \
    "$LOCAL_DIR/docs/" "$VPS_HOST:$VPS_DIR/docs/"

# Copy workflows as backup (but don't delete - API is source of truth)
rsync -avz \
    "$LOCAL_DIR/workflows/" "$VPS_HOST:$VPS_DIR/workflows-backup/"

echo "✅ Sync complete!"
echo ""
echo "Next steps:"
echo "1. Deploy workflows via API: ./deploy.sh"
echo "2. Or import manually in n8n UI"
