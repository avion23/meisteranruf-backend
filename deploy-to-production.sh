#!/bin/bash
set -euo pipefail

# Production Deployment Script for instance1.duckdns.org
# Deploys optimized containerized stack without WAHA (Twilio-only)

SERVER="ralf_waldukat@instance1.duckdns.org"
REMOTE_DIR="/opt/vorzimmerdrache"
LOCAL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[0;33m'
COLOR_RED='\033[0;31m'
NC='\033[0m'

log() {
    echo -e "${COLOR_GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${COLOR_YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${COLOR_RED}[ERROR]${NC} $1"
}

check_local_requirements() {
    log "Checking local requirements..."
    
    if ! command -v rsync &> /dev/null; then
        error "rsync not found. Install with: brew install rsync"
        exit 1
    fi
    
    if ! command -v ssh &> /dev/null; then
        error "ssh not found"
        exit 1
    fi
    
    log "✓ Local requirements satisfied"
}

check_remote_requirements() {
    log "Checking remote server requirements..."
    
    ssh "$SERVER" bash <<'EOF'
set -e

# Check Docker
if ! command -v docker &> /dev/null; then
    echo "ERROR: Docker not installed"
    exit 1
fi

# Check Docker Compose
if ! docker compose version &> /dev/null; then
    echo "ERROR: Docker Compose not available"
    exit 1
fi

# Check available memory
available_mem=$(free -m | awk '/^Mem:/ {print $7}')
if [ "$available_mem" -lt 500 ]; then
    echo "WARNING: Only ${available_mem}MB available memory (< 500MB)"
fi

# Check available disk
available_disk=$(df /opt | tail -1 | awk '{print $4}')
available_disk_gb=$((available_disk / 1024 / 1024))
if [ "$available_disk_gb" -lt 5 ]; then
    echo "ERROR: Only ${available_disk_gb}GB disk space available (< 5GB required)"
    exit 1
fi

echo "✓ Remote requirements satisfied"
echo "  Memory available: ${available_mem}MB"
echo "  Disk available: ${available_disk_gb}GB"
EOF
    
    if [ $? -ne 0 ]; then
        error "Remote requirements check failed"
        exit 1
    fi
}

prepare_env_file() {
    log "Preparing .env file..."
    
    if [ ! -f "$LOCAL_DIR/.env" ]; then
        if [ -f "$LOCAL_DIR/.env.example" ]; then
            log "Creating .env from .env.example"
            cp "$LOCAL_DIR/.env.example" "$LOCAL_DIR/.env"
            
            # Generate secure passwords
            POSTGRES_PASSWORD=$(openssl rand -base64 32)
            N8N_ENCRYPTION_KEY=$(openssl rand -hex 32)
            N8N_JWT_SECRET=$(openssl rand -hex 32)
            N8N_BASIC_AUTH_PASSWORD=$(openssl rand -base64 16)
            
            # Replace placeholders
            if [[ "$OSTYPE" == "darwin"* ]]; then
                sed -i '' "s|<strong-db-password>|$POSTGRES_PASSWORD|g" "$LOCAL_DIR/.env"
                sed -i '' "s|<generate-32-char-random-key>|$N8N_ENCRYPTION_KEY|g" "$LOCAL_DIR/.env"
                sed -i '' "s|<strong-password>|$N8N_BASIC_AUTH_PASSWORD|g" "$LOCAL_DIR/.env"
                sed -i '' "s|n8n.yourdomain.com|instance1.duckdns.org|g" "$LOCAL_DIR/.env"
                sed -i '' "s|yourdomain.com|instance1.duckdns.org|g" "$LOCAL_DIR/.env"
            else
                sed -i "s|<strong-db-password>|$POSTGRES_PASSWORD|g" "$LOCAL_DIR/.env"
                sed -i "s|<generate-32-char-random-key>|$N8N_ENCRYPTION_KEY|g" "$LOCAL_DIR/.env"
                sed -i "s|<strong-password>|$N8N_BASIC_AUTH_PASSWORD|g" "$LOCAL_DIR/.env"
                sed -i "s|n8n.yourdomain.com|instance1.duckdns.org|g" "$LOCAL_DIR/.env"
                sed -i "s|yourdomain.com|instance1.duckdns.org|g" "$LOCAL_DIR/.env"
            fi
            
            # Add production-specific variables
            cat >> "$LOCAL_DIR/.env" <<ENVEOF

# Production-specific settings
N8N_JWT_SECRET=$N8N_JWT_SECRET
ACME_EMAIL=admin@instance1.duckdns.org
ENVEOF
            
            warn "Generated .env file with secure passwords"
            warn "API keys can be configured later in n8n UI"
        else
            error ".env.example not found"
            exit 1
        fi
    else
        log "Using existing .env file"
    fi
    
    # Validate required variables
    source "$LOCAL_DIR/.env"
    
    if [ -z "$POSTGRES_PASSWORD" ] || [ "$POSTGRES_PASSWORD" == "<strong-db-password>" ]; then
        error "POSTGRES_PASSWORD not set in .env"
        exit 1
    fi
    
    if [ -z "$N8N_ENCRYPTION_KEY" ] || [ "$N8N_ENCRYPTION_KEY" == "<generate-32-char-random-key>" ]; then
        error "N8N_ENCRYPTION_KEY not set in .env"
        exit 1
    fi
    
    log "✓ Environment file validated"
}

sync_files() {
    log "Syncing files to remote server..."
    
    # Create remote directory
    ssh "$SERVER" "mkdir -p $REMOTE_DIR"
    
    # Sync files
    rsync -avz --progress \
        --exclude 'node_modules' \
        --exclude '.git' \
        --exclude '.DS_Store' \
        --exclude 'tests' \
        --exclude 'docs' \
        --exclude '*.md' \
        --exclude '.env.example' \
        --include '.env' \
        --include 'docker-compose-production.yml' \
        --include 'workflows/' \
        --include 'integrations/' \
        --include 'scripts/' \
        "$LOCAL_DIR/" "$SERVER:$REMOTE_DIR/"
    
    log "✓ Files synced"
}

deploy_stack() {
    log "Deploying Docker stack on remote server..."
    
    ssh "$SERVER" bash <<EOF
set -e
cd $REMOTE_DIR

# Create letsencrypt directory for Traefik
mkdir -p letsencrypt
chmod 600 letsencrypt 2>/dev/null || true

# Pull images
echo "Pulling Docker images..."
docker compose -f docker-compose-production.yml pull

# Stop existing containers (if any)
docker compose -f docker-compose-production.yml down 2>/dev/null || true

# Start services
echo "Starting services..."
docker compose -f docker-compose-production.yml up -d

# Wait for services to be healthy
echo "Waiting for services to start..."
sleep 30

# Show status
docker compose -f docker-compose-production.yml ps

echo ""
echo "✓ Deployment complete"
EOF
    
    if [ $? -ne 0 ]; then
        error "Deployment failed"
        exit 1
    fi
    
    log "✓ Stack deployed"
}

verify_deployment() {
    log "Verifying deployment..."
    
    ssh "$SERVER" bash <<EOF
set -e
cd $REMOTE_DIR

# Check container status
unhealthy=\$(docker compose -f docker-compose-production.yml ps | grep -v "Up" | grep -v "NAME" | wc -l)

if [ "\$unhealthy" -gt 0 ]; then
    echo "ERROR: Some containers are not running"
    docker compose -f docker-compose-production.yml ps
    exit 1
fi

# Check n8n accessibility
if ! docker exec n8n wget -q --spider http://localhost:5678/healthz; then
    echo "ERROR: n8n health check failed"
    exit 1
fi

# Check PostgreSQL
if ! docker exec postgres pg_isready -U n8n > /dev/null; then
    echo "ERROR: PostgreSQL not ready"
    exit 1
fi

# Check Redis
if ! docker exec redis redis-cli ping | grep -q PONG; then
    echo "ERROR: Redis not responding"
    exit 1
fi

echo "✓ All services healthy"
EOF
    
    if [ $? -ne 0 ]; then
        error "Verification failed"
        show_logs
        exit 1
    fi
    
    log "✓ Deployment verified"
}

show_logs() {
    log "Recent logs from containers:"
    ssh "$SERVER" "cd $REMOTE_DIR && docker compose -f docker-compose-production.yml logs --tail=50"
}

setup_monitoring() {
    log "Setting up monitoring..."
    
    ssh "$SERVER" bash <<'EOF'
set -e

# Create monitoring script
cat > /opt/vorzimmerdrache/monitor.sh <<'MONITOR'
#!/bin/bash
echo "=== System Resources $(date) ==="
free -h
df -h /
echo ""
echo "=== Docker Status ==="
cd /opt/vorzimmerdrache
docker compose -f docker-compose-production.yml ps
echo ""
echo "=== Container Resources ==="
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"
MONITOR

chmod +x /opt/vorzimmerdrache/monitor.sh

# Create backup script
cat > /opt/vorzimmerdrache/backup.sh <<'BACKUP'
#!/bin/bash
BACKUP_DIR="/opt/backups/vorzimmerdrache"
DATE=$(date +%Y%m%d_%H%M%S)
mkdir -p "$BACKUP_DIR"

# Backup PostgreSQL
docker exec postgres pg_dump -U n8n n8n | gzip > "$BACKUP_DIR/n8n_${DATE}.sql.gz"

# Backup n8n data
tar czf "$BACKUP_DIR/n8n_data_${DATE}.tar.gz" /var/lib/docker/volumes/*n8n_data* 2>/dev/null || true

# Remove old backups (keep 7 days)
find "$BACKUP_DIR" -name "n8n_*.sql.gz" -mtime +7 -delete
find "$BACKUP_DIR" -name "n8n_data_*.tar.gz" -mtime +7 -delete

echo "Backup completed: ${DATE}"
BACKUP

chmod +x /opt/vorzimmerdrache/backup.sh

echo "✓ Monitoring scripts created"
echo "  - Monitor: /opt/vorzimmerdrache/monitor.sh"
echo "  - Backup: /opt/vorzimmerdrache/backup.sh"
EOF
    
    log "✓ Monitoring setup complete"
}

show_summary() {
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    log "🎉 Deployment Successful!"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    log "Access URLs:"
    echo "  n8n:     https://instance1.duckdns.org"
    echo "  User:    $(grep N8N_BASIC_AUTH_USER "$LOCAL_DIR/.env" | cut -d= -f2)"
    echo "  Pass:    $(grep N8N_BASIC_AUTH_PASSWORD "$LOCAL_DIR/.env" | cut -d= -f2)"
    echo ""
    log "Useful commands:"
    echo "  Monitor:  ssh $SERVER '/opt/vorzimmerdrache/monitor.sh'"
    echo "  Logs:     ssh $SERVER 'cd /opt/vorzimmerdrache && docker compose -f docker-compose-production.yml logs -f n8n'"
    echo "  Restart:  ssh $SERVER 'cd /opt/vorzimmerdrache && docker compose -f docker-compose-production.yml restart n8n'"
    echo "  Backup:   ssh $SERVER '/opt/vorzimmerdrache/backup.sh'"
    echo ""
    log "Next steps:"
    echo "  1. Access n8n at https://instance1.duckdns.org"
    echo "  2. Import workflows from workflows/ directory"
    echo "  3. Configure credentials (Twilio, Google, Telegram)"
    echo "  4. Test webhook endpoint: https://instance1.duckdns.org/webhook/test"
    echo "  5. Set up cron backup: ssh $SERVER 'crontab -e'"
    echo "     Add: 0 2 * * * /opt/vorzimmerdrache/backup.sh >> /var/log/n8n-backup.log 2>&1"
    echo ""
    warn "Remember to configure API keys in n8n credentials!"
    echo "═══════════════════════════════════════════════════════════════"
}

main() {
    log "Starting production deployment to instance1.duckdns.org"
    echo ""
    
    check_local_requirements
    check_remote_requirements
    prepare_env_file
    sync_files
    deploy_stack
    verify_deployment
    setup_monitoring
    show_summary
}

main "$@"
