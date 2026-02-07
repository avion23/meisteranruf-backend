# Google Sheets Schema - Meisteranruf V2

## Übersicht

Das System verwendet **3 separate Tabs** in Google Sheets für verschiedene Zwecke:

| Tab | Zweck | Datenquelle | Update-Frequenz |
|-----|-------|-------------|-----------------|
| **Leads** | Für Sales-Team | Finale qualifizierte Leads | Bei jeder Qualifizierung |
| **Debug_Log** | Für Troubleshooting | Alle SMS-Interaktionen | Bei jeder SMS (inbound/outbound) |
| **Call_Log** | Für Analytics | Alle eingehenden Anrufe | Bei jedem Anruf |

**Architektur-Prinzip:**
- **State:** In n8n SQLite (schnell, race-condition-frei)
- **Debug:** In Google Sheets (übersichtlich, filterbar)
- **Leads:** In Google Sheets (für Sales-Team)

---

## Tab 1: Leads

**Zweck:** Übersicht aller qualifizierten Leads für das Sales-Team

**Wann wird geschrieben:** Nur wenn ein Lead vollständig qualifiziert ist (PLZ + Opt-In)

### Schema

| Spalte | Name | Typ | Beschreibung | Beispiel |
|--------|------|-----|--------------|----------|
| A | Phone | String (E.164) | Telefonnummer des Kunden | +491711234567 |
| B | PLZ | String (5 Zeichen) | Postleitzahl | 10115 |
| C | OptIn_Timestamp | ISO 8601 | Zeitpunkt des DSGVO Opt-In | 2026-02-01T14:31:00Z |
| D | Qualified_Timestamp | ISO 8601 | Zeitpunkt der Qualifizierung | 2026-02-01T14:32:00Z |
| E | Source | String | Ursprung des Leads | sms_opt_in |
| F | Status | String | Verarbeitungsstatus | NEW / CONTACTED / CONVERTED |

### Beispiel-Daten

```
| Phone          | PLZ   | OptIn_Timestamp      | Qualified_Timestamp  | Source      | Status    |
|----------------|-------|----------------------|----------------------|-------------|-----------|
| +491711234567  | 10115 | 2026-02-01T14:31:00Z | 2026-02-01T14:32:00Z | sms_opt_in  | NEW       |
| +491609876543  | 80331 | 2026-02-01T15:15:00Z | 2026-02-01T15:16:00Z | sms_opt_in  | CONTACTED |
| +4915211122233 | 20095 | 2026-02-01T16:00:00Z | 2026-02-01T16:01:00Z | sms_opt_in  | CONVERTED |
```

### Verwendung durch Sales

1. **Neue Leads:** Filter nach `Status = NEW`
2. **Kontaktiert:** Status manuell auf `CONTACTED` setzen
3. **Konvertiert:** Status auf `CONVERTED` setzen (Termin vereinbart)

---

## Tab 2: Debug_Log

**Zweck:** Vollständige Nachvollziehbarkeit aller SMS-Interaktionen für Debugging

**Wann wird geschrieben:** Bei JEDER SMS (inbound vom Kunden + outbound vom System)

### Schema

| Spalte | Name | Typ | Beschreibung | Beispiel |
|--------|------|-----|--------------|----------|
| A | Timestamp | ISO 8601 | Zeitpunkt der Interaktion | 2026-02-01T14:31:00Z |
| B | Phone | String (E.164) | Telefonnummer | +491711234567 |
| C | Direction | Enum | Richtung der Nachricht | inbound / outbound |
| D | Message | String | Inhalt der Nachricht | "JA" / "Danke! Bitte PLZ..." |
| E | State | String | Aktueller State nach Verarbeitung | awaiting_plz / qualified |
| F | Action | String | Ausgeführte Aktion | opt_in_received / plz_received |

### Beispiel-Daten (Kompletter Flow)

```
| Timestamp            | Phone         | Direction | Message                                          | State         | Action           |
|----------------------|---------------|-----------|--------------------------------------------------|---------------|------------------|
| 2026-02-01T14:30:00Z | +491711234567 | outbound  | "Hi, wir haben Ihren Anruf verpasst..."          | sms_sent      | sms_invite_sent  |
| 2026-02-01T14:31:00Z | +491711234567 | inbound   | "JA"                                             | awaiting_plz  | opt_in_received  |
| 2026-02-01T14:31:05Z | +491711234567 | outbound  | "Danke! Bitte sende mir deine Postleitzahl..."   | awaiting_plz  | request_plz      |
| 2026-02-01T14:32:00Z | +491711234567 | inbound   | "10115"                                          | qualified     | plz_received     |
| 2026-02-01T14:32:05Z | +491711234567 | outbound  | "Perfekt! Klicke hier für WhatsApp..."           | qualified     | whatsapp_link    |
```

### Debugging-Szenarien

**Problem:** Kunde bekommt keine Antwort
1. In Debug_Log nach `Phone` filtern
2. Prüfen ob letzte Nachricht `inbound` war
3. State und Action prüfen

**Problem:** Doppelte Nachrichten
1. Nach `MessageSid` suchen (im n8n Log)
2. Prüfen ob gleiche MessageSid mehrfach auftaucht

---

## Tab 3: Call_Log

**Zweck:** Übersicht aller eingehenden Anrufe für Analytics

**Wann wird geschrieben:** Bei jedem eingehenden Anruf (Roof-Mode Workflow)

### Schema

| Spalte | Name | Typ | Beschreibung | Beispiel |
|--------|------|-----|--------------|----------|
| A | Timestamp | ISO 8601 | Zeitpunkt des Anrufs | 2026-02-01T14:30:00Z |
| B | Phone | String (E.164) | Anrufernummer | +491711234567 |
| C | Status | Enum | Ergebnis des Anrufs | missed / handled / voicemail |
| D | SMS_Sent | Boolean | Opt-In SMS verschickt | true / false |
| E | Known_Customer | Boolean | Kunde bereits bekannt | true / false |
| F | Duration | Integer | Anrufdauer in Sekunden | 0 (bei missed) |

### Beispiel-Daten

```
| Timestamp            | Phone         | Status  | SMS_Sent | Known_Customer | Duration |
|----------------------|---------------|---------|----------|----------------|----------|
| 2026-02-01T14:30:00Z | +491711234567 | missed  | true     | false          | 0        |
| 2026-02-01T15:15:00Z | +491609876543 | missed  | true     | true           | 0        |
| 2026-02-01T16:00:00Z | +4915211122233 | handled | false    | true           | 45       |
```

### Analytics-Beispiele

**Conversion Rate berechnen:**
```
Anrufe: COUNT(Call_Log)
Leads: COUNT(Leads)
Conversion Rate: Leads / Anrufe * 100
```

**Neue vs. Wiederkehrende Kunden:**
```
Neu: COUNTIF(Call_Log, Known_Customer = false)
Wiederkehrend: COUNTIF(Call_Log, Known_Customer = true)
```

---

## Environment Variables

```bash
# Google Sheets Konfiguration
GOOGLE_SHEETS_SPREADSHEET_ID=1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgvE2upms
GOOGLE_SHEETS_LEADS_RANGE=Leads!A:F
GOOGLE_SHEETS_DEBUG_RANGE=Debug_Log!A:F
GOOGLE_SHEETS_CALL_LOG_RANGE=Call_Log!A:F
```

---

## Setup-Anleitung

### 1. Spreadsheet erstellen

1. Google Sheets öffnen
2. Neues Spreadsheet erstellen
3. 3 Tabs anlegen: `Leads`, `Debug_Log`, `Call_Log`

### 2. Header einfügen

**Leads Tab:**
```
A1: Phone
B1: PLZ
C1: OptIn_Timestamp
D1: Qualified_Timestamp
E1: Source
F1: Status
```

**Debug_Log Tab:**
```
A1: Timestamp
B1: Phone
C1: Direction
D1: Message
E1: State
F1: Action
```

**Call_Log Tab:**
```
A1: Timestamp
B1: Phone
C1: Status
D1: SMS_Sent
E1: Known_Customer
F1: Duration
```

### 3. Service Account freigeben

1. Google Cloud Console → Service Account E-Mail kopieren
2. In Spreadsheet: "Teilen" → Service Account E-Mail hinzufügen
3. Berechtigung: "Editor"

### 4. Spreadsheet ID ermitteln

URL: `https://docs.google.com/spreadsheets/d/1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgvE2upms/edit`

Spreadsheet ID: `1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgvE2upms`

---

## Troubleshooting

### Problem: Keine Daten in Sheets

**Prüfung:**
1. Service Account hat Zugriff?
2. Tab-Namen korrekt? (Groß-/Kleinschreibung beachten)
3. Range korrekt? (z.B. `Leads!A:F`)
4. In n8n Logs nach Google Sheets Errors suchen

### Problem: Daten kommen verzögert an

**Normal:** Google Sheets API hat Latenz von 200-500ms.
**Abnormal:** Wenn >5s, dann API-Limit erreicht.

**Lösung:**
- `continueOnFail: true` ist aktiviert
- Workflow läuft weiter auch wenn Sheets down ist
- Daten gehen nicht verloren (State in SQLite)

### Problem: Doppelte Einträge

**Ursache:** Twilio sendet manchmal doppelte Webhooks.

**Lösung:**
- MessageSid Deduplication ist implementiert
- Prüfe in Debug_Log ob gleiche Timestamp mehrfach vorkommt

---

## Daten-Retention

| Tab | Empfohlene Aufbewahrung | Lösch-Strategie |
|-----|------------------------|-----------------|
| Leads | Permanent | Nie löschen (DSGVO-relevant) |
| Debug_Log | 30-90 Tage | Alte Einträge manuell löschen |
| Call_Log | 1 Jahr | Archivieren nach 1 Jahr |

**Automatisches Cleanup:**
- Nicht implementiert (muss manuell erfolgen)
- Alternative: Google Apps Script für automatisches Archivieren

---

## Integration mit anderen Tools

### Zapier/Make.com

**Trigger:** Neue Zeile in `Leads` Tab
**Action:** CRM-Integration (HubSpot, Pipedrive, etc.)

### Google Data Studio

**Datenquelle:** Google Sheets
**Dashboard:** Conversion Rate, Anrufvolumen, Lead-Qualität

### Slack/Teams

**Trigger:** Neue Zeile in `Leads` Tab
**Action:** Benachrichtigung im Sales-Channel

---

## Migration von V1 zu V2

### Altes Schema (V1)
- Ein Tab mit State-Machine Spalten (`conversation_state`, `awaiting_plz`, etc.)
- State wurde in Sheets gehalten
- 4-6 API Calls pro Lead

### Neues Schema (V2)
- Drei separate Tabs (Leads, Debug_Log, Call_Log)
- State in SQLite, nur finale Leads + Debug in Sheets
- 2-3 API Calls pro Lead

### Migrationsschritte

1. **Neue Tabs erstellen** (Leads, Debug_Log, Call_Log)
2. **Alte Daten archivieren** (V1 Tab umbenennen zu "Legacy")
3. **Environment Variables aktualisieren**
   ```bash
   GOOGLE_SHEETS_LEADS_RANGE=Leads!A:F
   GOOGLE_SHEETS_DEBUG_RANGE=Debug_Log!A:F
   ```
4. **V2 Workflow aktivieren**

---

## Performance-Vergleich

| Metrik | V1 (Sheets State) | V2 (SQLite State) |
|--------|-------------------|-------------------|
| State Read | 200-500ms | <1ms |
| State Write | 500-2000ms | <10ms |
| Sheets API Calls | 4-6 pro Lead | 2-3 pro Lead |
| Race Conditions | Möglich | Unmöglich |

---

## Sicherheit & Datenschutz

- **Phone-Daten:** Hohe Sensitivität (personenbezogen)
- **PLZ-Daten:** Niedrige Sensitivität (Postleitzahlregion)
- **OptIn_Timestamp:** DSGVO-relevant (Proof of Consent)

**Empfehlungen:**
- Nur notwendige Daten in Sheets speichern
- Keine sensiblen Daten (z.B. vollständige Adresse)
- Opt-out Möglichkeit implementiert (STOP Handler)
- GDPR-Konformität: Explizites Opt-In erforderlich
