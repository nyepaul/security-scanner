#!/bin/bash
# menu.sh - Interactive Security Scanner Management Menu
# Provides user-friendly interface for managing scans, reports, logs, and scheduling

# Strict error handling
set -uo pipefail

# Determine script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Detect OS
detect_os() {
    case "$(uname -s)" in
        Linux*)
            OS="Linux"
            ;;
        Darwin*)
            OS="macOS"
            ;;
        *)
            OS="Unknown"
            ;;
    esac
}

# Auto-detect OS at startup
detect_os

# Load configuration
if [ ! -f "$SCRIPT_DIR/config/scanner.conf" ]; then
    echo "ERROR: Configuration file not found: $SCRIPT_DIR/config/scanner.conf"
    exit 1
fi

source "$SCRIPT_DIR/config/scanner.conf"

# Convert relative paths to absolute
[[ "$INSTALL_DIR" = /* ]] || INSTALL_DIR="$SCRIPT_DIR"
[[ "$MODULES_DIR" = /* ]] || MODULES_DIR="$INSTALL_DIR/$MODULES_DIR"
[[ "$REPORTS_DIR" = /* ]] || REPORTS_DIR="$INSTALL_DIR/$REPORTS_DIR"
[[ "$LOGS_DIR" = /* ]] || LOGS_DIR="$INSTALL_DIR/$LOGS_DIR"

# Load helper functions
if [ ! -f "$INSTALL_DIR/lib/menu_functions.sh" ]; then
    echo "ERROR: Helper functions not found: $INSTALL_DIR/lib/menu_functions.sh"
    exit 1
fi

source "$INSTALL_DIR/lib/menu_functions.sh"

# Global variables
BROWSER_CMD=""

# Initialize menu environment
init_menu() {
    # Detect browser
    detect_browser

    # Setup environment - create necessary directories
    local setup_msg=""

    if [ ! -d "$REPORTS_DIR" ]; then
        mkdir -p "$REPORTS_DIR"
        echo "*.html" > "$REPORTS_DIR/.gitignore"
        setup_msg="Created reports directory"
    fi

    if [ ! -d "$LOGS_DIR" ]; then
        mkdir -p "$LOGS_DIR"
        echo "*.log" > "$LOGS_DIR/.gitignore"
        [ -n "$setup_msg" ] && setup_msg="$setup_msg and logs directory" || setup_msg="Created logs directory"
    fi

    # Display setup message if directories were created
    if [ -n "$setup_msg" ]; then
        echo ""
        echo -e "${COLOR_GREEN}✓${NC} $setup_msg"
        echo ""
        sleep 1
    fi
}

# Get last scan information
get_last_scan_info() {
    # Cross-platform approach - use ls instead of find -printf
    local latest_report=$(ls -t "$REPORTS_DIR"/security_report_*.html 2>/dev/null | head -1)

    if [ -n "$latest_report" ]; then
        local basename=$(basename "$latest_report")
        local timestamp=$(echo "$basename" | sed 's/security_report_\(.*\)\.html/\1/')
        local date_part="${timestamp:0:8}"
        local time_part="${timestamp:9:6}"
        local formatted_date="${date_part:0:4}-${date_part:4:2}-${date_part:6:2}"
        local formatted_time="${time_part:0:2}:${time_part:2:2}:${time_part:4:2}"

        echo -e "Last scan: ${COLOR_BOLD}$formatted_date $formatted_time${COLOR_RESET}"
    else
        echo "Last scan: No scans found"
    fi
}

# Main Menu
main_menu() {
    local width=62

    # Determine schedule management label based on OS
    local schedule_label
    if [ "$OS" = "Linux" ]; then
        schedule_label="Schedule Management (systemd)"
    elif [ "$OS" = "macOS" ]; then
        schedule_label="Schedule Management (launchd)"
    else
        schedule_label="Schedule Management"
    fi

    while true; do
        display_header
        get_last_scan_info
        echo ""

        draw_box_top $width
        draw_box_line "${COLOR_YELLOW}Main Menu${NC}" $width
        draw_box_separator $width
        draw_box_line "${COLOR_GREEN}1)${NC} Run Security Scan" $width
        draw_box_line "${COLOR_GREEN}2)${NC} View Reports" $width
        draw_box_line "${COLOR_GREEN}3)${NC} View Logs" $width
        draw_box_line "${COLOR_GREEN}4)${NC} $schedule_label" $width
        draw_box_line "${COLOR_GREEN}5)${NC} Configuration" $width
        draw_box_line "${COLOR_GREEN}6)${NC} Help & Information" $width
        draw_box_line "${COLOR_GREEN}q)${NC} Quit" $width
        draw_box_bottom $width
        echo ""

        read -p "Select option: " choice

        case "$choice" in
            1) scan_menu ;;
            2) reports_menu ;;
            3) logs_menu ;;
            4) schedule_menu ;;
            5) config_menu ;;
            6) help_menu ;;
            q|Q)
                echo ""
                echo "Exiting Security Scanner Menu..."
                exit 0
                ;;
            *)
                error_message "Invalid selection."
                pause_for_user
                ;;
        esac
    done
}

# Scan Execution Menu
scan_menu() {
    local width=62
    while true; do
        display_header
        draw_box_top $width
        draw_box_line "${COLOR_YELLOW}Run Security Scan${NC}" $width
        draw_box_separator $width
        draw_box_line "${COLOR_GREEN}1)${NC} Run full scan with email delivery" $width
        draw_box_line "${COLOR_GREEN}2)${NC} Run scan in test mode (no email)" $width
        draw_box_line "${COLOR_GREEN}b)${NC} Back to Main Menu" $width
        draw_box_bottom $width
        echo ""

        read -p "Select option: " choice

        case "$choice" in
            1) run_scan_with_email ;;
            2) run_scan_test_mode ;;
            b|B) return ;;
            *)
                error_message "Invalid selection."
                pause_for_user
                ;;
        esac
    done
}

run_scan_with_email() {
    display_header
    echo "Run Full Security Scan with Email"
    echo "=================================="
    echo ""
    warning_message "This will run a complete security scan and send results to $EMAIL_RECIPIENT"
    echo "Estimated time: 3-5 minutes"
    echo ""

    if ! confirm_action "Proceed with scan?"; then
        info_message "Scan cancelled"
        pause_for_user
        return
    fi

    echo ""
    info_message "Starting scan..."
    echo ""

    # Start scan
    bash "$INSTALL_DIR/security-scan.sh"
    local scan_result=$?

    echo ""
    if [ $scan_result -eq 0 ]; then
        success_message "Scan completed successfully"

        # Find generated report
        local report=$(find "$REPORTS_DIR" -name "security_report_*.html" -type f -printf '%T+ %p\n' | sort -r | head -1 | cut -d' ' -f2-)

        if [ -n "$report" ] && confirm_action "View report in browser?"; then
            open_in_browser "$report"
        fi
    else
        error_message "Scan failed with exit code $scan_result"
        echo "Check logs in $LOGS_DIR for details"
    fi

    pause_for_user
}

run_scan_test_mode() {
    display_header
    echo "Run Security Scan - Test Mode"
    echo "=============================="
    echo ""
    info_message "This will run a complete scan WITHOUT sending email"
    echo "Estimated time: 3-5 minutes"
    echo ""

    if ! confirm_action "Proceed with scan?"; then
        info_message "Scan cancelled"
        pause_for_user
        return
    fi

    echo ""
    info_message "Starting scan in test mode..."
    echo ""

    # Start scan with --test flag
    bash "$INSTALL_DIR/security-scan.sh" --test
    local scan_result=$?

    echo ""
    if [ $scan_result -eq 0 ]; then
        success_message "Scan completed successfully (no email sent)"

        # Find generated report
        local report=$(find "$REPORTS_DIR" -name "security_report_*.html" -type f -printf '%T+ %p\n' | sort -r | head -1 | cut -d' ' -f2-)

        if [ -n "$report" ] && confirm_action "View report in browser?"; then
            open_in_browser "$report"
        fi
    else
        error_message "Scan failed with exit code $scan_result"
        echo "Check logs in $LOGS_DIR for details"
    fi

    pause_for_user
}

# Reports Menu
reports_menu() {
    local width=62
    while true; do
        display_header
        draw_box_top $width
        draw_box_line "${COLOR_YELLOW}View Reports${NC}" $width
        draw_box_separator $width
        draw_box_line "${COLOR_GREEN}1)${NC} List all reports" $width
        draw_box_line "${COLOR_GREEN}2)${NC} Open report in browser" $width
        draw_box_line "${COLOR_GREEN}3)${NC} Show report statistics" $width
        draw_box_line "${COLOR_GREEN}b)${NC} Back to Main Menu" $width
        draw_box_bottom $width
        echo ""

        read -p "Select option: " choice

        case "$choice" in
            1)
                display_header
                if list_reports "$REPORTS_DIR"; then
                    pause_for_user
                else
                    pause_for_user
                fi
                ;;
            2)
                display_header
                select_and_open_report "$REPORTS_DIR"
                ;;
            3)
                display_header
                show_report_statistics "$REPORTS_DIR"
                pause_for_user
                ;;
            b|B) return ;;
            *)
                error_message "Invalid selection."
                pause_for_user
                ;;
        esac
    done
}

# Logs Menu
logs_menu() {
    local width=62
    while true; do
        display_header
        draw_box_top $width
        draw_box_line "${COLOR_YELLOW}View Logs${NC}" $width
        draw_box_separator $width
        draw_box_line "${COLOR_GREEN}1)${NC} List all logs" $width
        draw_box_line "${COLOR_GREEN}2)${NC} View log file" $width
        draw_box_line "${COLOR_GREEN}3)${NC} Tail latest log (live)" $width
        draw_box_line "${COLOR_GREEN}b)${NC} Back to Main Menu" $width
        draw_box_bottom $width
        echo ""

        read -p "Select option: " choice

        case "$choice" in
            1)
                display_header
                if list_logs "$LOGS_DIR"; then
                    pause_for_user
                else
                    pause_for_user
                fi
                ;;
            2)
                display_header
                select_and_view_log "$LOGS_DIR"
                ;;
            3)
                display_header
                tail_latest_log "$LOGS_DIR"
                pause_for_user
                ;;
            b|B) return ;;
            *)
                error_message "Invalid selection."
                pause_for_user
                ;;
        esac
    done
}

# Schedule Management Menu (cross-platform)
schedule_menu() {
    if [ "$OS" = "Linux" ]; then
        systemd_menu
    elif [ "$OS" = "macOS" ]; then
        launchd_menu
    else
        display_header
        error_message "Schedule management not supported on $OS"
        echo ""
        echo "You can still run scans manually:"
        echo "  $INSTALL_DIR/security-scan.sh"
        echo ""
        pause_for_user
    fi
}

# Linux Systemd Management Menu
systemd_menu() {
    local width=62
    while true; do
        display_header
        draw_box_top $width
        draw_box_line "${COLOR_YELLOW}Schedule Management - systemd${NC}" $width
        draw_box_separator $width
        draw_box_line "${COLOR_GREEN}1)${NC} Show timer status" $width
        draw_box_line "${COLOR_GREEN}2)${NC} Show service status" $width
        draw_box_line "${COLOR_GREEN}3)${NC} View next scheduled run" $width
        draw_box_line "${COLOR_GREEN}4)${NC} View systemd logs" $width
        draw_box_line "${COLOR_GREEN}5)${NC} Enable timer (requires sudo)" $width
        draw_box_line "${COLOR_GREEN}6)${NC} Disable timer (requires sudo)" $width
        draw_box_line "${COLOR_GREEN}7)${NC} Start manual scan via systemd (requires sudo)" $width
        draw_box_line "${COLOR_GREEN}b)${NC} Back to Main Menu" $width
        draw_box_bottom $width
        echo ""

        read -p "Select option: " choice

        case "$choice" in
            1)
                display_header
                show_timer_status
                pause_for_user
                ;;
            2)
                display_header
                show_service_status
                pause_for_user
                ;;
            3)
                display_header
                show_next_run
                pause_for_user
                ;;
            4)
                display_header
                view_systemd_logs
                pause_for_user
                ;;
            5)
                display_header
                enable_timer
                ;;
            6)
                display_header
                disable_timer
                ;;
            7)
                display_header
                start_manual_systemd_scan
                ;;
            b|B) return ;;
            *)
                error_message "Invalid selection."
                pause_for_user
                ;;
        esac
    done
}

# macOS launchd Management Menu
launchd_menu() {
    local width=62
    while true; do
        display_header
        draw_box_top $width
        draw_box_line "${COLOR_YELLOW}Schedule Management - launchd${NC}" $width
        draw_box_separator $width
        draw_box_line "${COLOR_GREEN}1)${NC} Show launchd status" $width
        draw_box_line "${COLOR_GREEN}2)${NC} View launchd logs" $width
        draw_box_line "${COLOR_GREEN}3)${NC} Load/Enable schedule" $width
        draw_box_line "${COLOR_GREEN}4)${NC} Unload/Disable schedule" $width
        draw_box_line "${COLOR_GREEN}5)${NC} Create/Update plist file" $width
        draw_box_line "${COLOR_GREEN}6)${NC} Show plist configuration" $width
        draw_box_line "${COLOR_GREEN}b)${NC} Back to Main Menu" $width
        draw_box_bottom $width
        echo ""

        read -p "Select option: " choice

        case "$choice" in
            1)
                display_header
                show_launchd_status
                pause_for_user
                ;;
            2)
                display_header
                view_launchd_logs
                pause_for_user
                ;;
            3)
                display_header
                load_launchd_service
                ;;
            4)
                display_header
                unload_launchd_service
                ;;
            5)
                display_header
                create_launchd_plist_interactive
                ;;
            6)
                display_header
                show_plist_config
                pause_for_user
                ;;
            b|B) return ;;
            *)
                error_message "Invalid selection."
                pause_for_user
                ;;
        esac
    done
}



enable_timer() {
    echo "Enable Systemd Timer"
    echo "===================="
    echo ""
    warning_message "This will enable automatic weekly scans"
    echo ""

    if ! confirm_action "Enable timer?"; then
        info_message "Cancelled"
        pause_for_user
        return
    fi

    echo ""
    if sudo systemctl enable security-scanner.timer; then
        sudo systemctl start security-scanner.timer
        success_message "Timer enabled and started"
        echo ""
        show_next_run
    else
        error_message "Failed to enable timer"
    fi

    pause_for_user
}

disable_timer() {
    echo "Disable Systemd Timer"
    echo "====================="
    echo ""
    warning_message "This will disable automatic weekly scans"
    echo ""

    if ! confirm_action "Disable timer?"; then
        info_message "Cancelled"
        pause_for_user
        return
    fi

    echo ""
    if sudo systemctl stop security-scanner.timer; then
        sudo systemctl disable security-scanner.timer
        success_message "Timer stopped and disabled"
    else
        error_message "Failed to disable timer"
    fi

    pause_for_user
}

start_manual_systemd_scan() {
    echo "Start Manual Scan via Systemd"
    echo "=============================="
    echo ""
    info_message "This will trigger a scan using the systemd service"
    echo ""

    if ! confirm_action "Start scan?"; then
        info_message "Cancelled"
        pause_for_user
        return
    fi

    echo ""
    info_message "Starting scan..."
    if sudo systemctl start security-scanner.service; then
        success_message "Scan started"
        echo ""
        if confirm_action "Follow systemd logs?"; then
            journalctl -u security-scanner.service -f
        fi
    else
        error_message "Failed to start scan"
    fi

    pause_for_user
}

# Configuration Menu
config_menu() {
    local width=62
    while true; do
        display_header
        draw_box_top $width
        draw_box_line "${COLOR_YELLOW}Configuration${NC}" $width
        draw_box_separator $width
        draw_box_line "${COLOR_GREEN}1)${NC} Display current configuration" $width
        draw_box_line "${COLOR_GREEN}2)${NC} Verify paths" $width
        draw_box_line "${COLOR_GREEN}3)${NC} Check dependencies" $width
        draw_box_line "${COLOR_GREEN}b)${NC} Back to Main Menu" $width
        draw_box_bottom $width
        echo ""

        read -p "Select option: " choice

        case "$choice" in
            1)
                display_header
                show_configuration
                pause_for_user
                ;;
            2)
                display_header
                verify_paths
                pause_for_user
                ;;
            3)
                display_header
                check_dependencies
                pause_for_user
                ;;
            b|B) return ;;
            *)
                error_message "Invalid selection."
                pause_for_user
                ;;
        esac
    done
}

show_configuration() {
    echo "Current Configuration"
    echo "====================="
    echo ""

    echo -e "${COLOR_CYAN}Paths:${COLOR_RESET}"
    echo "  Install directory: $INSTALL_DIR"
    echo "  Modules directory: $MODULES_DIR"
    echo "  Reports directory: $REPORTS_DIR"
    echo "  Logs directory: $LOGS_DIR"
    echo ""

    echo -e "${COLOR_CYAN}Email Settings:${COLOR_RESET}"
    echo "  Recipient: $EMAIL_RECIPIENT"
    echo "  From name: $EMAIL_FROM_NAME"
    echo ""

    echo -e "${COLOR_CYAN}Scan Settings:${COLOR_RESET}"
    echo "  Network discovery timeout: ${NETWORK_DISCOVERY_TIMEOUT}s"
    echo "  Port scan timeout: ${PORT_SCAN_TIMEOUT}s"
    echo "  Detailed scan timeout: ${DETAILED_SCAN_TIMEOUT}s"
    echo "  Nmap timing: $NMAP_TIMING"
    echo ""

    echo -e "${COLOR_CYAN}Module Toggles:${COLOR_RESET}"
    echo "  Network scan: $ENABLE_NETWORK_SCAN"
    echo "  Vulnerability scan: $ENABLE_VULNERABILITY_SCAN"
    echo "  Localhost audit: $ENABLE_LOCALHOST_AUDIT"
    echo ""

    echo -e "${COLOR_CYAN}Retention:${COLOR_RESET}"
    echo "  Max reports to keep: $MAX_REPORTS_TO_KEEP"
    echo "  Max logs to keep: $MAX_LOGS_TO_KEEP"
    echo ""

    echo -e "${COLOR_CYAN}Risk Thresholds:${COLOR_RESET}"
    echo "  Critical threshold: $RISK_CRITICAL_THRESHOLD"
    echo "  High threshold: $RISK_HIGH_THRESHOLD"
    echo "  Medium threshold: $RISK_MEDIUM_THRESHOLD"
    echo ""
}

# Help Menu
help_menu() {
    display_header
    echo "Help & Information"
    echo "=================="
    echo ""

    echo -e "${COLOR_CYAN}About:${COLOR_RESET}"
    echo "  Security Scanner Management Menu v1.0"
    echo "  Interactive interface for managing security scans"
    echo ""

    echo -e "${COLOR_CYAN}Quick Start:${COLOR_RESET}"
    echo "  1. Run a test scan (no email) to verify everything works"
    echo "  2. Check systemd timer status to see scheduled scans"
    echo "  3. View reports in your browser"
    echo "  4. Review logs if you encounter any issues"
    echo ""

    echo -e "${COLOR_CYAN}Common Tasks:${COLOR_RESET}"
    echo "  • Run immediate scan: Menu → 1 → 1 or 2"
    echo "  • View latest report: Menu → 2 → 2 → select #1"
    echo "  • Check next scheduled scan: Menu → 4 → 3"
    echo "  • View recent logs: Menu → 3 → 2 → select #1"
    echo ""

    echo -e "${COLOR_CYAN}Browser Detection:${COLOR_RESET}"
    if [ -n "$BROWSER_CMD" ]; then
        echo "  Detected: $BROWSER_CMD"
    else
        echo "  No browser detected - reports can be opened manually"
    fi
    echo ""

    echo -e "${COLOR_CYAN}Documentation:${COLOR_RESET}"
    echo "  README: $INSTALL_DIR/README.md"
    echo "  Quick Start: $INSTALL_DIR/QUICK_START.txt"
    echo ""

    echo -e "${COLOR_CYAN}Manual Commands:${COLOR_RESET}"
    echo "  Run scan: $INSTALL_DIR/security-scan.sh"
    echo "  Test mode: $INSTALL_DIR/security-scan.sh --test"
    echo "  Help: $INSTALL_DIR/security-scan.sh --help"
    echo ""

    pause_for_user
}

# Entry point
main() {
    init_menu
    main_menu
}

# Run main function
main "$@"
