from enum import Enum
from typing import List, Optional, Dict, Any
from pydantic import BaseModel, Field
from datetime import datetime

class Severity(str, Enum):
    CRITICAL = "CRITICAL"
    HIGH = "HIGH"
    MEDIUM = "MEDIUM"
    LOW = "LOW"
    INFO = "INFO"

class Finding(BaseModel):
    title: str
    description: str
    severity: Severity
    remediation: Optional[str] = None
    evidence: Optional[str] = None

class Host(BaseModel):
    ip: str
    hostname: Optional[str] = None
    mac_address: Optional[str] = None
    vendor: Optional[str] = None
    open_ports: List[int] = Field(default_factory=list)

class NetworkScanResult(BaseModel):
    interfaces: List[str] = Field(default_factory=list)
    active_hosts: List[Host] = Field(default_factory=list)
    primary_ip: Optional[str] = None
    network_range: Optional[str] = None

class SystemInfo(BaseModel):
    hostname: str
    os: str
    kernel: str
    uptime: str

class AuditResult(BaseModel):
    system_info: SystemInfo
    security_updates_count: int = 0
    security_updates_details: List[str] = Field(default_factory=list)
    listening_services: List[str] = Field(default_factory=list)
    failed_logins_count: int = 0
    failed_logins_details: List[str] = Field(default_factory=list)
    firewall_status: str = "Unknown"
    users_with_shell: List[str] = Field(default_factory=list)
    
class ScanSummary(BaseModel):
    total: int
    critical: int
    high: int
    medium: int
    low: int
    info: int

class ToolStatus(str, Enum):
    INSTALLED = "Installed"
    MISSING = "Missing"

class ToolInfo(BaseModel):
    name: str
    status: ToolStatus
    version: Optional[str] = None
    description: str
    category: str

class ToolAssessmentResult(BaseModel):
    tools: List[ToolInfo] = Field(default_factory=list)

class SecurityReport(BaseModel):
    scan_id: str
    timestamp: datetime
    hostname: str
    risk_score: int
    risk_level: str
    summary: ScanSummary
    findings: List[Finding]
    network_scan: Optional[NetworkScanResult] = None
    audit_result: Optional[AuditResult] = None
    tool_assessment: Optional[ToolAssessmentResult] = None
