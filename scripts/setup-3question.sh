#!/bin/bash
# Complete 3-Question Flow Setup Script
# This script sets up everything needed for the 3-question qualification feature

set -e

echo "╔════════════════════════════════════════════════════════════╗"
echo "║   Vorzimmerdrache - 3-Question Flow Setup                  ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
VPS_HOST="${VPS_HOST:-root@instance1.duckdns.org}"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo "📋 Setup Plan:"
echo "   1. Sync project files to VPS (rsync)"
echo "   2. Update .env.local on VPS"
echo "   3. Deploy workflows via API"
echo "   4. Provide Google Sheets setup instructions"
echo ""

read -p "Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Setup cancelled"
    exit 1
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 1/4: Syncing project files to VPS..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
"$PROJECT_DIR/scripts/sync-to-vps.sh"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 2/4: Updating VPS environment..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
"$PROJECT_DIR/scripts/update-vps-env.sh"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 3/4: Deploying workflows via API..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
"$PROJECT_DIR/scripts/deploy.sh"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 4/4: Manual setup checklist"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

cat << 'CHECKLIST'

⚠️  IMPORTANT MANUAL STEPS REQUIRED:

1. Google Sheets Schema Update:
   ─────────────────────────────────
   Open your Google Sheet and add these columns to Lead_DB:
   
   | conversation_state | plz | kwh_consumption | meter_photo_url | 
   | qualification_timestamp | last_state_change |
   
   Valid states for conversation_state:
   - SMS_Sent, awaiting_plz, awaiting_kwh, awaiting_foto
   - qualified_complete, expired

2. n8n UI - Build State Machine:
   ─────────────────────────────────
   a) Open: https://instance1.duckdns.org
   b) Import "SMS Opt-In" workflow if not active
   c) Add these nodes after "Validate Phone Format":
   
      [Google Sheets: Lookup State] 
         → Operation: Search
         → Filter: Phone = {{$json.phone}}
      
      [Switch: State Router]
         → Branch 0: conversation_state is empty/SMS_Sent
         → Branch 1: awaiting_plz → PLZ validation
         → Branch 2: awaiting_kwh → kWh validation
         → Branch 3: awaiting_foto → Photo validation
         → Branch 4: qualified_complete → Send WhatsApp
   
   d) Add validation code nodes:
   
      PLZ: /^\d{5}$/ test, range 01000-99999
      kWh: numeric > 0, remove separators
      Photo: NumMedia > 0
   
   e) Add SMS response nodes:
   
      "Danke! Für ein Angebot brauchen wir 3 Infos: 1. Ihre PLZ?"
      "Danke! Noch 2 Fragen: 2. Jahresstromverbrauch (kWh)?"
      "Danke! Letzte Frage: 3. Foto vom Zählerschrank"
      "Perfekt! Hier ist Ihr WhatsApp-Link: wa.me/..."

3. Activate Workflows:
   ─────────────────────────────────
   - SMS Opt-In: Must be ACTIVE
   - Timeout Handler: Must be ACTIVE (runs hourly)
   - Roof-Mode: Must be ACTIVE

4. Test the Flow:
   ─────────────────────────────────
   curl -X POST https://instance1.duckdns.org/webhook/sms-response \
     -d "From=+491711234567" \
     -d "Body=JA"

5. Restart n8n (if env changed):
   ─────────────────────────────────
   docker-compose restart n8n

CHECKLIST

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ AUTOMATED SETUP COMPLETE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Summary:"
echo "   🔄 Files synced to VPS"
echo "   ⚙️  Environment updated"
echo "   🚀 Workflows deployed"
echo "   📋 Manual steps provided above"
echo ""
echo "Next: Complete the 3 manual steps above"
echo ""
