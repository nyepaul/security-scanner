#!/bin/bash
################################################################################
# Security Scanner Installation Script
# Cross-platform setup for Linux and macOS
################################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Auto-detect script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Detect OS
detect_os() {
    case "$(uname -s)" in
        Linux*)
            OS="Linux"
            if [ -f /etc/os-release ]; then
                . /etc/os-release
                DISTRO=$ID
            else
                DISTRO="unknown"
            fi
            ;;
        Darwin*)
            OS="macOS"
            DISTRO="darwin"
            ;;
        *)
            OS="Unknown"
            DISTRO="unknown"
            ;;
    esac
}

# Print colored message
print_msg() {
    local color=$1
    shift
    echo -e "${color}$*${NC}"
}

print_header() {
    echo ""
    print_msg "$BLUE" "=========================================="
    print_msg "$BLUE" "$1"
    print_msg "$BLUE" "=========================================="
    echo ""
}

print_success() {
    print_msg "$GREEN" "✓ $1"
}

print_warning() {
    print_msg "$YELLOW" "⚠ $1"
}

print_error() {
    print_msg "$RED" "✗ $1"
}

# Update configuration file with correct OS path
update_config_paths() {
    local config_file="$SCRIPT_DIR/config/scanner.conf"

    if [ ! -f "$config_file" ]; then
        print_error "Configuration file not found: $config_file"
        return 1
    fi

    print_msg "$BLUE" "[CONFIG] Updating configuration for $OS..."

    # Update INSTALL_DIR based on OS
    if [ "$OS" = "macOS" ]; then
        sed -i '' "s|^INSTALL_DIR=.*|INSTALL_DIR=\"$SCRIPT_DIR\"|g" "$config_file"
    else
        sed -i "s|^INSTALL_DIR=.*|INSTALL_DIR=\"$SCRIPT_DIR\"|g" "$config_file"
    fi

    print_success "Configuration updated with path: $SCRIPT_DIR"
}

# Setup directory structure
setup_directories() {
    print_msg "$BLUE" "[SETUP] Creating directory structure..."

    # Create directories
    mkdir -p "$SCRIPT_DIR/reports"
    mkdir -p "$SCRIPT_DIR/logs"
    mkdir -p "$SCRIPT_DIR/config"
    mkdir -p "$SCRIPT_DIR/modules"
    mkdir -p "$SCRIPT_DIR/lib"

    # Create .gitignore files
    echo "*.html" > "$SCRIPT_DIR/reports/.gitignore"
    echo "*.log" > "$SCRIPT_DIR/logs/.gitignore"

    # Make scripts executable
    chmod +x "$SCRIPT_DIR"/*.sh 2>/dev/null || true
    chmod +x "$SCRIPT_DIR/modules"/*.sh 2>/dev/null || true
    chmod +x "$SCRIPT_DIR/lib"/*.sh 2>/dev/null || true

    print_success "Directory structure created"
    print_success "Scripts made executable"
}

# Check and install dependencies for macOS
install_macos_dependencies() {
    print_msg "$BLUE" "[DEPS] Checking macOS dependencies..."

    # Check for Homebrew
    if ! command -v brew &> /dev/null; then
        print_warning "Homebrew not found. Install from: https://brew.sh"
        print_msg "$YELLOW" "Run: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        return 1
    fi

    local missing_deps=()

    # Check for nmap
    if ! command -v nmap &> /dev/null; then
        missing_deps+=("nmap")
    fi

    # Check for msmtp (optional for email)
    if ! command -v msmtp &> /dev/null; then
        print_warning "msmtp not installed (optional - needed for email reports)"
        print_msg "$YELLOW" "Install with: brew install msmtp"
    fi

    # Install missing dependencies
    if [ ${#missing_deps[@]} -gt 0 ]; then
        print_msg "$YELLOW" "Installing missing dependencies: ${missing_deps[*]}"
        if brew install "${missing_deps[@]}"; then
            print_success "Dependencies installed successfully"
        else
            print_error "Failed to install some dependencies"
            return 1
        fi
    else
        print_success "All core dependencies already installed"
    fi
}

# Check and install dependencies for Linux
install_linux_dependencies() {
    print_msg "$BLUE" "[DEPS] Checking Linux dependencies..."

    local pkg_manager=""
    local install_cmd=""

    # Detect package manager
    if command -v apt-get &> /dev/null; then
        pkg_manager="apt"
        install_cmd="apt-get install -y"
    elif command -v yum &> /dev/null; then
        pkg_manager="yum"
        install_cmd="yum install -y"
    elif command -v dnf &> /dev/null; then
        pkg_manager="dnf"
        install_cmd="dnf install -y"
    elif command -v pacman &> /dev/null; then
        pkg_manager="pacman"
        install_cmd="pacman -S --noconfirm"
    else
        print_warning "Unknown package manager. Please install dependencies manually:"
        print_msg "$YELLOW" "  - nmap"
        print_msg "$YELLOW" "  - msmtp (optional)"
        print_msg "$YELLOW" "  - chkrootkit (optional)"
        return 1
    fi

    print_msg "$GREEN" "Detected package manager: $pkg_manager"

    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        print_warning "Not running as root. Dependency installation will be skipped."
        print_msg "$YELLOW" "Run with sudo to install dependencies automatically"
        return 0
    fi

    local missing_deps=()

    # Check for nmap
    if ! command -v nmap &> /dev/null; then
        missing_deps+=("nmap")
    fi

    # Check for msmtp (optional)
    if ! command -v msmtp &> /dev/null; then
        print_warning "msmtp not installed (optional - needed for email reports)"
    fi

    # Check for chkrootkit (optional)
    if ! command -v chkrootkit &> /dev/null; then
        print_warning "chkrootkit not installed (optional - for rootkit detection)"
    fi

    # Install missing dependencies
    if [ ${#missing_deps[@]} -gt 0 ]; then
        print_msg "$YELLOW" "Installing missing dependencies: ${missing_deps[*]}"
        if $install_cmd "${missing_deps[@]}"; then
            print_success "Dependencies installed successfully"
        else
            print_error "Failed to install some dependencies"
            return 1
        fi
    else
        print_success "All core dependencies already installed"
    fi
}

# Install systemd service (Linux only)
install_systemd() {
    if [ "$OS" != "Linux" ]; then
        return 0
    fi

    print_msg "$BLUE" "[SYSTEMD] Installing systemd service and timer..."

    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        print_warning "Not running as root. Skipping systemd installation."
        print_msg "$YELLOW" "Run with sudo to install systemd service"
        return 0
    fi

    local service_file="$SCRIPT_DIR/security-scanner.service"
    local timer_file="$SCRIPT_DIR/security-scanner.timer"

    # Verify files exist
    if [ ! -f "$service_file" ]; then
        print_error "Service file not found: $service_file"
        return 1
    fi

    if [ ! -f "$timer_file" ]; then
        print_error "Timer file not found: $timer_file"
        return 1
    fi

    # Copy systemd unit files
    cp "$service_file" /etc/systemd/system/
    cp "$timer_file" /etc/systemd/system/
    print_success "Copied systemd unit files"

    # Reload systemd
    systemctl daemon-reload
    print_success "Reloaded systemd daemon"

    # Enable the timer
    systemctl enable security-scanner.timer
    print_success "Enabled security-scanner timer"

    # Start the timer
    systemctl start security-scanner.timer
    print_success "Started security-scanner timer"

    echo ""
    print_msg "$GREEN" "Systemd installation complete!"
    echo ""
    systemctl status security-scanner.timer --no-pager || true
    echo ""
    print_msg "$GREEN" "Next scheduled run:"
    systemctl list-timers security-scanner.timer --no-pager
}

# Setup macOS scheduling (launchd alternative)
setup_macos_scheduling() {
    print_msg "$BLUE" "[SCHEDULE] macOS scheduling options..."
    echo ""
    print_msg "$YELLOW" "macOS doesn't use systemd. You have several options:"
    echo ""
    print_msg "$GREEN" "Option 1: launchd (recommended)"
    print_msg "$NC" "  Create a launchd plist file to run the scanner automatically"
    print_msg "$NC" "  Location: ~/Library/LaunchAgents/com.security-scanner.plist"
    echo ""
    print_msg "$GREEN" "Option 2: cron"
    print_msg "$NC" "  Add to crontab: crontab -e"
    print_msg "$NC" "  Example: 0 2 * * 0 $SCRIPT_DIR/security-scan.sh"
    echo ""
    print_msg "$GREEN" "Option 3: Manual execution"
    print_msg "$NC" "  Run manually: $SCRIPT_DIR/security-scan.sh"
    print_msg "$NC" "  Or use menu: $SCRIPT_DIR/menu.sh"
    echo ""

    # Ask if user wants to create launchd plist
    read -p "Create launchd plist file? (y/n): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        create_launchd_plist
    fi
}

# Create launchd plist for macOS
create_launchd_plist() {
    local plist_file="$HOME/Library/LaunchAgents/com.security-scanner.plist"

    print_msg "$BLUE" "[LAUNCHD] Creating launchd plist..."

    mkdir -p "$HOME/Library/LaunchAgents"

    cat > "$plist_file" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.security-scanner</string>
    <key>ProgramArguments</key>
    <array>
        <string>$SCRIPT_DIR/security-scan.sh</string>
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
    <string>$SCRIPT_DIR/logs/launchd.log</string>
    <key>StandardErrorPath</key>
    <string>$SCRIPT_DIR/logs/launchd.err</string>
</dict>
</plist>
EOF

    print_success "Created: $plist_file"

    # Load the plist
    if launchctl load "$plist_file" 2>/dev/null; then
        print_success "Loaded launchd service"
        print_msg "$GREEN" "Scanner will run every Sunday at 2:00 AM"
    else
        print_warning "Failed to load launchd service (may already be loaded)"
        print_msg "$YELLOW" "To load manually: launchctl load $plist_file"
    fi
}

# Main installation
main() {
    print_header "Security Scanner Installation"

    # Detect OS
    detect_os
    print_msg "$GREEN" "Operating System: $OS ($DISTRO)"
    print_msg "$GREEN" "Install Directory: $SCRIPT_DIR"
    echo ""

    # Setup directories
    setup_directories
    echo ""

    # Update configuration
    update_config_paths
    echo ""

    # Install dependencies based on OS
    if [ "$OS" = "macOS" ]; then
        install_macos_dependencies
        echo ""
        setup_macos_scheduling
    elif [ "$OS" = "Linux" ]; then
        install_linux_dependencies
        echo ""
        install_systemd
    else
        print_error "Unsupported operating system: $OS"
        exit 1
    fi

    echo ""
    print_header "Installation Complete!"
    echo ""
    print_msg "$GREEN" "Security Scanner is ready to use!"
    echo ""
    print_msg "$BLUE" "Quick Start:"
    print_msg "$NC" "  Interactive menu:  $SCRIPT_DIR/menu.sh"
    print_msg "$NC" "  Run scan:          $SCRIPT_DIR/security-scan.sh"
    print_msg "$NC" "  Test mode:         $SCRIPT_DIR/security-scan.sh --test"
    echo ""
    print_msg "$BLUE" "Reports saved to:  $SCRIPT_DIR/reports/"
    print_msg "$BLUE" "Logs saved to:     $SCRIPT_DIR/logs/"
    echo ""

    if [ "$OS" = "Linux" ] && [ "$EUID" -eq 0 ]; then
        print_msg "$YELLOW" "Note: Systemd service installed. Scanner will run automatically."
    fi
}

# Run main installation
main "$@"
