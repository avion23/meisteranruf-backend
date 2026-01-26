#!/bin/bash

# n8n Workflow Import Helper
# This script helps import workflows into n8n via API
# Requires: n8n API credentials

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

N8N_BASE_URL="${N8N_BASE_URL:-https://instance1.duckdns.org}"
N8N_API_URL="${N8N_BASE_URL}/api/v1"

if [ -z "$N8N_API_KEY" ]; then
    echo "ERROR: N8N_API_KEY not set"
    echo ""
    echo "Get your API key from:"
    echo "  1. Login to n8n at $N8N_BASE_URL"
    echo "  2. Go to Settings → API"
    echo "  3. Click 'Create API Key'"
    echo "  4. Copy the key and run: export N8N_API_KEY=<your-key>"
    exit 1
fi

echo "Connecting to n8n at: $N8N_BASE_URL"
echo ""

# Import roof-mode workflow
echo "Importing roof-mode workflow..."
WORKFLOW_RESPONSE=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -H "X-N8N-API-KEY: $N8N_API_KEY" \
    -d @workflows/roof-mode.json \
    "$N8N_API_URL/workflows")

WORKFLOW_ID=$(echo "$WORKFLOW_RESPONSE" | grep -o '"id":"[^"]*' | cut -d'"' -f4)

if [ -n "$WORKFLOW_ID" ]; then
    echo "✅ roof-mode workflow imported successfully"
    echo "   Workflow ID: $WORKFLOW_ID"
else
    echo "❌ Failed to import roof-mode workflow"
    echo "   Response: $WORKFLOW_RESPONSE"
    exit 1
fi

echo ""

# Import sms-opt-in workflow
echo "Importing sms-opt-in workflow..."
WORKFLOW_RESPONSE=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -H "X-N8N-API-KEY: $N8N_API_KEY" \
    -d @workflows/sms-opt-in.json \
    "$N8N_API_URL/workflows")

WORKFLOW_ID=$(echo "$WORKFLOW_RESPONSE" | grep -o '"id":"[^"]*' | cut -d'"' -f4)

if [ -n "$WORKFLOW_ID" ]; then
    echo "✅ sms-opt-in workflow imported successfully"
    echo "   Workflow ID: $WORKFLOW_ID"
else
    echo "❌ Failed to import sms-opt-in workflow"
    echo "   Response: $WORKFLOW_RESPONSE"
    exit 1
fi

echo ""
echo "========================================="
echo "Workflows imported successfully!"
echo "========================================="
echo ""
echo "Next steps:"
echo "  1. Go to $N8N_BASE_URL"
echo "  2. Check that both workflows appear in the list"
echo "  3. Configure credentials in each workflow:"
echo "     - Google Sheets (OAuth2 or Service Account)"
echo "     - Twilio (account SID, auth token)"
echo "     - Telegram (bot token)"
echo "  4. Activate both workflows (toggle switch on)"
echo ""
echo "Webhook URLs to configure in Twilio:"
echo "  Voice:  ${N8N_BASE_URL}/webhook/incoming-call"
echo "  SMS:    ${N8N_BASE_URL}/webhook/sms-response"
echo ""