# Redesign Evaluation Report

**Date:** 2026-01-11
**Project:** Security Scanner
**Evaluated Against:** `pan-skills/design-dev-kit/AI_SKILLS.md`

## 1. Executive Summary

The current `security-scanner` application is a robust Bash-based orchestration tool that has been recently modernized to use a JSON data pipeline for reporting. While it meets functional requirements and now separates data from presentation, it fundamentally diverges from several core standards defined in `AI_SKILLS.md`, particularly regarding Type Safety, Unit Testing, and Object-Oriented Design.

**Recommendation:** A gradual migration to a Python-based CLI architecture is recommended to improve maintainability, testability, and security compliance.

## 2. Compliance Analysis

### 2.1 System Design & Architecture
*   **Current:** Bash script orchestration (`security-scan.sh`) invoking subprocesses (`modules/*.sh`). Data is passed via stdout (JSON) and files.
*   **Standard:** "Trade-off Analysis", "Security by Design".
*   **Gap:** The architecture is functional but brittle. Error handling relies on exit codes and log parsing. Passing complex data structures between Bash scripts is difficult (solved partially by `jq`).
*   **Verdict:** **Partial Compliance**. The recent JSON refactor improved this significantly by introducing a structured data contract.

### 2.2 Coding Standards
*   **Standard:** "Strict Typing", "No `any`", "SOLID", "DRY".
*   **Current:**
    *   **Bash:** Untyped. Stringly-typed logic. Difficult to enforce SOLID principles.
    *   **Python (`generate-html-report.py`):** Uses Python, but lacks type hints (`def generate_html_report(json_file, output_file):` has no types).
*   **Gap:** **Significant**. Bash does not support strict typing. The Python script needs type hints.
*   **Verdict:** **Non-Compliant**.

### 2.3 Security Standards
*   **Standard:** "Input Validation (Zod/Pydantic)", "No Hardcoded Secrets".
*   **Current:**
    *   **Input Validation:** Minimal. Relies on Bash variable expansion. `nmap` commands use variables that *should* be safe, but no formal schema validation exists for inputs or outputs.
    *   **Secrets:** Config is separate (`config/scanner.conf`), but no secrets management library is used.
*   **Gap:** Lack of formal schema validation for module outputs (e.g., if `nmap` output changes format, the parser breaks).
*   **Verdict:** **Partial Compliance**.

### 2.4 Development Workflow & Testing
*   **Standard:** "Unit Tests", "Integration Tests", "TDD".
*   **Current:**
    *   **Testing:** No unit tests for Bash functions. Integration testing is manual or via "run the whole thing" (`--test`).
    *   `validate-production-ready.sh` is a check script, not a test suite.
*   **Gap:** **Critical**. It is nearly impossible to unit test individual Bash logic (e.g., "did the regex extract the IP correctly?") without running the command.
*   **Verdict:** **Non-Compliant**.

## 3. Redesign Recommendation

To fully align with `AI_SKILLS.md`, the application should be redesigned as a **Python CLI Application**.

### Proposed Architecture

1.  **Language:** Python 3.10+
2.  **CLI Framework:** `typer` (Clean, type-safe CLI commands).
3.  **Configuration:** `pydantic-settings` (Type-safe config from ENV/files).
4.  **Domain Models:** `pydantic` models for:
    *   `NetworkScanResult`
    *   `Vulnerability`
    *   `AuditResult`
    *   `SecurityReport`
5.  **Module Pattern:**
    *   `scanner/modules/network.py`: Wraps `nmap` using `python-nmap` or `subprocess` with Pydantic parsing.
    *   `scanner/modules/audit.py`: Uses `psutil` or subprocesses for system checks.
6.  **Reporting:** `jinja2` templates for HTML generation (replacing string concatenation).
7.  **Testing:** `pytest` for unit tests (mocking subprocess calls) and integration tests.

### Migration Path (Strangler Fig Pattern)

We do not need to rewrite everything at once.

1.  **Phase 1 (Done):** Decouple Reporting. (Completed with `generate-html-report.py` + JSON).
2.  **Phase 2:** Replace the "Orchestrator". Write `main.py` using `typer` that calls the *existing* Bash modules, parses their JSON, and calls the Python reporter.
3.  **Phase 3:** Rewrite Modules one by one.
    *   Replace `modules/network_scan.sh` with `scanner/modules/network.py`.
    *   Replace `modules/localhost_audit.sh` with `scanner/modules/audit.py`.
4.  **Phase 4:** Deprecate Bash. Remove `security-scan.sh` and legacy scripts.

## 4. Immediate Actions (Low Effort, High Value)

If a full redesign is not prioritized:

1.  **Add Type Hints**: Update `scripts/generate-html-report.py` with full type annotations.
2.  **Validate JSON**: Add a simple JSON schema check (using Python) before generating reports.
3.  **Unit Tests for Python**: Add `pytest` tests for the reporting logic.

