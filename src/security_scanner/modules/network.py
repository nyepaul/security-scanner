import re
import platform
from typing import List, Optional
from security_scanner.utils import run_command, logger
from security_scanner.schemas import NetworkScanResult, Host
from security_scanner.config import settings

def get_interfaces() -> List[str]:
    system = platform.system()
    interfaces = []
    
    if system == "Linux":
        code, out, _ = run_command("ip -br addr show")
        if code == 0:
            for line in out.splitlines():
                if "UP" in line:
                    interfaces.append(line.split()[0])
    elif system == "Darwin":
        code, out, _ = run_command("ifconfig -l")
        if code == 0:
            interfaces = out.split()
            
    return interfaces

def get_primary_ip() -> str:
    # Try generic route command first
    code, out, _ = run_command("route get 1.1.1.1" if platform.system() == "Darwin" else "ip route get 1.1.1.1")
    
    if code == 0:
        # Linux: src 192.168.1.50
        # macOS: interface: en0 ... (need ifconfig lookup) but route get returns ip?
        # route get 1.1.1.1 on macOS:
        #    ...
        #    interface: en0
        #    flags: <UP,GATEWAY,HOST,DONE,WASCLONED,IFSCOPE,IFREF>
        #    ...
        # It doesn't give src IP easily.
        
        # Easier Python way:
        import socket
        try:
            s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            s.connect(("1.1.1.1", 80))
            ip = s.getsockname()[0]
            s.close()
            return ip
        except Exception:
            return "127.0.0.1"
    return "127.0.0.1"

def scan_network() -> NetworkScanResult:
    logger.info("Starting network scan...")
    result = NetworkScanResult()
    
    # 1. Interfaces
    result.interfaces = get_interfaces()
    
    # 2. Primary IP & Range
    result.primary_ip = get_primary_ip()
    # Simple /24 assumption for now, consistent with bash script
    base_ip = ".".join(result.primary_ip.split(".")[:3])
    result.network_range = f"{base_ip}.0/24"
    
    # 3. Active Hosts (Nmap)
    # Check if nmap exists
    code, _, _ = run_command("nmap --version")
    if code == 0:
        logger.info(f"Scanning range: {result.network_range}")
        cmd = f"nmap -sn {settings.nmap_timing} {result.network_range}"
        code, out, _ = run_command(cmd, timeout=settings.network_timeout)
        
        if code == 0:
            # Parse Nmap output
            # Nmap scan report for 192.168.1.1
            # Nmap scan report for some-host (192.168.1.5)
            for line in out.splitlines():
                if "Nmap scan report for" in line:
                    parts = line.split()
                    ip = parts[-1].strip("()")
                    hostname = parts[-2] if len(parts) > 5 else None
                    result.active_hosts.append(Host(ip=ip, hostname=hostname))
    else:
        logger.warning("Nmap not found. Skipping host discovery.")
        # Fallback: add localhost
        result.active_hosts.append(Host(ip="127.0.0.1", hostname="localhost"))

    return result
