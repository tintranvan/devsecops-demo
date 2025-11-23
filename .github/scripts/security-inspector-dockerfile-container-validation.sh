#!/bin/bash

# AWS Inspector SBOM Generator using Docker with SQS Integration
set -e

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

# Configuration from parameters
PROFILE=${1:-none}
REGION=${2:-${AWS_REGION}}

PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="$PROJECT_ROOT/security/inspector"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

echo "🔍 AWS Inspector SBOM Generator (Docker)"
echo "========================================"
echo "📋 Profile: $PROFILE"
echo "🌍 Region: $REGION"

mkdir -p "$OUTPUT_DIR"

# Check Docker
if ! command -v docker &> /dev/null; then
    echo "❌ Docker not found"
    exit 1
fi

if ! docker info >/dev/null 2>&1; then
    echo "❌ Docker not running"
    exit 1
fi

echo "✅ Docker available"

# Create temporary Dockerfile for inspector-sbomgen
cat > /tmp/Dockerfile.inspector << 'EOF'
FROM ubuntu:22.04

RUN apt-get update && apt-get install -y curl unzip && rm -rf /var/lib/apt/lists/*

# Download inspector-sbomgen
RUN curl -L -o /tmp/inspector-sbomgen.zip \
    https://amazon-inspector-sbomgen.s3.amazonaws.com/latest/linux/amd64/inspector-sbomgen.zip && \
    cd /tmp && \
    unzip inspector-sbomgen.zip && \
    cp inspector-sbomgen-*/linux/amd64/inspector-sbomgen /usr/local/bin/ && \
    chmod +x /usr/local/bin/inspector-sbomgen && \
    rm -rf /tmp/inspector-sbomgen*

WORKDIR /workspace
ENTRYPOINT ["inspector-sbomgen"]
EOF

# Build Docker image
echo "🏗️  Building inspector-sbomgen Docker image..."
docker build -f /tmp/Dockerfile.inspector -t inspector-sbomgen:latest /tmp

# Run Dockerfile scan
echo "🔍 Running Dockerfile security scan..."
docker run --rm \
    -v "$PROJECT_ROOT/application:/workspace" \
    -v "$OUTPUT_DIR:/output" \
    inspector-sbomgen:latest \
    directory \
    --path /workspace \
    --scanners dockerfile \
    --outfile /output/dockerfile_sbom_${TIMESTAMP}.json

echo "✅ SBOM generated successfully"

# Fix file permissions after Docker run
echo "🔧 Fixing file permissions..."
sudo chown -R $(whoami):$(whoami) "$OUTPUT_DIR" 2>/dev/null || true
sudo chmod -R 644 "$OUTPUT_DIR"/*.json 2>/dev/null || true

# Run vulnerability scan
echo "🛡️  Running vulnerability scan..."

# Set AWS environment for Docker container
if [ "$PROFILE" = "none" ]; then
    # Use OIDC credentials from environment
    docker run --rm \
        -v "$PROJECT_ROOT/application:/workspace" \
        -v "$OUTPUT_DIR:/output" \
        -e AWS_REGION="$REGION" \
        -e AWS_ACCESS_KEY_ID \
        -e AWS_SECRET_ACCESS_KEY \
        -e AWS_SESSION_TOKEN \
        inspector-sbomgen:latest \
        directory \
        --path /workspace \
        --scanners dockerfile \
        --scan-sbom \
        --outfile /output/dockerfile_vulnerabilities_${TIMESTAMP}.json || {
        echo "⚠️  Vulnerability scan failed, continuing..."
    }
else
    # Use profile-based credentials (local development only)
    docker run --rm \
        -v "$PROJECT_ROOT/application:/workspace" \
        -v "$OUTPUT_DIR:/output" \
        -e AWS_PROFILE="$PROFILE" \
        -e AWS_REGION="$REGION" \
        -v ~/.aws:/root/.aws:ro \
        inspector-sbomgen:latest \
        directory \
        --path /workspace \
        --scanners dockerfile \
        --scan-sbom \
        --outfile /output/dockerfile_vulnerabilities_${TIMESTAMP}.json || {
        echo "⚠️  Vulnerability scan failed, continuing..."
    }
fi

# Fix file permissions after vulnerability scan
echo "🔧 Fixing file permissions after vulnerability scan..."
sudo chown -R $(whoami):$(whoami) "$OUTPUT_DIR" 2>/dev/null || true
sudo chmod -R 644 "$OUTPUT_DIR"/*.json 2>/dev/null || true

# Send findings to SQS for Lambda processing
send_to_sqs() {
    local asff_file="$1"
    
    echo "📤 Sending findings to SQS for Lambda processing..."
    
    # Get AWS account ID dynamically
    if [ "$PROFILE" = "none" ]; then
        AWS_ACCOUNT_ID=$(get_aws_account_id "none")
    else
        AWS_ACCOUNT_ID=$(get_aws_account_id "$PROFILE")
    fi
    
    # SQS Queue URL (from our deployed infrastructure)
    SQS_QUEUE_URL="https://queue.amazonaws.com/$AWS_ACCOUNT_ID/security-findings-queue"
    
    echo "📍 Queue: security-findings-queue"
    
    # Check if findings exist
    findings_count=$(jq '.Findings | length' "$asff_file" 2>/dev/null || echo 0)
    
    if [ "$findings_count" -eq 0 ]; then
        echo "ℹ️  No findings to send to SQS"
        return 0
    fi
    
    echo "📊 Processing $findings_count findings..."
    
    # Send each finding individually to SQS
    success_count=0
    failed_count=0
    
    # Temporarily disable exit on error for SQS sending
    set +e
    
    while IFS= read -r finding; do
        # Create SQS message with finding
        message_body=$(echo "$finding" | jq -c .)
        
        # Send to SQS (in GitHub Actions, don't use profile)
        if [ -n "$GITHUB_ACTIONS" ] || [ -z "$PROFILE" ] || [ "$PROFILE" = "none" ]; then
            aws_result=$(aws sqs send-message \
                --queue-url "$SQS_QUEUE_URL" \
                --message-body "$message_body" \
                --region "$REGION" 2>&1)
        else
            aws_result=$(aws sqs send-message \
                --queue-url "$SQS_QUEUE_URL" \
                --message-body "$message_body" \
                --region "$REGION" \
                --profile "$PROFILE" 2>&1)
        fi
        
        if [ $? -eq 0 ]; then
            echo "✅ Sent finding to SQS: $(echo "$finding" | jq -r '.Title')"
            ((success_count++))
        else
            echo "❌ Failed to send finding: $(echo "$finding" | jq -r '.Title')"
            ((failed_count++))
        fi
        
        # Small delay to avoid throttling
        sleep 0.1
    done < <(jq -c '.Findings[]' "$asff_file")
    
    # Re-enable exit on error
    set -e
    
    echo ""
    echo "📊 SQS Send Summary:"
    echo "  ✅ Successful: $success_count"
    echo "  ❌ Failed: $failed_count"
    echo "  📍 Queue: security-findings-queue"
    echo ""
    echo "🔄 Lambda will process these findings and send to Security Hub"
    echo "⏱️  Check Security Hub in 1-2 minutes for processed findings"
    echo "🔗 View in Security Hub: https://$REGION.console.aws.amazon.com/securityhub/"
}

# Generate ASFF findings for Security Hub
generate_asff_findings() {
    local sbom_file="$1"
    local asff_file="$OUTPUT_DIR/asff_findings_${TIMESTAMP}.json"
    
    echo "🔄 Converting Dockerfile findings to ASFF format..."
    
    # Get AWS account ID and region
    if [ "$PROFILE" = "none" ]; then
        AWS_ACCOUNT_ID=$(get_aws_account_id "none")
    else
        AWS_ACCOUNT_ID=$(get_aws_account_id "$PROFILE")
    fi
    
    # Generate ASFF findings
    cat > "$asff_file" << EOF
{
  "Findings": [
EOF
    
    # Parse actual findings from SBOM - check vulnerabilities first
    vulnerabilities=$(jq '.vulnerabilities[]?' "$sbom_file" 2>/dev/null || echo "")
    
    if [ -n "$vulnerabilities" ]; then
        echo "📊 Processing vulnerability findings..."
        echo "$vulnerabilities" | jq -c '.' | while read -r vuln; do
            vuln_id=$(echo "$vuln" | jq -r '.id // "unknown"')
            vuln_desc=$(echo "$vuln" | jq -r '.description // "No description available"')
            vuln_severity=$(echo "$vuln" | jq -r '.ratings[0].severity // "MEDIUM"' | tr '[:lower:]' '[:upper:]')
            
            # Generate individual ASFF finding
            cat >> "$asff_file.tmp" << EOF
{
  "SchemaVersion": "2018-10-08",
  "Id": "dockerfile-vuln-$vuln_id-$(date +%s)",
  "ProductArn": "arn:aws:securityhub:$REGION:$AWS_ACCOUNT_ID:product/$AWS_ACCOUNT_ID/default",
  "GeneratorId": "aws-inspector-dockerfile-scanner",
  "AwsAccountId": "$AWS_ACCOUNT_ID",
  "Types": ["Software and Configuration Checks/Vulnerabilities"],
  "FirstObservedAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "LastObservedAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "CreatedAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "UpdatedAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "Severity": {
    "Label": "$vuln_severity"
  },
  "Title": "Dockerfile Vulnerability: $vuln_id",
  "Description": "$vuln_desc",
  "Resources": [
    {
      "Type": "Other",
      "Id": "$PROJECT_ROOT/application/Dockerfile",
      "Region": "$REGION",
      "Tags": {
        "Application": "devsecops-assessment",
        "Component": "dockerfile",
        "Environment": "development",
        "Team": "devsecops",
        "VulnerabilityId": "$vuln_id"
      }
    }
  ],
  "UserDefinedFields": {
    "ApplicationName": "devsecops-assessment",
    "VulnerabilityId": "$vuln_id",
    "ScanTimestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "FindingSource": "dockerfile-security-pipeline"
  },
  "WorkflowState": "NEW",
  "RecordState": "ACTIVE"
},
EOF
        done
    fi
    
    # Also check vulnerability scan file if exists
    vuln_scan_file="$OUTPUT_DIR/dockerfile_vulnerabilities_${TIMESTAMP}.json"
    if [ -f "$vuln_scan_file" ]; then
        echo "📊 Processing vulnerability scan file..."
        vuln_scan_data=$(jq '.vulnerabilities[]?' "$vuln_scan_file" 2>/dev/null || echo "")
        if [ -n "$vuln_scan_data" ]; then
            echo "$vuln_scan_data" | jq -c '.' | while read -r vuln; do
                vuln_id=$(echo "$vuln" | jq -r '.id // "unknown"')
                vuln_desc=$(echo "$vuln" | jq -r '.description // "No description available"')
                vuln_severity=$(echo "$vuln" | jq -r '.ratings[0].severity // "MEDIUM"' | tr '[:lower:]' '[:upper:]')
                
                # Fix severity mapping for Security Hub
                case "$vuln_severity" in
                    "INFO"|"INFORMATIONAL") vuln_severity="LOW" ;;
                    "CRITICAL"|"HIGH"|"MEDIUM"|"LOW") ;; # Valid values
                    *) vuln_severity="MEDIUM" ;; # Default fallback
                esac
                
                # Get affected lines from SBOM properties for this vulnerability
                affected_lines=$(jq -r ".components[]?.properties[]? | select(.name | contains(\"$vuln_id\")) | .value" "$sbom_file" 2>/dev/null | head -1)
                
                # Add line numbers to description
                if [ -n "$affected_lines" ]; then
                    description_with_lines="$vuln_desc (Affected: $affected_lines)"
                else
                    description_with_lines="$vuln_desc"
                fi
                
                # Generate individual ASFF finding with detailed description
                cat >> "$asff_file.tmp" << EOF
{
  "SchemaVersion": "2018-10-08",
  "Id": "dockerfile-vuln-scan-$vuln_id-$(date +%s)",
  "ProductArn": "arn:aws:securityhub:$REGION:$AWS_ACCOUNT_ID:product/$AWS_ACCOUNT_ID/default",
  "GeneratorId": "aws-inspector-dockerfile-scanner",
  "AwsAccountId": "$AWS_ACCOUNT_ID",
  "Types": ["Software and Configuration Checks/Vulnerabilities"],
  "FirstObservedAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "LastObservedAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "CreatedAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "UpdatedAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "Severity": {
    "Label": "$vuln_severity"
  },
  "Title": "Dockerfile Security Issue: $vuln_id",
  "Description": "$description_with_lines",
  "Resources": [
    {
      "Type": "Other",
      "Id": "$PROJECT_ROOT/application/Dockerfile",
      "Region": "$REGION",
      "Tags": {
        "Application": "devsecops-assessment",
        "Component": "dockerfile",
        "Environment": "development",
        "Team": "devsecops",
        "VulnerabilityId": "$vuln_id"
      }
    }
  ],
  "UserDefinedFields": {
    "ApplicationName": "devsecops-assessment",
    "VulnerabilityId": "$vuln_id",
    "ScanTimestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "FindingSource": "dockerfile-vulnerability-scan"
  },
  "WorkflowState": "NEW",
  "RecordState": "ACTIVE"
},
EOF
            done
        fi
    fi
    
    # Get dynamic description from local knowledge base
get_inspector_rule_description() {
    local rule_id="$1"
    
    # Try to fetch from AWS Inspector documentation or local cache
    local cache_file="/tmp/inspector_rules_cache.json"
    
    # Create cache if not exists
    if [ ! -f "$cache_file" ]; then
        cat > "$cache_file" << 'EOF'
{
  "IN-DOCKER-001": "Package manager cache not cleaned - apt-get update should be combined with install",
  "IN-DOCKER-005-008": "Insecure command flags detected - avoid using insecure options",
  "IN-DOCKER-007-001": "Hardcoded secrets detected - environment variables contain sensitive data",
  "IN-DOCKER-ROOT": "Container runs as root user - use non-root user for security"
}
EOF
    fi
    
    # Get description from cache
    local description=$(jq -r ".[\"$rule_id\"] // \"Dockerfile security issue: $rule_id\"" "$cache_file" 2>/dev/null)
    
    echo "$description"
}

# Parse component properties for Dockerfile-specific findings
    dockerfile_properties=$(jq -r '.components[]? | select(.name | contains("dockerfile")) | .properties[]? | select(.name | contains("dockerfile")) | "\(.name)|\(.value)"' "$sbom_file" 2>/dev/null || echo "")
    
    if [ -n "$dockerfile_properties" ]; then
        echo "📊 Processing Dockerfile property findings..."
        echo "$dockerfile_properties" | while IFS='|' read -r prop_name prop_value; do
            # Extract finding ID from property name
            finding_id=$(echo "$prop_name" | sed 's/.*dockerfile_finding://' | sed 's/:.*$//')
            
            # Determine severity based on finding pattern
            if echo "$finding_id" | grep -q "CRITICAL\|HIGH\|007"; then
                severity="HIGH"
            elif echo "$finding_id" | grep -q "MEDIUM\|005"; then
                severity="MEDIUM"
            else
                severity="LOW"
            fi
            
            # Generate title and description
            title="Dockerfile Security Finding: $finding_id"
            description="Dockerfile security issue: $prop_value"
            
            # Generate individual ASFF finding
            cat >> "$asff_file.tmp" << EOF
{
  "SchemaVersion": "2018-10-08",
  "Id": "dockerfile-prop-$finding_id-$(date +%s)",
  "ProductArn": "arn:aws:securityhub:$REGION:$AWS_ACCOUNT_ID:product/$AWS_ACCOUNT_ID/default",
  "GeneratorId": "aws-inspector-dockerfile-scanner",
  "AwsAccountId": "$AWS_ACCOUNT_ID",
  "Types": ["Software and Configuration Checks/Vulnerabilities"],
  "FirstObservedAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "LastObservedAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "CreatedAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "UpdatedAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "Severity": {
    "Label": "$severity"
  },
  "Title": "$title",
  "Description": "$description",
  "Resources": [
    {
      "Type": "Other",
      "Id": "$PROJECT_ROOT/application/Dockerfile",
      "Region": "$REGION",
      "Tags": {
        "Application": "devsecops-assessment",
        "Component": "dockerfile",
        "Environment": "development",
        "Team": "devsecops",
        "FindingId": "$finding_id"
      }
    }
  ],
  "UserDefinedFields": {
    "ApplicationName": "devsecops-assessment",
    "FindingId": "$finding_id",
    "ScanTimestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "FindingSource": "dockerfile-security-pipeline"
  },
  "WorkflowState": "NEW",
  "RecordState": "ACTIVE"
},
EOF
        done
    fi
    
    # If no findings from parsing, create a generic "no issues" finding
    if [ ! -f "$asff_file.tmp" ]; then
        echo "📊 No security findings detected, creating clean status finding..."
        cat >> "$asff_file.tmp" << EOF
{
  "SchemaVersion": "2018-10-08",
  "Id": "dockerfile-clean-$(date +%s)",
  "ProductArn": "arn:aws:securityhub:$REGION:$AWS_ACCOUNT_ID:product/$AWS_ACCOUNT_ID/default",
  "GeneratorId": "aws-inspector-dockerfile-scanner",
  "AwsAccountId": "$AWS_ACCOUNT_ID",
  "Types": ["Software and Configuration Checks/Vulnerabilities"],
  "FirstObservedAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "LastObservedAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "CreatedAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "UpdatedAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "Severity": {
    "Label": "INFORMATIONAL"
  },
  "Title": "Dockerfile Security Scan Complete",
  "Description": "Dockerfile security scan completed successfully with no security issues detected",
  "Resources": [
    {
      "Type": "Other",
      "Id": "$PROJECT_ROOT/application/Dockerfile",
      "Region": "$REGION",
      "Tags": {
        "Application": "devsecops-assessment",
        "Component": "dockerfile",
        "Environment": "development",
        "Team": "devsecops",
        "Status": "clean"
      }
    }
  ],
  "UserDefinedFields": {
    "ApplicationName": "devsecops-assessment",
    "ScanStatus": "clean",
    "ScanTimestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "FindingSource": "dockerfile-security-pipeline"
  },
  "WorkflowState": "NEW",
  "RecordState": "ACTIVE"
},
EOF
    fi
    
    # Combine findings into final ASFF format
    if [ -f "$asff_file.tmp" ]; then
        # Remove last comma and wrap in Findings array
        sed '$ s/,$//' "$asff_file.tmp" > "$asff_file.clean"
        cat > "$asff_file" << EOF
{
  "Findings": [
$(cat "$asff_file.clean")
  ]
}
EOF
        rm -f "$asff_file.tmp" "$asff_file.clean"
    else
        # No findings
        cat > "$asff_file" << EOF
{
  "Findings": []
}
EOF
    fi
    echo "✅ ASFF file generated: $(basename "$asff_file")"    
    # Send to SQS for Lambda processing
    send_to_sqs "$asff_file"
}

# Analyze results
if [ -f "$OUTPUT_DIR/dockerfile_sbom_${TIMESTAMP}.json" ]; then
    echo "📊 Analyzing SBOM results..."
    
    # Parse SBOM with detailed analysis
    analyze_sbom_detailed() {
        local sbom_file="$1"
        
        echo ""
        echo "🔍 SBOM Analysis Report"
        echo "======================"
        
        # Basic SBOM info
        if command -v jq &> /dev/null; then
            echo "📋 SBOM Metadata:"
            echo "  Format: $(jq -r '.bomFormat // "Unknown"' "$sbom_file")"
            echo "  Version: $(jq -r '.specVersion // "Unknown"' "$sbom_file")"
            echo "  Generated: $(jq -r '.metadata.timestamp // "Unknown"' "$sbom_file")"
            echo "  Tool: $(jq -r '.metadata.tools.components[0].name // "Unknown"' "$sbom_file") v$(jq -r '.metadata.tools.components[0].version // "Unknown"' "$sbom_file")"
            
            # Components analysis
            components_count=$(jq '.components | length' "$sbom_file" 2>/dev/null || echo 0)
            echo ""
            echo "📦 Components Found: $components_count"
            
            if [ "$components_count" -gt 0 ]; then
                echo "  Components:"
                jq -r '.components[] | "  - \(.name // "Unknown") (\(.type // "Unknown"))"' "$sbom_file" 2>/dev/null
            else
                echo "  ℹ️  No components detected by Dockerfile scanner"
                echo "  📝 Note: Dockerfile scanner only detects Dockerfile syntax issues"
                echo "  💡 To scan packages, use: --scanners dockerfile,pip,dpkg"
            fi
            
            # Vulnerabilities analysis
            vulns_count=$(jq '.vulnerabilities | length' "$sbom_file" 2>/dev/null || echo 0)
            echo ""
            echo "🛡️  Security Findings: $vulns_count"
            
            if [ "$vulns_count" -gt 0 ]; then
                echo "  Vulnerabilities:"
                jq -r '.vulnerabilities[] | "  - \(.id // "Unknown"): \(.description // "No description")"' "$sbom_file" 2>/dev/null
                
                # Group by severity
                critical=$(jq '[.vulnerabilities[] | select(.ratings[]?.severity == "critical")] | length' "$sbom_file" 2>/dev/null || echo 0)
                high=$(jq '[.vulnerabilities[] | select(.ratings[]?.severity == "high")] | length' "$sbom_file" 2>/dev/null || echo 0)
                medium=$(jq '[.vulnerabilities[] | select(.ratings[]?.severity == "medium")] | length' "$sbom_file" 2>/dev/null || echo 0)
                low=$(jq '[.vulnerabilities[] | select(.ratings[]?.severity == "low")] | length' "$sbom_file" 2>/dev/null || echo 0)
                
                echo ""
                echo "  📊 Severity Breakdown:"
                echo "    Critical: $critical"
                echo "    High: $high"
                echo "    Medium: $medium"
                echo "    Low: $low"
            else
                echo "  ✅ No security vulnerabilities found in Dockerfile"
            fi
            
            # Dockerfile specific findings from properties
            dockerfile_findings=$(jq '[.components[]? | select(.name | contains("dockerfile")) | .properties[]? | select(.name | contains("dockerfile_finding"))]' "$sbom_file" 2>/dev/null || echo "[]")
            dockerfile_findings_count=$(echo "$dockerfile_findings" | jq 'length')
            
            echo ""
            echo "🐳 Dockerfile Security Findings: $dockerfile_findings_count"
            
            if [ "$dockerfile_findings_count" -gt 0 ]; then
                echo "  Dockerfile Issues Found:"
                echo "$dockerfile_findings" | jq -r '.[] | "  - \(.name | split(":")[4]): \(.value)"' 2>/dev/null
                
                # Map findings to descriptions with detailed info
                echo ""
                echo "  📋 Detailed Finding Analysis:"
                echo "$dockerfile_findings" | jq -r '.[] | .name | split(":")[4]' | sort -u | while read finding_id; do
                    # Get line numbers for this finding
                    lines=$(echo "$dockerfile_findings" | jq -r --arg id "$finding_id" '.[] | select(.name | contains($id)) | .value' | sort -u | tr '\n' ',' | sed 's/,$//')
                    
                    case "$finding_id" in
                        "IN-DOCKER-001")
                            echo "    🔴 CRITICAL: $finding_id - Hardcoded Secrets/Credentials (Lines: $lines)"
                            echo "       Impact: Exposed sensitive data in container image"
                            echo "       Action: Remove hardcoded secrets, use environment variables or secrets manager"
                            ;;
                        "IN-DOCKER-005-008")
                            echo "    🟠 HIGH: $finding_id - Insecure Curl Flags (Lines: $lines)"
                            echo "       Impact: TLS certificate validation bypassed with --insecure/-k flag"
                            echo "       Action: Remove --insecure flag, use proper certificate validation"
                            ;;
                        "IN-DOCKER-007-001")
                            echo "    🟡 MEDIUM: $finding_id - APT Cache Layer Issue (Lines: $lines)"
                            echo "       Impact: Package cache not properly cleaned, increases image size"
                            echo "       Action: Use 'apt-get update && apt-get install && rm -rf /var/lib/apt/lists/*' in single RUN"
                            ;;
                        *)
                            echo "    ⚠️  UNKNOWN: $finding_id - Security issue detected (Lines: $lines)"
                            echo "       Action: Review Dockerfile line(s) for security best practices"
                            ;;
                    esac
                    echo ""
                done
            else
                echo "  ✅ No Dockerfile security issues detected"
            fi
            
        else
            echo "⚠️  jq not available for detailed analysis"
            echo "📄 Raw SBOM content:"
            head -20 "$sbom_file"
        fi
    }
    
    # Run detailed analysis
    analyze_sbom_detailed "$OUTPUT_DIR/dockerfile_sbom_${TIMESTAMP}.json"
    
    # Check for security issues and exit accordingly
    dockerfile_findings=$(jq '[.components[]? | select(.name | contains("dockerfile")) | .properties[]? | select(.name | contains("dockerfile_finding"))]' "$OUTPUT_DIR/dockerfile_sbom_${TIMESTAMP}.json" 2>/dev/null || echo "[]")
    dockerfile_findings_count=$(echo "$dockerfile_findings" | jq 'length')
    total_issues=$dockerfile_findings_count
    
    # Generate ASFF findings for Security Hub
    if [ "$total_issues" -gt 0 ]; then
        echo ""
        echo "📤 Generating ASFF findings for Security Hub..."
        generate_asff_findings "$OUTPUT_DIR/dockerfile_sbom_${TIMESTAMP}.json"
    fi
    
    if [ "$total_issues" -gt 0 ]; then
        echo ""
        echo "═══════════════════════════════════════════════════════════════"
        echo "🚨 DOCKERFILE SECURITY SCAN RESULTS"
        echo "═══════════════════════════════════════════════════════════════"
        echo "📊 TOTAL FINDINGS: $total_issues security issues detected"
        echo ""
        echo "🔍 FINDINGS BREAKDOWN:"
        
        # Count findings by severity
        critical_count=$(echo "$dockerfile_findings" | jq -r '.[] | .name | split(":")[4]' | grep -c "IN-DOCKER-001" 2>/dev/null || echo "0")
        high_count=$(echo "$dockerfile_findings" | jq -r '.[] | .name | split(":")[4]' | grep -c "IN-DOCKER-005-008" 2>/dev/null || echo "0")
        medium_count=$(echo "$dockerfile_findings" | jq -r '.[] | .name | split(":")[4]' | grep -c "IN-DOCKER-007-001" 2>/dev/null || echo "0")
        
        [ "$critical_count" -gt 0 ] && echo "  🔴 CRITICAL: $critical_count (Hardcoded Secrets)"
        [ "$high_count" -gt 0 ] && echo "  🟠 HIGH: $high_count (Insecure Configuration)"
        [ "$medium_count" -gt 0 ] && echo "  🟡 MEDIUM: $medium_count (Best Practice Violations)"
        
        echo ""
        echo "📋 CI/CD PIPELINE ACTION REQUIRED:"
        echo "  ❌ BUILD SHOULD FAIL - Security issues must be resolved"
        echo "  🔧 Review findings above and fix Dockerfile"
        echo "  📤 Findings sent to Security Hub for tracking"
        echo ""
        echo "═══════════════════════════════════════════════════════════════"
        echo "EXIT CODE: 1 (Security Issues Found)"
        exit 1
    else
        echo ""
        echo "═══════════════════════════════════════════════════════════════"
        echo "✅ DOCKERFILE SECURITY SCAN RESULTS"
        echo "═══════════════════════════════════════════════════════════════"
        echo "🎉 NO SECURITY ISSUES DETECTED"
        echo ""
        echo "📋 CI/CD PIPELINE STATUS:"
        echo "  ✅ BUILD CAN PROCEED - Dockerfile is secure"
        echo "  🛡️  All security checks passed"
        echo "  📊 Ready for next pipeline stage"
        echo ""
        echo "═══════════════════════════════════════════════════════════════"
        echo "EXIT CODE: 0 (Success)"
    fi
    
else
    echo "❌ SBOM file not found"
    echo "📋 Exit code: 2 (Tool failure)"
    exit 2
fi

# Cleanup function
cleanup_files() {
    echo "🧹 Cleaning up temporary files..."
    
    # Remove Docker image
    if docker images -q inspector-sbomgen:latest >/dev/null 2>&1; then
        docker rmi inspector-sbomgen:latest >/dev/null 2>&1 || true
        echo "  ✅ Removed Docker image: inspector-sbomgen:latest"
    fi
    
    # Remove temporary Dockerfile
    rm -f /tmp/Dockerfile.inspector
    echo "  ✅ Removed temporary Dockerfile"
    
    # Remove any temporary processing files
    rm -f "$OUTPUT_DIR"/*.tmp "$OUTPUT_DIR"/*.clean
    echo "  ✅ Removed temporary processing files"
}

# Cleanup
cleanup_files
echo "🎉 Cleanup completed successfully!"
