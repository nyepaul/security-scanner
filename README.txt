================================================================================
                    SECURITY SCANNER SYSTEM
                  Automated Security Assessment
================================================================================

OVERVIEW
--------
Comprehensive automated security scanning system that performs periodic 
security audits of your local environment and sends detailed HTML reports 
via email to nyepaul@gmail.com.

DIRECTORY STRUCTURE
-------------------
/home/paul/security-scanner/
├── config/
│   └── email-config.conf          # Email configuration (EDIT THIS!)
├── logs/
│   ├── scan_*.log                 # Scan execution logs
│   ├── cron.log                   # Cron job logs
│   └── wrapper_*.log              # Wrapper script logs
├── reports/
│   ├── security_report_*.html     # HTML reports
│   └── security_data_*.json       # JSON data files
└── scripts/
    ├── security-scan.sh           # Main scanning script
    ├── generate-html-report.py    # HTML report generator
    ├── send-email-report.sh       # Email sender
    ├── run-scan-and-email.sh      # Wrapper (called by cron)
    └── setup-cron.sh              # Interactive cron setup

QUICK START
-----------

1. CONFIGURE EMAIL DELIVERY

   Edit the configuration file:
   
   nano /home/paul/security-scanner/config/email-config.conf

   For Gmail:
   - Enable 2-factor authentication
   - Go to https://myaccount.google.com/apppasswords
   - Generate an "App Password" for "Mail"
   - Set SMTP_USER="nyepaul@gmail.com"
   - Set SMTP_PASS="your-16-char-app-password"
   - Set EMAIL_METHOD="smtp"

2. TEST THE SCANNER

   Run a manual scan:
   
   /home/paul/security-scanner/scripts/security-scan.sh

   View reports:
   
   ls -lt /home/paul/security-scanner/reports/ | head

3. TEST EMAIL DELIVERY

   Find latest report:
   
   LATEST=$(ls -t /home/paul/security-scanner/reports/security_report_*.html | head -1)
   
   Test email:
   
   /home/paul/security-scanner/scripts/send-email-report.sh "$LATEST" 50 5 1 2

4. VERIFY CRON SCHEDULE

   Check cron job:
   
   crontab -l | grep security-scanner

CURRENT SCHEDULE
----------------
Daily at 2:00 AM

To change schedule:
/home/paul/security-scanner/scripts/setup-cron.sh

Or manually edit:
crontab -e

MANUAL OPERATIONS
-----------------

Run scan with email:
/home/paul/security-scanner/scripts/run-scan-and-email.sh

Run scan only (no email):
/home/paul/security-scanner/scripts/security-scan.sh

View recent reports:
ls -lth /home/paul/security-scanner/reports/

View logs:
tail -f /home/paul/security-scanner/logs/cron.log

SECURITY CHECKS PERFORMED
--------------------------
- Network services and open ports
- User account security (empty passwords, multiple root accounts)
- File permissions (world-writable, SUID/SGID binaries)
- SSH configuration security
- Firewall status
- Available security updates
- Running services audit
- Failed login attempts
- Disk encryption status
- System configuration review

RISK SCORING
------------
Critical vulnerabilities: 25 points each
High vulnerabilities: 10 points each
Medium vulnerabilities: 5 points each
Low vulnerabilities: 2 points each

Risk Levels:
0-24:   LOW (Green)
25-49:  MEDIUM (Yellow)
50-74:  HIGH (Orange)
75-100: CRITICAL (Red)

TROUBLESHOOTING
---------------

Email not sending:
1. Check config: cat /home/paul/security-scanner/config/email-config.conf
2. Verify SMTP_USER and SMTP_PASS are set
3. Check logs: tail /home/paul/security-scanner/logs/wrapper_*.log

Scan not running automatically:
1. Verify cron: crontab -l
2. Check cron logs: tail /home/paul/security-scanner/logs/cron.log
3. Verify executable: ls -l /home/paul/security-scanner/scripts/*.sh

IMPORTANT FILES
---------------
Configuration: /home/paul/security-scanner/config/email-config.conf
Reports:       /home/paul/security-scanner/reports/
Logs:          /home/paul/security-scanner/logs/
Scripts:       /home/paul/security-scanner/scripts/

SECURITY NOTES
--------------
- Email config file contains sensitive credentials
- File permissions set to 600 (owner read/write only)
- Never commit email-config.conf to version control
- Use App Passwords for Gmail (not main password)
- Review reports regularly
- Act on CRITICAL and HIGH findings promptly

================================================================================
