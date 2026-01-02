#!/bin/bash
# Localhost Security Audit Module
# Performs comprehensive localhost security posture assessment

set -uo pipefail

AUDIT_OUTPUT=""

log_audit() {
    AUDIT_OUTPUT+="$1\n"
}

localhost_audit_module() {
    log_audit "<h2>Localhost Security Audit</h2>"

    # System Information
    log_audit "<h3>System Information</h3>"
    log_audit "<pre>"
    log_audit "Hostname: $(hostname)"
    log_audit "Kernel: $(uname -r)"
    log_audit "OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2 | tr -d '\"')"
    log_audit "Uptime: $(uptime -p)"
    log_audit "</pre>"

    # Check for security updates
    log_audit "<h3>Security Updates Status</h3>"
    log_audit "<pre>"

    # Try to get update info without updating cache
    UPDATE_CHECK=$(apt list --upgradable 2>/dev/null | grep -i security | head -20)
    if [ -z "$UPDATE_CHECK" ]; then
        log_audit "No pending security updates found (or apt cache needs refresh)"
    else
        SECURITY_COUNT=$(echo "$UPDATE_CHECK" | wc -l)
        log_audit "ALERT: $SECURITY_COUNT security updates available:"
        log_audit "$UPDATE_CHECK"
    fi
    log_audit "</pre>"

    # Running services
    log_audit "<h3>Running Services (Listening Ports)</h3>"
    log_audit "<pre>"
    LISTENING_SERVICES=$(ss -tulnp 2>/dev/null | grep LISTEN | head -25)
    log_audit "$LISTENING_SERVICES"
    log_audit "</pre>"

    # Check for failed login attempts
    log_audit "<h3>Failed Login Attempts (Last 24h)</h3>"
    log_audit "<pre>"
    if [ -f /var/log/auth.log ]; then
        FAILED_LOGINS=$(grep "Failed password" /var/log/auth.log 2>/dev/null | tail -20)
        if [ -z "$FAILED_LOGINS" ]; then
            log_audit "No failed login attempts found"
        else
            FAIL_COUNT=$(echo "$FAILED_LOGINS" | wc -l)
            log_audit "WARNING: $FAIL_COUNT failed login attempts detected:"
            log_audit "$FAILED_LOGINS"
        fi
    else
        log_audit "Auth log not accessible"
    fi
    log_audit "</pre>"

    # Check world-writable files in system directories
    log_audit "<h3>World-Writable Files (Security Risk)</h3>"
    log_audit "<pre>"
    WRITABLE_FILES=$(find /etc /usr/bin /usr/sbin -type f -perm -002 2>/dev/null | head -10)
    if [ -z "$WRITABLE_FILES" ]; then
        log_audit "No world-writable files found in system directories"
    else
        log_audit "WARNING: World-writable files found:"
        log_audit "$WRITABLE_FILES"
    fi
    log_audit "</pre>"

    # Check SUID/SGID binaries
    log_audit "<h3>SUID/SGID Binaries (Privilege Escalation Risk)</h3>"
    log_audit "<pre>"
    SUID_COUNT=$(find /usr/bin /usr/sbin /bin /sbin -type f \( -perm -4000 -o -perm -2000 \) 2>/dev/null | wc -l)
    log_audit "Found $SUID_COUNT SUID/SGID binaries (showing first 15):"
    find /usr/bin /usr/sbin /bin /sbin -type f \( -perm -4000 -o -perm -2000 \) -ls 2>/dev/null | head -15 | while read line; do
        log_audit "$line"
    done
    log_audit "</pre>"

    # Check user accounts
    log_audit "<h3>User Accounts Analysis</h3>"
    log_audit "<pre>"
    TOTAL_USERS=$(cat /etc/passwd | wc -l)
    SHELL_USERS=$(grep -E "/bash$|/zsh$|/sh$" /etc/passwd | grep -v "^#" | wc -l)
    log_audit "Total accounts: $TOTAL_USERS"
    log_audit "Accounts with shell access: $SHELL_USERS"
    log_audit ""
    log_audit "Users with shell access:"
    grep -E "/bash$|/zsh$|/sh$" /etc/passwd | grep -v "^#" | cut -d: -f1,3,6,7 | while read user; do
        log_audit "  $user"
    done
    log_audit "</pre>"

    # Check for users with empty passwords
    log_audit "<h3>Empty Password Check</h3>"
    log_audit "<pre>"
    if [ -r /etc/shadow ]; then
        EMPTY_PASS=$(awk -F: '($2 == "" || $2 == "!") {print $1}' /etc/shadow 2>/dev/null)
        if [ -z "$EMPTY_PASS" ]; then
            log_audit "No accounts with empty passwords found"
        else
            log_audit "WARNING: Accounts with potentially empty/locked passwords:"
            log_audit "$EMPTY_PASS"
        fi
    else
        log_audit "Shadow file not readable (requires root)"
    fi
    log_audit "</pre>"

    # Check firewall status
    log_audit "<h3>Firewall Status</h3>"
    log_audit "<pre>"
    if command -v ufw &> /dev/null; then
        UFW_STATUS=$(ufw status 2>/dev/null)
        log_audit "$UFW_STATUS"
    else
        log_audit "UFW not installed"
    fi

    if command -v iptables &> /dev/null; then
        IPTABLES_RULES=$(iptables -L -n 2>/dev/null | head -30)
        log_audit ""
        log_audit "IPTables rules (first 30 lines):"
        log_audit "$IPTABLES_RULES"
    fi
    log_audit "</pre>"

    # Check SSH configuration
    log_audit "<h3>SSH Security Configuration</h3>"
    log_audit "<pre>"
    if [ -f /etc/ssh/sshd_config ]; then
        log_audit "Key SSH security settings:"
        grep -E "^PermitRootLogin|^PasswordAuthentication|^PubkeyAuthentication|^Port" /etc/ssh/sshd_config 2>/dev/null | while read line; do
            log_audit "  $line"
        done
    else
        log_audit "SSH config not found"
    fi
    log_audit "</pre>"

    # Rootkit check (if available)
    log_audit "<h3>Rootkit Detection</h3>"
    log_audit "<pre>"
    if command -v chkrootkit &> /dev/null; then
        ROOTKIT_CHECK=$(chkrootkit 2>/dev/null | grep -E "INFECTED|WARNING" | head -10)
        if [ -z "$ROOTKIT_CHECK" ]; then
            log_audit "chkrootkit: No infections detected"
        else
            log_audit "WARNING: Potential rootkit signatures detected:"
            log_audit "$ROOTKIT_CHECK"
        fi
    else
        log_audit "chkrootkit not installed - skipping rootkit scan"
    fi
    log_audit "</pre>"

    # Check for core dumps
    log_audit "<h3>Core Dumps Status</h3>"
    log_audit "<pre>"
    ULIMIT_CORE=$(ulimit -c)
    log_audit "Core dump size limit: $ULIMIT_CORE"
    COREDUMPS=$(find /var/crash /tmp -name "core*" -o -name "*.core" 2>/dev/null | head -5)
    if [ -z "$COREDUMPS" ]; then
        log_audit "No core dumps found"
    else
        log_audit "Core dumps found:"
        log_audit "$COREDUMPS"
    fi
    log_audit "</pre>"

    echo "$AUDIT_OUTPUT"
}

# If run directly, execute
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    localhost_audit_module
fi
