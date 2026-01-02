#!/bin/bash
################################################################################
# Email Report Sender for Security Scanner
# Sends HTML security reports via email
################################################################################

set -euo pipefail

# Configuration file
CONFIG_FILE="/home/paul/src/security-scanner/config/email-config.conf"

# Default values (will be overridden by config file)
EMAIL_TO="nyepaul@gmail.com"
EMAIL_FROM="security-scanner@$(hostname)"
EMAIL_METHOD="sendmail"  # Options: sendmail, mailx, msmtp, smtp
SMTP_SERVER=""
SMTP_PORT="587"
SMTP_USER=""
SMTP_PASS=""
SMTP_TLS="yes"

# Load configuration if exists
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

# Check if report file is provided
if [ $# -lt 1 ]; then
    echo "Usage: $0 <report_html_file> [risk_score] [total_findings] [critical_count] [high_count]"
    exit 1
fi

REPORT_FILE="$1"
RISK_SCORE="${2:-0}"
TOTAL_FINDINGS="${3:-0}"
CRITICAL_COUNT="${4:-0}"
HIGH_COUNT="${5:-0}"

if [ ! -f "$REPORT_FILE" ]; then
    echo "Error: Report file not found: $REPORT_FILE"
    exit 1
fi

HOSTNAME=$(hostname)
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Determine urgency level
if [ "$CRITICAL_COUNT" -gt 0 ] || [ "$RISK_SCORE" -gt 75 ]; then
    URGENCY="[URGENT]"
    PRIORITY="High"
elif [ "$HIGH_COUNT" -gt 0 ] || [ "$RISK_SCORE" -gt 50 ]; then
    URGENCY="[HIGH]"
    PRIORITY="Normal"
else
    URGENCY=""
    PRIORITY="Normal"
fi

SUBJECT="${URGENCY} Security Scan Report - ${HOSTNAME} - ${TIMESTAMP}"

################################################################################
# Email sending functions
################################################################################

send_via_sendmail() {
    echo "Sending email via sendmail..."

    (
        echo "To: $EMAIL_TO"
        echo "From: $EMAIL_FROM"
        echo "Subject: $SUBJECT"
        echo "Content-Type: text/html; charset=UTF-8"
        echo "MIME-Version: 1.0"
        echo ""
        cat "$REPORT_FILE"
    ) | sendmail -t
}

send_via_mailx() {
    echo "Sending email via mailx..."

    mailx -s "$SUBJECT" \
          -a "Content-Type: text/html" \
          "$EMAIL_TO" < "$REPORT_FILE"
}

send_via_msmtp() {
    echo "Sending email via msmtp..."

    (
        echo "To: $EMAIL_TO"
        echo "From: $EMAIL_FROM"
        echo "Subject: $SUBJECT"
        echo "Content-Type: text/html; charset=UTF-8"
        echo ""
        cat "$REPORT_FILE"
    ) | msmtp "$EMAIL_TO"
}

send_via_smtp_python() {
    echo "Sending email via Python SMTP..."

    python3 - <<EOF
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

# Read HTML content
with open("$REPORT_FILE", "r") as f:
    html_content = f.read()

# Create message
msg = MIMEMultipart("alternative")
msg["Subject"] = "$SUBJECT"
msg["From"] = "$EMAIL_FROM"
msg["To"] = "$EMAIL_TO"
msg["X-Priority"] = "1" if "$PRIORITY" == "High" else "3"

# Attach HTML
html_part = MIMEText(html_content, "html")
msg.attach(html_part)

# Send email
try:
    server = smtplib.SMTP("$SMTP_SERVER", $SMTP_PORT)
    if "$SMTP_TLS" == "yes":
        server.starttls()
    if "$SMTP_USER" and "$SMTP_PASS":
        server.login("$SMTP_USER", "$SMTP_PASS")
    server.send_message(msg)
    server.quit()
    print("Email sent successfully via SMTP!")
except Exception as e:
    print(f"Error sending email: {e}")
    exit(1)
EOF
}

send_via_curl_smtp() {
    echo "Sending email via curl SMTP..."

    # Create temporary email file
    TEMP_EMAIL=$(mktemp)
    trap "rm -f $TEMP_EMAIL" EXIT

    cat > "$TEMP_EMAIL" <<EOF
From: $EMAIL_FROM
To: $EMAIL_TO
Subject: $SUBJECT
Content-Type: text/html; charset=UTF-8
MIME-Version: 1.0

EOF
    cat "$REPORT_FILE" >> "$TEMP_EMAIL"

    if [ -n "$SMTP_USER" ] && [ -n "$SMTP_PASS" ]; then
        curl --url "smtp://${SMTP_SERVER}:${SMTP_PORT}" \
             --ssl-reqd \
             --mail-from "$EMAIL_FROM" \
             --mail-rcpt "$EMAIL_TO" \
             --user "${SMTP_USER}:${SMTP_PASS}" \
             --upload-file "$TEMP_EMAIL"
    else
        curl --url "smtp://${SMTP_SERVER}:${SMTP_PORT}" \
             --mail-from "$EMAIL_FROM" \
             --mail-rcpt "$EMAIL_TO" \
             --upload-file "$TEMP_EMAIL"
    fi
}

################################################################################
# Main execution
################################################################################

case "$EMAIL_METHOD" in
    sendmail)
        if command -v sendmail &> /dev/null; then
            send_via_sendmail
        else
            echo "Error: sendmail not found. Please install sendmail or configure a different EMAIL_METHOD"
            exit 1
        fi
        ;;
    mailx)
        if command -v mailx &> /dev/null; then
            send_via_mailx
        else
            echo "Error: mailx not found. Please install mailx or configure a different EMAIL_METHOD"
            exit 1
        fi
        ;;
    msmtp)
        if command -v msmtp &> /dev/null; then
            send_via_msmtp
        else
            echo "Error: msmtp not found. Please install msmtp or configure a different EMAIL_METHOD"
            exit 1
        fi
        ;;
    smtp)
        if command -v python3 &> /dev/null; then
            send_via_smtp_python
        else
            echo "Error: Python 3 not found. Please install Python 3 or configure a different EMAIL_METHOD"
            exit 1
        fi
        ;;
    curl)
        if command -v curl &> /dev/null; then
            send_via_curl_smtp
        else
            echo "Error: curl not found. Please install curl or configure a different EMAIL_METHOD"
            exit 1
        fi
        ;;
    *)
        echo "Error: Unknown EMAIL_METHOD: $EMAIL_METHOD"
        echo "Valid options: sendmail, mailx, msmtp, smtp, curl"
        exit 1
        ;;
esac

echo "Email report sent successfully to $EMAIL_TO"
echo "Subject: $SUBJECT"
echo "Risk Score: $RISK_SCORE/100"
echo "Total Findings: $TOTAL_FINDINGS (Critical: $CRITICAL_COUNT, High: $HIGH_COUNT)"
