# AI Assistant Skills & Guidelines

This document defines the core skills, conventions, and workflows for AI assistants (Claude, Gemini, etc.) working on the `security-scanner` project. It serves as a shared knowledge base to ensure consistency and quality.

## 1. Bash Scripting Expertise

### Core Standards
*   **Safety First**: Main scripts must start with `set -euo pipefail`.
    *   `-e`: Exit immediately if a command exits with a non-zero status.
    *   `-u`: Treat unset variables as an error.
    *   `-o pipefail`: Return value of a pipeline is the status of the last command to exit with a non-zero status.
*   **Module Exception**: Sub-modules (in `modules/`) should generally use `set -uo pipefail` (omitting `-e`) to allow individual checks to fail without crashing the entire module. Failures should be logged/handled gracefully.
*   **Quoting**: Always quote variables (`"$VAR"`) to prevent word splitting and globbing issues.
*   **Test Expressions**: Prefer double brackets `[[ ... ]]` over single `[ ... ]` for safer and more feature-rich comparisons.

### Best Practices
*   **Idempotency**: Scripts (especially `install.sh` and `deploy-production.sh`) should be idempotent. Running them multiple times should be safe and result in the same state.
*   **Path Resolution**: dynamic path resolution using `SCRIPT_DIR`:
    ```bash
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    ```
*   **Logging**: Use a consistent logging format. Messages should be actionable.
*   **Portability**: Be mindful of differences between macOS (BSD-based userland) and Linux (GNU-based userland). Use `grep`, `sed`, `awk` in portable ways or detect OS and adapt.

## 2. Security Scanner Architecture

### Module Protocol
*   **Output**: Modules MUST print HTML content to `stdout`.
*   **Data Passing**: Vulnerability counts are passed via specific string patterns on their own lines:
    *   `CRITICAL=X`
    *   `HIGH=X`
    *   `MEDIUM=X`
    *   `LOW=X`
*   **Isolation**: Modules are executed as subprocesses (`bash module.sh`), not sourced. This prevents variable pollution.

### Report Generation
*   Reports are purely HTML/CSS generated via Bash here-docs.
*   Do not rely on external template engines.
*   CSS is embedded directly in the HTML `<head>`.
*   Risk scores are calculated in the main orchestration script based on the counts returned by modules.

## 3. Cross-Platform Strategy

This project targets **Linux** (production/servers) and **macOS** (development/local scanning).

*   **Service Management**:
    *   **Linux**: Use `systemd` (service + timer units).
    *   **macOS**: Use `launchd` (plist files) or manual execution.
*   **Dependency Management**:
    *   **Linux**: `apt-get`, `yum`, etc.
    *   **macOS**: `brew`.
*   **OS Detection**:
    ```bash
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS specific
    else
        # Linux specific
    fi
    ```

## 4. Development Workflow

### Testing
*   **Dry Run**: Always verify changes with `./security-scan.sh --test` to skip email delivery.
*   **Module Testing**: Test modified modules individually: `bash modules/vulnerability_scan.sh`.
*   **Production Validation**: Run `./validate-production-ready.sh` before marking a task complete.

### Deployment
*   Production logic resides in `deploy-production.sh`.
*   This script handles file copying, permission setting, and systemd reloading.
*   **Never** manually edit files in `/opt/security-scanner` on production; edit the source and redeploy.

## 5. System Prompt Augmentation (Role-Playing)

When acting as an expert developer on this project, adopt the following persona:
*   **Role**: Senior Security Engineer & Systems Architect.
*   **Focus**: Stability, security, and clean code.
*   **Tone**: Professional, concise, and safety-conscious.
*   **Priorities**:
    1.  Don't break the scanner (it runs unattended).
    2.  Don't leak sensitive data (reports contain vulnerability info).
    3.  Ensure emails are delivered reliably.
