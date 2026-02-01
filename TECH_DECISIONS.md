# Technische Architektur-Entscheidungen

## SQLite vs PostgreSQL

### Warum SQLite ausreicht

Für 5-20 Anrufe/Tag ist SQLite völlig ausreichend:

| Aspekt | SQLite | PostgreSQL |
|--------|--------|------------|
| RAM | ~50MB | ~150MB+ |
| Setup | Integriert | Separater Container |
| Backup | Datei kopieren | pg_dump |
| Wartung | Keine | Vacuum, Tuning |

**SQLite WAL-Mode ist aktiv:**
- Write-Ahead Logging (keine Blockierung)
- 30s Busy Timeout
- Automatische Checkpoints

### Wann zu PostgreSQL wechseln?

- 100+ Anrufe/Tag
- Multi-Tenant (mehrere Handwerker)
- Hohe Parallelität (10+ gleichzeitig)
- Compliance-Audit-Logs nötig

**Fazit:** SQLite bleibt, ist kein Problem.

---

## Circuit Breaker

**Problem:** Wenn Twilio ausfällt → endlose Retries → SQLite Locks

**Lösung:** Nach 3 Fehlern → Circuit OPEN → Admin Alert

```javascript
// Fehler-Zähler
const errorCount = ($run.executionData.customData?.errorCount || 0) + 1;
if (errorCount >= 3) {
  return [{ json: { circuitOpen: true } }];
}
```

---

## Typeform vs n8n

**Typeform + Zapier:**
- ❌ Keine Telefonie
- ❌ Verzögert
- ❌ $20-50/Monat
- ❌ US-Cloud

**n8n:**
- ✅ Anrufe sofort
- ✅ €4,15/Monat
- ✅ Selbst gehostet
- ✅ Beliebige Logik

**Fazit:** n8n ist für telefonbasierte Leads überlegen.

---

## STOP Keyword (DSGVO)

**Status:** Noch nicht implementiert

**Implementation:**
```javascript
const stopWords = ['stop', 'abmelden', 'ende', 'stopp'];
if (stopWords.some(w => body.includes(w))) {
  // OptIn_Status = "UNSUBSCRIBED"
  // SMS: "Sie wurden abgemeldet"
}
```

**Aufwand:** 30 Minuten
