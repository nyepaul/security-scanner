#!/bin/bash
################################################################################
# Security Scanner Installation Script (Python Version)
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

print_msg() { echo -e "${1}$2${NC}"; }

setup_python_env() {
    print_msg "$BLUE" "[PYTHON] Setting up virtual environment..."
    
    if ! command -v python3 &> /dev/null; then
        print_msg "$RED" "Error: python3 not found."
        exit 1
    fi
    
    # Create venv if not exists
    if [ ! -d "$SCRIPT_DIR/.venv" ]; then
        python3 -m venv "$SCRIPT_DIR/.venv"
        print_msg "$GREEN" "Virtual environment created."
    else
        print_msg "$GREEN" "Virtual environment already exists."
    fi
    
    # Install dependencies
    print_msg "$BLUE" "[PYTHON] Installing dependencies..."
    "$SCRIPT_DIR/.venv/bin/pip" install --upgrade pip
    "$SCRIPT_DIR/.venv/bin/pip" install typer pydantic pydantic-settings jinja2 rich
    
    print_msg "$GREEN" "Python dependencies installed."
}

check_system_deps() {
    print_msg "$BLUE" "[DEPS] Checking system dependencies..."
    
    if ! command -v nmap &> /dev/null; then
        print_msg "$RED" "Warning: nmap not found. Network scanning will be limited."
        if [[ "$OSTYPE" == "darwin"* ]]; then
             print_msg "$BLUE" "Install with: brew install nmap"
        elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
             print_msg "$BLUE" "Install with: sudo apt install nmap"
        fi
    else
        print_msg "$GREEN" "nmap found."
    fi
}

setup_service() {
    # Stub for service setup - pointing to new security-scan.sh
    # Reusing the existing service file but updating path logic if needed
    # For now, we assume the user invokes via the wrapper or cron.
    print_msg "$BLUE" "[SERVICE] Service setup is manual for now."
    print_msg "$BLUE" "To run periodically, add to crontab:"
    print_msg "$BLUE" "0 2 * * 0 $SCRIPT_DIR/pan-sec"
}

main() {
    print_msg "$BLUE" "=========================================="
    print_msg "$BLUE" "Pan-Sec Installation (v2.0)"
    print_msg "$BLUE" "=========================================="
    
    check_system_deps
    setup_python_env
    
    chmod +x "$SCRIPT_DIR/pan-sec"
    
    print_msg "$GREEN" "\nInstallation Complete!"
    print_msg "$GREEN" "Run: ./pan-sec"
    print_msg "$GREEN" "Test mode: ./pan-sec scan --test"
}

main
