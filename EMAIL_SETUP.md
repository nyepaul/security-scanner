# Email Configuration Guide

## Current Issue

The security scanner has detected that the Gmail App Password in `~/.msmtprc` may be expired or invalid.

Error message:
```
msmtp: authentication failed (method PLAIN)
msmtp: server message: 535-5.7.8 Username and Password not accepted
```

## How to Fix

### Option 1: Generate New Gmail App Password

1. Go to your Google Account: https://myaccount.google.com/
2. Navigate to Security → 2-Step Verification
3. Scroll down to "App passwords"
4. Generate a new app password for "Mail" on "Linux Computer"
5. Update the password in `~/.msmtprc`:

```bash
nano ~/.msmtprc
```

Replace the current password line with your new app password:
```
password    your-new-app-password-here
```

6. Test the email:
```bash
echo "Test email body" | msmtp nyepaul@gmail.com
```

### Option 2: Use Alternative Email Method

If Gmail App Passwords are not available, you can:

1. Use a different email service (like a local SMTP server)
2. Modify the email configuration in:
   - `/home/paul/security-scanner/send-email.sh`
   - `~/.msmtprc`

## Verification

After updating credentials, test the scanner:

```bash
/home/paul/security-scanner/security-scan.sh
```

Check the logs:
```bash
tail -f /home/paul/security-scanner/logs/scan_*.log
```

## Important Notes

- Even if email fails, reports are ALWAYS saved locally in:
  `/home/paul/security-scanner/reports/`

- You can manually view reports by opening the HTML files in a browser

- The scanner will continue to run on schedule even if email fails

## Current Configuration

- Recipient: nyepaul@gmail.com
- SMTP Server: smtp.gmail.com:587
- Username: nyepaul@gmail.com
- Authentication: TLS with STARTTLS
