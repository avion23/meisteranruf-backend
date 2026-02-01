import json
import urllib.request
import os

# Load API key from .env.local
with open(
    "/Users/avion/Documents.nosync/projects/vorzimmerdrache/.env.local", "r"
) as f:
    for line in f:
        if line.startswith("N8N_API_KEY="):
            api_key = line.strip().split("=", 1)[1]
            break

print(f"API Key: {api_key[:20]}...")


# Deploy function
def deploy(filepath, name):
    print(f"\nDeploying {name}...")
    with open(filepath, "r") as f:
        data = json.load(f)

    # Clean
    cleaned = {
        "name": data["name"],
        "nodes": [
            {k: v for k, v in n.items() if k not in ["id", "position", "webhookId"]}
            for n in data["nodes"]
        ],
        "connections": data.get("connections", {}),
        "settings": data.get("settings", {"executionOrder": "v1"}),
    }

    req = urllib.request.Request(
        "https://instance1.duckdns.org/api/v1/workflows",
        data=json.dumps(cleaned).encode(),
        headers={"X-N8N-API-KEY": api_key, "Content-Type": "application/json"},
        method="POST",
    )

    try:
        with urllib.request.urlopen(req) as resp:
            result = json.loads(resp.read())
            print(f"✅ Success: {result.get('data', {}).get('id', 'unknown')}")
            return True
    except Exception as e:
        print(f"❌ Failed: {e}")
        return False


# Deploy all
workflows = [
    (
        "/Users/avion/Documents.nosync/projects/vorzimmerdrache/workflows/roof-mode.json",
        "Roof-Mode",
    ),
    (
        "/Users/avion/Documents.nosync/projects/vorzimmerdrache/workflows/sms-opt-in.json",
        "SMS Opt-In",
    ),
    (
        "/Users/avion/Documents.nosync/projects/vorzimmerdrache/workflows/timeout-handler.json",
        "Timeout Handler",
    ),
]

for path, name in workflows:
    deploy(path, name)

print("\n✅ All deployments attempted")
