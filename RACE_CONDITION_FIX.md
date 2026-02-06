# Race Condition Protection Implementation

## Problem

Das Original-System nutzte Google Sheets als Echtzeit-State-Datenbank. Bei gleichzeitigen SMS:
1. SMS 1 liest State "empty"
2. SMS 2 liest State "empty" (bevor SMS 1 schreibt)
3. SMS 1 schreibt State "awaiting_plz"
4. SMS 2 überschreibt mit State "awaiting_plz"

Resultat: Verlorene Updates, inkonsistente Konversations-States.

## Lösung: Mehrschichtiger Schutz

### Layer 1: MessageSid Deduplizierung (sms-opt-in.json)

Jede SMS hat eine eindeutige Twilio `MessageSid`:
- Prüfe ob diese MessageSid bereits verarbeitet wurde
- Überspringe Duplikate sofort
- Speichere `last_message_sid` in Google Sheets

### Layer 2: Timestamp-basierte Race Detection

`processingTimestamp` trackt wann SMS empfangen wurde:
- Wenn letztes Update < 5 Sekunden her: Potenzielle Race Condition
- Flag für Workflow-Routing

### Layer 3: File-Based Locking (NEU)

**Warum?** Die Review-Kritik war berechtigt: Sheets-Latenz ist unzuverlässig.

**Implementierung:**
```javascript
// Code - Acquire Lock
const fs = require('fs');
const lockFile = `/tmp/n8n-locks/${phone.replace(/[^0-9]/g, '')}.lock`;

// Atomare Lock-Erzeugung mit fs.writeFileSync(..., { flag: 'wx' })
// Auto-Expiry nach 30 Sekunden (stale lock detection)
```

**Ablauf:**
1. Webhook empfangen → Signature-Check
2. Spam-Filter (Blacklist + Rate-Limit)
3. **Lock erwerben** → Falls belegt: "Bitte warten..."
4. State aus Sheets lesen
5. State Machine validieren
6. State in Sheets schreiben
7. Antwort senden
8. **Lock automatisch frei** (nach 30s oder Ende der Execution)

### Layer 4: Single-Threaded Execution (Hardware-Level)

```yaml
# docker-compose.yml
N8N_CONCURRENCY_PRODUCTION_LIMIT: "1"  # Nur eine Execution gleichzeitig
N8N_EXECUTIONS_PROCESS: "main"          # Keine Worker-Prozesse
```

**Effekt:** Selbst wenn File-Locking failt, kann nur ein Request gleichzeitig laufen.

## Google Sheets Schema

Erforderliche Spalten:

| Column Name | Purpose |
|-------------|---------|
| `phone` | Telefonnummer (E.164) |
| `conversation_state` | Aktueller State (awaiting_plz, awaiting_kwh, etc.) |
| `last_message_sid` | Letzte verarbeitete Twilio MessageSid |
| `last_processed_at` | ISO-Timestamp letzter Update |
| `OptIn_Timestamp` | DSGVO: Zeitpunkt des "JA" (Proof of Consent) |
| `plz` | Postleitzahl |
| `kwh` | Jahresverbrauch |
| `OptIn_Status` | subscribed / unsubscribed |

## Manuelle Schritte nach Deployment

1. **Spalten zu Google Sheets hinzufügen:**
   - `last_message_sid`
   - `last_processed_at`  
   - `OptIn_Timestamp`

2. **Workflow importieren:**
   - `sms-opt-in.json` in n8n importieren
   - Credentials konfigurieren
   - Workflow aktivieren

3. **Testen:**
   ```bash
   # Race Condition Test
   curl -X POST https://<DOMAIN>/webhook/sms-response \
     -d "From=+491711234567" \
     -d "Body=JA" \
     -d "MessageSid=TEST001" &
   
   curl -X POST https://<DOMAIN>/webhook/sms-response \
     -d "From=+491711234567" \
     -d "Body=JA" \
     -d "MessageSid=TEST001" &
   # Zweiter Request sollte sofort mit "wird bereits verarbeitet" antworten
   ```

## Alternative: Redis Locking

Für höhere Concurrency (>10 gleichzeitige Anrufe):
```javascript
// Redis RedLock Beispiel
const RedLock = require('redlock');
const lock = await redlock.acquire([`locks:${phone}`], 1000);
// ... processing ...
await lock.release();
```

**Aber:** Redis braucht +200MB RAM → Nicht für 1GB VPS geeignet.

## Fazit

Das aktuelle System (File Locking + MessageSid + Single-Threaded) ist für einen 1GB VPS mit moderatem Traffic (<50 Anrufe/Tag) ausreichend robust. Die Kritik aus der Review war berechtigt, aber die Lösung ist pragmatisch, nicht akademisch.

**Trade-off akzeptiert:** Sheets-Latenz vs. Einfachheit. File-Locking fängt die meisten Race Conditions ab, Single-Threaded-Execution den Rest.
