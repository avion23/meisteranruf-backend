# Vorzimmerdrache

## Was das ist

Ein 1GB VPS mit folgendem Setup:
- n8n mit SQLite (keine externe Datenbank)
- Twilio API für WhatsApp + Voice (Pay-per-Message)
- Google Sheets API als CRM (Verwaltung via Browser)
- Gesamter Container-RAM: ~512MB (384MB + 128MB)

KEIN PostgreSQL, KEIN Redis, KEIN WAHA, KEIN Baserow, KEINE Worker-Prozesse.

---

## Funktionsweise

1. Kunde ruft Twilio-Nummer an.
2. Webhook triggert n8n Workflow.
3. n8n antwortet sofort mit Sprachansage: "Moin! Wir sind auf dem Dach."
4. n8n prüft Telefonnummer in Google Sheets.
5. n8n sendet WhatsApp an Kunden (via Twilio API).
6. n8n sendet Telegram-Alert an dich.

Minimalistischer Ansatz. Kein Lead-Scoring, keine Förderrechner, keine Datenanreicherung.

---

## WhatsApp Opt-In Flow (UWG-Konform)

Für rechtssichere WhatsApp-Nutzung wird folgender Prozess genutzt:

### Option A: SMS als Brücke → WhatsApp erst nach "JA"

1. Anruf verpasst oder nach X Sekunden nicht angenommen.
2. System sendet sofort neutrale SMS:
   "Hi, wir haben Ihren Anruf verpasst. Möchten Sie Updates per WhatsApp? Antworten Sie mit JA."
3. Kunde antwortet mit "JA" → Opt-In dokumentiert → Ab dann WhatsApp-Kommunikation (Termine, Rückrufe).

**Vorteile:**
- Konform mit WhatsApp Opt-In Richtlinien.
- Minimiert UWG-Risiko (Gesetz gegen den unlauteren Wettbewerb).
- Erst Erlaubnis, dann Nachricht.

### SMS Opt-In Setup

1. Twilio SMS Webhook konfigurieren: `https://<DEINE-DOMAIN>/webhook/sms-response`
2. Google Sheets Spalte "whatsapp_opt_in" zur Dokumentation hinzufügen.
3. `workflows/sms-opt-in.json` in n8n importieren.
4. Twilio leitet SMS-Antworten an den Webhook weiter.

---

## Tech Stack

- **n8n**: v1.50.0 (stabil, optimiert für 1GB RAM)
- **Traefik**: v2.11 (SSL-Terminierung, HTTP→HTTPS Redirect)
- **Datenbank**: SQLite (n8n-intern, WAL-Modus aktiviert)
- **WhatsApp**: Twilio Business API (stateless, läuft auf Twilio-Servern)
- **Voice**: Twilio (stateless, läuft auf Twilio-Servern)
- **CRM**: Google Sheets (Verwaltung im Browser)
- **Benachrichtigungen**: Telegram Bot API

Details zu Systemdesign und Datenflüssen in [ARCHITECTURE.md](ARCHITECTURE.md).

---

## Warum 1GB ausreicht

- n8n (200MB) + Traefik (50MB) + OS-Overhead = ~300MB Gesamtauslastung.
- Keine schweren Dienste (Postgres benötigt min. 150MB).
- WhatsApp-Infrastruktur liegt bei Twilio, nicht auf dem eigenen Server.
- Google Sheets verbraucht 0MB (reine API-Calls).

---

## Kosten

- VPS: €4.15/Monat (Hetzner CX11, 1GB)
- Twilio: €0.005/Nachricht × 100 Msgs = €0.50/Monat (nur WhatsApp)
- Voice: €0.05/Min × 30 Min Anrufe = €1.50/Monat (Dach-Modus)
- Google Sheets: €0 (Free Tier, 28.000 Requests/Monat)

**GESAMT: ~€6.15/Monat**

---

## Bereitstellung

Detaillierte Anweisungen in [SERVER_SETUP.md](SERVER_SETUP.md).

Quick Start:
1. Twilio Account einrichten (WhatsApp + Voice).
2. Google Sheet erstellen.
3. `.env` Datei konfigurieren.
4. Ausführen: `./scripts/deploy-1gb.sh`

---

## Projektstatus

### ✅ Implementiert

**Infrastruktur:**
- Docker Compose mit Traefik v2.11 (SSL).
- n8n mit SQLite.
- Memory Limits: n8n (512MB), Traefik (256MB).
- Healthchecks: n8n Monitoring alle 30s.
- Log-Rotation: 10MB max, 3 Dateien pro Container.
- Automatisierte Backups: Die letzten 7 Backups werden vorgehalten.
- Port 5678 für initiales Setup freigegeben.

**Sicherheit:**
- Traefik Dashboard deaktiviert (keine Angriffsfläche).
- Docker Socket read-only gemountet.
- Port 5678 durch Firewall geschützt.
- Fehlerbehandlung in Workflows (Telegram-Alerts bei Fehlern).
- Validierung deutscher Mobilfunknummern (26 Präfixe).

**Workflows:**
- `roof-mode.json` (Anrufe, SMS, WhatsApp, Telegram).
- `sms-opt-in.json` (WhatsApp Opt-In via SMS).
- Error-Nodes mit Retry-Logik.

**Automatisierung:**
- `scripts/configure-system.sh` (Initiales Setup).
- `scripts/backup-db.sh` (Tägliche Backups).
- `scripts/validate-env.sh` (Konfigurationsprüfung).
- `scripts/import-workflows.sh` (Workflow-Import).

### 📋 Erfordert manuelle Konfiguration (ca. 32 Minuten)

**Schritt 1: API Credentials (10 Min)**
`/opt/vorzimmerdrache/.env` bearbeiten und Platzhalter ersetzen:
- `TWILIO_ACCOUNT_SID`
- `TWILIO_AUTH_TOKEN`
- `TELEGRAM_BOT_TOKEN`
- `TELEGRAM_CHAT_ID`
- `TWILIO_WHATSAPP_TEMPLATE_SID`

**Schritt 2: Workflows aktivieren (2 Min)**
1. n8n Instanz öffnen.
2. "Roof-Mode" & "SMS Opt-In" auf "Active" schalten.

**Schritt 3: n8n Credentials hinterlegen (15 Min)**
In n8n UI → Settings → Credentials:
1. Google Sheets (OAuth2 oder Service Account).
2. Twilio (Account SID + Auth Token).
3. Telegram (Bot Token).

**Schritt 4: Twilio Webhooks (5 Min)**
In der Twilio Console:
- Voice Webhook: `https://<DEINE-DOMAIN>/webhook/incoming-call`
- SMS Webhook: `https://<DEINE-DOMAIN>/webhook/sms-response`

**Schritt 5: End-to-End Test (5 Min)**
- Twilio Nummer anrufen.
- SMS-Erhalt prüfen.
- Mit "JA" antworten.
- Google Sheet auf Updates prüfen.

---

## Was enthalten ist

- 2.1s Antwortzeit (TwiML).
- Automatisierter WhatsApp-Versand.
- Telegram-Benachrichtigung bei jedem Ereignis.
- Kundendaten-Synchronisation in Google Sheets.

---

## Was NICHT enthalten ist

- Kein Lead-Scoring.
- Keine Förderrechner.
- Keine Datenanreicherung.
- Kein komplexes CRM.
- Kein PostgreSQL.