#!/usr/bin/env python3
"""
DevSecOps Security Findings Processor

This script processes security findings from various tools and sends them
to AWS Security Hub in ASFF (AWS Security Finding Format).

Supported tools:
- CodeQL (SAST)
- OWASP Dependency Check
- SpotBugs
- Trivy (Container scanning)
- GitLeaks (Secret detection)
"""

import json
import boto3
import argparse
import uuid
import datetime
from typing import List, Dict, Any
import os
import sys

class SecurityFindingsProcessor:
    def __init__(self, aws_region: str, repository: str, commit_sha: str):
        self.aws_region = aws_region
        self.repository = repository
        self.commit_sha = commit_sha
        self.security_hub = boto3.client('securityhub', region_name=aws_region)
        self.lambda_client = boto3.client('lambda', region_name=aws_region)
        
    def process_codeql_findings(self, sarif_file: str) -> List[Dict[str, Any]]:
        """Process CodeQL SARIF results"""
        findings = []
        
        if not os.path.exists(sarif_file):
            print(f"CodeQL SARIF file not found: {sarif_file}")
            return findings
            
        try:
            with open(sarif_file, 'r') as f:
                sarif_data = json.load(f)
                
            for run in sarif_data.get('runs', []):
                for result in run.get('results', []):
                    finding = self._create_asff_finding(
                        generator_id='CodeQL',
                        aws_account_id=self._get_account_id(),
                        finding_id=str(uuid.uuid4()),
                        product_arn=f'arn:aws:securityhub:{self.aws_region}::product/github/codeql',
                        title=result.get('message', {}).get('text', 'CodeQL Finding'),
                        description=result.get('message', {}).get('text', ''),
                        severity=self._map_codeql_severity(result.get('level', 'note')),
                        source_url=f"https://github.com/{self.repository}/commit/{self.commit_sha}",
                        finding_type='CodeQL SAST Finding'
                    )
                    findings.append(finding)
                    
        except Exception as e:
            print(f"Error processing CodeQL findings: {e}")
            
        return findings
    
    def process_owasp_findings(self, json_file: str) -> List[Dict[str, Any]]:
        """Process OWASP Dependency Check results"""
        findings = []
        
        if not os.path.exists(json_file):
            print(f"OWASP JSON file not found: {json_file}")
            return findings
            
        try:
            with open(json_file, 'r') as f:
                owasp_data = json.load(f)
                
            for dependency in owasp_data.get('dependencies', []):
                for vulnerability in dependency.get('vulnerabilities', []):
                    finding = self._create_asff_finding(
                        generator_id='OWASP-DependencyCheck',
                        aws_account_id=self._get_account_id(),
                        finding_id=str(uuid.uuid4()),
                        product_arn=f'arn:aws:securityhub:{self.aws_region}::product/owasp/dependency-check',
                        title=f"Vulnerable Dependency: {dependency.get('fileName', 'Unknown')}",
                        description=f"CVE: {vulnerability.get('name', 'Unknown')} - {vulnerability.get('description', '')}",
                        severity=self._map_cvss_severity(vulnerability.get('cvssv3', {}).get('baseScore', 0)),
                        source_url=vulnerability.get('references', [{}])[0].get('url', ''),
                        finding_type='Vulnerable Dependency'
                    )
                    findings.append(finding)
                    
        except Exception as e:
            print(f"Error processing OWASP findings: {e}")
            
        return findings
    
    def process_trivy_findings(self, json_file: str) -> List[Dict[str, Any]]:
        """Process Trivy container scan results"""
        findings = []
        
        if not os.path.exists(json_file):
            print(f"Trivy JSON file not found: {json_file}")
            return findings
            
        try:
            with open(json_file, 'r') as f:
                trivy_data = json.load(f)
                
            for result in trivy_data.get('Results', []):
                for vulnerability in result.get('Vulnerabilities', []):
                    finding = self._create_asff_finding(
                        generator_id='Trivy',
                        aws_account_id=self._get_account_id(),
                        finding_id=str(uuid.uuid4()),
                        product_arn=f'arn:aws:securityhub:{self.aws_region}::product/aquasecurity/trivy',
                        title=f"Container Vulnerability: {vulnerability.get('VulnerabilityID', 'Unknown')}",
                        description=f"Package: {vulnerability.get('PkgName', 'Unknown')} - {vulnerability.get('Description', '')}",
                        severity=self._map_trivy_severity(vulnerability.get('Severity', 'UNKNOWN')),
                        source_url=vulnerability.get('References', [None])[0] if vulnerability.get('References') else '',
                        finding_type='Container Vulnerability'
                    )
                    findings.append(finding)
                    
        except Exception as e:
            print(f"Error processing Trivy findings: {e}")
            
        return findings
    
    def process_gitleaks_findings(self, json_file: str) -> List[Dict[str, Any]]:
        """Process GitLeaks secret detection results"""
        findings = []
        
        if not os.path.exists(json_file):
            print(f"GitLeaks JSON file not found: {json_file}")
            return findings
            
        try:
            with open(json_file, 'r') as f:
                gitleaks_data = json.load(f)
                
            for secret in gitleaks_data:
                finding = self._create_asff_finding(
                    generator_id='GitLeaks',
                    aws_account_id=self._get_account_id(),
                    finding_id=str(uuid.uuid4()),
                    product_arn=f'arn:aws:securityhub:{self.aws_region}::product/gitleaks/gitleaks',
                    title=f"Secret Detected: {secret.get('RuleID', 'Unknown')}",
                    description=f"Secret found in {secret.get('File', 'Unknown file')} at line {secret.get('StartLine', 'Unknown')}",
                    severity='HIGH',  # All secrets are high severity
                    source_url=f"https://github.com/{self.repository}/blob/{self.commit_sha}/{secret.get('File', '')}#L{secret.get('StartLine', '')}",
                    finding_type='Secret Detection'
                )
                findings.append(finding)
                
        except Exception as e:
            print(f"Error processing GitLeaks findings: {e}")
            
        return findings
    
    def _create_asff_finding(self, generator_id: str, aws_account_id: str, finding_id: str,
                           product_arn: str, title: str, description: str, severity: str,
                           source_url: str, finding_type: str) -> Dict[str, Any]:
        """Create ASFF-compliant finding"""
        
        return {
            'SchemaVersion': '2018-10-08',
            'Id': finding_id,
            'ProductArn': product_arn,
            'GeneratorId': generator_id,
            'AwsAccountId': aws_account_id,
            'Types': [f'Sensitive Data Identifications/{finding_type}'],
            'FirstObservedAt': datetime.datetime.utcnow().isoformat() + 'Z',
            'LastObservedAt': datetime.datetime.utcnow().isoformat() + 'Z',
            'CreatedAt': datetime.datetime.utcnow().isoformat() + 'Z',
            'UpdatedAt': datetime.datetime.utcnow().isoformat() + 'Z',
            'Severity': {
                'Label': severity
            },
            'Title': title,
            'Description': description,
            'SourceUrl': source_url,
            'Resources': [
                {
                    'Type': 'AwsCodeBuildProject',
                    'Id': f'arn:aws:codebuild:{self.aws_region}:{aws_account_id}:project/devsecops-pipeline',
                    'Region': self.aws_region,
                    'Details': {
                        'Other': {
                            'Repository': self.repository,
                            'CommitSha': self.commit_sha,
                            'FindingType': finding_type
                        }
                    }
                }
            ],
            'WorkflowState': 'NEW',
            'RecordState': 'ACTIVE'
        }
    
    def _get_account_id(self) -> str:
        """Get AWS account ID"""
        try:
            sts = boto3.client('sts')
            return sts.get_caller_identity()['Account']
        except Exception:
            return '123456789012'  # Fallback for testing
    
    def _map_codeql_severity(self, level: str) -> str:
        """Map CodeQL severity levels to ASFF"""
        mapping = {
            'error': 'HIGH',
            'warning': 'MEDIUM',
            'note': 'LOW'
        }
        return mapping.get(level.lower(), 'INFORMATIONAL')
    
    def _map_cvss_severity(self, score: float) -> str:
        """Map CVSS score to ASFF severity"""
        if score >= 9.0:
            return 'CRITICAL'
        elif score >= 7.0:
            return 'HIGH'
        elif score >= 4.0:
            return 'MEDIUM'
        elif score > 0.0:
            return 'LOW'
        else:
            return 'INFORMATIONAL'
    
    def _map_trivy_severity(self, severity: str) -> str:
        """Map Trivy severity to ASFF"""
        mapping = {
            'CRITICAL': 'CRITICAL',
            'HIGH': 'HIGH',
            'MEDIUM': 'MEDIUM',
            'LOW': 'LOW',
            'UNKNOWN': 'INFORMATIONAL'
        }
        return mapping.get(severity.upper(), 'INFORMATIONAL')
    
    def send_findings_to_security_hub(self, findings: List[Dict[str, Any]]) -> bool:
        """Send findings to AWS Security Hub"""
        if not findings:
            print("No findings to send to Security Hub")
            return True
            
        try:
            # Security Hub has a limit of 100 findings per batch
            batch_size = 100
            for i in range(0, len(findings), batch_size):
                batch = findings[i:i + batch_size]
                
                response = self.security_hub.batch_import_findings(Findings=batch)
                
                if response.get('FailedCount', 0) > 0:
                    print(f"Failed to import {response['FailedCount']} findings")
                    for failed_finding in response.get('FailedFindings', []):
                        print(f"Failed finding: {failed_finding}")
                else:
                    print(f"Successfully imported {len(batch)} findings to Security Hub")
                    
            return True
            
        except Exception as e:
            print(f"Error sending findings to Security Hub: {e}")
            return False
    
    def trigger_security_lambda(self, findings_count: int) -> bool:
        """Trigger Lambda function for security findings processing"""
        try:
            payload = {
                'repository': self.repository,
                'commit_sha': self.commit_sha,
                'findings_count': findings_count,
                'timestamp': datetime.datetime.utcnow().isoformat()
            }
            
            response = self.lambda_client.invoke(
                FunctionName='devsecops-security-findings-processor',
                InvocationType='Event',  # Async invocation
                Payload=json.dumps(payload)
            )
            
            print(f"Security Lambda triggered successfully. Status: {response['StatusCode']}")
            return True
            
        except Exception as e:
            print(f"Error triggering security Lambda: {e}")
            return False

def main():
    parser = argparse.ArgumentParser(description='Process security findings and send to Security Hub')
    parser.add_argument('--aws-region', required=True, help='AWS region')
    parser.add_argument('--repository', required=True, help='GitHub repository')
    parser.add_argument('--commit-sha', required=True, help='Git commit SHA')
    parser.add_argument('--github-token', help='GitHub token')
    
    args = parser.parse_args()
    
    processor = SecurityFindingsProcessor(args.aws_region, args.repository, args.commit_sha)
    
    all_findings = []
    
    # Process different types of findings
    print("Processing security findings...")
    
    # CodeQL findings
    codeql_findings = processor.process_codeql_findings('codeql-results.sarif')
    all_findings.extend(codeql_findings)
    print(f"Found {len(codeql_findings)} CodeQL findings")
    
    # OWASP Dependency Check findings
    owasp_findings = processor.process_owasp_findings('application/target/dependency-check-report.json')
    all_findings.extend(owasp_findings)
    print(f"Found {len(owasp_findings)} OWASP findings")
    
    # Trivy findings
    trivy_findings = processor.process_trivy_findings('trivy-results.json')
    all_findings.extend(trivy_findings)
    print(f"Found {len(trivy_findings)} Trivy findings")
    
    # GitLeaks findings
    gitleaks_findings = processor.process_gitleaks_findings('gitleaks-report.json')
    all_findings.extend(gitleaks_findings)
    print(f"Found {len(gitleaks_findings)} GitLeaks findings")
    
    print(f"Total findings: {len(all_findings)}")
    
    # Send findings to Security Hub
    if all_findings:
        success = processor.send_findings_to_security_hub(all_findings)
        if success:
            # Trigger Lambda for additional processing
            processor.trigger_security_lambda(len(all_findings))
        else:
            sys.exit(1)
    
    # Check for critical/high severity findings
    critical_high_count = sum(1 for f in all_findings 
                             if f['Severity']['Label'] in ['CRITICAL', 'HIGH'])
    
    if critical_high_count > 0:
        print(f"Found {critical_high_count} critical/high severity findings")
        print("Pipeline should fail due to security issues")
        sys.exit(1)
    
    print("Security analysis completed successfully")

if __name__ == '__main__':
    main()
