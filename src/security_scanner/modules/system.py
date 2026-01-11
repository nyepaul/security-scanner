import platform
import os
from typing import List
from security_scanner.schemas import AuditResult, SystemInfo
from security_scanner.utils import run_command, logger

def get_system_info() -> SystemInfo:
    return SystemInfo(
        hostname=platform.node(),
        os=f"{platform.system()} {platform.release()}",
        kernel=platform.version(),
        uptime=get_uptime()
    )

def get_uptime() -> str:
    code, out, _ = run_command("uptime -p" if platform.system() == "Linux" else "uptime")
    return out if code == 0 else "Unknown"

def check_updates() -> tuple[int, List[str]]:
    if platform.system() == "Linux":
        # Check apt
        code, out, _ = run_command("apt list --upgradable")
        if code == 0:
            lines = [line for line in out.splitlines() if "security" in line.lower()]
            return len(lines), lines
    return 0, []

def get_failed_logins() -> tuple[int, List[str]]:
    log_files = ["/var/log/auth.log", "/var/log/secure", "/var/log/system.log"]
    for log_file in log_files:
        if os.path.exists(log_file):
            # Using grep is faster/easier than reading huge files in Python
            cmd = f"grep -iE 'failed password|authentication failure' {log_file} | tail -20"
            code, out, _ = run_command(cmd)
            if code == 0 and out:
                lines = out.splitlines()
                return len(lines), lines
    return 0, []

def get_shell_users() -> List[str]:
    users = []
    try:
        with open("/etc/passwd", "r") as f:
            for line in f:
                parts = line.strip().split(":")
                if len(parts) > 6:
                    shell = parts[6]
                    if any(s in shell for s in ["bash", "zsh", "sh"]) and "nologin" not in shell:
                        users.append(parts[0])
    except Exception:
        pass
    return users

def run_audit() -> AuditResult:
    logger.info("Starting system audit...")
    result = AuditResult(
        system_info=get_system_info()
    )
    
    # Security Updates
    count, details = check_updates()
    result.security_updates_count = count
    result.security_updates_details = details
    
    # Failed Logins
    f_count, f_details = get_failed_logins()
    result.failed_logins_count = f_count
    result.failed_logins_details = f_details
    
    # Listening Services
    code, out, _ = run_command("ss -tulnp" if platform.system() == "Linux" else "lsof -i -P -n | grep LISTEN")
    if code == 0:
        result.listening_services = out.splitlines()[:25]
        
    # Users
    result.users_with_shell = get_shell_users()
    
    return result
