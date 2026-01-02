# Production Deployment Guide

## Security Scanner v1.0.0

---

## ✅ Pre-Deployment Validation Complete

**All critical checks passed!** The security scanner has been validated and is ready for production deployment.

### Validation Results:
- ✓ Version tracking implemented (v1.0.0)
- ✓ All required files present
- ✓ All module files present
- ✓ All scripts executable
- ✓ Shell script syntax validated
- ✓ Directory structure complete
- ✓ Configuration file valid
- ✓ All documentation present
- ✓ Development testing completed successfully

---

## 🚀 Production Deployment Steps

### Current Location
- **Development:** `/home/paul/src/security-scanner`
- **Production:** `/opt/security-scanner` (to be created)

### Deployment Command

Run this single command to deploy to production:

```bash
cd /home/paul/src/security-scanner
sudo ./deploy-production.sh
```

### What This Does:
1. Backs up any existing production installation
2. Creates `/opt/security-scanner` directory
3. Copies all files to production location
4. Updates all configuration paths for production
5. Updates systemd unit files for production paths
6. Sets correct ownership (paul:paul) and permissions
7. Makes all scripts executable

---

## 📋 Post-Deployment Steps

### 1. Install Systemd Timer

```bash
cd /opt/security-scanner
sudo ./install.sh
```

This will:
- Install systemd service and timer
- Enable automatic startup on boot
- Start the timer immediately
- Schedule weekly scans (Sundays at 2 AM)

### 2. Verify Installation

```bash
# Check timer status
systemctl status security-scanner.timer

# View next scheduled run
systemctl list-timers | grep security-scanner
```

### 3. Run Test Scan

```bash
# Manual test scan
/opt/security-scanner/security-scan.sh

# Or via systemd
sudo systemctl start security-scanner.service
```

### 4. Verify Reports

```bash
# List generated reports
ls -lh /opt/security-scanner/reports/

# View latest report
firefox /opt/security-scanner/reports/security_report_*.html
```

### 5. Check Logs

```bash
# View scan logs
tail -f /opt/security-scanner/logs/scan_*.log

# View systemd journal
journalctl -u security-scanner.service -f
```

---

## 🔧 Production Configuration

The production configuration file is located at:
```
/opt/security-scanner/config/scanner.conf
```

Key settings to review/update:
- `EMAIL_RECIPIENT` - Your email address
- `NETWORK_DISCOVERY_TIMEOUT` - Network scan timeout (default: 60s)
- `ENABLE_*` - Enable/disable specific modules

After changing configuration:
```bash
# No restart needed - changes apply to next scan
```

---

## 📊 Production Deployment Summary

### File Structure

```
/opt/security-scanner/
├── security-scan.sh          # Main scanner script
├── send-email.sh             # Email delivery
├── install.sh                # Systemd installer
├── deploy-production.sh      # Production deployer
├── validate-production-ready.sh  # Validation script
├── VERSION                   # Version: 1.0.0
├── CHANGELOG.md              # Version history
├── README.md                 # Documentation
├── IMPROVEMENTS.md           # Enhancement log
├── INSTALL_INSTRUCTIONS.txt  # Systemd setup guide
├── PRODUCTION_DEPLOYMENT_GUIDE.md  # This file
├── config/
│   └── scanner.conf          # Configuration file
├── modules/
│   ├── network_scan.sh       # Network scanning
│   ├── vulnerability_scan.sh # Vulnerability detection
│   └── localhost_audit.sh    # Security audit
├── reports/                  # Generated reports
├── logs/                     # Scan logs
└── scripts/                  # Helper scripts
```

### Systemd Files

After installation, systemd files will be at:
- `/etc/systemd/system/security-scanner.service`
- `/etc/systemd/system/security-scanner.timer`

### Scan Schedule

- **Weekly:** Every Sunday at 2:00 AM (±30 min random delay)
- **On Boot:** 15 minutes after system startup
- **Catch-up:** Runs missed scans if system was off

---

## 🔐 Security Considerations

### Permissions
- Installation directory: `/opt/security-scanner` (paul:paul, 755)
- Configuration file: Readable by paul user
- Reports/logs: Stored in user-accessible directories
- Systemd service: Runs as user `paul` (unprivileged)

### Resource Limits
- CPU: 50% maximum
- Memory: 1GB limit
- Security: NoNewPrivileges, PrivateTmp enabled

### Data Privacy
- No sensitive data stored in reports
- Email credentials in `~/.msmtprc` (user-only readable)
- All scans run with limited privileges

---

## 📞 Management Commands

### Timer Management
```bash
# Start timer
sudo systemctl start security-scanner.timer

# Stop timer
sudo systemctl stop security-scanner.timer

# Enable (auto-start on boot)
sudo systemctl enable security-scanner.timer

# Disable
sudo systemctl disable security-scanner.timer

# Restart timer
sudo systemctl restart security-scanner.timer
```

### Manual Scans
```bash
# Run scan immediately
/opt/security-scanner/security-scan.sh

# Or via systemd
sudo systemctl start security-scanner.service
```

### Monitoring
```bash
# View timer status
systemctl status security-scanner.timer

# View service status
systemctl status security-scanner.service

# View logs (live)
journalctl -u security-scanner.service -f

# View logs (last 50 lines)
journalctl -u security-scanner.service -n 50

# View scan logs
tail -f /opt/security-scanner/logs/scan_*.log
```

### Report Management
```bash
# List all reports
ls -lht /opt/security-scanner/reports/

# View latest report
firefox $(ls -t /opt/security-scanner/reports/*.html | head -1)

# Clean old reports (keep last 30)
cd /opt/security-scanner/reports
ls -t security_report_*.html | tail -n +31 | xargs rm -f
```

---

## 🔄 Version Management

### Current Version
```bash
cat /opt/security-scanner/VERSION
# Output: 1.0.0
```

### View Changelog
```bash
cat /opt/security-scanner/CHANGELOG.md
```

### Future Updates
When deploying updates:
1. Update version in `/home/paul/src/security-scanner/VERSION`
2. Update `/home/paul/src/security-scanner/CHANGELOG.md`
3. Test in development
4. Run `validate-production-ready.sh`
5. Deploy with `sudo ./deploy-production.sh`
6. Restart timer if needed: `sudo systemctl restart security-scanner.timer`

---

## 🆘 Troubleshooting

### Email Not Sending
```bash
# Test msmtp configuration
echo "Test" | msmtp your-email@example.com

# Check msmtp config
cat ~/.msmtprc

# View email errors in logs
grep -i "email\|msmtp" /opt/security-scanner/logs/scan_*.log
```

### Scan Failing
```bash
# Check dependencies
/opt/security-scanner/security-scan.sh 2>&1 | grep -i "missing\|error"

# View full error log
tail -100 /opt/security-scanner/logs/scan_*.log
```

### Timer Not Running
```bash
# Check timer is enabled
systemctl is-enabled security-scanner.timer

# Check timer is active
systemctl is-active security-scanner.timer

# View timer errors
journalctl -u security-scanner.timer -p err
```

---

## 📈 Next Steps After Deployment

1. **Verify First Scan**
   - Wait for scheduled scan or run manually
   - Check report is generated
   - Verify email is received

2. **Review Configuration**
   - Update email recipient if needed
   - Adjust scan schedule if desired
   - Configure risk thresholds

3. **Monitor Initially**
   - Watch first few scans complete
   - Review reports for accuracy
   - Adjust timeouts if needed

4. **Set Up Monitoring** (Optional)
   - Create alerts for critical findings
   - Set up dashboard for reports
   - Configure log rotation

---

## ✅ Production Deployment Checklist

- [ ] Run `sudo ./deploy-production.sh` to deploy
- [ ] Run `cd /opt/security-scanner && sudo ./install.sh` to install timer
- [ ] Verify with `systemctl status security-scanner.timer`
- [ ] Update email address in `/opt/security-scanner/config/scanner.conf`
- [ ] Run test scan: `/opt/security-scanner/security-scan.sh`
- [ ] Verify report generated in `/opt/security-scanner/reports/`
- [ ] Check email received
- [ ] Review scan logs for errors
- [ ] Document in your change management system
- [ ] Schedule review of first automated scan

---

## 🎉 Deployment Complete!

Once deployed, your security scanner will:
- ✅ Run automatically every Sunday at 2 AM
- ✅ Generate detailed HTML reports
- ✅ Email reports to configured recipient
- ✅ Log all activity for auditing
- ✅ Calculate risk scores for your environment
- ✅ Provide actionable remediation guidance

**Production Location:** `/opt/security-scanner`
**Version:** 1.0.0
**Status:** Ready for deployment

---

*For questions or issues, review the documentation in `/opt/security-scanner/` after deployment.*
