#!/bin/bash
################################################################################
# Production Deployment Script
# Deploys Security Scanner from development to production location
################################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DEV_DIR="/home/paul/src/security-scanner"
PROD_DIR="/opt/security-scanner"
VERSION=$(cat "$DEV_DIR/VERSION" 2>/dev/null || echo "unknown")

echo -e "${BLUE}=================================="
echo "Security Scanner Production Deployment"
echo "Version: $VERSION"
echo -e "==================================${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}ERROR: This script must be run with sudo${NC}"
    echo "Usage: sudo ./deploy-production.sh"
    exit 1
fi

# Backup existing production if it exists
if [ -d "$PROD_DIR" ]; then
    BACKUP_DIR="/opt/security-scanner.backup.$(date +%Y%m%d_%H%M%S)"
    echo -e "${YELLOW}[1/8] Backing up existing production to: $BACKUP_DIR${NC}"
    mv "$PROD_DIR" "$BACKUP_DIR"
    echo "  ✓ Backup created"
else
    echo -e "${GREEN}[1/8] No existing production installation found${NC}"
fi

# Create production directory
echo ""
echo -e "${BLUE}[2/8] Creating production directory: $PROD_DIR${NC}"
mkdir -p "$PROD_DIR"
echo "  ✓ Directory created"

# Copy files to production
echo ""
echo -e "${BLUE}[3/8] Copying files to production...${NC}"
cp -r "$DEV_DIR"/* "$PROD_DIR/"
echo "  ✓ Files copied"

# Create production directories if they don't exist
echo ""
echo -e "${BLUE}[4/8] Setting up production directory structure...${NC}"
mkdir -p "$PROD_DIR/reports"
mkdir -p "$PROD_DIR/logs"
mkdir -p "$PROD_DIR/config"
echo "  ✓ Directory structure created"

# Update configuration for production paths
echo ""
echo -e "${BLUE}[5/8] Updating configuration for production paths...${NC}"
sed -i "s|INSTALL_DIR=\"/home/paul/src/security-scanner\"|INSTALL_DIR=\"$PROD_DIR\"|g" "$PROD_DIR/config/scanner.conf"
echo "  ✓ Configuration updated"

# Update systemd unit files for production
echo ""
echo -e "${BLUE}[6/8] Updating systemd unit files for production...${NC}"
sed -i "s|/home/paul/src/security-scanner|$PROD_DIR|g" "$PROD_DIR/security-scanner.service"
sed -i "s|/home/paul/src/security-scanner|$PROD_DIR|g" "$PROD_DIR/security-scanner.timer"
echo "  ✓ Systemd files updated"

# Set ownership and permissions
echo ""
echo -e "${BLUE}[7/8] Setting ownership and permissions...${NC}"
chown -R paul:paul "$PROD_DIR"
chmod -R 755 "$PROD_DIR"
chmod +x "$PROD_DIR"/*.sh
chmod +x "$PROD_DIR"/modules/*.sh
chmod 644 "$PROD_DIR/config/scanner.conf"
chmod 755 "$PROD_DIR/reports"
chmod 755 "$PROD_DIR/logs"
echo "  ✓ Permissions set"

# Make scripts executable
echo ""
echo -e "${BLUE}[8/8] Making scripts executable...${NC}"
chmod +x "$PROD_DIR/security-scan.sh"
chmod +x "$PROD_DIR/send-email.sh"
chmod +x "$PROD_DIR/install.sh"
chmod +x "$PROD_DIR/modules"/*.sh
echo "  ✓ Scripts are executable"

echo ""
echo -e "${GREEN}=================================="
echo "Production Deployment Complete!"
echo -e "==================================${NC}"
echo ""
echo "Production location: $PROD_DIR"
echo "Version deployed: $VERSION"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo ""
echo "1. Install systemd timer:"
echo "   cd $PROD_DIR && sudo ./install.sh"
echo ""
echo "2. Run a test scan:"
echo "   $PROD_DIR/security-scan.sh"
echo ""
echo "3. View reports:"
echo "   ls -lh $PROD_DIR/reports/"
echo ""
echo "4. Check logs:"
echo "   tail -f $PROD_DIR/logs/scan_*.log"
echo ""
echo -e "${GREEN}Deployment Summary:${NC}"
echo "  ✓ Files deployed to: $PROD_DIR"
echo "  ✓ Configuration updated for production"
echo "  ✓ Permissions set correctly"
echo "  ✓ Scripts are executable"
echo "  ✓ Ready for systemd installation"
echo ""
