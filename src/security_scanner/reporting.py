import os
import json
from security_scanner.schemas import SecurityReport
from security_scanner.config import settings
from jinja2 import Template

HTML_TEMPLATE = """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Security Assessment Report - {{ report.hostname }}</title>
    <style>
        body { font-family: -apple-system, sans-serif; line-height: 1.6; color: #333; max-width: 1200px; margin: 0 auto; padding: 20px; background: #f5f5f5; }
        .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px; border-radius: 10px; margin-bottom: 30px; }
        .card { background: white; padding: 25px; border-radius: 10px; margin-bottom: 20px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .metric-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin: 20px 0; }
        .metric-box { background: #f8f9fa; padding: 15px; border-radius: 8px; text-align: center; border-left: 4px solid #667eea; }
        .severity-CRITICAL { border-left-color: #dc3545; color: #dc3545; }
        .severity-HIGH { border-left-color: #fd7e14; color: #fd7e14; }
        .severity-MEDIUM { border-left-color: #ffc107; color: #ffc107; }
        .severity-LOW { border-left-color: #17a2b8; color: #17a2b8; }
        pre { background: #f1f1f1; padding: 10px; overflow-x: auto; }
        .finding { border-left: 4px solid #ccc; padding-left: 15px; margin-bottom: 20px; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Security Assessment Report</h1>
        <p>Hostname: {{ report.hostname }} | Date: {{ report.timestamp }}</p>
    </div>

    <div class="card">
        <h2>Executive Summary</h2>
        <div class="metric-grid">
            <div class="metric-box severity-{{ report.risk_level }}">
                <h3>Risk Score</h3>
                <h1>{{ report.risk_score }}</h1>
                <p>{{ report.risk_level }}</p>
            </div>
            <div class="metric-box">
                <h3>Total Findings</h3>
                <h1>{{ report.summary.total }}</h1>
            </div>
            <div class="metric-box severity-CRITICAL">
                <h3>Critical</h3>
                <h1>{{ report.summary.critical }}</h1>
            </div>
             <div class="metric-box severity-HIGH">
                <h3>High</h3>
                <h1>{{ report.summary.high }}</h1>
            </div>
        </div>
    </div>

    <div class="card">
        <h2>Network Discovery</h2>
        {% if report.network_scan %}
            <p><strong>Primary IP:</strong> {{ report.network_scan.primary_ip }}</p>
            <p><strong>Interfaces:</strong> {{ report.network_scan.interfaces | join(', ') }}</p>
            <h3>Active Hosts ({{ report.network_scan.active_hosts | length }})</h3>
            <ul>
            {% for host in report.network_scan.active_hosts %}
                <li>{{ host.ip }} {% if host.hostname %}({{ host.hostname }}){% endif %}</li>
            {% endfor %}
            </ul>
        {% else %}
            <p>No network scan data available.</p>
        {% endif %}
    </div>
    
    <div class="card">
        <h2>System Audit</h2>
        {% if report.audit_result %}
             <p><strong>OS:</strong> {{ report.audit_result.system_info.os }}</p>
             <p><strong>Kernel:</strong> {{ report.audit_result.system_info.kernel }}</p>
             
             {% if report.audit_result.security_updates_count > 0 %}
                 <p class="severity-HIGH"><strong>Security Updates:</strong> {{ report.audit_result.security_updates_count }} pending!</p>
             {% else %}
                 <p>System is up to date.</p>
             {% endif %}
             
             <h3>Open Ports</h3>
             <pre>{{ report.audit_result.listening_services | join('\n') }}</pre>
        {% endif %}
    </div>

    <div class="card">
        <h2>Tool Configuration & Recommendations</h2>
        {% if report.tool_assessment %}
        <table style="width: 100%; border-collapse: collapse;">
            <thead>
                <tr style="background: #eee;">
                    <th style="padding: 10px; text-align: left;">Tool</th>
                    <th style="padding: 10px; text-align: left;">Category</th>
                    <th style="padding: 10px; text-align: left;">Status</th>
                    <th style="padding: 10px; text-align: left;">Description</th>
                </tr>
            </thead>
            <tbody>
            {% for tool in report.tool_assessment.tools %}
                <tr style="border-bottom: 1px solid #ddd;">
                    <td style="padding: 10px;"><strong>{{ tool.name }}</strong></td>
                    <td style="padding: 10px;">{{ tool.category }}</td>
                    <td style="padding: 10px;">
                        {% if tool.status == 'Installed' %}
                            <span style="color: green;">✔ Installed</span>
                            {% if tool.version %}<br><small>{{ tool.version }}</small>{% endif %}
                        {% else %}
                            <span style="color: orange;">⚠ Missing</span>
                        {% endif %}
                    </td>
                    <td style="padding: 10px;">{{ tool.description }}</td>
                </tr>
            {% endfor %}
            </tbody>
        </table>
        {% endif %}
    </div>

    <div class="card">
        <h2>Detailed Findings</h2>
        {% if report.findings %}
            {% for finding in report.findings %}
                <div class="finding severity-{{ finding.severity }}">
                    <h3>[{{ finding.severity }}] {{ finding.title }}</h3>
                    <p>{{ finding.description }}</p>
                    <p><strong>Remediation:</strong> {{ finding.remediation }}</p>
                </div>
            {% endfor %}
        {% else %}
            <p>No vulnerabilities detected.</p>
        {% endif %}
    </div>
</body>
</html>
"""

def generate_report(report: SecurityReport) -> str:
    template = Template(HTML_TEMPLATE)
    html_content = template.render(report=report)
    
    filename = f"security_report_{report.timestamp.strftime('%Y%m%d_%H%M%S')}.html"
    filepath = os.path.join(settings.reports_dir, filename)
    
    os.makedirs(settings.reports_dir, exist_ok=True)
    
    with open(filepath, "w") as f:
        f.write(html_content)
        
    return filepath
