# Google Sheets Schema

## Überblick

Dieses Dokument beschreibt das Datenbankschema für die Google Sheets Integration, das für das 3-Fragen-Qualifikations-Flow verwendet wird.

## Sheet 1: Lead_DB (Kunden)

### Spaltenbeschreibung

| Spalte | Typ | Beschreibung | Beispiel | Pflichtfeld |
|--------|-----|--------------|----------|-------------|
| Phone | String | Telefonnummer im E.164-Format | `+491711234567` | Ja |
| Name | String | Vollständiger Name | `Hans Müller` | Nein |
| OptIn_Status | Boolean | Opt-in Status für SMS | `TRUE` | Ja |
| conversation_state | String | Aktueller Gesprächsstatus (siehe gültige Werte) | `awaiting_plz` | Nein |
| plz | String | Postleitzahl (5-stellig) | `12345` | Nein |
| kwh_consumption | Number | Jahresstromverbrauch in kWh | `3500` | Nein |
| meter_photo_url | String | Twilio MMS Medien-URL | `https://media.twilio.com/...` | Nein |
| qualification_timestamp | DateTime | Zeitstempel wenn alle 3 Antworten gesammelt | `2026-02-01 14:30:00` | Nein |
| last_state_change | DateTime | Zeitstempel der letzten Statusänderung | `2026-02-01 14:25:00` | Nein |
| Last_Contact | Date | Datum des letzten Kontakts | `2026-02-01` | Ja |

### Gültige Werte für conversation_state

| State | Beschreibung | Nächster Schritt |
|-------|--------------|------------------|
| `SMS_Sent` | Opt-in SMS gesendet, wartet auf "JA" | → `awaiting_plz` |
| `awaiting_plz` | Wartet auf Postleitzahl | → `awaiting_kwh` |
| `awaiting_kwh` | Wartet auf Jahresverbrauch | → `awaiting_foto` |
| `awaiting_foto` | Wartet auf Zählerfoto | → `qualified_complete` |
| `qualified_complete` | Alle Daten gesammelt | → WhatsApp-Link senden |
| `expired` | Timeout nach 24h | Manuelles Follow-up |

## Sheet 2: Call_Log (Anrufliste)

### Spaltenbeschreibung

| Spalte | Typ | Beschreibung | Beispiel |
|--------|-----|--------------|----------|
| Timestamp | DateTime | Zeitstempel des Anrufs | `2026-02-01 14:00:00` |
| Phone | String | Telefonnummer des Anrufers | `+491711234567` |
| Duration | Number | Anrufdauer in Sekunden | `45` |
| Status | String | Anrufstatus | `answered`, `missed`, `voicemail` |
| Notes | String | Notizen zum Anruf | `Kunde interessiert` |

## Sheet 3: Conversation_History (Gesprächsverlauf)

### Spaltenbeschreibung

| Spalte | Typ | Beschreibung | Beispiel |
|--------|-----|--------------|----------|
| Timestamp | DateTime | Zeitstempel der Nachricht | `2026-02-01 14:05:00` |
| Phone | String | Telefonnummer | `+491711234567` |
| From_State | String | Vorheriger Status | `Q1_Await_PLZ` |
| To_State | String | Neuer Status | `Q2_Await_kWh` |
| Message_Type | String | Nachrichtentyp | `system`, `customer` |
| Content | String | Nachrichteninhalt | `12345` oder `Danke! Für ein Angebot...` |

## Beispieldaten

### Lead_DB - Verschiedene Zustände

| Phone | Name | OptIn_Status | conversation_state | plz | kwh_consumption | meter_photo_url | qualification_timestamp | last_state_change | Last_Contact |
|-------|------|--------------|-------------------|-----|-----------------|-----------------|------------------------|-------------------|--------------|
| +491711234567 | Hans M. | TRUE | awaiting_plz | | | | | 2026-02-01 14:00 | 2026-02-01 |
| +491609876543 | Anna K. | TRUE | awaiting_kwh | 12345 | | | | 2026-02-01 14:05 | 2026-02-01 |
| +491721234567 | Thomas S. | TRUE | awaiting_foto | 54321 | 3500 | | | 2026-02-01 14:10 | 2026-02-01 |
| +491629876543 | Lisa B. | TRUE | qualified_complete | 12345 | 4200 | https://media.twilio.com/... | 2026-02-01 14:30 | 2026-02-01 14:30 | 2026-02-01 |
| +491733456789 | Max K. | TRUE | expired | | | | | 2026-01-31 10:00 | 2026-01-31 |

### Conversation_History - Beispielverlauf

| Timestamp | Phone | From_State | To_State | Message_Type | Content |
|-----------|-------|------------|----------|--------------|---------|
| 2026-02-01 14:00:00 | +491711234567 | SMS_Sent | Q1_Await_PLZ | system | Danke! Für ein Angebot brauchen wir 3 Infos: 1. Ihre PLZ? |
| 2026-02-01 14:05:23 | +491711234567 | Q1_Await_PLZ | Q2_Await_kWh | customer | 12345 |
| 2026-02-01 14:05:25 | +491711234567 | Q2_Await_kWh | Q3_Await_Foto | system | Danke! Noch 2 Fragen: 2. Jahresstromverbrauch (kWh)? |
| 2026-02-01 14:10:47 | +491711234567 | Q2_Await_kWh | Q3_Await_Foto | customer | 3500 |
| 2026-02-01 14:10:49 | +491711234567 | Q3_Await_Foto | - | system | Danke! Letzte Frage: 3. Foto vom Zählerschrank |
| 2026-02-01 14:30:12 | +491711234567 | Q3_Await_Foto | Qualified_Complete | customer | [MMS Foto] |
| 2026-02-01 14:30:15 | +491711234567 | Qualified_Complete | - | system | Perfekt! Hier ist Ihr WhatsApp-Link: https://wa.me/... |

## Migrationsanleitung

### Neue Spalten zum bestehenden Sheet hinzufügen

Führen Sie die folgenden Schritte aus, um das Schema zu migrieren:

#### Schritt 1: Spalten hinzufügen

Fügen Sie diese Spalten in der Reihenfolge am Ende des `Lead_DB` Sheets hinzu:

```
conversation_state | plz | kwh_consumption | meter_photo_url | qualification_timestamp | last_state_change
```

#### Schritt 2: Standardwerte setzen

Für existierende Zeilen:
- `conversation_state`: Leer lassen (NULL)
- `plz`: Leer lassen
- `kwh_consumption`: Leer lassen
- `meter_photo_url`: Leer lassen
- `qualification_timestamp`: Leer lassen
- `last_state_change`: Leer lassen

#### Schritt 3: Neues Sheet erstellen

Erstellen Sie ein neues Sheet namens `Conversation_History` mit den Spalten:

```
Timestamp | Phone | From_State | To_State | Message_Type | Content
```

#### Schritt 4: Formatierung einstellen

- **conversation_state**: Text (Plain Text)
- **plz**: Text (Plain Text) - für führende Nullen
- **kwh_consumption**: Zahl (Number)
- **meter_photo_url**: Text (Plain Text)
- **qualification_timestamp**: Datum/Zeit (DateTime)
- **last_state_change**: Datum/Zeit (DateTime)

#### Schritt 5: Validierung (optional)

Fügen Sie Datenvalidierung für `conversation_state` hinzu:
- Zulässige Werte: `SMS_Sent`, `awaiting_plz`, `awaiting_kwh`, `awaiting_foto`, `qualified_complete`, `expired`

### Vorhandene Daten sichern

Bevor Sie Änderungen vornehmen:

1. Erstellen Sie eine Kopie des gesamten Sheets
2. Exportieren Sie als CSV für Backup
3. Führen Sie die Migration während weniger Verkehrsstunden durch

### Rollback-Plan

Falls Probleme auftreten:

1. Setzen Sie `ENABLE_3_QUESTION_FLOW=false` in der `.env` Datei
2. Der alte Flow wird sofort wieder aktiv
3. Kein Datenverlust (neue Spalten bleiben gefüllt)
4. Analysieren Sie die Logs, beheben Sie die Probleme, deployen Sie erneut

## API-Integration

### Google Sheets API-Scope

Stellen Sie sicher, dass Ihr API-Token folgende Scopes hat:

```
https://www.googleapis.com/auth/spreadsheets
https://www.googleapis.com/auth/drive
```

### Beispiel: Status aktualisieren

```javascript
// Update conversation_state und last_state_change
const range = `Lead_DB!A${rowNumber}:K${rowNumber}`;
const values = [[
  phone,
  name,
  optInStatus,
  'awaiting_kwh',  // conversation_state
  '12345',         // plz
  '',              // kwh_consumption
  '',              // meter_photo_url
  '',              // qualification_timestamp
  new Date().toISOString(), // last_state_change
  lastContact
]];

await sheets.spreadsheets.values.update({
  spreadsheetId: SHEET_ID,
  range: range,
  valueInputOption: 'USER_ENTERED',
  resource: { values }
});
```

## Performance-Überlegungen

- **Google Sheets API**: ~100ms pro Lookup/Update
- **State Machine**: O(1) Lookup pro SMS
- **Geplante Workflows**: O(n) wobei n = Anzahl der wartenden States

**Geschätzter Durchsatz:** 100 gleichzeitige Gespräche ohne Performance-Einbußen.

## Sicherheit & Datenschutz

- **PLZ-Daten**: Niedrige Sensitivität (Postleitzahlregion)
- **kWh-Daten**: Mittlere Sensitivität (Verbrauchsgewohnheiten)
- **Foto-Daten**: Hohe Sensitivität (Innenansicht Haus)

**Empfehlungen:**
- Foto-URL Ablaufzeit setzen (7 Tage)
- Foto-URLs verschlüsselt speichern
- GDPR-Konformität: Nur notwendige Daten sammeln
- Opt-out Möglichkeit für Fotoanforderung bieten
