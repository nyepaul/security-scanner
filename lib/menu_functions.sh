#!/bin/bash
# menu_functions.sh - Helper functions library for interactive menu
# Provides display, user interaction, and utility functions

# Color definitions
readonly COLOR_RESET='\033[0m'
readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[1;33m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_CYAN='\033[0;36m'
readonly COLOR_WHITE='\033[1;37m'
readonly COLOR_MAGENTA='\033[0;35m'
readonly COLOR_BOLD='\033[1m'
readonly NC='\033[0m'

# Box-drawing helper functions
# Style: Single thin line, Green color
readonly BOX_COLOR="${COLOR_GREEN}"

strip_ansi() {
    echo -e "$1" | sed 's/\x1B\[[0-9;]*[a-zA-Z]//g'
}

display_header() {
    local width=62
    clear
    echo ""
    draw_box_top $width
    draw_box_centered "${COLOR_WHITE}Security Scanner Management Menu${NC}" $width
    draw_box_bottom $width
    echo ""
    echo -e "${COLOR_WHITE}Host:${NC} ${COLOR_GREEN}$(hostname)${NC}"
    echo -e "${COLOR_WHITE}Date:${NC} $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
}

display_footer() {
    echo ""
    echo -e "${COLOR_BLUE}Working directory: $INSTALL_DIR${COLOR_RESET}"
}

draw_box_top() {
    local width="${1:-62}"
    echo -ne "${BOX_COLOR}┌"
    printf '─%.0s' $(seq 1 $((width-2)))
    echo -e "┐${NC}"
}

draw_box_bottom() {
    local width="${1:-62}"
    echo -ne "${BOX_COLOR}└"
    printf '─%.0s' $(seq 1 $((width-2)))
    echo -e "┘${NC}"
}

draw_box_separator() {
    local width="${1:-62}"
    echo -ne "${BOX_COLOR}├"
    printf '─%.0s' $(seq 1 $((width-2)))
    echo -e "┤${NC}"
}

draw_box_line() {
    local content="$1"
    local width="${2:-62}"

    # Strip ANSI codes for length calculation
    local visual_content=$(strip_ansi "$content")
    local content_len=${#visual_content}
    local padding=$((width - content_len - 3))
    
    # Safety check for negative padding
    [ $padding -lt 0 ] && padding=0

    echo -ne "${BOX_COLOR}│${NC} ${content}"
    printf "%${padding}s" ""
    echo -e "${BOX_COLOR}│${NC}"
}

draw_box_centered() {
    local content="$1"
    local width="${2:-62}"
    
    local visual_content=$(strip_ansi "$content")
    local content_len=${#visual_content}
    local left_pad=$(( (width - content_len - 2) / 2 ))
    local right_pad=$(( width - content_len - left_pad - 2 ))
    
    echo -ne "${BOX_COLOR}│${NC}"
    printf "%${left_pad}s" ""
    echo -ne "${content}"
    printf "%${right_pad}s" ""
    echo -e "${BOX_COLOR}│${NC}"
}

pause_for_user() {
    echo ""
    read -p "Press Enter to continue..." -r
}

# User interaction functions
confirm_action() {
    local prompt="$1"
    local response

    while true; do
        read -p "$prompt [y/N]: " -r response
        case "$response" in
            [yY][eE][sS]|[yY])
                return 0
                ;;
            [nN][oO]|[nN]|"")
                return 1
                ;;
            *)
                echo "Please answer yes or no."
                ;;
        esac
    done
}

error_message() {
    local message="$1"
    echo -e "${COLOR_RED}[✗] ERROR: $message${NC}" >&2
}

success_message() {
    local message="$1"
    echo -e "${COLOR_GREEN}[✓] SUCCESS: $message${NC}"
}

warning_message() {
    local message="$1"
    echo -e "${COLOR_YELLOW}[!] WARNING: $message${NC}"
}

info_message() {
    local message="$1"
    echo -e "${COLOR_CYAN}[i] INFO: $message${NC}"
}

# Browser detection and opening
detect_browser() {
    # Check for common browsers in order of preference
    local browsers=("xdg-open" "firefox" "google-chrome" "chromium" "chromium-browser" "sensible-browser")

    for browser in "${browsers[@]}"; do
        if command -v "$browser" &> /dev/null; then
            BROWSER_CMD="$browser"
            return 0
        fi
    done

    BROWSER_CMD=""
    return 1
}

open_in_browser() {
    local file="$1"

    if [ ! -f "$file" ]; then
        error_message "File not found: $file"
        return 1
    fi

    if [ -z "$BROWSER_CMD" ]; then
        warning_message "No browser detected"
        echo "Report location: $file"
        echo "Please open this file manually in your browser"
        return 1
    fi

    info_message "Opening in browser ($BROWSER_CMD)..."

    # Try to open the browser and capture any errors
    if "$BROWSER_CMD" "$file" >/dev/null 2>&1 &
    then
        local browser_pid=$!
        # Give the browser a moment to start
        sleep 0.5

        # Check if the process is still running (browser successfully started)
        if kill -0 "$browser_pid" 2>/dev/null || ! kill -0 "$browser_pid" 2>/dev/null; then
            # Either still running or already completed successfully
            success_message "Report opened: $(basename "$file")"
            echo "Location: $file"
            return 0
        else
            error_message "Browser process failed to start"
            echo "Try opening manually: $file"
            return 1
        fi
    else
        error_message "Failed to execute browser command"
        echo "Command: $BROWSER_CMD"
        echo "File: $file"
        echo "Please open the file manually"
        return 1
    fi
}

# Report management functions
list_reports() {
    local reports_dir="$1"
    local reports=()

    # Find all report files sorted by modification time (newest first)
    while IFS= read -r -d '' report; do
        reports+=("$report")
    done < <(find "$reports_dir" -name "security_report_*.html" -type f -print0 | sort -zr)

    if [ ${#reports[@]} -eq 0 ]; then
        warning_message "No reports found in $reports_dir"
        return 1
    fi

    echo ""
    echo "Available Reports:"
    echo "=================="

    local index=1
    for report in "${reports[@]}"; do
        local basename=$(basename "$report")
        # Extract timestamp from filename (security_report_YYYYMMDD_HHMMSS.html)
        local timestamp=$(echo "$basename" | sed 's/security_report_\(.*\)\.html/\1/')
        local date_part="${timestamp:0:8}"
        local time_part="${timestamp:9:6}"

        # Format as YYYY-MM-DD HH:MM:SS
        local formatted_date="${date_part:0:4}-${date_part:4:2}-${date_part:6:2}"
        local formatted_time="${time_part:0:2}:${time_part:2:2}:${time_part:4:2}"

        local size=$(du -h "$report" | cut -f1)

        echo -e "$index) ${COLOR_BOLD}$formatted_date $formatted_time${COLOR_RESET} - $size - $basename"
        ((index++))
    done

    echo ""
    return 0
}

select_and_open_report() {
    local reports_dir="$1"
    local reports=()

    # Build array of reports
    while IFS= read -r -d '' report; do
        reports+=("$report")
    done < <(find "$reports_dir" -name "security_report_*.html" -type f -print0 | sort -zr)

    if [ ${#reports[@]} -eq 0 ]; then
        error_message "No reports found"
        pause_for_user
        return 1
    fi

    # Display reports
    list_reports "$reports_dir"

    # Get user selection
    echo "Enter report number to open (or 0 to cancel): "
    read -r selection

    if [ "$selection" = "0" ] || [ -z "$selection" ]; then
        info_message "Cancelled"
        pause_for_user
        return 1
    fi

    if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt ${#reports[@]} ]; then
        error_message "Invalid selection"
        pause_for_user
        return 1
    fi

    local selected_report="${reports[$((selection-1))]}"
    echo ""
    open_in_browser "$selected_report"
    pause_for_user
}

show_report_statistics() {
    local reports_dir="$1"
    local count=$(find "$reports_dir" -name "security_report_*.html" -type f | wc -l)

    echo ""
    echo "Report Statistics:"
    echo "=================="
    echo "Total reports: $count"

    if [ "$count" -gt 0 ]; then
        local total_size=$(du -sh "$reports_dir" 2>/dev/null | cut -f1)
        local newest=$(find "$reports_dir" -name "security_report_*.html" -type f -printf '%T+ %p\n' | sort -r | head -1 | cut -d' ' -f2-)
        local oldest=$(find "$reports_dir" -name "security_report_*.html" -type f -printf '%T+ %p\n' | sort | head -1 | cut -d' ' -f2-)

        echo "Total size: $total_size"
        if [ -n "$newest" ]; then
            echo "Newest: $(basename "$newest")"
        fi
        if [ -n "$oldest" ]; then
            echo "Oldest: $(basename "$oldest")"
        fi
    fi

    echo ""
}

# Log management functions
list_logs() {
    local logs_dir="$1"
    local logs=()

    # Find all log files sorted by modification time (newest first)
    while IFS= read -r -d '' log; do
        logs+=("$log")
    done < <(find "$logs_dir" -name "scan_*.log" -type f -print0 | sort -zr)

    if [ ${#logs[@]} -eq 0 ]; then
        warning_message "No logs found in $logs_dir"
        return 1
    fi

    echo ""
    echo "Available Logs:"
    echo "==============="

    local index=1
    for log in "${logs[@]}"; do
        local basename=$(basename "$log")
        local timestamp=$(echo "$basename" | sed 's/scan_\(.*\)\.log/\1/')
        local date_part="${timestamp:0:8}"
        local time_part="${timestamp:9:6}"

        local formatted_date="${date_part:0:4}-${date_part:4:2}-${date_part:6:2}"
        local formatted_time="${time_part:0:2}:${time_part:2:2}:${time_part:4:2}"

        local size=$(du -h "$log" | cut -f1)
        local lines=$(wc -l < "$log")

        echo -e "$index) ${COLOR_BOLD}$formatted_date $formatted_time${COLOR_RESET} - $size - $lines lines - $basename"
        ((index++))
    done

    echo ""
    return 0
}

select_and_view_log() {
    local logs_dir="$1"
    local logs=()

    # Build array of logs
    while IFS= read -r -d '' log; do
        logs+=("$log")
    done < <(find "$logs_dir" -name "scan_*.log" -type f -print0 | sort -zr)

    if [ ${#logs[@]} -eq 0 ]; then
        error_message "No logs found"
        pause_for_user
        return 1
    fi

    # Display logs
    list_logs "$logs_dir"

    # Get user selection
    echo "Enter log number to view (or 0 to cancel): "
    read -r selection

    if [ "$selection" = "0" ] || [ -z "$selection" ]; then
        info_message "Cancelled"
        pause_for_user
        return 1
    fi

    if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt ${#logs[@]} ]; then
        error_message "Invalid selection"
        pause_for_user
        return 1
    fi

    local selected_log="${logs[$((selection-1))]}"
    echo ""
    info_message "Opening log in pager (press 'q' to exit)..."
    sleep 1
    less "$selected_log"
}

tail_latest_log() {
    local logs_dir="$1"

    # Find the most recent log
    local latest_log=$(find "$logs_dir" -name "scan_*.log" -type f -printf '%T+ %p\n' | sort -r | head -1 | cut -d' ' -f2-)

    if [ -z "$latest_log" ]; then
        error_message "No logs found"
        pause_for_user
        return 1
    fi

    echo ""
    info_message "Following latest log: $(basename "$latest_log")"
    info_message "Press Ctrl+C to stop..."
    echo ""
    sleep 2
    tail -f "$latest_log"
}

# Systemd management functions
check_sudo_available() {
    if ! sudo -n true 2>/dev/null; then
        warning_message "This operation requires sudo privileges"
        return 1
    fi
    return 0
}

show_timer_status() {
    echo ""
    echo "Timer Status:"
    echo "============="
    systemctl status security-scanner.timer --no-pager -l
    echo ""
}

show_service_status() {
    echo ""
    echo "Service Status:"
    echo "==============="
    systemctl status security-scanner.service --no-pager -l
    echo ""
}

show_next_run() {
    echo ""
    echo "Scheduled Run Information:"
    echo "=========================="
    systemctl list-timers security-scanner.timer --no-pager
    echo ""
}

view_systemd_logs() {
    echo ""
    info_message "Showing systemd logs (press 'q' to exit)..."
    echo ""
    sleep 1
    journalctl -u security-scanner.service --no-pager -n 100
    echo ""
}

# Dependency checking
check_dependencies() {
    local deps=("nmap" "msmtp" "chkrootkit")
    local missing=()

    echo ""
    echo "Dependency Status:"
    echo "=================="

    for dep in "${deps[@]}"; do
        if command -v "$dep" &> /dev/null; then
            echo -e "${COLOR_GREEN}✓${COLOR_RESET} $dep: $(command -v "$dep")"
        else
            echo -e "${COLOR_RED}✗${COLOR_RESET} $dep: NOT FOUND"
            missing+=("$dep")
        fi
    done

    echo ""

    if [ ${#missing[@]} -gt 0 ]; then
        warning_message "Missing dependencies: ${missing[*]}"
        return 1
    fi

    return 0
}

# Path verification
verify_paths() {
    local paths=("$INSTALL_DIR" "$MODULES_DIR" "$REPORTS_DIR" "$LOGS_DIR")
    local path_names=("Install directory" "Modules directory" "Reports directory" "Logs directory")
    local all_good=true

    echo ""
    echo "Path Verification:"
    echo "=================="

    for i in "${!paths[@]}"; do
        local path="${paths[$i]}"
        local name="${path_names[$i]}"

        if [ -d "$path" ]; then
            echo -e "${COLOR_GREEN}✓${COLOR_RESET} $name: $path"
        else
            echo -e "${COLOR_RED}✗${COLOR_RESET} $name: $path (NOT FOUND)"
            all_good=false
        fi
    done

    echo ""

    if [ "$all_good" = false ]; then
        warning_message "Some paths are missing"
        return 1
    fi

    return 0
}

################################################################################
# macOS launchd Management Functions
################################################################################

PLIST_FILE="$HOME/Library/LaunchAgents/com.security-scanner.plist"

show_launchd_status() {
    echo ""
    echo "launchd Service Status:"
    echo "======================="
    echo ""

    if [ ! -f "$PLIST_FILE" ]; then
        warning_message "Plist file not found: $PLIST_FILE"
        echo ""
        echo "Create the plist file first (option 5 in menu)"
        return 1
    fi

    echo -e "${COLOR_BLUE}Plist File:${NC} $PLIST_FILE"
    echo ""

    # Check if loaded
    if launchctl list | grep -q "com.security-scanner"; then
        success_message "Service is LOADED and ACTIVE"
        echo ""
        echo "Service Details:"
        launchctl list | grep "com.security-scanner"
        echo ""
        echo -e "${COLOR_GREEN}Status:${NC} Scheduled scans enabled"
        echo -e "${COLOR_GREEN}Schedule:${NC} Every Sunday at 2:00 AM"
    else
        warning_message "Service is NOT LOADED"
        echo ""
        echo "Load the service with option 3 in menu"
    fi

    echo ""
}

view_launchd_logs() {
    echo ""
    info_message "Viewing launchd logs..."
    echo ""

    local log_file="$INSTALL_DIR/logs/launchd.log"
    local err_file="$INSTALL_DIR/logs/launchd.err"

    if [ -f "$log_file" ]; then
        echo "=== Standard Output Log ==="
        echo ""
        tail -50 "$log_file"
        echo ""
    else
        warning_message "No stdout log found at: $log_file"
        echo ""
    fi

    if [ -f "$err_file" ]; then
        echo "=== Error Log ==="
        echo ""
        tail -50 "$err_file"
        echo ""
    else
        info_message "No error log found at: $err_file"
        echo ""
    fi

    echo "Full logs at:"
    echo "  Stdout: $log_file"
    echo "  Stderr: $err_file"
    echo ""
}

load_launchd_service() {
    echo "Load launchd Service"
    echo "===================="
    echo ""

    if [ ! -f "$PLIST_FILE" ]; then
        error_message "Plist file not found: $PLIST_FILE"
        echo ""
        echo "Create the plist file first (option 5 in menu)"
        pause_for_user
        return 1
    fi

    # Check if already loaded
    if launchctl list | grep -q "com.security-scanner"; then
        warning_message "Service is already loaded"
        echo ""
        if confirm_action "Reload service?"; then
            launchctl unload "$PLIST_FILE" 2>/dev/null
            sleep 1
        else
            info_message "Cancelled"
            pause_for_user
            return 0
        fi
    fi

    info_message "Loading service from: $PLIST_FILE"
    echo ""

    if launchctl load "$PLIST_FILE" 2>/dev/null; then
        success_message "Service loaded successfully"
        echo ""
        echo -e "${COLOR_GREEN}✓${NC} Scheduled scans enabled"
        echo -e "${COLOR_GREEN}✓${NC} Will run every Sunday at 2:00 AM"
        echo ""
        echo "Check status with option 1"
    else
        error_message "Failed to load service"
        echo ""
        echo "This could be due to:"
        echo "  - Service already loaded (try option 4 to unload first)"
        echo "  - Permission issues"
        echo "  - Invalid plist format"
    fi

    pause_for_user
}

unload_launchd_service() {
    echo "Unload launchd Service"
    echo "======================"
    echo ""

    if ! launchctl list | grep -q "com.security-scanner"; then
        warning_message "Service is not currently loaded"
        pause_for_user
        return 0
    fi

    warning_message "This will disable automatic scheduled scans"
    echo ""

    if ! confirm_action "Unload service?"; then
        info_message "Cancelled"
        pause_for_user
        return 0
    fi

    echo ""
    if launchctl unload "$PLIST_FILE" 2>/dev/null; then
        success_message "Service unloaded successfully"
        echo ""
        echo "Scheduled scans are now disabled"
        echo "You can still run scans manually"
    else
        error_message "Failed to unload service"
    fi

    pause_for_user
}

create_launchd_plist_interactive() {
    echo "Create/Update launchd Plist"
    echo "==========================="
    echo ""

    if [ -f "$PLIST_FILE" ]; then
        warning_message "Plist file already exists"
        echo ""
        if ! confirm_action "Overwrite existing plist?"; then
            info_message "Cancelled"
            pause_for_user
            return 0
        fi

        # Unload if currently loaded
        if launchctl list | grep -q "com.security-scanner"; then
            info_message "Unloading current service..."
            launchctl unload "$PLIST_FILE" 2>/dev/null
        fi
    fi

    echo ""
    info_message "Creating plist file..."

    # Create directory if needed
    mkdir -p "$HOME/Library/LaunchAgents"

    # Create plist
    cat > "$PLIST_FILE" << PLIST_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.security-scanner</string>
    <key>ProgramArguments</key>
    <array>
        <string>$INSTALL_DIR/security-scan.sh</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Weekday</key>
        <integer>0</integer>
        <key>Hour</key>
        <integer>2</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
    <key>StandardOutPath</key>
    <string>$INSTALL_DIR/logs/launchd.log</string>
    <key>StandardErrorPath</key>
    <string>$INSTALL_DIR/logs/launchd.err</string>
</dict>
</plist>
PLIST_EOF

    if [ -f "$PLIST_FILE" ]; then
        success_message "Plist file created successfully"
        echo ""
        echo -e "${COLOR_GREEN}Location:${NC} $PLIST_FILE"
        echo -e "${COLOR_GREEN}Schedule:${NC} Every Sunday at 2:00 AM"
        echo ""

        if confirm_action "Load service now?"; then
            echo ""
            if launchctl load "$PLIST_FILE" 2>/dev/null; then
                success_message "Service loaded and enabled"
            else
                error_message "Failed to load service"
            fi
        fi
    else
        error_message "Failed to create plist file"
    fi

    pause_for_user
}

show_plist_config() {
    echo ""
    echo "launchd Plist Configuration:"
    echo "============================"
    echo ""

    if [ ! -f "$PLIST_FILE" ]; then
        warning_message "Plist file not found: $PLIST_FILE"
        echo ""
        echo "Create it with option 5"
        return 1
    fi

    echo -e "${COLOR_BLUE}File:${NC} $PLIST_FILE"
    echo ""
    echo "Contents:"
    echo "========="
    cat "$PLIST_FILE"
    echo ""

    # Extract schedule info
    echo "Schedule Details:"
    echo "================="
    if grep -q "Weekday" "$PLIST_FILE"; then
        local weekday=$(grep -A1 "Weekday" "$PLIST_FILE" | grep "integer" | sed 's/.*<integer>\(.*\)<\/integer>/\1/')
        local hour=$(grep -A1 "Hour" "$PLIST_FILE" | grep "integer" | sed 's/.*<integer>\(.*\)<\/integer>/\1/')
        local minute=$(grep -A1 "Minute" "$PLIST_FILE" | grep "integer" | sed 's/.*<integer>\(.*\)<\/integer>/\1/')

        local day_name="Sunday"
        case $weekday in
            0) day_name="Sunday" ;;
            1) day_name="Monday" ;;
            2) day_name="Tuesday" ;;
            3) day_name="Wednesday" ;;
            4) day_name="Thursday" ;;
            5) day_name="Friday" ;;
            6) day_name="Saturday" ;;
        esac

        echo -e "${COLOR_GREEN}Day:${NC} $day_name (weekday $weekday)"
        echo -e "${COLOR_GREEN}Time:${NC} $(printf "%02d:%02d" $hour $minute)"
    fi

    echo ""
}
