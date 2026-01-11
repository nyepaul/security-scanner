# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Shared AI Skills & Guidelines

**IMPORTANT**: Please refer to [AI_SKILLS.md](AI_SKILLS.md) for core coding standards, architectural patterns, and development workflows shared across AI assistants.

## Overview

This is an automated security scanning system written in Bash that performs comprehensive security audits of localhost environments. It discovers network topology, scans for vulnerabilities, audits system security posture, calculates risk scores, and generates beautiful HTML reports that are automatically emailed via msmtp.

**Platform Support**: Fully cross-platform with automatic OS detection. Supports both Linux (with systemd) and macOS (with launchd). The scanner automatically detects environment issues and offers to run `install.sh` to fix them.

**Quick Start**: Just run `./install.sh` on any supported platform - it handles everything automatically!

## Common Commands

### Interactive Menu (Recommended)

```bash
# Launch interactive menu system - easiest way to manage scanner
./menu.sh
```

The menu provides:
- Run scans (manual or test mode)
- View recent reports in browser
- Check scan logs
- Manage systemd timer (Linux only)
- View scanner status and configuration

### Running Scans

```bash
# Manual scan (run immediately with email)
./security-scan.sh

# Test mode - run scan WITHOUT sending email
./security-scan.sh --test
# or
./security-scan.sh --no-email

# Show help and usage information
./security-scan.sh --help

# Run via systemd (Linux only, always sends email)
sudo systemctl start security-scanner.service

# View scan schedule (Linux only)
systemctl list-timers security-scanner.timer

# View real-time logs (Linux only)
journalctl -u security-scanner.service -f

# Check local log files
tail -f logs/scan_*.log
```

### Installation & Management

```bash
# CROSS-PLATFORM: Works on both macOS and Linux
# Auto-detects OS, installs dependencies, updates config
./install.sh                    # macOS (no sudo needed)
sudo ./install.sh               # Linux (sudo required for dependencies/systemd)

# Deploy to production (copies to /opt/security-scanner)
sudo ./deploy-production.sh

# Linux systemd commands
systemctl status security-scanner.timer
systemctl status security-scanner.service
sudo systemctl enable security-scanner.timer
sudo systemctl disable security-scanner.timer
sudo systemctl daemon-reload
sudo systemctl restart security-scanner.timer

# macOS launchd commands (if plist created by install.sh)
launchctl load ~/Library/LaunchAgents/com.security-scanner.plist
launchctl unload ~/Library/LaunchAgents/com.security-scanner.plist
launchctl list | grep security-scanner
```

### Development & Testing

```bash
# Make scripts executable
chmod +x *.sh modules/*.sh lib/*.sh

# Test individual modules directly
bash modules/network_scan.sh
bash modules/vulnerability_scan.sh
bash modules/localhost_audit.sh

# Test email sending
echo "Test" | msmtp nyepaul@gmail.com

# View generated reports
ls -lh reports/
open reports/security_report_*.html    # macOS
firefox reports/security_report_*.html # Linux

# Validate production readiness
./validate-production-ready.sh
```

## Architecture

### Directory Structure

```
security-scanner/
├── security-scan.sh          # Main orchestration script
├── menu.sh                   # Interactive menu interface
├── send-email.sh             # Email delivery utility
├── install.sh                # Systemd installation
├── deploy-production.sh      # Production deployment script
├── validate-production-ready.sh # Pre-deployment validation
├── config/
│   ├── scanner.conf          # Main configuration file
│   └── email-config.conf     # Email-specific configuration
├── modules/
│   ├── network_scan.sh       # Network discovery module
│   ├── vulnerability_scan.sh # Vulnerability detection module
│   └── localhost_audit.sh    # System security audit module
├── lib/
│   └── menu_functions.sh     # Shared menu UI functions
├── reports/                  # Generated HTML reports (created at runtime)
├── logs/                     # Scan execution logs (created at runtime)
├── security-scanner.service  # Systemd service definition
└── security-scanner.timer    # Systemd timer definition
```

### Main Orchestration Script

`security-scan.sh` is the main entry point that:
1. Parses command-line arguments (`--test`, `--help`)
2. Loads configuration from `config/scanner.conf`
3. Checks dependencies (nmap, msmtp, chkrootkit)
4. Creates timestamped report and log files
5. Executes modules in sequence via `bash $MODULES_DIR/module.sh`
6. Generates HTML report with embedded CSS (gradient headers, metric cards, risk gauges)
7. Calculates overall risk score based on weighted vulnerability counts
8. Sends report via email using `send-email.sh` (unless `--test` mode)

### Interactive Menu System

`menu.sh` provides a user-friendly TUI interface:
- **Depends on**: `lib/menu_functions.sh` for UI rendering (box-drawing, colors, prompts)
- **Features**: Scan execution, report viewing, log inspection, systemd management, status display
- **UI Style**: Green single-line borders with color-coded status indicators
- **Browser detection**: Auto-detects `open` (macOS), `xdg-open`, `firefox`, `chromium` for report viewing

### Module System

Modules are standalone bash scripts in `modules/` that output HTML fragments to stdout:

- **network_scan.sh**: Discovers network interfaces, active hosts, and scans localhost ports using nmap. Uses timeout commands to prevent hanging.

- **vulnerability_scan.sh**: Detects security issues (SSL/TLS, SSH misconfigurations, firewall problems, exposed databases, container security). Uses an `add_finding()` function to log vulnerabilities with severity levels (CRITICAL/HIGH/MEDIUM/LOW). Outputs count variables like `CRITICAL=5` that the main script parses.

- **localhost_audit.sh**: Audits system security posture including security updates, running services, failed login attempts, file permissions, SUID/SGID binaries, user accounts, firewall status, SSH config, and rootkit detection.

**Critical**: Modules output HTML to stdout and vulnerability counts as special formatted lines (e.g., `CRITICAL=2`). The main script uses grep to extract counts and strip them from HTML output.

### Configuration System

**Primary Configuration**: `config/scanner.conf` centralizes all settings:
- Installation paths (INSTALL_DIR, MODULES_DIR, REPORTS_DIR, LOGS_DIR)
- Email configuration (EMAIL_RECIPIENT, EMAIL_FROM_NAME)
- Scan timeouts and nmap timing settings (NMAP_TIMING, *_TIMEOUT values)
- Module enable/disable flags (ENABLE_NETWORK_SCAN, etc.)
- Risk score thresholds and vulnerability weights (WEIGHT_CRITICAL, RISK_*_THRESHOLD)
- Report/log retention limits (MAX_REPORTS_TO_KEEP, MAX_LOGS_TO_KEEP)

**Email Configuration**: `config/email-config.conf` (separate file for email-specific settings)

The main script sources config files and converts relative paths to absolute paths.

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

1. Create `modules/custom_check.sh` with HTML output to stdout:
   ```bash
   #!/bin/bash
   set -uo pipefail  # Note: No -e to continue on check failures

   echo "<h2>Custom Security Check</h2>"
   echo "<div class='findings'>"

   # Your checks here
   # For vulnerabilities, use: echo "CRITICAL=N" to output counts

   echo "</div>"
   ```

2. Add execution in `security-scan.sh` (search for module execution section):
   ```bash
   echo '<div class="section">' >> "$REPORT_FILE"
   bash "$MODULES_DIR/custom_check.sh" >> "$REPORT_FILE" 2>&1
   echo '</div>' >> "$REPORT_FILE"
   ```

3. Make executable: `chmod +x modules/custom_check.sh`

4. Optionally add enable/disable flag in `config/scanner.conf`:
   ```bash
   ENABLE_CUSTOM_CHECK=true
   ```

## Deployment Workflow

### Development → Production Path

1. **Development** (macOS/Linux): `/Users/paul/src/security-scanner` or `/home/paul/src/security-scanner`
   - Test changes with `./security-scan.sh --test`
   - Use `./menu.sh` for interactive testing
   - Validate with `./validate-production-ready.sh`

2. **Production** (Linux): `/opt/security-scanner`
   - Deploy with `sudo ./deploy-production.sh` (copies and configures)
   - Installs systemd service/timer automatically
   - Updates all paths in config files

### Path Configuration

When moving between environments, update `INSTALL_DIR` in `config/scanner.conf`:
- Development macOS: `/Users/paul/src/security-scanner`
- Development Linux: `/home/paul/src/security-scanner`
- Production Linux: `/opt/security-scanner`

All other paths (MODULES_DIR, REPORTS_DIR, etc.) are relative and auto-resolve.

## Configuration Notes

- **Default paths**:
  - Development: `/Users/paul/src/security-scanner` (macOS)
  - Production: `/opt/security-scanner` (Linux deployment target)
  - Update `INSTALL_DIR` in `config/scanner.conf` to match your environment
- **Default schedule**: Every Sunday at 2:00 AM with 30min random delay (modify `OnCalendar` in `security-scanner.timer`)
- **Email recipient**: nyepaul@gmail.com (modify `EMAIL_RECIPIENT` in `config/scanner.conf`)
- **Retention**: Reports and logs retained up to `MAX_REPORTS_TO_KEEP` and `MAX_LOGS_TO_KEEP` (default: 30 each)
- **Nmap timing**: T4 (aggressive) - adjust via `NMAP_TIMING` in config (T0-T5)
- **Risk thresholds**: Critical ≥50, High ≥30, Medium ≥15 (modify `RISK_*_THRESHOLD` values)
- **Vulnerability weights**: Critical=10, High=5, Medium=2, Low=1 (modify `WEIGHT_*` values)

## Important Development Notes

### Module Output Protocol

Modules MUST follow this output pattern:
1. **HTML content** goes to stdout
2. **Vulnerability counts** as `SEVERITY=NUMBER` lines (e.g., `CRITICAL=3`)
3. Main script extracts counts via grep and strips them from HTML

If a module fails to follow this protocol, risk score calculation will be incorrect.

### Testing Checklist

Before committing changes:
- [ ] Run `./security-scan.sh --test` successfully
- [ ] Verify HTML report renders correctly
- [ ] Check logs for errors
- [ ] Run `./validate-production-ready.sh` if preparing for deployment
- [ ] Test individual modules: `bash modules/module_name.sh`

### Common Pitfalls

- **Don't use `-e` in module scripts**: Modules use `set -uo pipefail` (no `-e`) so individual check failures don't stop the entire module
- **Path assumptions**: Always use `$INSTALL_DIR` relative paths, never hardcode
- **Email testing**: Use `--test` flag during development to avoid sending real emails
- **Systemd on macOS**: Systemd commands won't work on macOS - deploy to Linux for full testing
