#!/bin/bash
set -e

DOCKER_COMPOSE_FILE="${1:-docker-compose.yml}"

if ! command -v docker &> /dev/null; then
    apt update && apt install -y docker.io
fi

if [ ! -f /swapfile ]; then
    fallocate -l 4G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

if [ ! -f .env ]; then
    cp .env.example .env
fi

docker compose -f "$DOCKER_COMPOSE_FILE" pull
docker compose -f "$DOCKER_COMPOSE_FILE" down 2>/dev/null || true
docker compose -f "$DOCKER_COMPOSE_FILE" up -d

sleep 30

docker compose -f "$DOCKER_COMPOSE_FILE" ps

if [ -f .env ]; then
    DOMAIN=$(grep "^DOMAIN=" .env | cut -d'=' -f2)
    echo "https://${DOMAIN}/"
fi
