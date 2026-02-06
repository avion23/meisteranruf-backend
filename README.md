# MEISTERANRUF (Projekt: Vorzimmerdrache)

**Status:** EXECUTION PHASE (MVP)  
**Stack:** n8n (SQLite), Twilio API, Google Sheets, Telegram.

## Was es ist

Ein extrem leichtgewichtiger "Dach-Modus" Bot für Handwerker. Er verwandelt stressige Anrufe in qualifizierte WhatsApp-Leads, während der Meister auf dem Dach steht.

## Der Datenfluss (ASCII)

```text
KUNDE RUFT AN
      |
[Twilio Phone Number] <---- Webhook ----> [n8n auf 1GB VPS]
      |                                       |
      | (Parallel)                            | (Logik)
      v                                       v
1. SPRACHANSAGE                      1. PRÜFE BLACKLIST
   "Bin auf dem Dach!"               2. LOGGE ANRUF IN SHEETS
      |                              3. SENDE OPT-IN SMS
      v                                       |
KUNDE ANTWORTET AUF SMS ("JA") <--------------+
      |
      v
[n8n STATE MACHINE]
      |
      |-- Q1: PLZ? --------> [Sheets: awaiting_plz]
      |-- Q2: kWh? --------> [Sheets: awaiting_kwh]
      |-- Q3: Foto? -------> [Sheets: awaiting_foto]
      v
[QUALIFIZIERTER LEAD] ----> [WhatsApp Link an Kunde]
                      ----> [Telegram Alarm an Meister]
```

## Kern-Features (Minimal State)

- **Zero-Maintenance:** Kein Postgres, kein Redis. n8n nutzt SQLite.
- **Spam-Filter:** Blacklist + Rate-Limiting (max 10 SMS/Stunde) reduziert Kosten.
- **File-Based Locking:** Verhindert Race Conditions bei gleichzeitigen Anrufen.
- **DSGVO-Brücke:** SMS-zu-WhatsApp Opt-In Flow mit Zeitstempel (Proof of Consent).
- **Auto-Qualifizierung:** Sammelt Postleitzahl, Verbrauch und Zählerfotos vor dem Rückruf.
- **Speed-to-Lead:** Reaktion innerhalb von < 3 Sekunden.

## Setup & Deployment

### 1. VPS Vorbereitung

- 1GB RAM Ubuntu VPS (Hetzner CX11 ~€4/Monat)
- Docker & Docker Compose installiert
- Domain zeigt auf Server-IP

### 2. .env Konfiguration

Kopiere `.env.example` zu `.env` und fülle aus:

```bash
# Pflichtfelder
DOMAIN=deine-domain.de
TWILIO_ACCOUNT_SID=ACxxxxx
TWILIO_AUTH_TOKEN=xxxxx
TWILIO_PHONE_NUMBER=+49xxxx
TELEGRAM_BOT_TOKEN=xxxxx
TELEGRAM_CHAT_ID=xxxxx
GOOGLE_SHEETS_SPREADSHEET_ID=xxxxx

# Spam-Schutz
BLACKLISTED_NUMBERS=+491711234567,+49301234567
```

### 3. Start

```bash
cd backend
./scripts/setup.sh
```

### 4. Twilio Webhooks konfigurieren

- Voice Webhook: `https://<DOMAIN>/webhook/incoming-call`
- SMS Webhook: `https://<DOMAIN>/webhook/sms-response`

## Lokale Logik & Kompaktheit

Die gesamte Chat-Logik befindet sich im Workflow `sms-opt-in.json`:

- **Validation:** PLZ muss 5-stellig sein, kWh muss positive Zahl sein
- **Deduplizierung:** Twilio `MessageSid` verhindert doppelte Webhooks
- **File Locking:** `/tmp/n8n-locks/<phone>.lock` verhindert Race Conditions
- **Rate Limiting:** Max 10 SMS pro Stunde pro Nummer
- **Timeout:** Nach 24h ohne Antwort wird der State automatisch auf `expired` gesetzt

## Hardware-Optimierung (1GB VPS)

```yaml
# docker-compose.yml
N8N_CONCURRENCY_PRODUCTION_LIMIT: "1"    # Single execution
N8N_EXECUTIONS_PROCESS: "main"            # Kein Queue-Mode (spart RAM)
NODE_OPTIONS: "--max-old-space-size=768"  # Heap-Limit
```

**Warum diese Einstellungen?**
- Ohne `N8N_EXECUTIONS_PROCESS=main`: n8n startet Worker-Prozesse → RAM-Überlastung bei 3+ gleichzeitigen Anrufen
- Ohne Concurrency-Limit: Gleichzeitige Ausführungen konkurrieren um 1GB RAM

## Warum Google Sheets?

Sheets dient als UI für den Handwerker. Er braucht keine App, er braucht nur seine Tabelle. Das System bleibt für uns zustandslos, die Daten liegen beim Kunden.

**Trade-off:** Sheets hat Latenz (~200-500ms), aber mit File-Locking + MessageSid-Deduplizierung ist das System robust genug für MVP.

## DSGVO-Compliance

- **Opt-In Zeitstempel:** Jede "JA"-Antwort wird mit `OptIn_Timestamp` in Sheets gespeichert
- **STOP-Handler:** Automatische Abmeldung bei Keywords (stop, abmelden, ende)
- **Datenlöschung:** Kunde kann jederzeit "STOP" schreiben → sofortige Abmeldung

## Monitoring

- **Telegram Alerts:** Jeder Anruf und jede Qualifizierung wird per Telegram gemeldet
- **Test-Workflow:** `tester-state-machine.json` validiert alle State-Transitions
- **Logs:** `docker compose logs -f n8n`

## Kosten

- VPS (1GB): ~€4/Monat
- Twilio SMS: ~€0.05 pro Lead
- Twilio Voice: ~€0.01 pro Anruf
- **Gesamt:** ~€6-10/Monat bei moderater Nutzung

## Support

- n8n Community: https://community.n8n.io
- Twilio Support: https://support.twilio.com

---

**Es ist dreckig, aber es wird sich verkaufen, weil Handwerker keine Software-Architektur kaufen, sondern freie Abende.**
