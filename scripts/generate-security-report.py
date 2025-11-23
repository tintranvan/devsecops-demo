#!/usr/bin/env python3
"""
Security Report Generator
Aggregates findings from all security scans and generates XML report
"""

import json
import sys
import os
from datetime import datetime

def load_json_safe(filepath):
    """Safely load JSON file"""
    try:
        if os.path.exists(filepath):
            with open(filepath, 'r') as f:
                return json.load(f)
    except Exception as e:
        print(f"Warning: Could not load {filepath}: {e}")
    return None

def sort_findings_by_severity(findings):
    """Sort findings by severity: CRITICAL > HIGH > MEDIUM > LOW"""
    severity_order = {'CRITICAL': 0, 'HIGH': 1, 'MEDIUM': 2, 'LOW': 3, 'UNKNOWN': 4}
    return sorted(findings, key=lambda x: severity_order.get(str(x.get('severity', 'UNKNOWN')).upper(), 4))

def count_by_severity(findings, severity_field='severity'):
    """Count findings by severity"""
    counts = {'CRITICAL': 0, 'HIGH': 0, 'MEDIUM': 0, 'LOW': 0}
    
    if not findings:
        return counts
    
    for finding in findings:
        severity_value = finding.get(severity_field, 'UNKNOWN')
        # Handle nested severity object (e.g., {'Label': 'HIGH'})
        if isinstance(severity_value, dict):
            severity = severity_value.get('Label', 'UNKNOWN').upper()
        else:
            severity = str(severity_value).upper()
        
        if severity in counts:
            counts[severity] += 1
    
    return counts

def generate_html_report(report_data):
    """Generate beautiful HTML report"""
    
    # Determine overall status
    critical = report_data['critical_count']
    high = report_data['high_count']
    
    if critical > 0:
        status_color = '#dc3545'
        status_text = 'CRITICAL'
        status_icon = '🔴'
    elif high > 0:
        status_color = '#fd7e14'
        status_text = 'HIGH RISK'
        status_icon = '🟠'
    elif report_data['medium_count'] > 0:
        status_color = '#ffc107'
        status_text = 'MEDIUM RISK'
        status_icon = '🟡'
    else:
        status_color = '#28a745'
        status_text = 'PASSED'
        status_icon = '✅'
    
    html = f'''<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Security Report - Build #{report_data['build_number']}</title>
    <style>
        * {{ margin: 0; padding: 0; box-sizing: border-box; }}
        body {{ 
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
            background: #f5f5f5;
            padding: 20px;
            color: #333;
            font-size: 14px;
        }}
        .container {{ 
            max-width: 1200px; 
            margin: 0 auto; 
            background: white;
            border-radius: 8px;
            box-shadow: 0 2px 8px rgba(0,0,0,0.1);
            overflow: hidden;
        }}
        .header {{
            background: #2c3e50;
            color: white;
            padding: 30px;
            text-align: center;
        }}
        .header h1 {{ font-size: 1.8em; margin-bottom: 8px; }}
        .header .subtitle {{ opacity: 0.9; font-size: 0.95em; }}
        
        .status-badge {{
            display: inline-block;
            background: {status_color};
            color: white;
            padding: 12px 30px;
            border-radius: 25px;
            font-size: 1.2em;
            font-weight: bold;
            margin: 20px 0;
        }}
        
        .metadata {{
            background: #f8f9fa;
            padding: 30px;
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
        }}
        .metadata-item {{
            text-align: center;
            padding: 15px;
            background: white;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }}
        .metadata-item .label {{ 
            color: #6c757d; 
            font-size: 0.9em; 
            margin-bottom: 5px;
        }}
        .metadata-item .value {{ 
            font-size: 1.3em; 
            font-weight: bold;
            color: #495057;
        }}
        
        .summary {{
            padding: 40px;
        }}
        .summary h2 {{ 
            font-size: 2em; 
            margin-bottom: 30px;
            color: #495057;
        }}
        
        .severity-grid {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
            margin-bottom: 40px;
        }}
        .severity-card {{
            padding: 15px;
            border-radius: 6px;
            text-align: center;
            border: 2px solid #e9ecef;
            background: white;
        }}
        .severity-card.critical {{ border-color: #dc3545; }}
        .severity-card.high {{ border-color: #fd7e14; }}
        .severity-card.medium {{ border-color: #ffc107; }}
        .severity-card.low {{ border-color: #28a745; }}
        .severity-card .count {{ font-size: 2em; font-weight: bold; margin: 8px 0; color: #495057; }}
        .severity-card .label {{ font-size: 0.9em; color: #6c757d; }}
        
        .scans {{
            padding: 0 40px 40px 40px;
        }}
        .scans h2 {{ 
            font-size: 2em; 
            margin-bottom: 30px;
            color: #495057;
        }}
        
        .scan-card {{
            background: white;
            border: 2px solid #e9ecef;
            border-radius: 12px;
            padding: 25px;
            margin-bottom: 20px;
            transition: all 0.3s;
        }}
        .scan-card:hover {{ 
            border-color: #667eea;
            box-shadow: 0 4px 12px rgba(102, 126, 234, 0.2);
        }}
        .scan-header {{
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 15px;
        }}
        .scan-title {{ 
            font-size: 1.5em; 
            font-weight: bold;
            color: #495057;
        }}
        .scan-status {{
            padding: 8px 20px;
            border-radius: 20px;
            font-weight: bold;
            font-size: 0.9em;
        }}
        .scan-status.passed {{ background: #d4edda; color: #155724; }}
        .scan-status.failed {{ background: #f8d7da; color: #721c24; }}
        .scan-status.skipped {{ background: #d1ecf1; color: #0c5460; }}
        
        .scan-stats {{
            display: flex;
            gap: 15px;
            margin-top: 15px;
        }}
        .stat {{
            padding: 10px 15px;
            background: #f8f9fa;
            border-radius: 8px;
            font-size: 0.9em;
        }}
        .stat .num {{ font-weight: bold; font-size: 1.2em; }}
        
        .footer {{
            background: #f8f9fa;
            padding: 30px;
            text-align: center;
            color: #6c757d;
        }}
        
        @media print {{
            body {{ background: white; padding: 0; }}
            .container {{ box-shadow: none; }}
        }}
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>DevSecOps Security Report</h1>
            <p class="subtitle">Build #{report_data['build_number']} - {report_data['environment'].upper()}</p>
            <div class="status-badge">{status_text}</div>
        </div>
        
        <div class="metadata">
            <div class="metadata-item">
                <div class="label">Build Number</div>
                <div class="value">#{report_data['build_number']}</div>
            </div>
            <div class="metadata-item">
                <div class="label">Environment</div>
                <div class="value">{report_data['environment'].upper()}</div>
            </div>
            <div class="metadata-item">
                <div class="label">Service</div>
                <div class="value">{report_data['service']}</div>
            </div>
            <div class="metadata-item">
                <div class="label">Generated</div>
                <div class="value">{report_data['generated_at'][:10]}</div>
            </div>
            <div class="metadata-item">
                <div class="label">Git Commit</div>
                <div class="value">{report_data['git_commit'][:7]}</div>
            </div>
        </div>
        
        <div class="summary">
            <h2>Overall Statistics</h2>
            <div class="severity-grid">
                <div class="severity-card critical">
                    <div class="label">Critical</div>
                    <div class="count">{report_data['critical_count']}</div>
                </div>
                <div class="severity-card high">
                    <div class="label">High</div>
                    <div class="count">{report_data['high_count']}</div>
                </div>
                <div class="severity-card medium">
                    <div class="label">Medium</div>
                    <div class="count">{report_data['medium_count']}</div>
                </div>
                <div class="severity-card low">
                    <div class="label">Low</div>
                    <div class="count">{report_data['low_count']}</div>
                </div>
            </div>
            <div style="text-align: center; font-size: 1.2em; color: #495057; margin-top: 15px;">
                <strong>Total Findings: {report_data['total_findings']}</strong>
            </div>
        </div>
        
        <div class="scans">
            <h2>Scan Results</h2>
'''
    
    # Add scan cards
    for scan_type, scan_data in report_data['scans'].items():
        status_class = scan_data['status'].lower()
        status_display = scan_data['status']
        
        html += f'''
            <div class="scan-card">
                <div class="scan-header">
                    <div class="scan-title">{scan_type}</div>
                    <div class="scan-status {status_class}">{status_display}</div>
                </div>
                <div class="scan-stats">
                    <div class="stat">
                        <div class="num">{scan_data['total']}</div>
                        <div>Total Findings</div>
                    </div>
                    <div class="stat">
                        <div class="num">{scan_data['severity']['CRITICAL']}</div>
                        <div>Critical</div>
                    </div>
                    <div class="stat">
                        <div class="num">{scan_data['severity']['HIGH']}</div>
                        <div>High</div>
                    </div>
                    <div class="stat">
                        <div class="num">{scan_data['severity']['MEDIUM']}</div>
                        <div>Medium</div>
                    </div>
                    <div class="stat">
                        <div class="num">{scan_data['severity']['LOW']}</div>
                        <div>Low</div>
                    </div>
                </div>
'''
        
        # Add findings details if available
        if scan_data.get('findings') and len(scan_data['findings']) > 0:
            html += '''
                <div style="margin-top: 15px; padding-top: 15px; border-top: 1px solid #e9ecef;">
                    <h4 style="color: #495057; margin-bottom: 12px; font-size: 1em;">Findings Details:</h4>
'''
            for idx, finding in enumerate(scan_data['findings'], 1):
                title = finding.get('title', finding.get('Title', 'Unknown Issue'))
                severity = finding.get('severity', finding.get('Severity', {}))
                if isinstance(severity, dict):
                    severity = severity.get('Label', 'UNKNOWN')
                description = finding.get('description', finding.get('Description', 'No description available'))
                
                # Get file path and line info
                file_path = finding.get('file_path', '')
                line = finding.get('line', '')
                
                # Truncate description if too long
                if len(description) > 300:
                    description = description[:300] + '...'
                
                severity_colors = {
                    'CRITICAL': '#dc3545',
                    'HIGH': '#fd7e14',
                    'MEDIUM': '#ffc107',
                    'LOW': '#28a745'
                }
                severity_color = severity_colors.get(str(severity).upper(), '#6c757d')
                
                html += f'''
                    <div style="background: #f8f9fa; padding: 10px; border-radius: 4px; margin-bottom: 8px; border-left: 3px solid {severity_color};">
                        <div style="display: flex; justify-content: space-between; align-items: start; margin-bottom: 6px;">
                            <strong style="color: #495057; font-size: 0.9em;">{idx}. {title}</strong>
                            <span style="background: {severity_color}; color: white; padding: 2px 8px; border-radius: 3px; font-size: 0.75em; font-weight: bold;">
                                {severity}
                            </span>
                        </div>
                        <p style="color: #6c757d; font-size: 0.85em; margin: 0; white-space: pre-line; line-height: 1.4;">{description}</p>
                    </div>
'''
            
            html += '''
                </div>
'''
        
        html += '''
            </div>
'''
    
    html += '''
        </div>
        
        <div class="footer">
            <p><strong>DevSecOps Pipeline</strong> | Generated automatically by GitHub Actions</p>
            <p style="margin-top: 10px; font-size: 0.9em;">
                All findings have been sent to AWS Security Hub for centralized management
            </p>
        </div>
    </div>
</body>
</html>
'''
    
    return html

def main():
    if len(sys.argv) < 4:
        print("Usage: python3 generate-security-report.py <environment> <build_number> <git_commit>")
        sys.exit(1)
    
    environment = sys.argv[1]
    build_number = sys.argv[2]
    git_commit = sys.argv[3] if len(sys.argv) > 3 else 'N/A'
    
    # Initialize report data
    report_data = {
        'generated_at': datetime.now().strftime('%Y-%m-%dT%H:%M:%SZ'),
        'build_number': build_number,
        'environment': environment,
        'service': 'demo-app',
        'git_commit': git_commit,
        'total_findings': 0,
        'critical_count': 0,
        'high_count': 0,
        'medium_count': 0,
        'low_count': 0,
        'scans': {}
    }
    
    # SAST Scan (from AWS Inspector)
    sast_outcome = os.getenv('SAST_OUTCOME', 'unknown')
    if os.path.exists('security/inspector'):
        sast_files = [f for f in os.listdir('security/inspector') if 'sast_findings' in f and f.endswith('.json')]
    else:
        sast_files = []
    
    if sast_files:
        latest_sast = sorted(sast_files)[-1]
        sast_data = load_json_safe(f'security/inspector/{latest_sast}')
        if sast_data and 'findings' in sast_data:
            findings = sast_data['findings']
            # AWS Inspector format: findings array with severity field
            severity_counts = count_by_severity(findings, 'severity')
            
            # Transform findings to common format
            transformed_findings = []
            for finding in findings:  # All findings
                # Extract file path and line info from codeVulnerabilityDetails
                code_details = finding.get('codeVulnerabilityDetails', {})
                file_path_info = code_details.get('filePath', {})
                file_path = file_path_info.get('filePath', 'Unknown')
                start_line = file_path_info.get('startLine', '')
                end_line = file_path_info.get('endLine', '')
                
                # Build location string
                location = f"{file_path}"
                if start_line:
                    location += f" (Line {start_line}"
                    if end_line and end_line != start_line:
                        location += f"-{end_line}"
                    location += ")"
                
                description = finding.get('description', 'No description')
                # Add location to description
                full_description = f"{description}\n📁 Location: {location}"
                
                transformed_findings.append({
                    'title': finding.get('title', 'Unknown'),
                    'severity': finding.get('severity', 'UNKNOWN'),
                    'description': full_description,
                    'file_path': file_path,
                    'line': f"{start_line}-{end_line}" if start_line else 'N/A'
                })
            
            # Sort by severity
            transformed_findings = sort_findings_by_severity(transformed_findings)
            
            report_data['scans']['SAST/IaC/SCA/SBOM'] = {
                'status': 'COMPLETED',
                'total': len(findings),
                'severity': severity_counts,
                'findings': transformed_findings
            }
            report_data['total_findings'] += len(findings)
            for sev, count in severity_counts.items():
                if sev.lower() in ['critical', 'high', 'medium', 'low']:
                    report_data[f'{sev.lower()}_count'] += count
        else:
            report_data['scans']['SAST/IaC/SCA/SBOM'] = {
                'status': 'PASSED' if sast_outcome == 'success' else 'FAILED' if sast_outcome == 'failure' else 'SKIPPED',
                'total': 0,
                'severity': {'CRITICAL': 0, 'HIGH': 0, 'MEDIUM': 0, 'LOW': 0},
                'findings': []
            }
    else:
        report_data['scans']['SAST/IaC/SCA/SBOM'] = {
            'status': 'PASSED' if sast_outcome == 'success' else 'FAILED' if sast_outcome == 'failure' else 'SKIPPED',
            'total': 0,
            'severity': {'CRITICAL': 0, 'HIGH': 0, 'MEDIUM': 0, 'LOW': 0},
            'findings': []
        }
    
    # Dockerfile Scan
    dockerfile_outcome = os.getenv('DOCKERFILE_OUTCOME', 'unknown')
    if os.path.exists('security/inspector'):
        dockerfile_files = [f for f in os.listdir('security/inspector') if 'dockerfile' in f.lower() and f.endswith('.json')]
    else:
        dockerfile_files = []
    
    if dockerfile_files:
        latest_dockerfile = sorted(dockerfile_files)[-1]
        dockerfile_data = load_json_safe(f'security/inspector/{latest_dockerfile}')
        if dockerfile_data:
            findings = dockerfile_data.get('vulnerabilities', [])
            severity_counts = count_by_severity(findings, 'severity')
            report_data['scans']['Dockerfile'] = {
                'status': 'COMPLETED',
                'total': len(findings),
                'severity': severity_counts,
                'findings': findings[:5]
            }
            report_data['total_findings'] += len(findings)
            for sev, count in severity_counts.items():
                report_data[f'{sev.lower()}_count'] += count
    else:
        report_data['scans']['Dockerfile'] = {
            'status': 'PASSED' if dockerfile_outcome == 'success' else 'FAILED' if dockerfile_outcome == 'failure' else 'SKIPPED',
            'total': 0,
            'severity': {'CRITICAL': 0, 'HIGH': 0, 'MEDIUM': 0, 'LOW': 0},
            'findings': []
        }
    
    # Image Security Scan (ECR)
    image_outcome = os.getenv('IMAGE_OUTCOME', 'unknown')
    if os.path.exists('security/ecr'):
        ecr_files = [f for f in os.listdir('security/ecr') if 'ecr_enhanced_results' in f and f.endswith('.json')]
    else:
        ecr_files = []
    
    if ecr_files:
        latest_ecr = sorted(ecr_files)[-1]
        ecr_data = load_json_safe(f'security/ecr/{latest_ecr}')
        if ecr_data:
            findings = ecr_data.get('imageScanFindings', {}).get('enhancedFindings', [])
            severity_counts = count_by_severity(findings, 'severity')
            report_data['scans']['ImageSecurity'] = {
                'status': 'COMPLETED',
                'total': len(findings),
                'severity': severity_counts,
                'findings': findings[:5]
            }
            report_data['total_findings'] += len(findings)
            for sev, count in severity_counts.items():
                report_data[f'{sev.lower()}_count'] += count
    else:
        report_data['scans']['ImageSecurity'] = {
            'status': 'PASSED' if image_outcome == 'success' else 'FAILED' if image_outcome == 'failure' else 'SKIPPED',
            'total': 0,
            'severity': {'CRITICAL': 0, 'HIGH': 0, 'MEDIUM': 0, 'LOW': 0},
            'findings': []
        }
    
    # DAST Scan (OWASP ZAP)
    dast_outcome = os.getenv('DAST_OUTCOME', 'unknown')
    if os.path.exists('security/reports'):
        dast_files = [f for f in os.listdir('security/reports') if 'zap-report' in f and f.endswith('-asff.json')]
    else:
        dast_files = []
    
    if dast_files:
        latest_dast = sorted(dast_files)[-1]
        dast_data = load_json_safe(f'security/reports/{latest_dast}')
        if dast_data and isinstance(dast_data, list):
            # Sort DAST findings by severity
            dast_data_sorted = sort_findings_by_severity(dast_data)
            severity_counts = count_by_severity(dast_data, 'Severity')
            report_data['scans']['DAST'] = {
                'status': 'COMPLETED',
                'total': len(dast_data),
                'severity': severity_counts,
                'findings': dast_data_sorted
            }
            report_data['total_findings'] += len(dast_data)
            for sev, count in severity_counts.items():
                report_data[f'{sev.lower()}_count'] += count
    else:
        report_data['scans']['DAST'] = {
            'status': 'PASSED' if dast_outcome == 'success' else 'FAILED' if dast_outcome == 'failure' else 'SKIPPED',
            'total': 0,
            'severity': {'CRITICAL': 0, 'HIGH': 0, 'MEDIUM': 0, 'LOW': 0},
            'findings': []
        }
    
    # Container Signing
    signing_outcome = os.getenv('SIGNING_OUTCOME', 'unknown')
    if os.path.exists('security/reports'):
        signing_files = [f for f in os.listdir('security/reports') if 'notation-signing-report' in f]
    else:
        signing_files = []
    
    if signing_files:
        latest_signing = sorted(signing_files)[-1]
        signing_data = load_json_safe(f'security/reports/{latest_signing}')
        if signing_data:
            report_data['scans']['ContainerSigning'] = {
                'status': 'COMPLETED' if signing_data.get('signature_verified') else 'FAILED',
                'total': 0,
                'severity': {'CRITICAL': 0, 'HIGH': 0, 'MEDIUM': 0, 'LOW': 0},
                'findings': []
            }
    else:
        report_data['scans']['ContainerSigning'] = {
            'status': 'PASSED' if signing_outcome == 'success' else 'FAILED' if signing_outcome == 'failure' else 'SKIPPED',
            'total': 0,
            'severity': {'CRITICAL': 0, 'HIGH': 0, 'MEDIUM': 0, 'LOW': 0},
            'findings': []
        }
    
    # Generate HTML report
    html_content = generate_html_report(report_data)
    
    # Save HTML report
    os.makedirs('security/reports', exist_ok=True)
    html_filename = f'security/reports/security-report-{build_number}.html'
    with open(html_filename, 'w', encoding='utf-8') as f:
        f.write(html_content)
    
    print(f"✅ Security report generated: {html_filename}")
    
    # Generate JSON summary for GitHub Actions
    summary_filename = f'security/reports/security-summary-{build_number}.json'
    with open(summary_filename, 'w') as f:
        json.dump(report_data, f, indent=2)
    
    print(f"✅ Security summary generated: {summary_filename}")
    
    # Print summary to console
    print("\n📊 Security Scan Summary:")
    print(f"  Total Findings: {report_data['total_findings']}")
    print(f"  Critical: {report_data['critical_count']}")
    print(f"  High: {report_data['high_count']}")
    print(f"  Medium: {report_data['medium_count']}")
    print(f"  Low: {report_data['low_count']}")
    
    return 0

if __name__ == '__main__':
    sys.exit(main())
