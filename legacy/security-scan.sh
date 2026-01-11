#!/bin/bash
################################################################################
# Comprehensive Security Scanner
# Orchestrates multiple security scanning modules and generates HTML reports
# Version: 1.1.0
# License: MIT
# Author: Security Scanner Team
################################################################################

set -euo pipefail

# Default settings
SKIP_EMAIL=false

# Determine script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Detect OS
detect_os() {
    case "$(uname -s)" in
        Linux*)
            OS="Linux"
            ;;
        Darwin*)
            OS="macOS"
            ;;
        *)
            OS="Unknown"
            ;;
    esac
}

# Auto-detect OS at startup
detect_os

# Load version
VERSION="1.1.0"
if [ -f "$SCRIPT_DIR/VERSION" ]; then
    VERSION=$(cat "$SCRIPT_DIR/VERSION" | tr -d '[:space:]')
fi

# Load configuration file
CONFIG_FILE="$SCRIPT_DIR/config/scanner.conf"
if [ -f "$CONFIG_FILE" ]; then
    # shellcheck disable=SC1090
    source "$CONFIG_FILE"
else
    echo "ERROR: Configuration file not found: $CONFIG_FILE"
    exit 1
fi

# Set derived paths (allow override from config)
INSTALL_DIR="${INSTALL_DIR:-$SCRIPT_DIR}"
MODULES_DIR="${MODULES_DIR:-modules}"
REPORTS_DIR="${REPORTS_DIR:-reports}"
LOGS_DIR="${LOGS_DIR:-logs}"
SCRIPTS_DIR="${INSTALL_DIR}/scripts"

# Convert relative paths to absolute
[[ "$MODULES_DIR" = /* ]] || MODULES_DIR="$INSTALL_DIR/$MODULES_DIR"
[[ "$REPORTS_DIR" = /* ]] || REPORTS_DIR="$INSTALL_DIR/$REPORTS_DIR"
[[ "$LOGS_DIR" = /* ]] || LOGS_DIR="$INSTALL_DIR/$LOGS_DIR"

# Email configuration from config file
EMAIL_RECIPIENT="${EMAIL_RECIPIENT:-root@localhost}"

# Timestamp for this scan
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_FILE="$REPORTS_DIR/security_report_${TIMESTAMP}.html"
LOG_FILE="$LOGS_DIR/scan_${TIMESTAMP}.log"

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --test|--no-email)
                SKIP_EMAIL=true
                shift
                ;;
            --help|-h)
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --test, --no-email    Run in test mode (skip email sending)"
                echo "  --help, -h            Show this help message"
                echo ""
                echo "Examples:"
                echo "  $0                    Run full scan with email"
                echo "  $0 --test             Run scan without sending email"
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done
}

# Check for critical environment issues and offer to run install.sh
check_environment_health() {
    local issues_found=false
    local issue_list=""

    # Check if config paths match current OS
    if [ "$OS" = "macOS" ]; then
        if [[ "$INSTALL_DIR" == /home/* ]]; then
            issues_found=true
            issue_list="${issue_list}\n  - Configuration has Linux paths but running on macOS"
        fi
    elif [ "$OS" = "Linux" ]; then
        if [[ "$INSTALL_DIR" == /Users/* ]]; then
            issues_found=true
            issue_list="${issue_list}\n  - Configuration has macOS paths but running on Linux"
        fi
    fi

    # Check if critical dependencies are missing
    if ! command -v nmap &> /dev/null; then
        issues_found=true
        issue_list="${issue_list}\n  - nmap is not installed (required for network scanning)"
    fi

    # If issues found, offer to run install script
    if [ "$issues_found" = true ]; then
        echo ""
        echo "========================================"
        echo "⚠  ENVIRONMENT ISSUES DETECTED"
        echo "========================================"
        echo -e "$issue_list"
        echo ""
        echo "The install.sh script can fix these issues automatically."
        echo ""
        read -p "Run install.sh now? (y/n): " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo ""
            echo "Running installation script..."
            bash "$SCRIPT_DIR/install.sh"
            echo ""
            echo "Installation complete. Please run the scanner again."
            exit 0
        else
            echo ""
            echo "Continuing with current configuration..."
            echo "You can run install.sh manually later: $SCRIPT_DIR/install.sh"
            echo ""
            sleep 2
        fi
    fi
}

# Environment setup - ensures required directories exist
setup_environment() {
    local setup_needed=false

    # Create reports directory if it doesn't exist
    if [ ! -d "$REPORTS_DIR" ]; then
        echo "Creating reports directory: $REPORTS_DIR"
        mkdir -p "$REPORTS_DIR"
        setup_needed=true
    fi

    # Create logs directory if it doesn't exist
    if [ ! -d "$LOGS_DIR" ]; then
        echo "Creating logs directory: $LOGS_DIR"
        mkdir -p "$LOGS_DIR"
        setup_needed=true
    fi

    # Create .gitignore for reports and logs if they don't exist
    if [ ! -f "$REPORTS_DIR/.gitignore" ]; then
        echo "*.html" > "$REPORTS_DIR/.gitignore"
    fi

    if [ ! -f "$LOGS_DIR/.gitignore" ]; then
        echo "*.log" > "$LOGS_DIR/.gitignore"
    fi

    # Verify directories are writable
    if [ ! -w "$REPORTS_DIR" ]; then
        echo "ERROR: Reports directory is not writable: $REPORTS_DIR"
        exit 1
    fi

    if [ ! -w "$LOGS_DIR" ]; then
        echo "ERROR: Logs directory is not writable: $LOGS_DIR"
        exit 1
    fi

    if [ "$setup_needed" = true ]; then
        echo "Environment setup complete"
        echo ""
    fi
}

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

# Dependency validation
check_dependencies() {
    local missing_deps=()
    local optional_deps=()

    # Required dependencies
    local required_tools=("bash" "date" "hostname" "grep" "awk" "sed" "jq" "python3")

    # Optional but recommended dependencies
    local optional_tools=("nmap" "ss" "msmtp" "chkrootkit")

    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing_deps+=("$tool")
        fi
    done

    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo "ERROR: Missing required dependencies: ${missing_deps[*]}"
        echo "Please install them before running the scanner."
        exit 1
    fi

    for tool in "${optional_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            optional_deps+=("$tool")
        fi
    done

    if [ ${#optional_deps[@]} -gt 0 ]; then
        log "WARNING: Optional tools not found: ${optional_deps[*]}"
        log "Some features may be limited. Install them for full functionality."
    fi

    # Check if modules directory exists
    if [ ! -d "$MODULES_DIR" ]; then
        echo "ERROR: Modules directory not found: $MODULES_DIR"
        exit 1
    fi

    # Check if module scripts exist
    for module in "network_scan.sh" "vulnerability_scan.sh" "localhost_audit.sh"; do
        if [ ! -f "$MODULES_DIR/$module" ]; then
            echo "ERROR: Module not found: $MODULES_DIR/$module"
            exit 1
        fi
    done
}

# Send email report
send_email_report() {
    local report_file=$1
    local subject="Security Scan Report - $(hostname) - $(date '+%Y-%m-%d %H:%M')"

    log "Preparing to send email report to $EMAIL_RECIPIENT"

    # Use dedicated email script
    if [ -x "$SCRIPT_DIR/send-email.sh" ]; then
        log "Sending email via msmtp..."
        if "$SCRIPT_DIR/send-email.sh" "$report_file" "$subject" >> "$LOG_FILE" 2>&1; then
            log "Email sent successfully to $EMAIL_RECIPIENT"
            return 0
        else
            log "WARNING: Email sending failed via msmtp"
        fi
    fi

    # Fallback: Try sendmail
    if command -v msmtp &> /dev/null; then
        log "Trying msmtp directly..."
        (
            echo "To: $EMAIL_RECIPIENT"
            echo "From: Security Scanner <security@$(hostname)>"
            echo "Subject: $subject"
            echo "Content-Type: text/html; charset=UTF-8"
            echo "MIME-Version: 1.0"
            echo ""
            cat "$report_file"
        ) | msmtp -t >> "$LOG_FILE" 2>&1

        if [ $? -eq 0 ]; then
            log "Email sent successfully via msmtp fallback"
            return 0
        fi
    fi

    log "WARNING: Could not send email - check msmtp configuration"
    log "Report saved locally at: $report_file"
    return 1
}

################################################################################
# Main Execution
################################################################################

main() {
    # Parse command line arguments
    parse_arguments "$@"

    # Check environment health and offer to run install.sh if needed
    check_environment_health

    # Setup environment (create directories, etc.)
    setup_environment

    log "==================== Security Scan Started ===================="
    log "Operating System: $OS"
    log "Version: $VERSION"
    log "Scan ID: $TIMESTAMP"
    log "Report will be saved to: $REPORT_FILE"

    if [ "$SKIP_EMAIL" = true ]; then
        log "Test mode: Email sending is DISABLED"
    fi

    # Validate dependencies
    log "Checking dependencies..."
    check_dependencies

    # Make modules executable
    chmod +x "$MODULES_DIR"/*.sh 2>/dev/null || true
    
    # Create temporary directory for JSON partials
    TMP_DIR=$(mktemp -d)
    trap 'rm -rf "$TMP_DIR"' EXIT
    log "Created temporary directory: $TMP_DIR"

    # --- Run Modules ---
    
    # 1. Network Scan
    log "Running network discovery and port scan module..."
    if bash "$MODULES_DIR/network_scan.sh" --json > "$TMP_DIR/network.json"; then
        log "Network scan completed successfully"
    else
        log "WARNING: Network scan module encountered errors"
        echo "{}" > "$TMP_DIR/network.json"
    fi

    # 2. Vulnerability Scan
    log "Running vulnerability scan module..."
    if bash "$MODULES_DIR/vulnerability_scan.sh" --json > "$TMP_DIR/vuln.json"; then
        log "Vulnerability scan completed successfully"
    else
        log "ERROR: Vulnerability scan module failed"
        echo '{"summary": {"critical": 0, "high": 0, "medium": 0, "low": 0}, "findings": []}' > "$TMP_DIR/vuln.json"
    fi

    # 3. Localhost Audit
    log "Running localhost security audit module..."
    if bash "$MODULES_DIR/localhost_audit.sh" --json > "$TMP_DIR/audit.json"; then
        log "Localhost audit completed successfully"
    else
        log "WARNING: Localhost audit module encountered errors"
        echo "{}" > "$TMP_DIR/audit.json"
    fi

    # --- Data Aggregation & Risk Calculation ---
    log "Aggregating data and calculating risk score..."

    # Use configured weights for risk calculation
    WEIGHT_CRITICAL=${WEIGHT_CRITICAL:-10}
    WEIGHT_HIGH=${WEIGHT_HIGH:-5}
    WEIGHT_MEDIUM=${WEIGHT_MEDIUM:-2}
    WEIGHT_LOW=${WEIGHT_LOW:-1}

    # Aggregate into master.json
    MASTER_JSON="$TMP_DIR/master.json"
    
    jq -n \
      --slurpfile net "$TMP_DIR/network.json" \
      --slurpfile vuln "$TMP_DIR/vuln.json" \
      --slurpfile audit "$TMP_DIR/audit.json" \
      --arg hostname "$(hostname)" \
      --arg w_crit "$WEIGHT_CRITICAL" \
      --arg w_high "$WEIGHT_HIGH" \
      --arg w_med "$WEIGHT_MEDIUM" \
      --arg w_low "$WEIGHT_LOW" \
      '
      ($vuln[0].summary.critical // 0) as $crit |
      ($vuln[0].summary.high // 0) as $high |
      ($vuln[0].summary.medium // 0) as $med |
      ($vuln[0].summary.low // 0) as $low |
      
      (($crit * ($w_crit|tonumber)) + ($high * ($w_high|tonumber)) + ($med * ($w_med|tonumber)) + ($low * ($w_low|tonumber))) as $score |
      
      {
         scan_timestamp: (now | todate),
         hostname: $hostname,
         kernel: ($audit[0].data.system.kernel // "Unknown"),
         risk_score: $score,
         summary: {
           total: ($crit + $high + $med + $low),
           critical: $crit,
           high: $high,
           medium: $med,
           low: $low,
           info: 0
         },
         findings: ($vuln[0].findings // []),
         modules: {
           network: ($net[0] // {}),
           audit: ($audit[0] // {})
         }
       }
      ' > "$MASTER_JSON"

    log "Master JSON generated"

    # --- Report Generation ---
    log "Generating HTML report..."
    
    if python3 "$SCRIPTS_DIR/generate-html-report.py" "$MASTER_JSON" "$REPORT_FILE"; then
        log "Report generation complete: $REPORT_FILE"
    else
        log "ERROR: HTML report generation failed"
        exit 1
    fi

    # --- Email Delivery ---
    # Send email (unless in test mode)
    if [ "$SKIP_EMAIL" = true ]; then
        log "Test mode: Skipping email delivery"
        log "Report available at: $REPORT_FILE"
    else
        send_email_report "$REPORT_FILE"
    fi

    log "==================== Security Scan Completed ===================="
}

# Execute main function
main "$@"
