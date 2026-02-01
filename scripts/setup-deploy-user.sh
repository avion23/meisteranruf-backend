#!/bin/bash
# Setup dedicated deployment user on VPS (run once as root)
# This replaces insecure root login with a dedicated deploy user

set -e

DEPLOY_USER="${DEPLOY_USER:-deploy}"
PROJECT_DIR="/opt/vorzimmerdrache"

echo "🔐 Setting up secure deployment user: $DEPLOY_USER"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "❌ Please run as root (or with sudo)"
    exit 1
fi

# Create deploy user if not exists
if id "$DEPLOY_USER" &>/dev/null; then
    echo "✅ User $DEPLOY_USER already exists"
else
    echo "👤 Creating user $DEPLOY_USER..."
    useradd -m -s /bin/bash -d /home/$DEPLOY_USER $DEPLOY_USER
    echo "✅ User created"
fi

# Add to docker group for n8n management
usermod -aG docker $DEPLOY_USER
echo "✅ Added to docker group"

# Create project directory with correct permissions
mkdir -p $PROJECT_DIR
chown -R $DEPLOY_USER:$DEPLOY_USER $PROJECT_DIR
echo "✅ Project directory $PROJECT_DIR created"

# Setup SSH directory
SSH_DIR="/home/$DEPLOY_USER/.ssh"
mkdir -p $SSH_DIR
touch $SSH_DIR/authorized_keys
chmod 700 $SSH_DIR
chmod 600 $SSH_DIR/authorized_keys
chown -R $DEPLOY_USER:$DEPLOY_USER $SSH_DIR
echo "✅ SSH directory configured"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎉 Setup complete!"
echo ""
echo "NEXT STEPS:"
echo "1. Add your SSH public key to:"
echo "   $SSH_DIR/authorized_keys"
echo ""
echo "2. From your local machine:"
echo "   ssh-copy-id $DEPLOY_USER@instance1.duckdns.org"
echo ""
echo "3. Test deployment:"
echo "   export VPS_HOST=$DEPLOY_USER@instance1.duckdns.org"
echo "   ./scripts/deploy.sh"
echo ""
echo "4. (Optional) Disable root login in /etc/ssh/sshd_config:"
echo "   PermitRootLogin no"
echo "   systemctl restart sshd"
echo ""
