import typer
import logging
import uuid
from datetime import datetime
from rich.console import Console
from rich.logging import RichHandler

from security_scanner.config import settings
from security_scanner.schemas import SecurityReport, ScanSummary, Severity, Finding
from security_scanner.modules import network, system, vuln, tools
from security_scanner.reporting import generate_report
from security_scanner.utils import setup_logging
from security_scanner import interactive

app = typer.Typer()
console = Console()

@app.callback(invoke_without_command=True)
def main(ctx: typer.Context):
    """
    Pan-Sec Security Scanner
    """
    if ctx.invoked_subcommand is None:
        interactive.main_menu()

def calculate_risk_score(findings: list[Finding]) -> tuple[int, str]:
    score = 0
    counts = {s: 0 for s in Severity}
    
    for f in findings:
        counts[f.severity] += 1
        if f.severity == Severity.CRITICAL:
            score += settings.weight_critical
        elif f.severity == Severity.HIGH:
            score += settings.weight_high
        elif f.severity == Severity.MEDIUM:
            score += settings.weight_medium
        elif f.severity == Severity.LOW:
            score += settings.weight_low
            
    level = "LOW"
    if score >= settings.threshold_critical:
        level = "CRITICAL"
    elif score >= settings.threshold_high:
        level = "HIGH"
    elif score >= settings.threshold_medium:
        level = "MEDIUM"
        
    return score, level, counts

@app.command()
def scan(
    email: bool = typer.Option(True, help="Send email report"),
    test: bool = typer.Option(False, "--test", help="Run in test mode (no email)")
):
    """
    Run a full security scan.
    """
    scan_id = str(uuid.uuid4())
    console.print(f"[bold green]Starting Security Scan[/bold green] (ID: {scan_id})")
    
    # 1. Network Scan
    with console.status("Running Network Scan..."):
        net_result = network.scan_network()
        console.print(f"✓ Network Scan complete ({len(net_result.active_hosts)} hosts found)")

    # 2. System Audit
    with console.status("Running System Audit..."):
        audit_result = system.run_audit()
        console.print("✓ System Audit complete")
        
    # 3. Vulnerability Scan
    with console.status("Running Vulnerability Scan..."):
        findings = vuln.scan_vulnerabilities()
        console.print(f"✓ Vulnerability Scan complete ({len(findings)} findings)")

    # 4. Tool Assessment
    with console.status("Assessing Configured Tools..."):
        tool_result = tools.assess_tools()
        missing_count = sum(1 for t in tool_result.tools if t.status == "Missing")
        console.print(f"✓ Tool Assessment complete ({missing_count} missing tools recommended)")

    # Calculate Risk
    score, level, counts = calculate_risk_score(findings)
    
    # Create Report Object
    summary = ScanSummary(
        total=len(findings),
        critical=counts[Severity.CRITICAL],
        high=counts[Severity.HIGH],
        medium=counts[Severity.MEDIUM],
        low=counts[Severity.LOW],
        info=counts[Severity.INFO]
    )
    
    report = SecurityReport(
        scan_id=scan_id,
        timestamp=datetime.now(),
        hostname=audit_result.system_info.hostname,
        risk_score=score,
        risk_level=level,
        summary=summary,
        findings=findings,
        network_scan=net_result,
        audit_result=audit_result,
        tool_assessment=tool_result
    )
    
    # Generate HTML
    report_path = generate_report(report)
    console.print(f"\n[bold]Report generated:[/bold] {report_path}")
    console.print(f"Risk Score: {score} ({level})")
    
    # Email (Placeholder for now, porting msmtp logic later if needed or relying on legacy)
    if email and not test:
        # TODO: Implement python email sending or call legacy script
        console.print("[yellow]Email sending not fully implemented in Python version yet.[/yellow]")
        pass

if __name__ == "__main__":
    app()
