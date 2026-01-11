#!/bin/bash
# Localhost Security Audit Module
# Performs comprehensive localhost security posture assessment

set -uo pipefail

AUDIT_OUTPUT=""
JSON_MODE=false

# Check for --json argument
for arg in "$@"; do
    if [[ "$arg" == "--json" ]]; then
        JSON_MODE=true
        shift
    fi
done

log_audit() {
    AUDIT_OUTPUT+="$1\n"
}

localhost_audit_module() {
    # --- DATA GATHERING ---

    # 1. System Information
    local hostname=$(hostname)
    local kernel=$(uname -r)
    local os_info="Unknown"
    local uptime_info=$(uptime | sed 's/^.*up //;s/,.*//')

    if [ -f /etc/os-release ]; then
        os_info=$(cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2 | tr -d '\"')
    elif command -v sw_vers &>/dev/null; then
        os_info=$(sw_vers -productName)
        os_info+=" $(sw_vers -productVersion)"
    fi

    # 2. Security Updates
    local security_updates_raw=""
    local security_count=0
    
    if command -v apt &>/dev/null; then
        # Debian/Ubuntu
        local update_check=$(apt list --upgradable 2>/dev/null | grep -i security | head -20)
        if [ -n "$update_check" ]; then
            security_updates_raw="$update_check"
            security_count=$(echo "$update_check" | wc -l)
        else
            security_updates_raw="No pending security updates found"
        fi
    else
        security_updates_raw="Package manager not supported for security check"
    fi

    # 3. Running Services
    local listening_services=$(ss -tulnp 2>/dev/null | grep LISTEN | head -25 || echo "ss command failed or no services found")

    # 4. Failed Logins
    local failed_logins_raw=""
    local failed_count=0
    local log_file=""

    if [ -f /var/log/auth.log ]; then
        log_file="/var/log/auth.log"
    elif [ -f /var/log/secure ]; then
        log_file="/var/log/secure"
    elif [ -f /var/log/system.log ]; then
        log_file="/var/log/system.log"
    fi

    if [ -n "$log_file" ] && [ -r "$log_file" ]; then
        local failures=$(grep -iE "failed password|authentication failure" "$log_file" 2>/dev/null | tail -20)
        if [ -n "$failures" ]; then
            failed_logins_raw="$failures"
            failed_count=$(echo "$failures" | wc -l)
        else
            failed_logins_raw="No recent failed logins found"
        fi
    else
        failed_logins_raw="Auth log not found or not readable"
    fi

    # 5. File Permissions
    local writable_files=$(find /etc /usr/bin /usr/sbin -type f -perm -002 2>/dev/null | head -10 || echo "None found")
    local suid_count=$(find /usr/bin /usr/sbin /bin /sbin -type f \( -perm -4000 -o -perm -2000 \) 2>/dev/null | wc -l)
    local suid_list=$(find /usr/bin /usr/sbin /bin /sbin -type f \( -perm -4000 -o -perm -2000 \) 2>/dev/null | head -15)

    # 6. User Accounts
    local total_users=0
    local shell_users_count=0
    local shell_users_list=""

    if [ -f /etc/passwd ]; then
        total_users=$(cat /etc/passwd | wc -l)
        shell_users_count=$(grep -E "/bash$|/zsh$|/sh$" /etc/passwd | grep -v "^#" | wc -l)
        shell_users_list=$(grep -E "/bash$|/zsh$|/sh$" /etc/passwd | grep -v "^#" | cut -d: -f1,3,6,7)
    else
        # fallback for macOS dscl if needed, but /etc/passwd usually exists (though minimal)
        total_users="Unknown"
    fi

    # 7. Empty Passwords
    local empty_pass_users=""
    if [ -r /etc/shadow ]; then
        empty_pass_users=$(awk -F: '($2 == "" || $2 == "!") {print $1}' /etc/shadow 2>/dev/null || echo "")
    else
        empty_pass_users="Shadow file not readable"
    fi

    # 8. Firewall
    local firewall_status=""
    if command -v ufw &> /dev/null; then
        firewall_status=$(ufw status 2>/dev/null)
    elif command -v iptables &> /dev/null; then
        firewall_status=$(iptables -L -n 2>/dev/null | head -30)
    elif command -v pfctl &> /dev/null; then
        if pfctl -s info &>/dev/null; then
             firewall_status="pf is enabled"
        else
             firewall_status="pf is disabled or requires root"
        fi
    else
        firewall_status="No supported firewall detected"
    fi

    # 9. SSH Config
    local ssh_config_details=""
    if [ -f /etc/ssh/sshd_config ]; then
        ssh_config_details=$(grep -E "^PermitRootLogin|^PasswordAuthentication|^PubkeyAuthentication|^Port" /etc/ssh/sshd_config 2>/dev/null)
    else
        ssh_config_details="SSH config not found"
    fi

    # 10. Rootkit
    local rootkit_status=""
    if command -v chkrootkit &> /dev/null; then
        rootkit_status=$(chkrootkit 2>/dev/null | grep -E "INFECTED|WARNING" | head -10 || echo "No infections detected")
    else
        rootkit_status="chkrootkit not installed"
    fi

    # 11. Core Dumps
    local ulimit_core=$(ulimit -c)
    local core_dumps=$(find /var/crash /tmp -name "core*" -o -name "*.core" 2>/dev/null | head -5 || echo "None found")

    # --- OUTPUT ---

    if [ "$JSON_MODE" = true ]; then
        jq -n \
           --arg hostname "$hostname" \
           --arg kernel "$kernel" \
           --arg os "$os_info" \
           --arg uptime "$uptime_info" \
           --arg sec_updates "$security_updates_raw" \
           --arg sec_count "$security_count" \
           --arg services "$listening_services" \
           --arg failed_logins "$failed_logins_raw" \
           --arg failed_count "$failed_count" \
           --arg writable "$writable_files" \
           --arg suid_count "$suid_count" \
           --arg suid_list "$suid_list" \
           --arg total_users "$total_users" \
           --arg shell_users_count "$shell_users_count" \
           --arg shell_users_list "$shell_users_list" \
           --arg empty_pass "$empty_pass_users" \
           --arg firewall "$firewall_status" \
           --arg ssh_config "$ssh_config_details" \
           --arg rootkit "$rootkit_status" \
           --arg ulimit "$ulimit_core" \
           --arg cores "$core_dumps" \
           --arg timestamp "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
           '{
               module: "localhost_audit",
               timestamp: $timestamp,
               data: {
                   system: {
                       hostname: $hostname,
                       kernel: $kernel,
                       os: $os,
                       uptime: $uptime
                   },
                   security_updates: {
                       count: ($sec_count | tonumber),
                       details: $sec_updates
                   },
                   services: $services,
                   failed_logins: {
                       count: ($failed_count | tonumber),
                       details: $failed_logins
                   },
                   file_permissions: {
                       world_writable: $writable,
                       suid_sgid_count: ($suid_count | tonumber),
                       suid_sgid_list: $suid_list
                   },
                   users: {
                       total: ($total_users | tonumber),
                       shell_users_count: ($shell_users_count | tonumber),
                       shell_users_list: $shell_users_list,
                       empty_passwords: $empty_pass
                   },
                   firewall: $firewall,
                   ssh_config: $ssh_config,
                   rootkit: $rootkit,
                   core_dumps: {
                       ulimit: $ulimit,
                       found: $cores
                   }
               }
           }'
    else
        # Legacy HTML Output
        log_audit "<h2>Localhost Security Audit</h2>"

        log_audit "<h3>System Information</h3>"
        log_audit "<pre>"
        log_audit "Hostname: $hostname"
        log_audit "Kernel: $kernel"
        log_audit "OS: $os_info"
        log_audit "Uptime: $uptime_info"
        log_audit "</pre>"

        log_audit "<h3>Security Updates Status</h3>"
        log_audit "<pre>"
        if [ "$security_count" -gt 0 ]; then
             log_audit "ALERT: $security_count security updates available:"
             log_audit "$security_updates_raw"
        else
             log_audit "$security_updates_raw"
        fi
        log_audit "</pre>"

        log_audit "<h3>Running Services (Listening Ports)</h3>"
        log_audit "<pre>"
        log_audit "$listening_services"
        log_audit "</pre>"

        log_audit "<h3>Failed Login Attempts (Last 24h)</h3>"
        log_audit "<pre>"
        if [ "$failed_count" -gt 0 ]; then
            log_audit "WARNING: $failed_count failed login attempts detected:"
            log_audit "$failed_logins_raw"
        else
            log_audit "$failed_logins_raw"
        fi
        log_audit "</pre>"

        log_audit "<h3>World-Writable Files (Security Risk)</h3>"
        log_audit "<pre>"
        if [ "$writable_files" != "None found" ] && [ -n "$writable_files" ]; then
            log_audit "WARNING: World-writable files found:"
            log_audit "$writable_files"
        else
            log_audit "No world-writable files found in system directories"
        fi
        log_audit "</pre>"

        log_audit "<h3>SUID/SGID Binaries (Privilege Escalation Risk)</h3>"
        log_audit "<pre>"
        log_audit "Found $suid_count SUID/SGID binaries (showing first 15):"
        log_audit "$suid_list"
        log_audit "</pre>"

        log_audit "<h3>User Accounts Analysis</h3>"
        log_audit "<pre>"
        log_audit "Total accounts: $total_users"
        log_audit "Accounts with shell access: $shell_users_count"
        log_audit ""
        log_audit "Users with shell access:"
        # Need to format the list again for display as it was captured raw
        echo "$shell_users_list" | while read user; do
            log_audit "  $user"
        done
        log_audit "</pre>"

        log_audit "<h3>Empty Password Check</h3>"
        log_audit "<pre>"
        if [ "$empty_pass_users" != "Shadow file not readable" ] && [ -n "$empty_pass_users" ]; then
            log_audit "WARNING: Accounts with potentially empty/locked passwords:"
            log_audit "$empty_pass_users"
        else
            log_audit "$empty_pass_users"
        fi
        log_audit "</pre>"

        log_audit "<h3>Firewall Status</h3>"
        log_audit "<pre>"
        log_audit "$firewall_status"
        log_audit "</pre>"

        log_audit "<h3>SSH Security Configuration</h3>"
        log_audit "<pre>"
        if [ "$ssh_config_details" != "SSH config not found" ]; then
            log_audit "Key SSH security settings:"
            echo "$ssh_config_details" | while read line; do
                log_audit "  $line"
            done
        else
            log_audit "SSH config not found"
        fi
        log_audit "</pre>"

        log_audit "<h3>Rootkit Detection</h3>"
        log_audit "<pre>"
        log_audit "$rootkit_status"
        log_audit "</pre>"

        log_audit "<h3>Core Dumps Status</h3>"
        log_audit "<pre>"
        log_audit "Core dump size limit: $ulimit_core"
        if [ "$core_dumps" != "None found" ]; then
            log_audit "Core dumps found:"
            log_audit "$core_dumps"
        else
            log_audit "No core dumps found"
        fi
        log_audit "</pre>"

        echo -e "$AUDIT_OUTPUT"
    fi
}

# If run directly, execute
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    localhost_audit_module
fi
