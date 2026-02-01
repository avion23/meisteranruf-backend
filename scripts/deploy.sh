#!/bin/bash
# Deploy workflows to n8n via API
# Usage: ./deploy.sh [production|staging]

set -e

ENV=${1:-production}
N8N_HOST=${N8N_HOST:-"instance1.duckdns.org"}

# Load .env.local if exists
SCRIPT_DIR="$(dirname "$0")"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

if [ -f "$PROJECT_DIR/.env.local" ]; then
    export $(grep -v '^#' "$PROJECT_DIR/.env.local" | xargs)
fi

N8N_API_KEY=${N8N_API_KEY:-""}
WORKFLOW_DIR="$PROJECT_DIR/workflows"

echo "🚀 Deploying workflows to n8n ($ENV)..."

# Check prerequisites
if [ -z "$N8N_API_KEY" ]; then
    echo "❌ Error: N8N_API_KEY not set"
    echo "Set it with: export N8N_API_KEY=your_api_key"
    exit 1
fi

# Function to clean and deploy a workflow
deploy_workflow() {
    local file=$1
    local name=$(basename "$file" .json)
    
    echo "📤 Deploying: $name"
    
    # Clean workflow JSON - remove UI-specific fields
    local cleaned=$(cat "$file" | jq '{
        name: .name,
        nodes: [.nodes[] | del(.id, .position, .webhookId)],
        connections: .connections,
        settings: .settings
    }')
    
    # Import workflow via API
    curl -s -X POST "https://$N8N_HOST/api/v1/workflows" \
        -H "X-N8N-API-KEY: $N8N_API_KEY" \
        -H "Content-Type: application/json" \
        -d "$cleaned" | jq -r '.data.id // .message'
}

# Deploy each workflow
for workflow in "$WORKFLOW_DIR"/*.json; do
    if [ -f "$workflow" ]; then
        deploy_workflow "$workflow"
    fi
done

echo "✅ Deployment complete!"
