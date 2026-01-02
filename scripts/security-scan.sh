#!/bin/bash
################################################################################
# Comprehensive Security Scanner
# Performs localhost security assessment and generates detailed reports
################################################################################

set -eo pipefail

# Configuration
SCAN_DIR="/home/paul/src/security-scanner"
REPORT_DIR="${SCAN_DIR}/reports"
LOG_DIR="${SCAN_DIR}/logs"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_FILE="${REPORT_DIR}/security_report_${TIMESTAMP}.html"
JSON_FILE="${REPORT_DIR}/security_data_${TIMESTAMP}.json"
LOG_FILE="${LOG_DIR}/scan_${TIMESTAMP}.log"

# Colors for terminal output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $*" | tee -a "${LOG_FILE}"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" | tee -a "${LOG_FILE}"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*" | tee -a "${LOG_FILE}"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*" | tee -a "${LOG_FILE}"
}

# Initialize counters
CRITICAL_COUNT=0
HIGH_COUNT=0
MEDIUM_COUNT=0
LOW_COUNT=0
INFO_COUNT=0

# JSON data storage
declare -a FINDINGS=()

add_finding() {
    local severity="$1"
    local title="$2"
    local description="$3"
    local recommendation="$4"

    case "$severity" in
        CRITICAL) ((CRITICAL_COUNT++)) ;;
        HIGH) ((HIGH_COUNT++)) ;;
        MEDIUM) ((MEDIUM_COUNT++)) ;;
        LOW) ((LOW_COUNT++)) ;;
        INFO) ((INFO_COUNT++)) ;;
    esac

    local finding=$(cat <<EOF
{
    "severity": "$severity",
    "title": "$title",
    "description": "$description",
    "recommendation": "$recommendation",
    "timestamp": "$(date -Iseconds)"
}
EOF
)
    FINDINGS+=("$finding")
}

################################################################################
# SECURITY CHECKS
################################################################################

log "Starting comprehensive security scan..."

# 1. Network Services Scan
log "Checking network services and open ports..."
LISTENING_PORTS=$(ss -tuln 2>/dev/null | grep LISTEN || echo "")
if [ -n "$LISTENING_PORTS" ]; then
    PORT_COUNT=$(echo "$LISTENING_PORTS" | wc -l)
    log "Found $PORT_COUNT listening ports/services"

    # Check for common vulnerable ports
    if echo "$LISTENING_PORTS" | grep -q ":23 "; then
        add_finding "HIGH" "Telnet Service Detected" \
            "Telnet (port 23) is running and transmits data in cleartext" \
            "Disable telnet and use SSH instead"
    fi

    if echo "$LISTENING_PORTS" | grep -q ":21 "; then
        add_finding "HIGH" "FTP Service Detected" \
            "FTP (port 21) is running and may transmit credentials in cleartext" \
            "Disable FTP and use SFTP or SCP instead"
    fi

    if echo "$LISTENING_PORTS" | grep -q ":3389 "; then
        add_finding "MEDIUM" "RDP Service Detected" \
            "Remote Desktop Protocol detected on port 3389" \
            "Ensure RDP is properly secured with strong authentication"
    fi
fi

# 2. User Account Security
log "Auditing user accounts..."

# Check for users with empty passwords
EMPTY_PASS=$(awk -F: '($2 == "" ) { print $1 }' /etc/shadow 2>/dev/null || echo "")
if [ -n "$EMPTY_PASS" ]; then
    add_finding "CRITICAL" "Users with Empty Passwords" \
        "The following users have empty passwords: $EMPTY_PASS" \
        "Set strong passwords for all user accounts immediately"
fi

# Check for users with UID 0 (root privileges)
ROOT_USERS=$(awk -F: '($3 == "0") {print $1}' /etc/passwd)
ROOT_COUNT=$(echo "$ROOT_USERS" | wc -l)
if [ "$ROOT_COUNT" -gt 1 ]; then
    add_finding "HIGH" "Multiple Root-Level Accounts" \
        "Found $ROOT_COUNT accounts with UID 0: $ROOT_USERS" \
        "Only the root account should have UID 0"
fi

# Check for users with shell access
SHELL_USERS=$(grep -E '/bin/(bash|sh|zsh|fish)$' /etc/passwd | cut -d: -f1)
SHELL_COUNT=$(echo "$SHELL_USERS" | wc -l)
log "Found $SHELL_COUNT users with shell access"

# 3. File Permission Audit
log "Checking critical file permissions..."

# World-writable files in system directories
WORLD_WRITABLE=$(find /etc /usr/bin /usr/sbin -type f -perm -002 2>/dev/null | head -20 || echo "")
if [ -n "$WORLD_WRITABLE" ]; then
    WW_COUNT=$(echo "$WORLD_WRITABLE" | wc -l)
    add_finding "HIGH" "World-Writable System Files" \
        "Found $WW_COUNT world-writable files in system directories" \
        "Review and restrict permissions: chmod o-w <filename>"
fi

# Check SUID/SGID binaries
SUID_FILES=$(find /usr/bin /usr/sbin /bin /sbin -type f \( -perm -4000 -o -perm -2000 \) 2>/dev/null | head -30 || echo "")
if [ -n "$SUID_FILES" ]; then
    SUID_COUNT=$(echo "$SUID_FILES" | wc -l)
    log "Found $SUID_COUNT SUID/SGID binaries"
    add_finding "INFO" "SUID/SGID Binaries Inventory" \
        "Found $SUID_COUNT SUID/SGID binaries (normal, but review recommended)" \
        "Audit SUID/SGID binaries to ensure they are necessary"
fi

# 4. SSH Configuration Check
log "Auditing SSH configuration..."
if [ -f /etc/ssh/sshd_config ]; then
    # Check PermitRootLogin
    if grep -q "^PermitRootLogin yes" /etc/ssh/sshd_config 2>/dev/null; then
        add_finding "HIGH" "SSH Root Login Enabled" \
            "SSH is configured to allow direct root login" \
            "Set 'PermitRootLogin no' in /etc/ssh/sshd_config"
    fi

    # Check PasswordAuthentication
    if grep -q "^PasswordAuthentication yes" /etc/ssh/sshd_config 2>/dev/null; then
        add_finding "MEDIUM" "SSH Password Authentication Enabled" \
            "SSH allows password-based authentication (key-based is more secure)" \
            "Consider using key-based authentication and setting 'PasswordAuthentication no'"
    fi

    # Check for Protocol version
    if grep -q "^Protocol 1" /etc/ssh/sshd_config 2>/dev/null; then
        add_finding "CRITICAL" "SSH Protocol 1 Enabled" \
            "SSH is using deprecated and insecure Protocol 1" \
            "Use Protocol 2 only in /etc/ssh/sshd_config"
    fi
fi

# 5. Firewall Status
log "Checking firewall status..."
if command -v ufw &> /dev/null; then
    UFW_STATUS=$(ufw status 2>/dev/null | grep -i "Status:" || echo "unknown")
    if echo "$UFW_STATUS" | grep -qi "inactive"; then
        add_finding "MEDIUM" "Firewall Disabled (UFW)" \
            "UFW firewall is installed but inactive" \
            "Enable UFW: sudo ufw enable"
    fi
elif command -v firewall-cmd &> /dev/null; then
    if ! systemctl is-active --quiet firewalld 2>/dev/null; then
        add_finding "MEDIUM" "Firewall Disabled (firewalld)" \
            "firewalld is installed but not running" \
            "Enable firewalld: sudo systemctl enable --now firewalld"
    fi
else
    add_finding "LOW" "No Firewall Detected" \
        "No common firewall (ufw/firewalld) detected" \
        "Consider installing and configuring a firewall"
fi

# 6. Package Update Status
log "Checking for available security updates..."
if command -v apt &> /dev/null; then
    apt update -qq 2>/dev/null || true
    SECURITY_UPDATES=$(apt list --upgradable 2>/dev/null | grep -i security | wc -l || echo "0")
    if [ "$SECURITY_UPDATES" -gt 0 ]; then
        add_finding "HIGH" "Security Updates Available" \
            "$SECURITY_UPDATES security updates are available" \
            "Apply security updates: sudo apt upgrade"
    fi

    ALL_UPDATES=$(apt list --upgradable 2>/dev/null | wc -l || echo "0")
    if [ "$ALL_UPDATES" -gt 10 ]; then
        add_finding "MEDIUM" "Multiple Package Updates Available" \
            "$ALL_UPDATES total package updates are available" \
            "Regularly update system packages: sudo apt update && sudo apt upgrade"
    fi
elif command -v dnf &> /dev/null; then
    SECURITY_UPDATES=$(dnf updateinfo list security 2>/dev/null | wc -l || echo "0")
    if [ "$SECURITY_UPDATES" -gt 0 ]; then
        add_finding "HIGH" "Security Updates Available" \
            "$SECURITY_UPDATES security updates are available" \
            "Apply security updates: sudo dnf upgrade --security"
    fi
fi

# 7. Running Services Audit
log "Auditing running services..."
RUNNING_SERVICES=$(systemctl list-units --type=service --state=running 2>/dev/null | grep -c "running" || echo "0")
log "Found $RUNNING_SERVICES running services"

# Check for unnecessary services
for service in cups bluetooth avahi-daemon; do
    if systemctl is-active --quiet "$service" 2>/dev/null; then
        add_finding "LOW" "Potentially Unnecessary Service: $service" \
            "Service $service is running (may not be needed)" \
            "Review if $service is necessary for your system"
    fi
done

# 8. Check for failed login attempts
log "Checking for failed login attempts..."
if [ -f /var/log/auth.log ]; then
    FAILED_LOGINS=$(grep -i "failed password" /var/log/auth.log 2>/dev/null | tail -50 | wc -l || echo "0")
    if [ "$FAILED_LOGINS" -gt 20 ]; then
        add_finding "MEDIUM" "Multiple Failed Login Attempts" \
            "Detected $FAILED_LOGINS recent failed login attempts" \
            "Review /var/log/auth.log and consider implementing fail2ban"
    fi
fi

# 9. Check disk encryption
log "Checking disk encryption status..."
if ! command -v cryptsetup &> /dev/null; then
    add_finding "LOW" "Disk Encryption Tools Not Installed" \
        "cryptsetup is not installed (full disk encryption may not be configured)" \
        "Consider using LUKS for disk encryption"
else
    ENCRYPTED_VOLUMES=$(lsblk -o NAME,TYPE | grep -c "crypt" || echo "0")
    if [ "$ENCRYPTED_VOLUMES" -eq 0 ]; then
        add_finding "MEDIUM" "No Encrypted Volumes Detected" \
            "No encrypted disk volumes detected" \
            "Consider enabling full disk encryption for sensitive data"
    fi
fi

# 10. Check kernel version and support
log "Checking kernel version..."
KERNEL_VERSION=$(uname -r)
log "Running kernel: $KERNEL_VERSION"

# 11. Check for core dumps
log "Checking core dump configuration..."
if [ -f /proc/sys/kernel/core_pattern ]; then
    CORE_PATTERN=$(cat /proc/sys/kernel/core_pattern)
    if [ "$CORE_PATTERN" != "|/bin/false" ] && [ "$CORE_PATTERN" != "/dev/null" ]; then
        add_finding "LOW" "Core Dumps Enabled" \
            "System is configured to generate core dumps which may contain sensitive data" \
            "Disable core dumps or ensure they are stored securely"
    fi
fi

# 12. Check umask
log "Checking default umask..."
CURRENT_UMASK=$(umask)
if [ "$CURRENT_UMASK" != "0022" ] && [ "$CURRENT_UMASK" != "0027" ]; then
    add_finding "LOW" "Non-Standard umask" \
        "Current umask is $CURRENT_UMASK (recommended: 0022 or 0027)" \
        "Set secure default umask in /etc/profile"
fi

################################################################################
# Generate Reports
################################################################################

log "Generating security report..."

# Calculate risk score (0-100, higher is worse)
RISK_SCORE=$((CRITICAL_COUNT * 25 + HIGH_COUNT * 10 + MEDIUM_COUNT * 5 + LOW_COUNT * 2))
if [ $RISK_SCORE -gt 100 ]; then
    RISK_SCORE=100
fi

TOTAL_FINDINGS=$((CRITICAL_COUNT + HIGH_COUNT + MEDIUM_COUNT + LOW_COUNT + INFO_COUNT))

log_success "Scan complete!"
log "Total findings: $TOTAL_FINDINGS (Critical: $CRITICAL_COUNT, High: $HIGH_COUNT, Medium: $MEDIUM_COUNT, Low: $LOW_COUNT, Info: $INFO_COUNT)"
log "Risk Score: $RISK_SCORE/100"

# Save findings to JSON
echo "{" > "$JSON_FILE"
echo "  \"scan_timestamp\": \"$(date -Iseconds)\"," >> "$JSON_FILE"
echo "  \"hostname\": \"$(hostname)\"," >> "$JSON_FILE"
echo "  \"kernel\": \"$KERNEL_VERSION\"," >> "$JSON_FILE"
echo "  \"risk_score\": $RISK_SCORE," >> "$JSON_FILE"
echo "  \"summary\": {" >> "$JSON_FILE"
echo "    \"total\": $TOTAL_FINDINGS," >> "$JSON_FILE"
echo "    \"critical\": $CRITICAL_COUNT," >> "$JSON_FILE"
echo "    \"high\": $HIGH_COUNT," >> "$JSON_FILE"
echo "    \"medium\": $MEDIUM_COUNT," >> "$JSON_FILE"
echo "    \"low\": $LOW_COUNT," >> "$JSON_FILE"
echo "    \"info\": $INFO_COUNT" >> "$JSON_FILE"
echo "  }," >> "$JSON_FILE"
echo "  \"findings\": [" >> "$JSON_FILE"

# Add findings to JSON
FIRST=true
for finding in "${FINDINGS[@]}"; do
    if [ "$FIRST" = true ]; then
        FIRST=false
    else
        echo "," >> "$JSON_FILE"
    fi
    echo "$finding" >> "$JSON_FILE"
done

echo "  ]" >> "$JSON_FILE"
echo "}" >> "$JSON_FILE"

log "JSON report saved to: $JSON_FILE"

# Generate HTML report (will be done by separate script)
/home/paul/src/security-scanner/scripts/generate-html-report.py "$JSON_FILE" "$REPORT_FILE"

log_success "HTML report saved to: $REPORT_FILE"

# Output summary for email
echo "SCAN_COMPLETE:$REPORT_FILE:$RISK_SCORE:$TOTAL_FINDINGS:$CRITICAL_COUNT:$HIGH_COUNT"
