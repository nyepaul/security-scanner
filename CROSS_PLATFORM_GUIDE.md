# Cross-Platform Support Guide

## Overview

The Security Scanner now includes comprehensive cross-platform support for both Linux and macOS, with automatic OS detection and environment setup.

## Supported Operating Systems

### ✅ Fully Supported
- **macOS** (Darwin) - Tested on macOS 11+
- **Linux** distributions:
  - Ubuntu/Debian (apt)
  - CentOS/RHEL (yum)
  - Fedora (dnf)
  - Arch Linux (pacman)

### ⚠️ Partial Support
- Other Unix-like systems may work but are untested

## Key Features

### 1. Automatic OS Detection

The scanner automatically detects the operating system at startup:

```bash
./security-scan.sh --test
# Output: [2026-01-11 10:17:47] Operating System: macOS
```

**How it works:**
- Uses `uname -s` to detect OS
- Sets `$OS` variable to "Linux" or "macOS"
- Logs OS info in scan reports

### 2. Auto-Install on Environment Issues

The scanner checks for environment problems and offers to fix them automatically:

**Detected Issues:**
- ✗ Config paths don't match current OS (e.g., Linux paths on macOS)
- ✗ Critical dependencies missing (nmap)
- ✗ Directory structure incomplete

**Example:**
```bash
./security-scan.sh

========================================
⚠  ENVIRONMENT ISSUES DETECTED
========================================

  - Configuration has Linux paths but running on macOS
  - nmap is not installed (required for network scanning)

The install.sh script can fix these issues automatically.

Run install.sh now? (y/n):
```

### 3. Cross-Platform install.sh

The `install.sh` script now handles both operating systems:

**macOS Installation:**
```bash
./install.sh
```
- Detects macOS automatically
- Checks/installs Homebrew dependencies
- Offers to create launchd plist for scheduling
- Updates config with macOS paths

**Linux Installation:**
```bash
sudo ./install.sh
```
- Detects Linux distro and package manager
- Installs dependencies via apt/yum/dnf/pacman
- Installs systemd service and timer
- Updates config with Linux paths

### 4. Smart Path Resolution

Configuration file automatically adapts to your environment:

```bash
# config/scanner.conf
# NOTE: This is auto-updated by install.sh to match your OS and location
# Common paths:
#   macOS Development:   /Users/paul/src/security-scanner
#   Linux Development:   /home/paul/src/security-scanner
#   Linux Production:    /opt/security-scanner
INSTALL_DIR="/Users/paul/src/security-scanner"
```

## Installation Instructions

### macOS Setup

1. **Clone or download the repository**
   ```bash
   cd ~/src
   git clone <repository>
   cd security-scanner
   ```

2. **Run installation script**
   ```bash
   ./install.sh
   ```

3. **What gets installed:**
   - Directory structure created
   - Config updated with macOS paths
   - Homebrew dependencies checked/installed
   - Optional: launchd plist for automatic scheduling

4. **Dependencies:**
   - **Required:** nmap (auto-installed via brew)
   - **Optional:** msmtp (for email), chkrootkit (for rootkit detection)

5. **Scheduling Options:**
   - **launchd** (recommended): Created by install.sh
   - **cron**: Add manually to crontab
   - **Manual**: Run via `./menu.sh` or `./security-scan.sh`

### Linux Setup

1. **Clone or download the repository**
   ```bash
   cd /home/paul/src  # or /opt for production
   git clone <repository>
   cd security-scanner
   ```

2. **Run installation script with sudo**
   ```bash
   sudo ./install.sh
   ```

3. **What gets installed:**
   - Directory structure created
   - Config updated with Linux paths
   - System dependencies installed (nmap, etc.)
   - Systemd service and timer installed
   - Service enabled and started

4. **Dependencies:**
   - **Required:** nmap (auto-installed)
   - **Optional:** msmtp (email), chkrootkit (rootkit detection), ss (networking)

5. **Scheduling:**
   - Automatic via systemd timer
   - Runs every Sunday at 2:00 AM
   - Also runs 15 minutes after boot

## Dependency Management

### macOS Dependencies

**Package Manager:** Homebrew

**Install Homebrew:**
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

**Manual Dependency Installation:**
```bash
brew install nmap
brew install msmtp      # optional
```

### Linux Dependencies

**Package Managers:** apt-get, yum, dnf, pacman (auto-detected)

**Manual Installation (Ubuntu/Debian):**
```bash
sudo apt-get update
sudo apt-get install -y nmap msmtp chkrootkit
```

**Manual Installation (CentOS/RHEL):**
```bash
sudo yum install -y nmap msmtp chkrootkit
```

## Platform-Specific Features

### macOS Specific

**Scheduling Options:**

1. **launchd (Recommended)**
   - Plist created in `~/Library/LaunchAgents/`
   - Load: `launchctl load ~/Library/LaunchAgents/com.security-scanner.plist`
   - Unload: `launchctl unload ~/Library/LaunchAgents/com.security-scanner.plist`

2. **cron**
   ```bash
   crontab -e
   # Add: 0 2 * * 0 /Users/paul/src/security-scanner/security-scan.sh
   ```

**Known Limitations:**
- No systemd (use launchd instead)
- No `ss` command (uses netstat alternatives)
- No chkrootkit by default (optional install)

### Linux Specific

**Systemd Service:**
```bash
# Check status
systemctl status security-scanner.timer
systemctl status security-scanner.service

# View logs
journalctl -u security-scanner.service -f

# Manual run
sudo systemctl start security-scanner.service

# Enable/disable
sudo systemctl enable security-scanner.timer
sudo systemctl disable security-scanner.timer
```

**Service Details:**
- Unit files: `/etc/systemd/system/security-scanner.{service,timer}`
- Runs as user `paul`
- Resource limits: 50% CPU, 1GB memory
- Security hardening enabled

## Configuration File Updates

### Auto-Detection in scanner.conf

The scanner automatically detects and validates paths:

```bash
# Detected issues trigger install.sh offer
if [ "$OS" = "macOS" ] && [[ "$INSTALL_DIR" == /home/* ]]; then
    # Offers to run install.sh to fix paths
fi
```

### Manual Path Updates

If needed, manually edit `config/scanner.conf`:

```bash
# For macOS
INSTALL_DIR="/Users/paul/src/security-scanner"

# For Linux Development
INSTALL_DIR="/home/paul/src/security-scanner"

# For Linux Production
INSTALL_DIR="/opt/security-scanner"
```

## Testing Cross-Platform Setup

### Test on macOS
```bash
# Run install
./install.sh

# Test scan
./security-scan.sh --test

# Verify OS detection
grep "Operating System" logs/scan_*.log
# Should show: Operating System: macOS
```

### Test on Linux
```bash
# Run install with sudo
sudo ./install.sh

# Test scan
./security-scan.sh --test

# Verify systemd
systemctl status security-scanner.timer

# Check logs
journalctl -u security-scanner.service -n 20
```

## Migration Between Platforms

### Moving from macOS to Linux

1. Copy repository to Linux system
2. Run `./install.sh` on Linux (with sudo)
3. Config automatically updated to Linux paths
4. Systemd service installed automatically

### Moving from Linux to macOS

1. Copy repository to macOS system
2. Run `./install.sh` on macOS
3. Config automatically updated to macOS paths
4. Choose launchd or manual scheduling

## Troubleshooting

### Issue: "Operation not supported" when creating directories

**Cause:** Config has wrong OS paths (e.g., `/home/paul` on macOS)

**Solution:** Run `./install.sh` to auto-fix paths

### Issue: Dependencies not installing

**macOS:**
- Ensure Homebrew is installed
- Run: `brew install nmap`

**Linux:**
- Ensure running with sudo
- Check package manager: `./install.sh` will detect and use correct one

### Issue: Systemd service not found (macOS)

**Cause:** systemd doesn't exist on macOS

**Solution:** Use launchd instead (created by install.sh) or run manually

### Issue: Permission denied errors

**Solution:**
```bash
# Make scripts executable
chmod +x *.sh modules/*.sh lib/*.sh

# Verify permissions
ls -la *.sh
```

## Development Recommendations

### For Cross-Platform Development

1. **Always test on both platforms** before committing
2. **Use install.sh after git pull** to sync environment
3. **Avoid hardcoded paths** - use `$INSTALL_DIR` variable
4. **Test scheduling separately** - systemd vs launchd vs cron

### Platform-Specific Code

When adding features, check for OS:

```bash
if [ "$OS" = "macOS" ]; then
    # macOS-specific code
    open "$REPORT_FILE"
elif [ "$OS" = "Linux" ]; then
    # Linux-specific code
    xdg-open "$REPORT_FILE"
fi
```

### Testing Matrix

| Test Case | macOS | Linux |
|-----------|-------|-------|
| Fresh install | ✅ | ✅ |
| Dependency check | ✅ | ✅ |
| Path detection | ✅ | ✅ |
| Scan execution | ✅ | ✅ |
| Report generation | ✅ | ✅ |
| Scheduling | launchd | systemd |
| Email delivery | msmtp | msmtp |

## Summary

The Security Scanner now provides seamless cross-platform support with:

- ✅ Automatic OS detection
- ✅ Smart path resolution
- ✅ Auto-install on environment issues
- ✅ Platform-specific dependency management
- ✅ Native scheduling (launchd/systemd)
- ✅ Zero manual configuration required

Simply run `./install.sh` on any supported platform and you're ready to scan!
