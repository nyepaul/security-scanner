# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is an automated security scanning system written in Bash that performs comprehensive security audits of localhost environments. It discovers network topology, scans for vulnerabilities, audits system security posture, calculates risk scores, and generates beautiful HTML reports that are automatically emailed via msmtp.

## Common Commands

### Running Scans

```bash
# Manual scan (run immediately with email)
/home/paul/src/security-scanner/security-scan.sh

# Test mode - run scan WITHOUT sending email
/home/paul/src/security-scanner/security-scan.sh --test
# or
/home/paul/src/security-scanner/security-scan.sh --no-email

# Show help and usage information
/home/paul/src/security-scanner/security-scan.sh --help

# Run via systemd (always sends email)
sudo systemctl start security-scanner.service

# View scan schedule
systemctl list-timers security-scanner.timer

# View real-time logs
journalctl -u security-scanner.service -f

# Check local log files
tail -f /home/paul/src/security-scanner/logs/scan_*.log
```

### Installation & Management

```bash
# Install systemd service and timer
sudo /home/paul/src/security-scanner/install.sh

# Check status
systemctl status security-scanner.timer
systemctl status security-scanner.service

# Enable/disable automatic scans
sudo systemctl enable security-scanner.timer
sudo systemctl disable security-scanner.timer

# Restart timer after config changes
sudo systemctl daemon-reload
sudo systemctl restart security-scanner.timer
```

### Development & Testing

```bash
# Make scripts executable
chmod +x /home/paul/src/security-scanner/*.sh
chmod +x /home/paul/src/security-scanner/modules/*.sh

# Test individual modules directly
bash /home/paul/src/security-scanner/modules/network_scan.sh
bash /home/paul/src/security-scanner/modules/vulnerability_scan.sh
bash /home/paul/src/security-scanner/modules/localhost_audit.sh

# Test email sending
echo "Test" | msmtp nyepaul@gmail.com

# View generated reports
ls -lh /home/paul/src/security-scanner/reports/
firefox /home/paul/src/security-scanner/reports/security_report_*.html
```

## Architecture

### Main Orchestration Script

`security-scan.sh` is the main entry point that:
1. Loads configuration from `config/scanner.conf`
2. Checks dependencies (nmap, msmtp, chkrootkit)
3. Creates timestamped report and log files
4. Executes modules in sequence via `bash $MODULES_DIR/module.sh`
5. Generates HTML report with embedded CSS
6. Calculates overall risk score based on weighted vulnerability counts
7. Sends report via email using `send-email.sh`

### Module System

Modules are standalone bash scripts in `modules/` that output HTML fragments to stdout:

- **network_scan.sh**: Discovers network interfaces, active hosts, and scans localhost ports using nmap. Uses timeout commands to prevent hanging.

- **vulnerability_scan.sh**: Detects security issues (SSL/TLS, SSH misconfigurations, firewall problems, exposed databases, container security). Uses an `add_finding()` function to log vulnerabilities with severity levels (CRITICAL/HIGH/MEDIUM/LOW). Outputs count variables like `CRITICAL=5` that the main script parses.

- **localhost_audit.sh**: Audits system security posture including security updates, running services, failed login attempts, file permissions, SUID/SGID binaries, user accounts, firewall status, SSH config, and rootkit detection.

**Critical**: Modules output HTML to stdout and vulnerability counts as special formatted lines (e.g., `CRITICAL=2`). The main script uses grep to extract counts and strip them from HTML output.

### Configuration System

`config/scanner.conf` centralizes all settings:
- Installation paths (INSTALL_DIR, MODULES_DIR, REPORTS_DIR, LOGS_DIR)
- Email configuration (EMAIL_RECIPIENT, EMAIL_FROM_NAME)
- Scan timeouts and nmap timing settings
- Module enable/disable flags
- Risk score thresholds and vulnerability weights
- Report/log retention limits

The main script sources this file and converts relative paths to absolute paths.

### Report Generation

HTML reports are generated inline in `security-scan.sh` using here-docs:
1. `generate_html_header()` - Creates document with embedded CSS (gradient headers, metric cards, risk gauges)
2. `generate_executive_summary()` - Displays overall risk score, risk level, and vulnerability counts
3. Modules append their HTML sections wrapped in `<div class="section">`
4. Remediation roadmap is added at the end
5. Report footer closes HTML document

Risk score calculation: `(critical * 10) + (high * 5) + (medium * 2) + (low * 1)`, with configurable weights and thresholds.

### Systemd Integration

- **security-scanner.service**: Oneshot service that runs as user `paul` with security hardening (NoNewPrivileges, PrivateTmp, resource limits: 50% CPU, 1G memory, 100 tasks max)

- **security-scanner.timer**: Scheduled to run every Sunday at 2:00 AM with 30-minute random delay. Also runs 15 minutes after boot and has `Persistent=true` to catch up missed runs.

Installation via `install.sh` copies unit files to `/etc/systemd/system/` and enables the timer.

### Email Delivery

`send-email.sh` uses msmtp to send HTML emails. Constructs proper MIME headers (Content-Type: text/html, MIME-Version) and pipes the complete email to `msmtp -t`. Credentials are stored in `~/.msmtprc` (configured separately, see EMAIL_SETUP.md).

## Key Implementation Details

### Command Line Arguments

The script supports command-line flags for testing and debugging:
- `--test` or `--no-email`: Runs the full scan but skips email delivery (test mode)
- `--help` or `-h`: Shows usage information

Test mode is useful during development or when you want to generate reports without sending emails. The `SKIP_EMAIL` variable controls this behavior and is logged at scan start.

### Module Execution Pattern

Modules are executed as subprocesses, not sourced. This isolation prevents variable contamination but requires special handling for vulnerability counts:

```bash
# Vulnerability module runs first to get counts
VULN_OUTPUT=$(bash "$MODULES_DIR/vulnerability_scan.sh" 2>&1)
TOTAL_CRITICAL=$(echo "$VULN_OUTPUT" | grep "^CRITICAL=" | cut -d= -f2)
# ... extract other counts ...
VULN_HTML=$(echo "$VULN_OUTPUT" | grep -v "^CRITICAL=\|^HIGH=\|^MEDIUM=\|^LOW=")
```

Other modules append directly to the report file via stdout redirection.

### Path Resolution

The script uses `SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"` to determine its location, then loads config and converts relative paths to absolute:

```bash
[[ "$MODULES_DIR" = /* ]] || MODULES_DIR="$INSTALL_DIR/$MODULES_DIR"
```

This allows flexible deployment while supporting both relative and absolute paths in config.

### Error Handling

- Main script uses `set -euo pipefail` for strict error handling
- Modules use `set -uo pipefail` (no `-e`) to continue on individual check failures
- Timeout commands prevent nmap scans from hanging indefinitely
- Module failures are caught and logged but don't stop report generation

## Adding New Modules

To create a custom security check:

1. Create `modules/custom_check.sh` with HTML output to stdout
2. If tracking vulnerabilities, output count lines like `CRITICAL=N`
3. Add execution in `security-scan.sh` after line 450:
   ```bash
   echo '<div class="section">' >> "$REPORT_FILE"
   bash "$MODULES_DIR/custom_check.sh" >> "$REPORT_FILE" 2>&1
   echo '</div>' >> "$REPORT_FILE"
   ```
4. Make executable: `chmod +x modules/custom_check.sh`

## Configuration Notes

- Default schedule: Every Sunday at 2:00 AM (modify in `security-scanner.timer`)
- Email recipient: nyepaul@gmail.com (modify EMAIL_RECIPIENT in `config/scanner.conf`)
- Reports are retained up to MAX_REPORTS_TO_KEEP (default: 30)
- Nmap timing default: T4 (aggressive) - adjust via NMAP_TIMING in config
- Risk thresholds: Critical ≥50, High ≥30, Medium ≥15 (configurable)
