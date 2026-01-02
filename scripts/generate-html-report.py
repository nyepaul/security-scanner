#!/usr/bin/env python3
"""
HTML Report Generator for Security Scanner
Creates visually appealing security reports with charts and severity indicators
"""

import json
import sys
import os
import html as html_module
from datetime import datetime

def severity_color(severity):
    """Return color code for severity level"""
    colors = {
        'CRITICAL': '#dc3545',
        'HIGH': '#fd7e14',
        'MEDIUM': '#ffc107',
        'LOW': '#17a2b8',
        'INFO': '#6c757d'
    }
    return colors.get(severity, '#6c757d')

def severity_badge(severity):
    """Generate HTML badge for severity"""
    color = severity_color(severity)
    return f'<span class="severity-badge" style="background-color: {color};">{severity}</span>'

def generate_html_report(json_file, output_file):
    """Generate comprehensive HTML security report"""

    # Load JSON data
    with open(json_file, 'r') as f:
        data = json.load(f)

    scan_time = data.get('scan_timestamp', 'Unknown')
    hostname = data.get('hostname', 'Unknown')
    kernel = data.get('kernel', 'Unknown')
    risk_score = data.get('risk_score', 0)
    summary = data.get('summary', {})
    findings = data.get('findings', [])

    # Calculate percentages for chart
    total = summary.get('total', 0)
    critical = summary.get('critical', 0)
    high = summary.get('high', 0)
    medium = summary.get('medium', 0)
    low = summary.get('low', 0)
    info = summary.get('info', 0)

    # Determine risk level
    if risk_score >= 75:
        risk_level = "CRITICAL"
        risk_color = "#dc3545"
    elif risk_score >= 50:
        risk_level = "HIGH"
        risk_color = "#fd7e14"
    elif risk_score >= 25:
        risk_level = "MEDIUM"
        risk_color = "#ffc107"
    else:
        risk_level = "LOW"
        risk_color = "#28a745"

    # Start HTML
    html = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Security Assessment Report - {hostname}</title>
    <style>
        * {{
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }}

        body {{
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
            line-height: 1.6;
            color: #333;
            background: #f5f5f5;
            padding: 20px;
        }}

        .container {{
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
            border-radius: 8px;
            overflow: hidden;
        }}

        .header {{
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 40px;
            text-align: center;
        }}

        .header h1 {{
            font-size: 2.5em;
            margin-bottom: 10px;
        }}

        .header .subtitle {{
            font-size: 1.1em;
            opacity: 0.9;
        }}

        .executive-summary {{
            padding: 40px;
            background: #f8f9fa;
            border-bottom: 3px solid #667eea;
        }}

        .executive-summary h2 {{
            color: #667eea;
            margin-bottom: 20px;
            font-size: 1.8em;
        }}

        .metrics-grid {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
            margin-top: 30px;
        }}

        .metric-card {{
            background: white;
            padding: 25px;
            border-radius: 8px;
            box-shadow: 0 2px 5px rgba(0,0,0,0.1);
            text-align: center;
            border-left: 4px solid #667eea;
        }}

        .metric-card.risk {{
            border-left-color: {risk_color};
        }}

        .metric-value {{
            font-size: 2.5em;
            font-weight: bold;
            color: #667eea;
            margin: 10px 0;
        }}

        .metric-card.risk .metric-value {{
            color: {risk_color};
        }}

        .metric-label {{
            font-size: 0.9em;
            color: #6c757d;
            text-transform: uppercase;
            letter-spacing: 1px;
        }}

        .chart-section {{
            padding: 40px;
        }}

        .chart-section h2 {{
            color: #667eea;
            margin-bottom: 30px;
            font-size: 1.8em;
        }}

        .chart-container {{
            display: flex;
            justify-content: center;
            align-items: center;
            margin: 30px 0;
        }}

        .bar-chart {{
            width: 100%;
            max-width: 600px;
        }}

        .bar {{
            display: flex;
            align-items: center;
            margin: 15px 0;
        }}

        .bar-label {{
            width: 100px;
            font-weight: 600;
            text-align: right;
            margin-right: 15px;
        }}

        .bar-container {{
            flex: 1;
            height: 30px;
            background: #e9ecef;
            border-radius: 5px;
            overflow: hidden;
            position: relative;
        }}

        .bar-fill {{
            height: 100%;
            transition: width 0.3s ease;
            display: flex;
            align-items: center;
            padding: 0 10px;
            color: white;
            font-weight: bold;
            font-size: 0.9em;
        }}

        .findings-section {{
            padding: 40px;
            background: #f8f9fa;
        }}

        .findings-section h2 {{
            color: #667eea;
            margin-bottom: 30px;
            font-size: 1.8em;
        }}

        .finding-card {{
            background: white;
            border-radius: 8px;
            padding: 25px;
            margin-bottom: 20px;
            box-shadow: 0 2px 5px rgba(0,0,0,0.1);
            border-left: 5px solid;
        }}

        .finding-card.CRITICAL {{
            border-left-color: #dc3545;
        }}

        .finding-card.HIGH {{
            border-left-color: #fd7e14;
        }}

        .finding-card.MEDIUM {{
            border-left-color: #ffc107;
        }}

        .finding-card.LOW {{
            border-left-color: #17a2b8;
        }}

        .finding-card.INFO {{
            border-left-color: #6c757d;
        }}

        .finding-header {{
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 15px;
        }}

        .finding-title {{
            font-size: 1.3em;
            font-weight: 600;
            color: #333;
        }}

        .severity-badge {{
            display: inline-block;
            padding: 5px 15px;
            border-radius: 20px;
            color: white;
            font-size: 0.85em;
            font-weight: bold;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }}

        .finding-description {{
            color: #555;
            margin: 15px 0;
            padding: 15px;
            background: #f8f9fa;
            border-radius: 5px;
        }}

        .finding-recommendation {{
            color: #333;
            padding: 15px;
            background: #e7f3ff;
            border-left: 3px solid #0066cc;
            border-radius: 5px;
            margin-top: 15px;
        }}

        .recommendation-label {{
            font-weight: 600;
            color: #0066cc;
            margin-bottom: 5px;
        }}

        .footer {{
            padding: 30px;
            text-align: center;
            background: #667eea;
            color: white;
        }}

        .system-info {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 15px;
            margin: 20px 0;
        }}

        .info-item {{
            background: white;
            padding: 15px;
            border-radius: 5px;
            box-shadow: 0 1px 3px rgba(0,0,0,0.1);
        }}

        .info-label {{
            font-size: 0.85em;
            color: #6c757d;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }}

        .info-value {{
            font-size: 1.1em;
            font-weight: 600;
            color: #333;
            margin-top: 5px;
        }}

        .no-findings {{
            text-align: center;
            padding: 40px;
            color: #28a745;
            font-size: 1.2em;
        }}

        .timestamp {{
            font-size: 0.9em;
            color: #6c757d;
            margin-top: 10px;
        }}
    </style>
</head>
<body>
    <div class="container">
        <!-- Header -->
        <div class="header">
            <h1>Security Assessment Report</h1>
            <div class="subtitle">Comprehensive Localhost Security Audit</div>
            <div class="timestamp">{scan_time}</div>
        </div>

        <!-- Executive Summary -->
        <div class="executive-summary">
            <h2>Executive Summary</h2>

            <div class="system-info">
                <div class="info-item">
                    <div class="info-label">Hostname</div>
                    <div class="info-value">{hostname}</div>
                </div>
                <div class="info-item">
                    <div class="info-label">Kernel Version</div>
                    <div class="info-value">{kernel}</div>
                </div>
                <div class="info-item">
                    <div class="info-label">Scan Date</div>
                    <div class="info-value">{datetime.fromisoformat(scan_time.replace('Z', '+00:00')).strftime('%Y-%m-%d %H:%M')}</div>
                </div>
            </div>

            <div class="metrics-grid">
                <div class="metric-card risk">
                    <div class="metric-label">Risk Score</div>
                    <div class="metric-value">{risk_score}/100</div>
                    <div class="metric-label">{risk_level} Risk</div>
                </div>
                <div class="metric-card">
                    <div class="metric-label">Total Findings</div>
                    <div class="metric-value">{total}</div>
                    <div class="metric-label">Issues Detected</div>
                </div>
                <div class="metric-card">
                    <div class="metric-label">Critical</div>
                    <div class="metric-value" style="color: #dc3545;">{critical}</div>
                    <div class="metric-label">Immediate Action Required</div>
                </div>
                <div class="metric-card">
                    <div class="metric-label">High</div>
                    <div class="metric-value" style="color: #fd7e14;">{high}</div>
                    <div class="metric-label">Urgent Attention</div>
                </div>
            </div>
        </div>

        <!-- Vulnerability Distribution Chart -->
        <div class="chart-section">
            <h2>Vulnerability Distribution</h2>
            <div class="chart-container">
                <div class="bar-chart">
"""

    # Add bars for each severity
    max_count = max(critical, high, medium, low, info, 1)  # Avoid division by zero

    severities = [
        ('Critical', critical, '#dc3545'),
        ('High', high, '#fd7e14'),
        ('Medium', medium, '#ffc107'),
        ('Low', low, '#17a2b8'),
        ('Info', info, '#6c757d')
    ]

    for label, count, color in severities:
        width_percent = (count / max_count * 100) if max_count > 0 else 0
        html += f"""
                    <div class="bar">
                        <div class="bar-label">{label}</div>
                        <div class="bar-container">
                            <div class="bar-fill" style="width: {width_percent}%; background-color: {color};">
                                {count}
                            </div>
                        </div>
                    </div>
"""

    html += """
                </div>
            </div>
        </div>

        <!-- Detailed Findings -->
        <div class="findings-section">
            <h2>Detailed Findings</h2>
"""

    if not findings:
        html += """
            <div class="no-findings">
                <strong>No security issues detected!</strong><br>
                Your system appears to be well-configured.
            </div>
"""
    else:
        # Sort findings by severity
        severity_order = {'CRITICAL': 0, 'HIGH': 1, 'MEDIUM': 2, 'LOW': 3, 'INFO': 4}
        sorted_findings = sorted(findings, key=lambda x: severity_order.get(x['severity'], 5))

        for finding in sorted_findings:
            severity = finding.get('severity', 'INFO')
            title = finding.get('title', 'Unknown Issue')
            description = finding.get('description', 'No description available')
            recommendation = finding.get('recommendation', 'No recommendation provided')

            # Convert newlines to HTML breaks and escape HTML
            description = html_module.escape(description).replace('\\n', '<br>').replace('\n', '<br>')
            recommendation = html_module.escape(recommendation).replace('\\n', '<br>').replace('\n', '<br>')

            html_content = f"""
            <div class="finding-card {severity}">
                <div class="finding-header">
                    <div class="finding-title">{html_module.escape(title)}</div>
                    {severity_badge(severity)}
                </div>
                <div class="finding-description">
                    <strong>Description:</strong><br>
                    {description}
                </div>
                <div class="finding-recommendation">
                    <div class="recommendation-label">Recommendation:</div>
                    {recommendation}
                </div>
            </div>
"""
            html += html_content

    html += """
        </div>

        <!-- Footer -->
        <div class="footer">
            <p>Security Assessment Report Generated by Automated Security Scanner</p>
            <p style="margin-top: 10px; font-size: 0.9em;">This report should be reviewed by qualified security personnel</p>
        </div>
    </div>
</body>
</html>
"""

    # Write HTML to file
    with open(output_file, 'w') as f:
        f.write(html)

    print(f"HTML report generated successfully: {output_file}")

if __name__ == '__main__':
    if len(sys.argv) != 3:
        print("Usage: generate-html-report.py <json_file> <output_html>")
        sys.exit(1)

    json_file = sys.argv[1]
    output_file = sys.argv[2]

    if not os.path.exists(json_file):
        print(f"Error: JSON file not found: {json_file}")
        sys.exit(1)

    generate_html_report(json_file, output_file)
