#!/bin/bash
################################################################################
# Security Scanner Installation Script
# Installs systemd service and timer for automated security scanning
################################################################################

set -e

# Auto-detect script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_FILE="$SCRIPT_DIR/security-scanner.service"
TIMER_FILE="$SCRIPT_DIR/security-scanner.timer"

echo "=================================="
echo "Security Scanner Installation"
echo "=================================="
echo ""

# Check if running as root for systemd installation
if [ "$EUID" -ne 0 ]; then
    echo "Note: This script needs to be run with sudo to install systemd units"
    echo "Usage: sudo $0"
    exit 1
fi

# Verify files exist
if [ ! -f "$SERVICE_FILE" ]; then
    echo "Error: Service file not found: $SERVICE_FILE"
    exit 1
fi

if [ ! -f "$TIMER_FILE" ]; then
    echo "Error: Timer file not found: $TIMER_FILE"
    exit 1
fi

# Copy systemd unit files
echo "[1/5] Installing systemd service and timer..."
cp "$SERVICE_FILE" /etc/systemd/system/
cp "$TIMER_FILE" /etc/systemd/system/
echo "  - Copied security-scanner.service to /etc/systemd/system/"
echo "  - Copied security-scanner.timer to /etc/systemd/system/"

# Reload systemd
echo ""
echo "[2/5] Reloading systemd daemon..."
systemctl daemon-reload
echo "  - Systemd daemon reloaded"

# Enable the timer
echo ""
echo "[3/5] Enabling security scanner timer..."
systemctl enable security-scanner.timer
echo "  - Timer enabled (will start on boot)"

# Start the timer
echo ""
echo "[4/5] Starting security scanner timer..."
systemctl start security-scanner.timer
echo "  - Timer started"

# Show timer status
echo ""
echo "[5/5] Verifying installation..."
echo ""
systemctl status security-scanner.timer --no-pager || true
echo ""
echo "Next scheduled run:"
systemctl list-timers security-scanner.timer --no-pager
echo ""

echo "=================================="
echo "Installation Complete!"
echo "=================================="
echo ""
echo "The security scanner is now configured to run:"
echo "  - Every Sunday at 2:00 AM (±30 min random delay)"
echo "  - 15 minutes after system boot"
echo "  - Reports will be emailed to: nyepaul@gmail.com"
echo ""
echo "Useful commands:"
echo "  View timer status:    systemctl status security-scanner.timer"
echo "  View service status:  systemctl status security-scanner.service"
echo "  View logs:            journalctl -u security-scanner.service"
echo "  Run scan manually:    sudo systemctl start security-scanner.service"
echo "  Stop timer:           sudo systemctl stop security-scanner.timer"
echo "  Disable timer:        sudo systemctl disable security-scanner.timer"
echo ""
echo "Local reports saved to: $SCRIPT_DIR/reports/"
echo "Logs saved to: $SCRIPT_DIR/logs/"
echo ""
