import json
import boto3
import hashlib
from datetime import datetime

def lambda_handler(event, context):
    securityhub = boto3.client('securityhub')
    
    for record in event['Records']:
        try:
            # Parse SQS message
            finding = json.loads(record['body'])
            
            # Ensure required fields exist
            generator_id = finding.get('GeneratorId', 'aws-inspector-dockerfile-scanner')
            title = finding.get('Title', 'Unknown Security Finding')
            resource_id = finding.get('Resources', [{}])[0].get('Id', 'unknown-resource')
            
            # Validate and fix severity
            if 'Severity' in finding and 'Label' in finding['Severity']:
                severity = finding['Severity']['Label'].upper()
                if severity not in ['CRITICAL', 'HIGH', 'MEDIUM', 'LOW']:
                    # Map invalid severities
                    severity_map = {'INFO': 'LOW', 'INFORMATIONAL': 'LOW'}
                    finding['Severity']['Label'] = severity_map.get(severity, 'LOW')
            
            # Generate unique finding key for deduplication
            finding_key = f"{generator_id}-{title}-{resource_id}"
            finding_hash = hashlib.md5(finding_key.encode()).hexdigest()[:8]
            
            # Only skip if finding exists and is NOT resolved
            existing_findings = securityhub.get_findings(
                Filters={
                    'GeneratorId': [{'Value': generator_id, 'Comparison': 'EQUALS'}],
                    'Title': [{'Value': title, 'Comparison': 'EQUALS'}],
                    'RecordState': [{'Value': 'ACTIVE', 'Comparison': 'EQUALS'}]
                },
                MaxResults=1
            )
            
            if existing_findings['Findings']:
                workflow_state = existing_findings['Findings'][0].get('Workflow', {}).get('Status', 'NEW')
                if workflow_state != 'RESOLVED':
                    print(f"⏭️ Skipping duplicate ACTIVE finding (WorkflowState: {workflow_state}): {title}")
                    continue
                else:
                    print(f"✅ Found RESOLVED finding, will create new one: {title}")
            
            
            # Update finding ID to be unique
            finding['Id'] = f"{generator_id}-{finding_hash}-{int(datetime.now().timestamp())}"
            
            # Send to Security Hub
            response = securityhub.batch_import_findings(Findings=[finding])
            
            if response['SuccessCount'] > 0:
                print(f"✅ Imported finding: {title}")
            else:
                print(f"❌ Failed to import: {title} - {response.get('FailedFindings', [])}")
                
        except Exception as e:
            print(f"❌ Error processing finding: {str(e)}")
    
    return {'statusCode': 200, 'body': json.dumps('Processed findings')}
