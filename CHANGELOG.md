# Changelog

All notable changes to the Security Scanner project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-12-26

### Added
- Initial production release
- Comprehensive vulnerability scanning module
- Network discovery and port scanning module
- Localhost security audit module
- Beautiful HTML report generation with risk scoring
- Email delivery via msmtp integration
- Systemd timer for automated weekly scans
- Centralized configuration file (`config/scanner.conf`)
- Dependency validation and error handling
- Timeout controls for all network operations
- Configurable risk thresholds and scoring weights

### Features
- **Multi-module scanning**: Network, vulnerability, and localhost audit
- **Risk scoring**: Weighted vulnerability scoring with configurable thresholds
- **Automated scheduling**: Weekly scans via systemd timer
- **Email reports**: HTML reports delivered via email
- **Graceful error handling**: Modules can fail without crashing entire scan
- **Timeout protection**: Network scans complete within configured timeouts
- **Production-ready**: Comprehensive testing and validation

### Configuration
- Configurable scan timeouts (network: 60s, port: 30s, detailed: 45s)
- Adjustable risk thresholds (Critical: 50, High: 30, Medium: 15)
- Customizable vulnerability weights (Critical: 10, High: 5, Medium: 2, Low: 1)
- Module enable/disable flags
- Email and path configuration

### Security
- Runs as unprivileged user (paul)
- Resource limits (50% CPU, 1GB memory)
- Security hardening (NoNewPrivileges, PrivateTmp)
- No sensitive data in reports

### Documentation
- Complete README.md with installation and usage instructions
- IMPROVEMENTS.md detailing all enhancements
- INSTALL_INSTRUCTIONS.txt for systemd setup
- Inline code comments and documentation

### Testing
- All modules tested and validated
- Full scan completes in ~80 seconds
- Complete 304-line HTML reports generated
- Syntax validation passed for all scripts
- Production deployment tested

---

## Version History

- **1.0.0** - Production release (2025-12-26)
  - Feature-complete security scanner
  - All critical and high-priority issues resolved
  - Comprehensive testing completed
  - Ready for production deployment
