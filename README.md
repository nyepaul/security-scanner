# Security Scanner - Automated Localhost Security Assessment

## Overview

A comprehensive, automated security scanning system that performs periodic security audits of your local environment and sends detailed HTML reports via email.

## Features

- **Network Discovery & Port Scanning**: Discovers active hosts and scans for open ports and services
- **Localhost Security Audit**: Evaluates system security posture including:
  - Security update status
  - Running services and listening ports
  - Failed login attempts
  - File permission issues
  - SUID/SGID binaries
  - User account analysis
  - Firewall status
  - SSH configuration
  - Rootkit detection
- **Vulnerability Detection**: Identifies security vulnerabilities including:
  - SSL/TLS certificate issues
  - Weak SSH configurations
  - Missing security updates
  - Firewall configuration problems
  - Container security issues
  - Database exposure
  - Kernel vulnerabilities
- **Risk Scoring**: Calculates overall risk score based on findings
- **Beautiful HTML Reports**: Generates visually appealing reports with charts and metrics
- **Automated Email Delivery**: Sends reports to specified email address
- **Periodic Execution**: Runs automatically on schedule via systemd timer

## Directory Structure

```
/home/paul/security-scanner/
├── security-scan.sh          # Main orchestration script
├── send-email.sh             # Email sending utility
├── install.sh                # Installation script for systemd
├── security-scanner.service  # Systemd service definition
├── security-scanner.timer    # Systemd timer definition
├── modules/
│   ├── network_scan.sh       # Network discovery module
│   ├── localhost_audit.sh    # Localhost security audit module
│   └── vulnerability_scan.sh # Vulnerability detection module
├── reports/                  # Generated HTML reports
└── logs/                     # Scan execution logs
```

## Installation

### Prerequisites

- nmap (installed)
- msmtp (configured with Gmail credentials)
- chkrootkit (optional, for rootkit detection)

### Setup

1. Install the systemd service and timer:
```bash
sudo /home/paul/security-scanner/install.sh
```

This will:
- Copy systemd unit files to /etc/systemd/system/
- Enable and start the timer
- Schedule automatic scans

## Usage

### Manual Scan

Run a security scan immediately:
```bash
/home/paul/security-scanner/security-scan.sh
```

Run a scan in test mode (without sending email):
```bash
/home/paul/security-scanner/security-scan.sh --test
```

Show usage help:
```bash
/home/paul/security-scanner/security-scan.sh --help
```

Or using systemd:
```bash
sudo systemctl start security-scanner.service
```

### View Scan Schedule

Check when the next scan is scheduled:
```bash
systemctl list-timers security-scanner.timer
```

### View Scan Status

Check the status of the scanner:
```bash
systemctl status security-scanner.timer
systemctl status security-scanner.service
```

### View Logs

View scan execution logs:
```bash
journalctl -u security-scanner.service -f
```

Or check local log files:
```bash
ls -lh /home/paul/security-scanner/logs/
tail -f /home/paul/security-scanner/logs/scan_*.log
```

### View Reports

HTML reports are saved locally:
```bash
ls -lh /home/paul/security-scanner/reports/
```

Open a report in browser:
```bash
firefox /home/paul/security-scanner/reports/security_report_*.html
```

## Schedule Configuration

Default schedule: **Every Sunday at 2:00 AM** (with 30-minute random delay)

To modify the schedule, edit the timer file:
```bash
sudo nano /etc/systemd/system/security-scanner.timer
```

Example schedules:
- Daily at 3 AM: `OnCalendar=*-*-* 03:00:00`
- Every 6 hours: `OnCalendar=*-*-* 0/6:00:00`
- Weekdays at midnight: `OnCalendar=Mon-Fri *-*-* 00:00:00`

After changes, reload systemd:
```bash
sudo systemctl daemon-reload
sudo systemctl restart security-scanner.timer
```

## Email Configuration

Reports are automatically emailed to: **nyepaul@gmail.com**

To change the recipient, edit:
```bash
nano /home/paul/security-scanner/security-scan.sh
```

Update the EMAIL_RECIPIENT variable.

## Report Content

Each report includes:

1. **Executive Summary**
   - Overall risk score
   - Risk level (Critical/High/Medium/Low)
   - Vulnerability count by severity
   - Key findings overview

2. **Network Discovery & Port Scanning**
   - Network interfaces
   - Active hosts on network
   - Open ports on localhost
   - Service detection

3. **Vulnerability Assessment**
   - SSL/TLS certificate validation
   - SSH security issues
   - Firewall configuration
   - Database exposure
   - Container security
   - Detailed findings with severity ratings

4. **Localhost Security Audit**
   - System information
   - Security update status
   - Running services
   - Failed login attempts
   - File permission issues
   - User account analysis
   - Rootkit detection

5. **Remediation Roadmap**
   - Prioritized action plan
   - Recommended fixes

## Security Considerations

- The scanner runs with limited privileges (user: paul)
- Resource limits prevent excessive CPU/memory usage
- Scan data is stored locally in user's home directory
- Email credentials are stored in ~/.msmtprc with restricted permissions

## Troubleshooting

### Email not sending

1. Check msmtp configuration:
```bash
cat ~/.msmtprc
```

2. Test email manually:
```bash
echo "Test" | msmtp nyepaul@gmail.com
```

3. Check logs:
```bash
tail -f /home/paul/security-scanner/logs/scan_*.log
```

### Timer not running

1. Check timer status:
```bash
systemctl status security-scanner.timer
```

2. Verify timer is enabled:
```bash
systemctl is-enabled security-scanner.timer
```

3. Check for errors:
```bash
journalctl -u security-scanner.timer -e
```

### Permission issues

Ensure scripts are executable:
```bash
chmod +x /home/paul/security-scanner/*.sh
chmod +x /home/paul/security-scanner/modules/*.sh
```

## Management Commands

Start timer:
```bash
sudo systemctl start security-scanner.timer
```

Stop timer:
```bash
sudo systemctl stop security-scanner.timer
```

Enable timer (start on boot):
```bash
sudo systemctl enable security-scanner.timer
```

Disable timer:
```bash
sudo systemctl disable security-scanner.timer
```

Uninstall:
```bash
sudo systemctl stop security-scanner.timer
sudo systemctl disable security-scanner.timer
sudo rm /etc/systemd/system/security-scanner.{service,timer}
sudo systemctl daemon-reload
```

## Customization

### Adding Custom Checks

Create a new module in `/home/paul/security-scanner/modules/`:

```bash
#!/bin/bash
custom_module() {
    echo "<h2>Custom Security Check</h2>"
    echo "<pre>"
    # Your security checks here
    echo "</pre>"
}

custom_module
```

Add to main script:
```bash
bash "$MODULES_DIR/custom_module.sh" >> "$REPORT_FILE"
```

### Adjusting Scan Intensity

Modify nmap parameters in `modules/network_scan.sh`:
- Aggressive: `-T4` → `-T5`
- Stealthy: `-T4` → `-T2`
- More ports: `-F` → `--top-ports 1000`

## Support

For issues or questions:
- Check logs: `/home/paul/security-scanner/logs/`
- Review reports: `/home/paul/security-scanner/reports/`
- Check systemd status: `systemctl status security-scanner.service`
