#!/bin/bash

# Activate workflows directly in n8n database
# This bypasses the Web UI activation requirement

set -e

DB_PATH="/var/lib/docker/volumes/vorzimmerdrache_n8n_data/_data/database.sqlite"

if [ ! -f "$DB_PATH" ]; then
    echo "ERROR: n8n database not found at $DB_PATH"
    exit 1
fi

echo "Activating workflows in n8n database..."
echo "Database: $DB_PATH"
echo ""

# Backup database first
cp "$DB_PATH" "$DB_PATH.backup.$(date +%s)"

echo "✅ Database backed up to $DB_PATH.backup.$(date +%s)"

# Activate both workflows using Node.js (sqlite3 not available in container)
docker exec vorzimmerdrache-n8n-1 node -e "const sqlite = require('sqlite3'); const db = new sqlite.Database('$DB_PATH'); const stmt = db.prepare('UPDATE workflow_entity SET active = 1, updated_at = datetime(\"now\") WHERE name IN (\"Roof-Mode\", \"SMS Opt-In\")'); stmt.run(); stmt.finalize(); console.log('Workflows activated');"

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Workflows activated successfully!"
    echo ""
    echo "Activated workflows:"
    echo "  - Roof-Mode"
    echo "  - SMS Opt-In"
    echo ""
    echo "Next steps:"
    echo "  1. Access n8n at http://instance1.duckdns.org:5678"
    echo "  2. Verify workflows are active (should show green toggle)"
    echo "  3. Configure Twilio webhooks:"
    echo "     Voice:  https://instance1.duckdns.org/webhook/incoming-call"
    echo "     SMS:    https://instance1.duckdns.org/webhook/sms-response"
    echo ""
    echo "Test webhooks:"
    echo "  curl -X POST http://instance1.duckdns.org:5678/webhook/incoming-call \\"
    echo "    -d '{\"From\": \"+491511234567\", \"CallStatus\": \"ringing\"}'"
else
    echo "❌ Failed to activate workflows"
    echo "Restoring backup..."
    cp "$DB_PATH.backup.$(date +%s)" "$DB_PATH"
    exit 1
fi