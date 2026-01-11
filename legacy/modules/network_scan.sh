#!/bin/bash
# Network Discovery and Port Scanning Module
# Discovers network topology and performs comprehensive port scanning

set -uo pipefail

SCAN_OUTPUT=""
JSON_MODE=false

# Check for --json argument
for arg in "$@"; do
    if [[ "$arg" == "--json" ]]; then
        JSON_MODE=true
        shift
    fi
done

# Timeout settings (in seconds)
NETWORK_DISCOVERY_TIMEOUT=60
PORT_SCAN_TIMEOUT=30
DETAILED_SCAN_TIMEOUT=45

log_scan() {
    SCAN_OUTPUT+="$1\n"
}

get_primary_ip() {
    # Try ip route (Linux)
    if command -v ip &> /dev/null; then
        # Use portable grep or awk instead of grep -P
        ip route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src") print $(i+1)}'
    else
        # Fallback for macOS/BSD
        route get 1.1.1.1 2>/dev/null | awk '/interface:/ {print $2}' | xargs ifconfig | grep "inet " | awk '{print $2}'
    fi
}

network_scan_module() {
    # --- DATA GATHERING PHASE ---
    
    # 1. Network Interfaces
    local interfaces_raw=""
    if command -v ip &> /dev/null; then
        interfaces_raw=$(ip -br addr show 2>/dev/null | grep -v "DOWN" || echo "No interfaces found")
    else
        interfaces_raw=$(ifconfig | grep -E "^[a-z0-9]+: flags" -A 3 | grep -E "inet " || echo "ifconfig not available or no inet found")
    fi

    # 2. Network Range
    local primary_ip=$(get_primary_ip)
    if [ -z "$primary_ip" ]; then
        primary_ip="127.0.0.1"
    fi
    
    # Simple subnet calculation (assuming /24)
    local network_range=$(echo "$primary_ip" | cut -d'.' -f1-3).0/24

    # 3. Active Hosts
    local active_hosts_raw=""
    local host_count=0
    
    if command -v nmap &> /dev/null; then
        if active_hosts_output=$(timeout $NETWORK_DISCOVERY_TIMEOUT nmap -sn -T4 "$network_range" 2>/dev/null); then
            active_hosts_raw=$(echo "$active_hosts_output" | grep "Nmap scan report" | awk '{print $5}')
            host_count=$(echo "$active_hosts_raw" | wc -l | xargs) # xargs trims whitespace
        else
            active_hosts_raw="Timeout or failure"
        fi
    else
        active_hosts_raw="nmap not installed"
    fi

    # 4. Localhost Port Scan
    local localhost_scan_raw=""
    local scan_method=""
    
    if command -v nmap &> /dev/null; then
        if localhost_scan_output=$(timeout $PORT_SCAN_TIMEOUT nmap -sV -T4 -F localhost 2>/dev/null); then
            localhost_scan_raw="$localhost_scan_output"
            scan_method="nmap"
        else
            scan_method="ss (fallback)"
            if command -v ss &> /dev/null; then
                localhost_scan_raw=$(ss -tulnp 2>/dev/null | head -30)
            else
                localhost_scan_raw="Scan failed and ss not available"
            fi
        fi
    else
        scan_method="ss"
        if command -v ss &> /dev/null; then
            localhost_scan_raw=$(ss -tulnp 2>/dev/null | head -30)
        else
            localhost_scan_raw="nmap and ss not available"
        fi
    fi

    # 5. Detailed Service Detection
    local detailed_scan_raw=""
    if command -v nmap &> /dev/null; then
        if detailed_output=$(timeout $DETAILED_SCAN_TIMEOUT nmap -sV -sC -T4 --top-ports 100 localhost 2>/dev/null); then
            detailed_scan_raw="$detailed_output"
        else
            detailed_scan_raw="Timeout"
        fi
    else
        detailed_scan_raw="Skipped (nmap missing)"
    fi

    # --- OUTPUT PHASE ---

    if [ "$JSON_MODE" = true ]; then
        # Generate JSON using jq
        # We handle multiline strings by creating a JSON object
        
        # Helper to safely encode strings
        jq -n \
           --arg interfaces "$interfaces_raw" \
           --arg primary_ip "$primary_ip" \
           --arg network_range "$network_range" \
           --arg active_hosts "$active_hosts_raw" \
           --arg host_count "$host_count" \
           --arg scan_method "$scan_method" \
           --arg port_scan "$localhost_scan_raw" \
           --arg detailed_scan "$detailed_scan_raw" \
           '{
               module: "network_scan",
               timestamp: (now | todate),
               data: {
                   interfaces: $interfaces,
                   primary_ip: $primary_ip,
                   network_range: $network_range,
                   active_hosts: {
                       count: ($host_count | tonumber),
                       list: ($active_hosts | split("\n") | map(select(length > 0)))
                   },
                   port_scan: {
                       method: $scan_method,
                       output: $port_scan
                   },
                   detailed_scan: {
                       output: $detailed_scan
                   }
               }
           }'
    else
        # HTML Output (Legacy)
        log_scan "<h2>Network Discovery & Port Scanning</h2>"

        log_scan "<h3>Network Interfaces</h3>"
        log_scan "<pre>"
        log_scan "$interfaces_raw"
        log_scan "</pre>"

        log_scan "<h3>Network Range: $network_range</h3>"

        log_scan "<h4>Active Hosts Discovery</h4>"
        log_scan "<pre>"
        if [ "$active_hosts_raw" != "nmap not installed" ] && [ "$active_hosts_raw" != "Timeout or failure" ]; then
            log_scan "Found $host_count active hosts on $network_range:"
            log_scan "$active_hosts_raw"
        else
            log_scan "$active_hosts_raw"
        fi
        log_scan "</pre>"

        log_scan "<h3>Localhost Port Scan (Common Ports)</h3>"
        log_scan "<pre>"
        if [ "$scan_method" = "ss (fallback)" ]; then
            log_scan "Localhost scan timed out after ${PORT_SCAN_TIMEOUT}s, falling back to ss"
        elif [ "$scan_method" = "ss" ]; then
            log_scan "Using ss for port enumeration:"
        fi
        log_scan "$localhost_scan_raw"
        log_scan "</pre>"

        log_scan "<h3>Detailed Service Detection (Localhost Top 100 Ports)</h3>"
        log_scan "<pre>"
        if [ "$detailed_scan_raw" = "Timeout" ]; then
            log_scan "Detailed scan timed out after ${DETAILED_SCAN_TIMEOUT}s - skipped"
        elif [ "$detailed_scan_raw" = "Skipped (nmap missing)" ]; then
            log_scan "nmap not available - skipped detailed scan"
        else
            log_scan "$detailed_scan_raw"
        fi
        log_scan "</pre>"

        echo -e "$SCAN_OUTPUT"
    fi
}

# If sourced, don't execute; if run directly, execute
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    network_scan_module
fi
