#!/bin/bash
################################################################################
# Main Security Scanner Wrapper
# Executes scan and sends email report
################################################################################

set -euo pipefail

SCRIPT_DIR="/home/paul/src/security-scanner/scripts"
LOG_DIR="/home/paul/src/security-scanner/logs"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
WRAPPER_LOG="${LOG_DIR}/wrapper_${TIMESTAMP}.log"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$WRAPPER_LOG"
}

log "Starting security scan wrapper..."

# Run the security scan
log "Executing security scan..."
SCAN_OUTPUT=$("${SCRIPT_DIR}/security-scan.sh" 2>&1 | tee -a "$WRAPPER_LOG")

# Parse the scan output
SCAN_RESULT=$(echo "$SCAN_OUTPUT" | grep "^SCAN_COMPLETE:" || echo "")

if [ -z "$SCAN_RESULT" ]; then
    log "ERROR: Scan did not complete successfully"
    exit 1
fi

# Extract values from scan result
# Format: SCAN_COMPLETE:report_file:risk_score:total:critical:high
REPORT_FILE=$(echo "$SCAN_RESULT" | cut -d: -f2)
RISK_SCORE=$(echo "$SCAN_RESULT" | cut -d: -f3)
TOTAL_FINDINGS=$(echo "$SCAN_RESULT" | cut -d: -f4)
CRITICAL_COUNT=$(echo "$SCAN_RESULT" | cut -d: -f5)
HIGH_COUNT=$(echo "$SCAN_RESULT" | cut -d: -f6)

log "Scan completed successfully"
log "Report: $REPORT_FILE"
log "Risk Score: $RISK_SCORE/100"
log "Findings: $TOTAL_FINDINGS (Critical: $CRITICAL_COUNT, High: $HIGH_COUNT)"

# Send email report
log "Sending email report..."
if "${SCRIPT_DIR}/send-email-report.sh" "$REPORT_FILE" "$RISK_SCORE" "$TOTAL_FINDINGS" "$CRITICAL_COUNT" "$HIGH_COUNT" 2>&1 | tee -a "$WRAPPER_LOG"; then
    log "Email sent successfully"
else
    log "ERROR: Failed to send email report"
    log "Report is still available at: $REPORT_FILE"
    exit 1
fi

log "Security scan and email process completed successfully"
