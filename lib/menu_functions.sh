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
