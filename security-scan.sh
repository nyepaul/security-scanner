#!/bin/bash
################################################################################
# Comprehensive Security Scanner
# Orchestrates multiple security scanning modules and generates HTML reports
# Version: 1.0.0
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
VERSION="1.0.0"
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

# Vulnerability counters (will be populated by modules)
TOTAL_CRITICAL=0
TOTAL_HIGH=0
TOTAL_MEDIUM=0
TOTAL_LOW=0

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
    local required_tools=("bash" "date" "hostname" "grep" "awk" "sed")

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

# Calculate risk score
calculate_risk_score() {
    local critical=$1
    local high=$2
    local medium=$3
    local low=$4

    # Use configured weights
    local weight_crit=${WEIGHT_CRITICAL:-10}
    local weight_high=${WEIGHT_HIGH:-5}
    local weight_med=${WEIGHT_MEDIUM:-2}
    local weight_low=${WEIGHT_LOW:-1}

    local score=$((critical * weight_crit + high * weight_high + medium * weight_med + low * weight_low))
    echo $score
}

# Generate HTML report header
generate_html_header() {
    cat <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Security Assessment Report - $(date '+%Y-%m-%d %H:%M')</title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            line-height: 1.6;
            color: #333;
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
            background-color: #f5f5f5;
        }
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 30px;
            border-radius: 10px;
            margin-bottom: 30px;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
        }
        .header h1 {
            margin: 0 0 10px 0;
        }
        .executive-summary {
            background: white;
            padding: 25px;
            border-radius: 10px;
            margin-bottom: 30px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .metrics-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
            margin: 20px 0;
        }
        .metric-card {
            background: white;
            padding: 20px;
            border-radius: 8px;
            text-align: center;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .metric-card .number {
            font-size: 36px;
            font-weight: bold;
            margin: 10px 0;
        }
        .metric-card .label {
            color: #666;
            font-size: 14px;
            text-transform: uppercase;
        }
        .critical { color: #dc3545; }
        .high { color: #fd7e14; }
        .medium { color: #ffc107; }
        .low { color: #17a2b8; }
        .risk-gauge {
            width: 100%;
            height: 30px;
            background: #e9ecef;
            border-radius: 15px;
            overflow: hidden;
            margin: 20px 0;
        }
        .risk-fill {
            height: 100%;
            background: linear-gradient(90deg, #28a745, #ffc107, #fd7e14, #dc3545);
            transition: width 0.5s ease;
        }
        .section {
            background: white;
            padding: 25px;
            border-radius: 10px;
            margin-bottom: 20px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        table {
            width: 100%;
            border-collapse: collapse;
            margin: 15px 0;
        }
        th, td {
            padding: 12px;
            text-align: left;
            border-bottom: 1px solid #ddd;
        }
        th {
            background-color: #f8f9fa;
            font-weight: 600;
        }
        pre {
            background: #f8f9fa;
            padding: 15px;
            border-radius: 5px;
            overflow-x: auto;
            border-left: 4px solid #667eea;
        }
        .footer {
            text-align: center;
            margin-top: 40px;
            padding: 20px;
            color: #666;
            font-size: 14px;
        }
        .timestamp {
            color: rgba(255,255,255,0.9);
            font-size: 14px;
        }
        h2 {
            color: #667eea;
            border-bottom: 2px solid #667eea;
            padding-bottom: 10px;
        }
        h3 {
            color: #764ba2;
            margin-top: 20px;
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>Security Assessment Report</h1>
        <div class="timestamp">Generated: $(date '+%Y-%m-%d %H:%M:%S %Z')</div>
        <div class="timestamp">Hostname: $(hostname)</div>
    </div>
EOF
}

# Generate executive summary
generate_executive_summary() {
    local risk_score=$1
    local risk_percent=$((risk_score > 100 ? 100 : risk_score))

    # Use configured thresholds
    local threshold_crit=${RISK_CRITICAL_THRESHOLD:-50}
    local threshold_high=${RISK_HIGH_THRESHOLD:-30}
    local threshold_med=${RISK_MEDIUM_THRESHOLD:-15}

    local risk_level="LOW"
    local risk_color="#28a745"

    if [ $risk_score -ge $threshold_crit ]; then
        risk_level="CRITICAL"
        risk_color="#dc3545"
    elif [ $risk_score -ge $threshold_high ]; then
        risk_level="HIGH"
        risk_color="#fd7e14"
    elif [ $risk_score -ge $threshold_med ]; then
        risk_level="MEDIUM"
        risk_color="#ffc107"
    fi

    cat <<EOF
    <div class="executive-summary">
        <h2>Executive Summary</h2>
        <p>This automated security assessment evaluated the security posture of <strong>$(hostname)</strong>
        across multiple dimensions including network exposure, vulnerability detection, and localhost security configuration.</p>

        <div style="text-align: center; margin: 30px 0;">
            <div style="font-size: 18px; color: #666;">Overall Risk Score</div>
            <div style="font-size: 48px; font-weight: bold; color: $risk_color; margin: 10px 0;">$risk_score</div>
            <div style="font-size: 20px; font-weight: bold; color: $risk_color;">RISK LEVEL: $risk_level</div>
            <div class="risk-gauge">
                <div class="risk-fill" style="width: ${risk_percent}%;"></div>
            </div>
        </div>

        <div class="metrics-grid">
            <div class="metric-card">
                <div class="label">Critical Findings</div>
                <div class="number critical">$TOTAL_CRITICAL</div>
            </div>
            <div class="metric-card">
                <div class="label">High Severity</div>
                <div class="number high">$TOTAL_HIGH</div>
            </div>
            <div class="metric-card">
                <div class="label">Medium Severity</div>
                <div class="number medium">$TOTAL_MEDIUM</div>
            </div>
            <div class="metric-card">
                <div class="label">Low Severity</div>
                <div class="number low">$TOTAL_LOW</div>
            </div>
        </div>

        <h3>Key Findings</h3>
        <ul>
            <li><strong>Total Vulnerabilities:</strong> $((TOTAL_CRITICAL + TOTAL_HIGH + TOTAL_MEDIUM + TOTAL_LOW))</li>
            <li><strong>Immediate Action Required:</strong> $((TOTAL_CRITICAL + TOTAL_HIGH)) critical/high severity issues</li>
            <li><strong>Scan Duration:</strong> Comprehensive multi-module assessment</li>
        </ul>
    </div>
EOF
}

# Generate HTML footer
generate_html_footer() {
    cat <<EOF
    <div class="footer">
        <p>This report was automatically generated by the Security Scanner System v$VERSION</p>
        <p>Next scan scheduled according to configured timer</p>
        <p>For questions or concerns, review the detailed findings above</p>
    </div>
</body>
</html>
EOF
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

    # Start HTML report
    generate_html_header > "$REPORT_FILE"

    # Run vulnerability scan module and capture counts
    log "Running vulnerability scan module..."
    if VULN_OUTPUT=$(bash "$MODULES_DIR/vulnerability_scan.sh" 2>&1); then
        # Extract vulnerability counts
        TOTAL_CRITICAL=$(echo "$VULN_OUTPUT" | grep "^CRITICAL=" | cut -d= -f2 || echo "0")
        TOTAL_HIGH=$(echo "$VULN_OUTPUT" | grep "^HIGH=" | cut -d= -f2 || echo "0")
        TOTAL_MEDIUM=$(echo "$VULN_OUTPUT" | grep "^MEDIUM=" | cut -d= -f2 || echo "0")
        TOTAL_LOW=$(echo "$VULN_OUTPUT" | grep "^LOW=" | cut -d= -f2 || echo "0")

        # Remove count lines from output
        VULN_HTML=$(echo "$VULN_OUTPUT" | grep -v "^CRITICAL=\|^HIGH=\|^MEDIUM=\|^LOW=")
    else
        log "ERROR: Vulnerability scan module failed"
        VULN_HTML="<p style='color: red;'>Vulnerability scan failed to execute. Check logs for details.</p>"
        TOTAL_CRITICAL=0
        TOTAL_HIGH=0
        TOTAL_MEDIUM=0
        TOTAL_LOW=0
    fi

    # Calculate risk score
    RISK_SCORE=$(calculate_risk_score $TOTAL_CRITICAL $TOTAL_HIGH $TOTAL_MEDIUM $TOTAL_LOW)
    log "Risk Score: $RISK_SCORE (Critical: $TOTAL_CRITICAL, High: $TOTAL_HIGH, Medium: $TOTAL_MEDIUM, Low: $TOTAL_LOW)"

    # Generate executive summary
    generate_executive_summary $RISK_SCORE >> "$REPORT_FILE"

    # Run network scan module
    log "Running network discovery and port scan module..."
    echo '<div class="section">' >> "$REPORT_FILE"
    if bash "$MODULES_DIR/network_scan.sh" >> "$REPORT_FILE" 2>&1; then
        log "Network scan completed successfully"
    else
        log "WARNING: Network scan module encountered errors"
        echo "<p style='color: orange;'>Network scan encountered errors. See logs for details.</p>" >> "$REPORT_FILE"
    fi
    echo '</div>' >> "$REPORT_FILE"

    # Add vulnerability findings
    log "Adding vulnerability findings to report..."
    echo '<div class="section">' >> "$REPORT_FILE"
    echo "$VULN_HTML" >> "$REPORT_FILE"
    echo '</div>' >> "$REPORT_FILE"

    # Run localhost audit module
    log "Running localhost security audit module..."
    echo '<div class="section">' >> "$REPORT_FILE"
    if bash "$MODULES_DIR/localhost_audit.sh" >> "$REPORT_FILE" 2>&1; then
        log "Localhost audit completed successfully"
    else
        log "WARNING: Localhost audit module encountered errors"
        echo "<p style='color: orange;'>Localhost audit encountered errors. See logs for details.</p>" >> "$REPORT_FILE"
    fi
    echo '</div>' >> "$REPORT_FILE"

    # Add remediation roadmap
    log "Generating remediation roadmap..."
    echo '<div class="section">' >> "$REPORT_FILE"
    cat >> "$REPORT_FILE" <<EOF
        <h2>Remediation Roadmap</h2>
        <h3>Priority 1: Immediate Action (Critical/High Severity)</h3>
        <p>Address all <strong class="critical">CRITICAL</strong> and <strong class="high">HIGH</strong> severity findings immediately.
        These represent significant security risks that could be actively exploited.</p>

        <h3>Priority 2: Short-term (Medium Severity)</h3>
        <p>Plan to address <strong class="medium">MEDIUM</strong> severity findings within the next 30 days.
        These represent potential security weaknesses that should be mitigated.</p>

        <h3>Priority 3: Long-term (Low Severity)</h3>
        <p>Address <strong class="low">LOW</strong> severity findings as part of regular maintenance cycles.
        These represent security best practices that improve overall posture.</p>

        <h3>Recommended Actions</h3>
        <ol>
            <li>Review all CRITICAL findings and implement fixes immediately</li>
            <li>Ensure firewall rules are properly configured and enabled</li>
            <li>Verify all services are running latest security patches</li>
            <li>Review user access and remove unnecessary privileged accounts</li>
            <li>Configure automatic security updates for critical packages</li>
            <li>Schedule next security assessment for 7 days from now</li>
        </ol>
EOF
    echo '</div>' >> "$REPORT_FILE"

    # Finish HTML report
    generate_html_footer >> "$REPORT_FILE"

    log "Report generation complete: $REPORT_FILE"

    # Send email (unless in test mode)
    if [ "$SKIP_EMAIL" = true ]; then
        log "Test mode: Skipping email delivery"
        log "Report available at: $REPORT_FILE"
    else
        send_email_report "$REPORT_FILE"
    fi

    log "==================== Security Scan Completed ===================="
    log "Total findings: $((TOTAL_CRITICAL + TOTAL_HIGH + TOTAL_MEDIUM + TOTAL_LOW))"
    log "Risk Score: $RISK_SCORE"
}

# Execute main function
main "$@"
