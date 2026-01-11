import os
import platform
from typing import List
from security_scanner.schemas import Finding, Severity
from security_scanner.utils import run_command, logger

def check_ssh_config() -> List[Finding]:
    findings = []
    config_path = "/etc/ssh/sshd_config"
    if not os.path.exists(config_path):
        return findings
        
    try:
        with open(config_path, "r") as f:
            content = f.read()
            
        if "PermitRootLogin yes" in content:
            findings.append(Finding(
                title="SSH Root Login Enabled",
                description="SSH allows direct root login.",
                severity=Severity.CRITICAL,
                remediation="Set 'PermitRootLogin no' in /etc/ssh/sshd_config"
            ))
            
        if "PasswordAuthentication yes" in content:
            findings.append(Finding(
                title="SSH Password Authentication Enabled",
                description="Password auth is enabled. Key-based auth is recommended.",
                severity=Severity.MEDIUM,
                remediation="Set 'PasswordAuthentication no' in /etc/ssh/sshd_config"
            ))
    except Exception as e:
        logger.error(f"Error reading sshd_config: {e}")
        
    return findings

def check_firewall() -> List[Finding]:
    findings = []
    system = platform.system()
    
    active = False
    if system == "Linux":
        # Check UFW
        code, out, _ = run_command("ufw status")
        if code == 0 and "active" in out.lower():
            active = True
    elif system == "Darwin":
        # Check PF or socketfilterfw
        code, out, _ = run_command("/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate")
        if code == 0 and "enabled" in out.lower():
            active = True
            
    if not active:
        findings.append(Finding(
            title="Firewall Disabled",
            description="No active firewall detected.",
            severity=Severity.HIGH,
            remediation="Enable UFW (Linux) or Application Firewall (macOS)."
        ))
        
    return findings

def scan_vulnerabilities() -> List[Finding]:
    logger.info("Starting vulnerability scan...")
    findings = []
    
    findings.extend(check_ssh_config())
    findings.extend(check_firewall())
    
    # Check for exposed DB ports
    db_ports = {
        3306: "MySQL",
        5432: "PostgreSQL",
        27017: "MongoDB",
        6379: "Redis"
    }
    
    # Simple check using standard socket connect or checking netstat output
    # Let's reuse the listening services check from system module or just run ss/lsof again
    # For robustness, we'll check open ports on localhost
    import socket
    for port, name in db_ports.items():
        try:
            s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            s.settimeout(0.5)
            result = s.connect_ex(('127.0.0.1', port))
            if result == 0:
                # Open port found. Is it exposed to network?
                # Without complex parsing, we assume localhost binding is OK, but 0.0.0.0 is bad.
                # We'll flag it as Info/Low for now if found, asking user to check binding.
                findings.append(Finding(
                    title=f"{name} Port Open",
                    description=f"{name} is listening on port {port}. Ensure it is not exposed to public network.",
                    severity=Severity.MEDIUM,
                    remediation=f"Check binding for {name}. Should be 127.0.0.1."
                ))
            s.close()
        except Exception:
            pass
            
    return findings
