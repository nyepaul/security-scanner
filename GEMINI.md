# Gemini Context: Security Scanner

This file provides specific context and instructions for Gemini when working on the `security-scanner` project.

## Project Overview
The `security-scanner` is a cross-platform (Linux/macOS) automated security auditing tool. It uses native bash scripting to perform network scans, vulnerability assessments, and system audits, generating HTML reports sent via email.

## Core Instructions

1.  **Follow the Skills Guide**: Refer to `AI_SKILLS.md` for coding standards, architectural patterns, and workflow guidelines. This is the source of truth for "how we work" on this project.
2.  **Cross-Platform Awareness**: Always consider both Linux and macOS. Use the `CROSS_PLATFORM_GUIDE.md` if you are unsure about specific implementation details.
3.  **Safety & Testing**:
    *   Use `--test` mode for verification.
    *   Validate changes with `./validate-production-ready.sh`.

## Key Files
*   `security-scan.sh`: Main logic.
*   `modules/`: Individual scan components.
*   `AI_SKILLS.md`: Best practices and "skills".
*   `CLAUDE.md`: Additional project context (shared with Claude).

## Quick Reference
*   **Run Test**: `./security-scan.sh --test`
*   **Install**: `./install.sh`
*   **Deploy**: `./deploy-production.sh`
