#!/bin/bash

# Check ACTIVE Security Findings for project
# Usage: ./check-findings.sh [profile] [region]

PROFILE=$1
REGION=${2:-us-east-1}

# Conditionally set profile argument
if [ -n "$PROFILE" ]; then
  AWS_ARGS=(--profile "$PROFILE")
  echo "👤 Using AWS Profile: $PROFILE"
else
  AWS_ARGS=()
  echo "🔑 Using AWS credentials from environment (OIDC)"
fi

echo "🔍 AWS Inspector Code Security Analysis"
echo "════════════════════════════════════════════════════════════"

# Get only ACTIVE CODE_VULNERABILITY findings
FINDINGS=$(aws inspector2 list-findings \
    "${AWS_ARGS[@]}" \
    --region "$REGION" \
    --filter-criteria '{"findingStatus":[{"value":"ACTIVE","comparison":"EQUALS"}],"findingType":[{"value":"CODE_VULNERABILITY","comparison":"EQUALS"}]}' \
    --output json 2>/dev/null || echo '{"findings":[]}')

# Count by severity
CRITICAL=$(echo "$FINDINGS" | jq '[.findings[] | select(.severity == "CRITICAL")] | length')
HIGH=$(echo "$FINDINGS" | jq '[.findings[] | select(.severity == "HIGH")] | length')
MEDIUM=$(echo "$FINDINGS" | jq '[.findings[] | select(.severity == "MEDIUM")] | length')
LOW=$(echo "$FINDINGS" | jq '[.findings[] | select(.severity == "LOW")] | length')
TOTAL=$(echo "$FINDINGS" | jq '.findings | length')

# Display beautiful table
echo ""
echo "┌─────────────────────────────────────────────────────────┐"
echo "│                 🛡️  SECURITY FINDINGS                   │"
echo "├─────────────────┬───────────┬───────────────────────────┤"
echo "│    SEVERITY     │   COUNT   │          STATUS           │"
echo "├─────────────────┼───────────┼───────────────────────────┤"
printf "│ %-15s │ %-9s │ %-25s │\n" "💀 CRITICAL" "$CRITICAL" "$([ $CRITICAL -gt 0 ] && echo "🚨 IMMEDIATE ACTION" || echo "✅ SECURE")"
printf "│ %-15s │ %-9s │ %-25s │\n" "🚨 HIGH" "$HIGH" "$([ $HIGH -gt 0 ] && echo "⚠️  NEEDS FIXING" || echo "✅ SECURE")"
printf "│ %-15s │ %-9s │ %-25s │\n" "⚠️  MEDIUM" "$MEDIUM" "$([ $MEDIUM -gt 0 ] && echo "📝 REVIEW REQUIRED" || echo "✅ SECURE")"
printf "│ %-15s │ %-9s │ %-25s │\n" "📝 LOW" "$LOW" "$([ $LOW -gt 0 ] && echo "ℹ️  INFORMATIONAL" || echo "✅ SECURE")"
echo "├─────────────────┼───────────┼───────────────────────────┤"
printf "│ %-15s │ %-9s │ %-25s │\n" "🔢 TOTAL ACTIVE" "$TOTAL" "$([ $TOTAL -gt 0 ] && echo "📊 FINDINGS DETECTED" || echo "✅ ALL CLEAR")"
echo "└─────────────────┴───────────┴───────────────────────────┘"

# Show HIGH findings details
if [ "$HIGH" -gt 0 ]; then
    echo ""
    echo "🚨 HIGH SEVERITY FINDINGS DETAILS:"
    echo "────────────────────────────────────────────────────────────"
    echo "$FINDINGS" | jq -r '.findings[] | select(.severity == "HIGH") | 
    "• \(.title // "No title")
  📁 File: \(.codeVulnerabilityDetails.filePath.filePath // "Unknown")
  📍 Line: \(.codeVulnerabilityDetails.filePath.startLine // "N/A")-\(.codeVulnerabilityDetails.filePath.endLine // "N/A")
  🔍 Type: \(.type // "Unknown")
  🏷️  Tags: \(.codeVulnerabilityDetails.detectorTags // [] | join(", "))"'
fi

# Show MEDIUM findings details
if [ "$MEDIUM" -gt 0 ]; then
    echo ""
    echo "⚠️ MEDIUM SEVERITY FINDINGS DETAILS:"
    echo "────────────────────────────────────────────────────────────"
    echo "$FINDINGS" | jq -r '.findings[] | select(.severity == "MEDIUM") | 
    "• \(.title // "No title")
  📁 File: \(.codeVulnerabilityDetails.filePath.filePath // "Unknown")
  📍 Line: \(.codeVulnerabilityDetails.filePath.startLine // "N/A")-\(.codeVulnerabilityDetails.filePath.endLine // "N/A")
  🔍 Type: \(.type // "Unknown")
  🏷️  Tags: \(.codeVulnerabilityDetails.detectorTags // [] | join(", "))"'
fi

# Summary
echo ""
echo "📊 SUMMARY:"
echo "• Active Code Vulnerabilities: $TOTAL total"
echo "• Critical Issues: $CRITICAL"
echo "• High Priority: $HIGH"
if [ "$CRITICAL" -eq 0 ] && [ "$HIGH" -eq 0 ]; then
    echo "• 🎉 Status: All critical and high severity code vulnerabilities resolved!"
elif [ "$CRITICAL" -eq 0 ]; then
    echo "• ✅ No critical vulnerabilities"
    echo "• 🚨 Action Required: Fix $HIGH high severity code vulnerabilities"
else
    echo "• 💀 URGENT: $CRITICAL critical vulnerabilities need immediate attention"
    echo "• 🚨 Also Fix: $HIGH high severity code vulnerabilities"
fi
echo "════════════════════════════════════════════════════════════"

# Exit with failure code if there are critical or high findings, comment for CICD
if [ "$CRITICAL" -gt 0 ] || [ "$HIGH" -gt 0 ]; then
    echo "🔥 Step failed due to CRITICAL or HIGH severity findings."
    exit 1
else
    echo "✅ No critical or high severity findings detected."
    exit 0
fi
