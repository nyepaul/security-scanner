#!/bin/bash
################################################################################
# Email Sender Script
# Sends HTML security reports via email using msmtp
################################################################################

RECIPIENT="nyepaul@gmail.com"
HOSTNAME=$(hostname)

send_html_email() {
    local html_file=$1
    local subject=$2

    if [ ! -f "$html_file" ]; then
        echo "Error: HTML file not found: $html_file"
        return 1
    fi

    # Create email with proper headers
    (
        echo "To: $RECIPIENT"
        echo "From: Security Scanner <security@$HOSTNAME>"
        echo "Subject: $subject"
        echo "Content-Type: text/html; charset=UTF-8"
        echo "MIME-Version: 1.0"
        echo ""
        cat "$html_file"
    ) | msmtp -t

    if [ $? -eq 0 ]; then
        echo "Email sent successfully to $RECIPIENT"
        return 0
    else
        echo "Failed to send email"
        return 1
    fi
}

# If script is called directly
if [ $# -eq 2 ]; then
    send_html_email "$1" "$2"
elif [ $# -eq 1 ]; then
    send_html_email "$1" "Security Scan Report - $HOSTNAME - $(date '+%Y-%m-%d %H:%M')"
else
    echo "Usage: $0 <html_file> [subject]"
    exit 1
fi
