#!/bin/bash

set -euo pipefail

COLOR_RED='\033[0;31m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[1;33m'
COLOR_NC='\033[0m'

log_info() {
  echo -e "${COLOR_GREEN}[INFO]${COLOR_NC} $1"
}

log_error() {
  echo -e "${COLOR_RED}[ERROR]${COLOR_NC} $1"
}

log_warn() {
  echo -e "${COLOR_YELLOW}[WARN]${COLOR_NC} $1"
}

check_service() {
  local name="$1"
  local url="$2"
  local expected_status="${3:-200}"

  log_info "Checking $name: $url"

  status=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 --max-time 30 "$url")

  if [[ "$status" =~ ^($expected_status)$ ]]; then
    log_info "✓ $name is healthy (HTTP $status)"
    return 0
  else
    log_error "✗ $name is not healthy (expected $expected_status, got $status)"
    return 1
  fi
}

failures=0

if [ -f .env ]; then
  source .env
else
  log_warn ".env file not found, using defaults"
fi

DOMAIN="${DOMAIN:-localhost}"

log_info "Starting smoke tests..."

check_service "n8n" "http://localhost/healthz" "200" || ((failures++))
check_service "Traefik" "http://${DOMAIN}/health" "200|301|302|404" || ((failures++))

echo ""
log_info "Smoke tests completed"

if [ $failures -eq 0 ]; then
  log_info "✓ All checks passed"
  exit 0
else
  log_error "✗ $failures check(s) failed"
  exit 1
fi
