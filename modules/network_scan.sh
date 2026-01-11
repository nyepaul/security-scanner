#!/bin/bash
# Network Discovery and Port Scanning Module
# Discovers network topology and performs comprehensive port scanning

set -uo pipefail

SCAN_OUTPUT=""

# Timeout settings (in seconds)
NETWORK_DISCOVERY_TIMEOUT=60
PORT_SCAN_TIMEOUT=30
DETAILED_SCAN_TIMEOUT=45

log_scan() {
    SCAN_OUTPUT+="$1\n"
}

network_scan_module() {
    log_scan "<h2>Network Discovery & Port Scanning</h2>"

    # Discover local network interfaces
    log_scan "<h3>Network Interfaces</h3>"
    log_scan "<pre>"
    INTERFACES=$(ip -br addr show | grep -v "DOWN")
    log_scan "$INTERFACES"
    log_scan "</pre>"

    # Get primary network details
    PRIMARY_IP=$(ip route get 1.1.1.1 | grep -oP 'src \K\S+' 2>/dev/null || echo "192.168.87.50")
    NETWORK_RANGE=$(echo "$PRIMARY_IP" | cut -d'.' -f1-3).0/24

    log_scan "<h3>Network Range: $NETWORK_RANGE</h3>"

    # Quick host discovery
    log_scan "<h4>Active Hosts Discovery</h4>"
    log_scan "<pre>"

    if command -v nmap &> /dev/null; then
        if ACTIVE_HOSTS=$(timeout $NETWORK_DISCOVERY_TIMEOUT nmap -sn -T4 $NETWORK_RANGE 2>/dev/null | grep "Nmap scan report" | awk '{print $5}'); then
            HOST_COUNT=$(echo "$ACTIVE_HOSTS" | wc -l)
            log_scan "Found $HOST_COUNT active hosts on $NETWORK_RANGE:"
            log_scan "$ACTIVE_HOSTS"
        else
            log_scan "Network discovery timed out or failed after ${NETWORK_DISCOVERY_TIMEOUT}s"
        fi
    else
        log_scan "nmap not available - skipping network scan"
    fi
    log_scan "</pre>"

    # Scan localhost ports
    log_scan "<h3>Localhost Port Scan (Common Ports)</h3>"
    log_scan "<pre>"

    if command -v nmap &> /dev/null; then
        if LOCALHOST_SCAN=$(timeout $PORT_SCAN_TIMEOUT nmap -sV -T4 -F localhost 2>/dev/null); then
            log_scan "$LOCALHOST_SCAN"
        else
            log_scan "Localhost scan timed out after ${PORT_SCAN_TIMEOUT}s, falling back to ss"
            SS_OUTPUT=$(ss -tulnp 2>/dev/null | head -30)
            log_scan "$SS_OUTPUT"
        fi
    else
        # Fallback to ss/netstat
        log_scan "Using ss for port enumeration:"
        SS_OUTPUT=$(ss -tulnp 2>/dev/null | head -30)
        log_scan "$SS_OUTPUT"
    fi
    log_scan "</pre>"

    # Detailed scan of localhost top ports
    log_scan "<h3>Detailed Service Detection (Localhost Top 100 Ports)</h3>"
    log_scan "<pre>"

    if command -v nmap &> /dev/null; then
        if DETAILED_SCAN=$(timeout $DETAILED_SCAN_TIMEOUT nmap -sV -sC -T4 --top-ports 100 localhost 2>/dev/null); then
            log_scan "$DETAILED_SCAN"
        else
            log_scan "Detailed scan timed out after ${DETAILED_SCAN_TIMEOUT}s - skipped"
        fi
    else
        log_scan "nmap not available - skipped detailed scan"
    fi
    log_scan "</pre>"

    echo "$SCAN_OUTPUT"
}

# If sourced, don't execute; if run directly, execute
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    network_scan_module
fi
