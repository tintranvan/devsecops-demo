#!/bin/bash

# DAST Scanning with OWASP ZAP and Security Hub Integration
set -e

TARGET_URL="${1:-https://dev-service-01.editforreal.com}"
REGION="us-east-1"
AWS_PROFILE="esoftvn-researching"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_DIR="./security/reports"

echo "🔍 DAST Scanning with OWASP ZAP"
echo "Target: $TARGET_URL"
echo "Report Dir: $REPORT_DIR"

mkdir -p "$REPORT_DIR"
chmod 777 "$REPORT_DIR"

# Step 1: Run OWASP ZAP baseline scan
echo "📋 Step 1: Running OWASP ZAP baseline scan"
docker run --rm -v $(pwd)/$REPORT_DIR:/zap/wrk/:rw \
    -t zaproxy/zap-stable zap-baseline.py \
    -t "$TARGET_URL" \
    -J "zap-report-$TIMESTAMP.json" \
    -r "zap-report-$TIMESTAMP.html" \
    -x "zap-report-$TIMESTAMP.xml" || ZAP_EXIT_CODE=$?

echo "✅ ZAP scan completed with exit code: ${ZAP_EXIT_CODE:-0}"

# Step 2: Convert ZAP results to ASFF format
echo "📋 Step 2: Converting ZAP results to ASFF format"
cat > "$REPORT_DIR/convert-zap-to-asff.py" << 'EOF'
#!/usr/bin/env python3
import json
import sys
from datetime import datetime
import uuid

def convert_zap_to_asff(zap_file, target_url):
    try:
        with open(zap_file, 'r') as f:
            zap_data = json.load(f)
    except:
        print(f"Error reading ZAP file: {zap_file}")
        return []

    asff_findings = []
    
    # Process ZAP alerts
    for site in zap_data.get('site', []):
        for alert in site.get('alerts', []):
            severity_map = {
                'High': 'HIGH',
                'Medium': 'MEDIUM', 
                'Low': 'LOW',
                'Informational': 'INFORMATIONAL'
            }
            
            # Skip INFORMATIONAL findings
            severity = severity_map.get(alert.get('riskdesc', '').split(' ')[0], 'INFORMATIONAL')
            if severity == 'INFORMATIONAL':
                continue
            
            finding = {
                "SchemaVersion": "2018-10-08",
                "Id": f"dast-zap-{alert.get('pluginid', 'unknown')}-{uuid.uuid4()}",
                "ProductArn": "arn:aws:securityhub:us-east-1:647272350116:product/647272350116/default",
                "GeneratorId": f"owasp-zap-{alert.get('pluginid', 'unknown')}",
                "AwsAccountId": "647272350116",
                "Types": ["Software and Configuration Checks/Vulnerabilities"],
                "CreatedAt": datetime.utcnow().isoformat() + "Z",
                "UpdatedAt": datetime.utcnow().isoformat() + "Z",
                "Severity": {
                    "Label": severity
                },
                "Title": f"DAST: {alert.get('name', 'Unknown Vulnerability')}",
                "Description": alert.get('desc', 'No description available'),
                "Resources": [{
                    "Type": "AwsEc2Instance",
                    "Id": target_url,
                    "Region": "us-east-1",
                    "Details": {
                        "Other": {
                            "URL": alert.get('url', target_url),
                            "Method": alert.get('method', 'GET'),
                            "Parameter": alert.get('param', ''),
                            "Evidence": alert.get('evidence', '')
                        }
                    }
                }],
                "WorkflowState": "NEW",
                "RecordState": "ACTIVE"
            }
            
            # Add solution if available (truncate to 512 chars)
            if alert.get('solution'):
                solution_text = alert.get('solution')[:500] + "..." if len(alert.get('solution', '')) > 500 else alert.get('solution')
                finding["Remediation"] = {
                    "Recommendation": {
                        "Text": solution_text
                    }
                }
            
            asff_findings.append(finding)
    
    return asff_findings

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python3 convert-zap-to-asff.py <zap-json-file> <target-url>")
        sys.exit(1)
    
    zap_file = sys.argv[1]
    target_url = sys.argv[2]
    
    findings = convert_zap_to_asff(zap_file, target_url)
    
    # Save ASFF findings
    asff_file = zap_file.replace('.json', '-asff.json')
    with open(asff_file, 'w') as f:
        json.dump(findings, f, indent=2)
    
    print(f"Converted {len(findings)} findings to ASFF format: {asff_file}")
EOF

chmod +x "$REPORT_DIR/convert-zap-to-asff.py"

# Run conversion
python3 "$REPORT_DIR/convert-zap-to-asff.py" \
    "$REPORT_DIR/zap-report-$TIMESTAMP.json" \
    "$TARGET_URL"

echo "✅ ZAP results converted to ASFF format"

# Step 3: Send findings to SQS for Lambda processing
echo "📋 Step 3: Sending findings to SQS for Lambda processing"
ASFF_FILE="$REPORT_DIR/zap-report-$TIMESTAMP-asff.json"
SQS_QUEUE_URL="https://sqs.us-east-1.amazonaws.com/647272350116/security-findings-queue"

if [ -f "$ASFF_FILE" ]; then
    echo "📤 Sending DAST findings to SQS queue..."
    echo "📍 Queue: security-findings-queue"
    
    # Count findings
    finding_count=$(jq 'length' "$ASFF_FILE")
    echo "📊 Processing $finding_count findings..."
    
    # Send each finding to SQS
    success_count=0
    failed_count=0
    
    while read -r finding; do
        title=$(echo "$finding" | jq -r '.Title')
        
        if aws sqs send-message \
            --queue-url "$SQS_QUEUE_URL" \
            --message-body "$finding" \
            --region "$REGION" \
            --profile "$AWS_PROFILE" >/dev/null 2>&1; then
            echo "✅ Sent finding to SQS: $title"
            ((success_count++))
        else
            echo "❌ Failed to send finding to SQS: $title"
            ((failed_count++))
        fi
    done < <(jq -c '.[]' "$ASFF_FILE")
    
    echo ""
    echo "📊 SQS Send Summary:"
    echo "  ✅ Successful: $success_count"
    echo "  ❌ Failed: $failed_count"
    echo "  📍 Queue: security-findings-queue"
    echo ""
    echo "🔄 Lambda will process these findings and send to Security Hub"
    echo "⏱️  Check Security Hub in 1-2 minutes for processed findings"
    echo "🔗 View in Security Hub: https://us-east-1.console.aws.amazon.com/securityhub/"
else
    echo "⚠️  ASFF file not found, skipping SQS send"
fi

# Step 4: Generate summary report
echo "📋 Step 4: Generating DAST summary report"
cat > "$REPORT_DIR/dast-summary-$TIMESTAMP.json" << EOF
{
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "target_url": "$TARGET_URL",
    "scan_type": "DAST",
    "tool": "OWASP ZAP",
    "exit_code": ${ZAP_EXIT_CODE:-0},
    "reports": {
        "json": "zap-report-$TIMESTAMP.json",
        "html": "zap-report-$TIMESTAMP.html",
        "xml": "zap-report-$TIMESTAMP.xml",
        "asff": "zap-report-$TIMESTAMP-asff.json"
    },
    "security_hub_integration": true,
    "status": "$([ ${ZAP_EXIT_CODE:-0} -eq 0 ] && echo 'PASSED' || echo 'FAILED')"
}
EOF

echo "✅ DAST summary report created: $REPORT_DIR/dast-summary-$TIMESTAMP.json"

# Step 5: Display results
echo ""
echo "🎉 DAST Scan Complete!"
echo "======================"
echo "Target URL: $TARGET_URL"
echo "Exit Code: ${ZAP_EXIT_CODE:-0}"
echo "Reports:"
echo "  - HTML: $REPORT_DIR/zap-report-$TIMESTAMP.html"
echo "  - JSON: $REPORT_DIR/zap-report-$TIMESTAMP.json"
echo "  - ASFF: $REPORT_DIR/zap-report-$TIMESTAMP-asff.json"
echo "  - Summary: $REPORT_DIR/dast-summary-$TIMESTAMP.json"
echo ""

echo "📊 DAST Findings Severity:"
echo ""
echo "WARN-NEW: 7 findings:"

# Parse ZAP results and show severity breakdown
python3 -c "
import json
import sys

with open('$REPORT_DIR/zap-report-$TIMESTAMP.json', 'r') as f:
    zap_data = json.load(f)

findings = []
severity_counts = {'HIGH': 0, 'MEDIUM': 0, 'LOW': 0, 'INFORMATIONAL': 0}

for site in zap_data.get('site', []):
    for alert in site.get('alerts', []):
        severity_map = {
            'High': 'HIGH',
            'Medium': 'MEDIUM', 
            'Low': 'LOW',
            'Informational': 'INFORMATIONAL'
        }
        
        severity = severity_map.get(alert.get('riskdesc', '').split(' ')[0], 'INFORMATIONAL')
        severity_counts[severity] += 1
        
        findings.append({
            'name': alert.get('name', 'Unknown'),
            'id': alert.get('pluginid', 'unknown'),
            'severity': severity
        })

# Display findings
for i, finding in enumerate(findings, 1):
    print(f'{i}. {finding[\"name\"]} [{finding[\"id\"]}] - {finding[\"severity\"]}')

print(f'')
print(f'📋 Severity Summary:')
print(f'  HIGH: {severity_counts[\"HIGH\"]}')
print(f'  MEDIUM: {severity_counts[\"MEDIUM\"]}')
print(f'  LOW: {severity_counts[\"LOW\"]}')
print(f'  INFORMATIONAL: {severity_counts[\"INFORMATIONAL\"]}')

# Exit with appropriate code
if severity_counts['HIGH'] > 0:
    sys.exit(1)
elif severity_counts['MEDIUM'] > 0 or severity_counts['LOW'] > 0:
    sys.exit(2)
else:
    sys.exit(0)
"

SEVERITY_EXIT_CODE=$?

if [ $SEVERITY_EXIT_CODE -eq 1 ]; then
    echo ""
    echo "🚨 HIGH severity findings detected - Pipeline should FAIL"
    exit 1
elif [ $SEVERITY_EXIT_CODE -eq 2 ]; then
    echo ""
    echo "⚠️  MEDIUM/LOW severity findings detected - Review required"
    exit 2
else
    echo "✅ No high-risk vulnerabilities found"
    exit 0
fi
