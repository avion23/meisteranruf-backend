# Zusätzliche Skripte

Dieses Verzeichnis enthält Hilfsskripte, die über das Haupt-Deployment hinausgehen.

## Skripte

### configure-system.sh
Automatisiert die initiale Systemkonfiguration ohne API-Zugangsdaten:
- Korrigiert `SSL_EMAIL` auf eine domainbasierte E-Mail (verhindert Let's Encrypt-Fehler).
- Erstellt ein automatisiertes Backup-System (behält 7 Backups).
- Erstellt ein Validierungsskript für die Konfiguration (prüft auf Platzhalterwerte).
- Aktualisiert `.env.example` mit der realen Google Sheets CRM ID.

**Nutzung:**
```bash
./scripts/configure-system.sh
```

**Konfigurierte Komponenten:**
- ✅ Automatisierte Backups (`scripts/backup-db.sh`)
- ✅ Konfigurationsvalidierung (`scripts/validate-env.sh`)
- ✅ SSL-E-Mail für Let's Encrypt
- ✅ Google Sheets CRM Integration

**Nicht konfigurierbare Komponenten (Manuelle Eingabe erforderlich):**
- ❌ API-Zugangsdaten
- ❌ n8n-Anmeldedaten (über Web-UI)
- ❌ Workflow-Aktivierung (über Web-UI)

### backup-db.sh
Automatisiertes n8n-Datenbank-Backup (erstellt durch `configure-system.sh`).
Sichert die Datenbank mit Zeitstempel im Verzeichnis `backups/`.
Behält automatisch nur die letzten 7 Sicherungen.

**Nutzung:**
```bash
./scripts/backup-db.sh
```

### validate-env.sh
Validiert die `.env`-Konfiguration, um sicherzustellen, dass alle Platzhalter ersetzt wurden.

**Nutzung:**
```bash
./scripts/validate-env.sh
```

**Prüfpunkte:**
- Twilio Account SID (kein Platzhalter)
- Twilio Auth Token (kein Platzhalter)
- Telegram Bot Token (kein Platzhalter)
- Telegram Chat ID (kein Platzhalter)
- Twilio WhatsApp Template SID (kein Platzhalter)
- SSL-E-Mail (nicht admin@example.com)

### import-workflows.sh
Importiert beide Workflows via REST-API in n8n.

**Nutzung:**
```bash
export N8N_API_KEY=<your-api-key>
./scripts/import-workflows.sh
```

**Hinweis:** Workflows müssen nach dem Import manuell über das n8n Web-UI aktiviert werden.

### activate-workflows.sh
**DERZEIT NICHT FUNKTIONSFÄHIG** – n8n sqlite3-Modul im Container nicht verfügbar.
Workflows müssen manuell über das n8n Web-UI aktiviert werden (2 Klicks).

**Alternative Vorgehensweise:**
1. https://instance1.duckdns.org öffnen.
2. "Workflows" in der Seitenleiste auswählen.
3. Workflow "Roof-Mode" auswählen.
4. Schalter oben rechts zur Aktivierung klicken.
5. Workflow "SMS Opt-In" auswählen.
6. Schalter oben rechts zur Aktivierung klicken.
