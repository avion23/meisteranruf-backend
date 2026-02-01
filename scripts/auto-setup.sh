#!/bin/bash
# Auto-execute complete setup without user interaction
set -e

VPS_HOST="${VPS_HOST:-root@instance1.duckdns.org}"
PROJECT_DIR="/Users/avion/Documents.nosync/projects/vorzimmerdrache"

echo "🚀 Auto-Executing 3-Question Flow Setup"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 1. Deploy workflows
echo "📤 Deploying workflows..."
cd "$PROJECT_DIR"
./scripts/deploy.sh

# 2. Sync files
echo "🔄 Syncing to VPS..."
./scripts/sync-to-vps.sh

# 3. Update VPS environment
echo "⚙️  Updating VPS environment..."
ssh "$VPS_HOST" << 'REMOTE'
    ENV_FILE="/opt/vorzimmerdrache/.env.local"
    
    # 3-Question flow is mandatory - no feature flag needed
    
    # Get SPREADSHEET_ID and add DOCUMENT_ID if missing
    if ! grep -q "GOOGLE_SHEETS_DOCUMENT_ID" "$ENV_FILE"; then
        SHEET_ID=$(grep "GOOGLE_SHEETS_SPREADSHEET_ID" "$ENV_FILE" | cut -d'=' -f2 || echo "")
        if [ -n "$SHEET_ID" ]; then
            echo "GOOGLE_SHEETS_DOCUMENT_ID=$SHEET_ID" >> "$ENV_FILE"
        fi
    fi
    
    echo "✅ Environment updated"
    echo ""
    echo "🔧 Restart n8n to apply changes:"
    echo "   docker-compose restart n8n"
REMOTE

echo ""
echo "✅ Auto-Setup Complete!"
echo ""
echo "⚠️  MANUAL STEP REQUIRED:"
echo "   Add Google Sheets columns: conversation_state | plz | kwh_consumption | meter_photo_url"
echo ""
