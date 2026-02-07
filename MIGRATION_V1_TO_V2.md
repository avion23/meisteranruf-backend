# Migration: SMS Opt-In V1 → V2

## Übersicht

Die neue Version (V2) verwendet **SQLite für State-Management** statt Google Sheets, was die Performance drastisch verbessert und Race Conditions eliminiert.

## Hauptänderungen

### 1. State-Management

| V1 (Alt) | V2 (Neu) |
|----------|----------|
| State in Google Sheets | State in n8n SQLite (`$getWorkflowStaticData`) |
| 4-6 API Calls pro Conversation | 1 API Call pro Lead (nur final) |
| Race Conditions möglich | Single-threaded, keine Konflikte |
| Latenz: 500ms-2s | Latenz: <10ms |

### 2. SMS Flow (Abgekürzt)

**V1 (3 Fragen):**
```
Anruf → SMS "JA?" → PLZ → kWh → Foto → WhatsApp Link
```

**V2 (2 Fragen):**
```
Anruf → SMS "JA für WhatsApp?" → PLZ → WhatsApp Link
```

**Warum nur PLZ?**
- DSGVO Opt-In ist zwingend (erste SMS)
- PLZ reicht für geografische Qualifizierung
- Weniger Fragen = höhere Conversion
- Rest im WhatsApp-Chat

### 3. Google Sheets Schema (Vereinfacht)

**V1:** Sheets als State-Machine
- `conversation_state`, `last_message_sid`, `last_processed_at`
- Konstante Updates bei jeder Antwort

**V2:** Sheets nur für finale Leads
```
| Phone | PLZ | OptIn_Timestamp | Qualified_Timestamp | Source | Status |
```

Nur **ein Eintrag** pro qualifiziertem Lead.

## Migrationsschritte

### 1. Backup

```bash
# Alte Workflows exportieren
cd /Users/avion/Documents.nosync/projects/meisteranruf/backend
mkdir -p backups
cp workflows/sms-opt-in.json backups/sms-opt-in-v1-$(date +%Y%m%d).json
cp workflows/roof-mode.json backups/roof-mode-v1-$(date +%Y%m%d).json
```

### 2. Neue Workflows importieren

```bash
# In n8n UI oder via API
curl -X POST http://localhost:5678/api/v1/workflows \
  -H "X-N8N-API-KEY: $N8N_API_KEY" \
  -H "Content-Type: application/json" \
  -d @workflows/sms-opt-in-v2.json
```

### 3. Environment Variables prüfen

```bash
# .env.local muss enthalten:
TWILIO_PHONE_NUMBER=+491234567890
TWILIO_WHATSAPP_NUMBER=491234567890  # Ohne + für wa.me Links!
GOOGLE_SHEETS_SPREADSHEET_ID=...
GOOGLE_SHEETS_LEADS_RANGE=Leads!A:F
GOOGLE_SHEETS_DEBUG_RANGE=Debug_Log!A:F
TELEGRAM_BOT_API_URL=https://api.telegram.org/bot...
TELEGRAM_CHAT_ID=...
```

### 4. Google Sheets vorbereiten

**Tab 1: "Leads"** (Für Sales - Nur finale Leads)

| Spalte | Inhalt |
|--------|--------|
| A | Phone |
| B | PLZ |
| C | OptIn_Timestamp |
| D | Qualified_Timestamp |
| E | Source |
| F | Status |

**Tab 2: "Debug_Log"** (Für Debugging - Alle SMS-Interaktionen)

| Spalte | Inhalt | Beispiel |
|--------|--------|----------|
| A | Timestamp | 2026-01-25T10:00:00Z |
| B | Phone | +491234567890 |
| C | Direction | inbound / outbound |
| D | Message | "JA" / "Danke! Bitte PLZ..." |
| E | State | awaiting_plz / qualified |
| F | Action | opt_in_received / plz_received |

**Tab 3: "Call_Log"** (Für Roof-Mode - Alle Anrufe)

| Spalte | Inhalt |
|--------|--------|
| A | Timestamp |
| B | Phone |
| C | Status | missed / handled |
| D | SMS_Sent | true / false |

### 5. Twilio Webhook URL aktualisieren

```
Alt: https://your-domain.de/webhook/sms-response
Neu: https://your-domain.de/webhook/sms-response  (gleich!)
```

Die Webhook-URL bleibt gleich, nur der Workflow ändert sich.

### 6. Testing

```bash
# Test-SMS senden
curl -X POST https://api.twilio.com/2010-04-01/Accounts/$TWILIO_ACCOUNT_SID/Messages.json \
  --data-urlencode "From=$TWILIO_PHONE_NUMBER" \
  --data-urlencode "To=+491234567890" \
  --data-urlencode "Body=JA" \
  -u "$TWILIO_ACCOUNT_SID:$TWILIO_AUTH_TOKEN"
```

## State-Machine Details

### SQLite State Struktur

```javascript
// In n8n Code-Node via $getWorkflowStaticData('global')
{
  "conversations": {
    "+491234567890": {
      "state": "qualified",
      "createdAt": "2026-01-25T10:00:00Z",
      "optInAt": "2026-01-25T10:01:00Z",
      "optInMessage": "JA",
      "plz": "10115",
      "qualifiedAt": "2026-01-25T10:02:00Z",
      "lastMessageAt": "2026-01-25T10:02:00Z",
      "lastResponse": "10115"
    }
  },
  "rateLimiter": {
    "+491234567890": [1706174400000, 1706174460000]
  },
  "processedSids": {
    "SM1234567890": 1706174400000
  }
}
```

### States

| State | Bedeutung | Nächster Schritt |
|-------|-----------|------------------|
| `new` | Frisch angelegt | Warte auf "JA" |
| `sms_sent` | SMS gesendet | Warte auf "JA" |
| `awaiting_plz` | Opt-In erhalten | Warte auf PLZ |
| `qualified` | PLZ erhalten | WhatsApp Link gesendet |
| `opted_out` | Abgemeldet | Keine weiteren Nachrichten |

## Vorteile der neuen Architektur

### Performance
- **10x schneller**: SQLite vs. Sheets API
- **Keine Race Conditions**: Single-threaded execution
- **Weniger RAM**: Kompaktere Workflow-Struktur

### Kosten
- **Weniger Twilio SMS**: 2 statt 4-5 pro Lead
- **Keine Sheets API Limits**: Nur 1 Call pro Lead

### Zuverlässigkeit
- **Keine API-Timeouts**: Alles lokal in n8n
- **DSGVO-konform**: Opt-In bleibt explizit
- **Einfacheres Debugging**: State ist lokal sichtbar

## Rollback (falls nötig)

```bash
# Alte Workflows wiederherstellen
cp backups/sms-opt-in-v1-YYYYMMDD.json workflows/sms-opt-in.json

# In n8n UI: Alten Workflow reaktivieren
```

## Monitoring

### Logs prüfen
```bash
# n8n Logs
docker logs vorzimmerdrache-n8n-1 | grep -E "(sms-opt-in|lead|error)"

# State-Größe überwachen (wachst mit Konversationen)
docker exec vorzimmerdrache-n8n-1 sqlite3 /home/node/.n8n/database.sqlite \
  "SELECT COUNT(*) FROM workflow_statistics;"
```

### Telegram Alerts
- ✅ Neuer Lead: `🎯 NEUER LEAD! 📱 +49123... 📍 PLZ: 10115`
- ⚠️ Opt-Out: `🚫 Opt-out: +49123...`
- ❌ Fehler: `❌ Workflow Error: ...`

## FAQ

**Q: Was passiert mit alten Konversationen in Sheets?**
A: Bleiben erhalten. V2 startet mit leerem SQLite-State. Alte Einträge werden nicht migriert (nicht nötig, da nur finale Leads wichtig sind).

**Q: Wie lange bleibt State in SQLite erhalten?**
A: Solange n8n läuft. Bei Container-Restart bleibt SQLite persistent (Volume `n8n_data`).

**Q: Was ist der maximale State?**
A: SQLite kann Millionen von Einträgen handhaben. Für 1000 aktive Konversationen: ~1MB.

**Q: Kann ich State manuell löschen?**
A: Ja, via n8n UI → Executions → "Clear All Data" oder direkt in SQLite:
```sql
DELETE FROM workflow_static_data WHERE workflowId = '...';
```

## Support

Bei Problemen:
1. Logs prüfen: `docker logs vorzimmerdrache-n8n-1`
2. State prüfen: Workflow → Executions → Static Data
3. Telegram Alerts beobachten
4. Rollback auf V1 falls kritisch
