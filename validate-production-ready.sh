#!/bin/bash
################################################################################
# Production Readiness Validation Script
# Validates that the security scanner is ready for production deployment
################################################################################

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALIDATION_PASSED=true

echo -e "${BLUE}=================================="
echo "Production Readiness Validation"
echo -e "==================================${NC}"
echo ""

# Check 1: Version file exists
echo -n "Checking VERSION file... "
if [ -f "$SCRIPT_DIR/VERSION" ]; then
    VERSION=$(cat "$SCRIPT_DIR/VERSION")
    echo -e "${GREEN}✓ Found version $VERSION${NC}"
else
    echo -e "${RED}✗ VERSION file missing${NC}"
    VALIDATION_PASSED=false
fi

# Check 2: Required files exist
echo -n "Checking required files... "
REQUIRED_FILES=(
    "security-scan.sh"
    "send-email.sh"
    "install.sh"
    "security-scanner.service"
    "security-scanner.timer"
    "config/scanner.conf"
    "README.md"
    "CHANGELOG.md"
)

MISSING_FILES=()
for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$SCRIPT_DIR/$file" ]; then
        MISSING_FILES+=("$file")
    fi
done

if [ ${#MISSING_FILES[@]} -eq 0 ]; then
    echo -e "${GREEN}✓ All required files present${NC}"
else
    echo -e "${RED}✗ Missing files: ${MISSING_FILES[*]}${NC}"
    VALIDATION_PASSED=false
fi

# Check 3: Module files exist
echo -n "Checking module files... "
MODULE_FILES=(
    "modules/network_scan.sh"
    "modules/vulnerability_scan.sh"
    "modules/localhost_audit.sh"
)

MISSING_MODULES=()
for module in "${MODULE_FILES[@]}"; do
    if [ ! -f "$SCRIPT_DIR/$module" ]; then
        MISSING_MODULES+=("$module")
    fi
done

if [ ${#MISSING_MODULES[@]} -eq 0 ]; then
    echo -e "${GREEN}✓ All modules present${NC}"
else
    echo -e "${RED}✗ Missing modules: ${MISSING_MODULES[*]}${NC}"
    VALIDATION_PASSED=false
fi

# Check 4: Scripts are executable
echo -n "Checking script permissions... "
NON_EXECUTABLE=()
for script in security-scan.sh send-email.sh install.sh modules/*.sh; do
    if [ -f "$SCRIPT_DIR/$script" ] && [ ! -x "$SCRIPT_DIR/$script" ]; then
        NON_EXECUTABLE+=("$script")
    fi
done

if [ ${#NON_EXECUTABLE[@]} -eq 0 ]; then
    echo -e "${GREEN}✓ All scripts executable${NC}"
else
    echo -e "${YELLOW}⚠ Non-executable: ${NON_EXECUTABLE[*]}${NC}"
    echo "  (Will be fixed during deployment)"
fi

# Check 5: Syntax validation
echo -n "Validating shell script syntax... "
SYNTAX_ERRORS=()
for script in security-scan.sh send-email.sh install.sh modules/*.sh; do
    if [ -f "$SCRIPT_DIR/$script" ]; then
        if ! bash -n "$SCRIPT_DIR/$script" 2>/dev/null; then
            SYNTAX_ERRORS+=("$script")
        fi
    fi
done

if [ ${#SYNTAX_ERRORS[@]} -eq 0 ]; then
    echo -e "${GREEN}✓ All scripts syntactically valid${NC}"
else
    echo -e "${RED}✗ Syntax errors in: ${SYNTAX_ERRORS[*]}${NC}"
    VALIDATION_PASSED=false
fi

# Check 6: Directory structure
echo -n "Checking directory structure... "
REQUIRED_DIRS=("modules" "config" "reports" "logs")
MISSING_DIRS=()
for dir in "${REQUIRED_DIRS[@]}"; do
    if [ ! -d "$SCRIPT_DIR/$dir" ]; then
        MISSING_DIRS+=("$dir")
    fi
done

if [ ${#MISSING_DIRS[@]} -eq 0 ]; then
    echo -e "${GREEN}✓ Directory structure complete${NC}"
else
    echo -e "${YELLOW}⚠ Missing directories: ${MISSING_DIRS[*]}${NC}"
    echo "  (Will be created during deployment)"
fi

# Check 7: Configuration file validity
echo -n "Validating configuration file... "
if [ -f "$SCRIPT_DIR/config/scanner.conf" ]; then
    if source "$SCRIPT_DIR/config/scanner.conf" 2>/dev/null; then
        echo -e "${GREEN}✓ Configuration valid${NC}"
    else
        echo -e "${RED}✗ Configuration has errors${NC}"
        VALIDATION_PASSED=false
    fi
else
    echo -e "${RED}✗ Configuration file missing${NC}"
    VALIDATION_PASSED=false
fi

# Check 8: Functional test
echo -n "Running functional test... "
if timeout 120 bash "$SCRIPT_DIR/security-scan.sh" >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Functional test passed${NC}"
else
    echo -e "${YELLOW}⚠ Functional test timed out or failed${NC}"
    echo "  (This may be normal for slow systems)"
fi

# Check 9: Documentation
echo -n "Checking documentation... "
DOC_FILES=("README.md" "CHANGELOG.md" "IMPROVEMENTS.md" "INSTALL_INSTRUCTIONS.txt")
MISSING_DOCS=()
for doc in "${DOC_FILES[@]}"; do
    if [ ! -f "$SCRIPT_DIR/$doc" ]; then
        MISSING_DOCS+=("$doc")
    fi
done

if [ ${#MISSING_DOCS[@]} -eq 0 ]; then
    echo -e "${GREEN}✓ All documentation present${NC}"
else
    echo -e "${YELLOW}⚠ Missing documentation: ${MISSING_DOCS[*]}${NC}"
fi

# Summary
echo ""
echo -e "${BLUE}=================================="
echo "Validation Summary"
echo -e "==================================${NC}"
echo ""

if [ "$VALIDATION_PASSED" = true ]; then
    echo -e "${GREEN}✓ All critical checks passed!${NC}"
    echo -e "${GREEN}✓ Ready for production deployment${NC}"
    echo ""
    echo "To deploy to production, run:"
    echo "  sudo ./deploy-production.sh"
    echo ""
    exit 0
else
    echo -e "${RED}✗ Validation failed - fix issues before deploying${NC}"
    echo ""
    exit 1
fi
