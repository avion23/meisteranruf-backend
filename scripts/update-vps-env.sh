#!/bin/bash
# Update VPS .env.local with 3-question flow configuration
# Usage: ./update-vps-env.sh

set -e

VPS_HOST="${VPS_HOST:-deploy@instance1.duckdns.org}"
VPS_DIR="/opt/vorzimmerdrache"

echo "🔄 Updating VPS environment configuration..."
echo "   Host: $VPS_HOST"

# SSH to VPS and update .env
ssh "$VPS_HOST" << 'REMOTE_SCRIPT'
    ENV_FILE="/opt/vorzimmerdrache/.env.local"
    
    # Backup existing env
    if [ -f "$ENV_FILE" ]; then
        cp "$ENV_FILE" "${ENV_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
        echo "✅ Backup created"
    fi
    
    # 3-Question flow is mandatory (DSGVO compliant) - always enabled, no feature flag needed
    
    # Add Google Sheets Document ID if missing (using SPREADSHEET_ID)
    if ! grep -q "GOOGLE_SHEETS_DOCUMENT_ID" "$ENV_FILE"; then
        # Extract SPREADSHEET_ID value
        SHEET_ID=$(grep "GOOGLE_SHEETS_SPREADSHEET_ID" "$ENV_FILE" | cut -d'=' -f2 || echo "")
        if [ -n "$SHEET_ID" ]; then
            echo "" >> "$ENV_FILE"
            echo "# For timeout-handler workflow" >> "$ENV_FILE"
            echo "GOOGLE_SHEETS_DOCUMENT_ID=$SHEET_ID" >> "$ENV_FILE"
            echo "✅ Added GOOGLE_SHEETS_DOCUMENT_ID=$SHEET_ID"
        else
            echo "⚠️  Warning: GOOGLE_SHEETS_SPREADSHEET_ID not found, can't set DOCUMENT_ID"
        fi
    fi
    
    # Add QUALIFICATION_TIMEOUT if missing
    if ! grep -q "QUALIFICATION_TIMEOUT_HOURS" "$ENV_FILE"; then
        echo "" >> "$ENV_FILE"
        echo "# 3-Question Flow Settings" >> "$ENV_FILE"
        echo "QUALIFICATION_TIMEOUT_HOURS=24" >> "$ENV_FILE"
        echo "✅ Added QUALIFICATION_TIMEOUT_HOURS=24"
    fi
    
    echo ""
    echo "📝 Current 3-Question related env vars:"
    grep -E "(ENABLE_3_QUESTION|GOOGLE_SHEETS|QUALIFICATION)" "$ENV_FILE" || echo "   None found"
    
    echo ""
    echo "⚠️  Remember to restart n8n to apply changes:"
    echo "   docker-compose restart n8n"
REMOTE_SCRIPT

echo ""
echo "✅ VPS environment updated!"
