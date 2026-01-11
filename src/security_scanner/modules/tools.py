import shutil
from typing import List
from security_scanner.schemas import ToolAssessmentResult, ToolInfo, ToolStatus
from security_scanner.utils import run_command

TOOLS_TO_CHECK = [
    # Scanning
    {"name": "nmap", "category": "Scanning", "description": "Network discovery and security auditing."},
    {"name": "masscan", "category": "Scanning", "description": "Fastest Internet port scanner."},
    {"name": "nikto", "category": "Scanning", "description": "Web server scanner."},
    {"name": "sqlmap", "category": "Scanning", "description": "Automatic SQL injection tool."},
    {"name": "nuclei", "category": "Scanning", "description": "Template based vulnerability scanner."},
    {"name": "gobuster", "category": "Scanning", "description": "Directory/File, DNS and VHost busting tool."},

    # Network
    {"name": "tcpdump", "category": "Network", "description": "Command-line packet analyzer."},
    {"name": "tshark", "category": "Network", "description": "Dump and analyze network traffic.", "package": "wireshark"},
    {"name": "nc", "category": "Network", "description": "Netcat - TCP/IP swiss army knife.", "package": "netcat"},
    {"name": "socat", "category": "Network", "description": "Multipurpose relay (SOcket CAT)."},
    {"name": "hping3", "category": "Network", "description": "Packet assembler/analyzer."},

    # Cracking
    {"name": "hydra", "category": "Cracking", "description": "Parallelized login cracker."},
    {"name": "john", "category": "Cracking", "description": "John the Ripper password cracker.", "package": "john-jumbo"},
    {"name": "hashcat", "category": "Cracking", "description": "World's fastest password cracker."},
    {"name": "medusa", "category": "Cracking", "description": "Parallel network login auditor."},

    # Spoofing
    {"name": "ettercap", "category": "Spoofing", "description": "Comprehensive suite for MITM attacks."},
    {"name": "bettercap", "category": "Spoofing", "description": "Network reconnaissance and MITM attacks."},
    {"name": "mitmproxy", "category": "Spoofing", "description": "Interactive TLS-capable intercepting HTTP proxy."},
    {"name": "arpspoof", "category": "Spoofing", "description": "Intercept packets on a switched LAN (part of dsniff).", "package": "dsniff"},

    # Host
    {"name": "chkrootkit", "category": "Host", "description": "Locally checks for signs of a rootkit."},
    {"name": "rkhunter", "category": "Host", "description": "Rootkit Hunter."},
    {"name": "lynis", "category": "Host", "description": "Security auditing tool for systems."},
    {"name": "enum4linux", "category": "Host", "description": "Enumerating information from Windows/Samba."},
]

def get_package_name(tool_name: str) -> str:
    for tool in TOOLS_TO_CHECK:
        if tool["name"] == tool_name:
            return tool.get("package", tool_name)
    return tool_name

def get_tool_version(name: str) -> str:
    # Basic version check logic
    try:
        if name == "nmap":
            code, out, _ = run_command("nmap --version")
            if code == 0:
                return out.splitlines()[0] if out else "Unknown"
        elif name == "nikto":
            code, out, _ = run_command("nikto -Version")
            if code == 0:
                return out.splitlines()[0] if out else "Unknown"
        elif name == "sqlmap":
            code, out, _ = run_command("sqlmap --version")
            if code == 0:
                return out.strip()
        elif name == "hydra":
            code, out, _ = run_command("hydra -h") # hydra prints version in help or just runs
            # Hydra often prints version to stderr or stdout on help.
            # Let's try to parse first line of help output which usually contains version
            if out:
                return out.splitlines()[0]
        elif name == "john":
            # john usually requires --list=build-info or just run without args to see version banner
            code, out, _ = run_command("john")
            if out:
                return out.splitlines()[0]
    except Exception:
        pass
    
    # Add more specific version checks if needed
    return "Unknown"

def assess_tools() -> ToolAssessmentResult:
    results = []
    
    for tool_def in TOOLS_TO_CHECK:
        name = tool_def["name"]
        path = shutil.which(name)
        
        if path:
            status = ToolStatus.INSTALLED
            version = get_tool_version(name)
            desc = tool_def["description"]
        else:
            status = ToolStatus.MISSING
            version = None
            desc = f"{tool_def['description']} (Recommended)"
            
        results.append(ToolInfo(
            name=name,
            status=status,
            version=version,
            description=desc,
            category=tool_def["category"]
        ))
        
    return ToolAssessmentResult(tools=results)
