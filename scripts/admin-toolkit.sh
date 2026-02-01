#!/bin/bash
# Vorzimmerdrache Admin Toolkit
# SSH/Docker-basierte System-Administration

set -e

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Konfiguration
N8N_CONTAINER="vorzimmerdrache-n8n-1"
DATA_DIR="/home/node/.n8n"

echo -e "${GREEN}=== Vorzimmerdrache Admin Toolkit ===${NC}"
echo ""

# Funktion: Workflows exportieren
export_workflows() {
    echo -e "${YELLOW}Exportiere alle Workflows...${NC}"
    docker exec $N8N_CONTAINER n8n export:workflow --all --output=$DATA_DIR/backup/
    echo -e "${GREEN}✓ Workflows exportiert nach $DATA_DIR/backup/${NC}"
}

# Funktion: Workflows importieren
import_workflows() {
    echo -e "${YELLOW}Importiere Workflows...${NC}"
    docker exec $N8N_CONTAINER n8n import:workflow --input=$DATA_DIR/backup/
    echo -e "${GREEN}✓ Workflows importiert${NC}"
}

# Funktion: Datenbank-Backup
db_backup() {
    local backup_file="n8n-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
    echo -e "${YELLOW}Erstelle Backup: $backup_file${NC}"
    docker exec $N8N_CONTAINER tar czf /tmp/$backup_file -C $DATA_DIR database.sqlite
    docker cp $N8N_CONTAINER:/tmp/$backup_file ./backups/
    echo -e "${GREEN}✓ Backup erstellt: ./backups/$backup_file${NC}"
}

# Funktion: Credentials anzeigen (verschlüsselt)
list_credentials() {
    echo -e "${YELLOW}Credentials in Datenbank:${NC}"
    docker exec $N8N_CONTAINER node -e "
    const sqlite3 = require('sqlite3').verbose();
    const db = new sqlite3.Database('$DATA_DIR/database.sqlite');
    db.all('SELECT id, name, type FROM credentials_entity', [], (err, rows) => {
        if (err) throw err;
        rows.forEach(row => console.log('ID: ' + row.id + ' | Name: ' + row.name + ' | Type: ' + row.type));
    });
    db.close();
    " 2>/dev/null || echo "Fehler: sqlite3 Modul nicht verfügbar"
}

# Funktion: Workflow-Status prüfen
check_workflows() {
    echo -e "${YELLOW}Workflow-Status:${NC}"
    docker exec $N8N_CONTAINER node -e "
    const sqlite3 = require('sqlite3').verbose();
    const db = new sqlite3.Database('$DATA_DIR/database.sqlite');
    db.all('SELECT id, name, active FROM workflow_entity', [], (err, rows) => {
        if (err) throw err;
        rows.forEach(row => {
            const status = row.active ? '${GREEN}AKTIV${NC}' : '${RED}INAKTIV${NC}';
            console.log(status + ' | ' + row.name + ' (ID: ' + row.id + ')');
        });
    });
    db.close();
    " 2>/dev/null || echo "Fehler bei Abfrage"
}

# Funktion: System-Status
system_status() {
    echo -e "${YELLOW}System-Status:${NC}"
    docker ps --filter "name=vorzimmerdrache" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    echo ""
    echo -e "${YELLOW}Speicher-Nutzung:${NC}"
    docker stats --no-stream --format "table {{.Name}}\t{{.MemUsage}}" vorzimmerdrache-n8n-1 vorzimmerdrache-traefik-1
}

# Funktion: Logs anzeigen
show_logs() {
    local lines=${1:-50}
    echo -e "${YELLOW}Letzte $lines Zeilen n8n Logs:${NC}"
    docker logs --tail $lines $N8N_CONTAINER
}

# Funktion: Passwort zurücksetzen
reset_password() {
    local email=$1
    if [ -z "$email" ]; then
        echo -e "${RED}Fehler: E-Mail erforderlich${NC}"
        echo "Usage: $0 reset-password admin@example.com"
        exit 1
    fi
    echo -e "${YELLOW}Setze Passwort zurück für $email...${NC}"
    docker exec $N8N_CONTAINER n8n user-management:reset-password --email=$email
}

# Main Menu
case "${1:-menu}" in
    export)
        export_workflows
        ;;
    import)
        import_workflows
        ;;
    backup)
        db_backup
        ;;
    credentials)
        list_credentials
        ;;
    workflows)
        check_workflows
        ;;
    status)
        system_status
        ;;
    logs)
        show_logs $2
        ;;
    reset-password)
        reset_password $2
        ;;
    menu|*)
        echo "Verfügbare Befehle:"
        echo "  $0 export              - Alle Workflows exportieren"
        echo "  $0 import              - Workflows importieren"
        echo "  $0 backup              - Datenbank-Backup erstellen"
        echo "  $0 credentials         - Credentials anzeigen"
        echo "  $0 workflows           - Workflow-Status prüfen"
        echo "  $0 status              - System-Status"
        echo "  $0 logs [N]            - Letzte N Zeilen Logs (default: 50)"
        echo "  $0 reset-password <email> - Passwort zurücksetzen"
        ;;
esac
