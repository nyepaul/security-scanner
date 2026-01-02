#!/bin/bash
################################################################################
# Cron Job Setup Script for Security Scanner
# Configures periodic security scans
################################################################################

set -euo pipefail

SCRIPT_PATH="/home/paul/src/security-scanner/scripts/run-scan-and-email.sh"
CRON_SCHEDULE="0 2 * * *"  # Default: 2 AM daily

echo "Security Scanner - Cron Job Setup"
echo "=================================="
echo ""
echo "Current schedule options:"
echo "1. Daily at 2 AM (recommended)"
echo "2. Daily at 6 AM"
echo "3. Every 12 hours (2 AM and 2 PM)"
echo "4. Weekly on Monday at 2 AM"
echo "5. Custom schedule"
echo ""
read -p "Select schedule (1-5) [1]: " choice
choice=${choice:-1}

case $choice in
    1)
        CRON_SCHEDULE="0 2 * * *"
        DESCRIPTION="Daily at 2:00 AM"
        ;;
    2)
        CRON_SCHEDULE="0 6 * * *"
        DESCRIPTION="Daily at 6:00 AM"
        ;;
    3)
        CRON_SCHEDULE="0 2,14 * * *"
        DESCRIPTION="Every 12 hours (2:00 AM and 2:00 PM)"
        ;;
    4)
        CRON_SCHEDULE="0 2 * * 1"
        DESCRIPTION="Weekly on Monday at 2:00 AM"
        ;;
    5)
        echo ""
        echo "Enter custom cron schedule (e.g., '0 3 * * *' for 3 AM daily):"
        read -p "Schedule: " CRON_SCHEDULE
        DESCRIPTION="Custom: $CRON_SCHEDULE"
        ;;
    *)
        echo "Invalid choice, using default (Daily at 2 AM)"
        CRON_SCHEDULE="0 2 * * *"
        DESCRIPTION="Daily at 2:00 AM"
        ;;
esac

echo ""
echo "Selected schedule: $DESCRIPTION"
echo "Cron expression: $CRON_SCHEDULE"
echo ""

# Create cron job entry
CRON_ENTRY="$CRON_SCHEDULE $SCRIPT_PATH >> /home/paul/src/security-scanner/logs/cron.log 2>&1"

# Check if cron job already exists
if crontab -l 2>/dev/null | grep -q "security-scanner/scripts/run-scan-and-email.sh"; then
    echo "Existing security scanner cron job found."
    read -p "Do you want to replace it? (y/n) [y]: " replace
    replace=${replace:-y}

    if [ "$replace" = "y" ] || [ "$replace" = "Y" ]; then
        # Remove old entry and add new one
        (crontab -l 2>/dev/null | grep -v "security-scanner/scripts/run-scan-and-email.sh"; echo "$CRON_ENTRY") | crontab -
        echo "Cron job updated successfully!"
    else
        echo "Keeping existing cron job."
        exit 0
    fi
else
    # Add new entry
    (crontab -l 2>/dev/null; echo "# Security Scanner - $DESCRIPTION"; echo "$CRON_ENTRY") | crontab -
    echo "Cron job added successfully!"
fi

echo ""
echo "Current crontab:"
echo "==============="
crontab -l | grep -A1 "Security Scanner" || crontab -l | grep "security-scanner"

echo ""
echo "Setup complete!"
echo ""
echo "The security scanner will run automatically according to the schedule."
echo "Logs will be saved to: /home/paul/src/security-scanner/logs/"
echo "Reports will be saved to: /home/paul/src/security-scanner/reports/"
echo ""
echo "To view current cron jobs: crontab -l"
echo "To edit cron jobs manually: crontab -e"
echo "To remove the cron job: crontab -e (then delete the security-scanner line)"
