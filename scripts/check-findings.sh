#!/bin/bash

# Check Security Findings for project
# Usage: ./check-findings.sh [profile] [region]

PROFILE=${1:-esoftvn-researching}
REGION=${2:-us-east-1}

echo "🔍 Checking security findings..."

# Get all findings
FINDINGS=$(aws inspector2 list-findings \
    --profile $PROFILE \
    --region $REGION \
    --output json 2>/dev/null || echo '{"findings":[]}')

# Count by severity
CRITICAL=$(echo "$FINDINGS" | jq '[.findings[] | select(.severity == "CRITICAL")] | length')
HIGH=$(echo "$FINDINGS" | jq '[.findings[] | select(.severity == "HIGH")] | length')
MEDIUM=$(echo "$FINDINGS" | jq '[.findings[] | select(.severity == "MEDIUM")] | length')
LOW=$(echo "$FINDINGS" | jq '[.findings[] | select(.severity == "LOW")] | length')
TOTAL=$(echo "$FINDINGS" | jq '.findings | length')

# Display table
echo ""
echo "╔═══════════════════════════════╗"
echo "║    SECURITY FINDINGS SUMMARY  ║"
echo "╠═══════════════════════════════╣"
printf "║ %-10s │ %-6s │ %-8s ║\n" "SEVERITY" "COUNT" "STATUS"
echo "╠═══════════════════════════════╣"
printf "║ %-10s │ %-6s │ %-8s ║\n" "💀 CRITICAL" "$CRITICAL" "$([ $CRITICAL -gt 0 ] && echo "🚨 FIX" || echo "✅ OK")"
printf "║ %-10s │ %-6s │ %-8s ║\n" "🚨 HIGH" "$HIGH" "$([ $HIGH -gt 0 ] && echo "⚠️  FIX" || echo "✅ OK")"
printf "║ %-10s │ %-6s │ %-8s ║\n" "⚠️  MEDIUM" "$MEDIUM" "$([ $MEDIUM -gt 0 ] && echo "📝 CHECK" || echo "✅ OK")"
printf "║ %-10s │ %-6s │ %-8s ║\n" "📝 LOW" "$LOW" "$([ $LOW -gt 0 ] && echo "ℹ️  INFO" || echo "✅ OK")"
echo "╠═══════════════════════════════╣"
printf "║ %-10s │ %-6s │ %-8s ║\n" "🔢 TOTAL" "$TOTAL" "$([ $TOTAL -gt 0 ] && echo "📊 FOUND" || echo "✅ CLEAN")"
echo "╚═══════════════════════════════╝"

# Show HIGH findings details
if [ "$HIGH" -gt 0 ]; then
    echo ""
    echo "🚨 HIGH SEVERITY FINDINGS:"
    echo "────────────────────────────────────────"
    echo "$FINDINGS" | jq -r '.findings[] | select(.severity == "HIGH") | 
    "• \(.title // "No title")
  File: \(.codeVulnerabilityDetails.filePath.filePath // .packageVulnerabilityDetails.vulnerablePackages[0].filePath // "Unknown")
  Type: \(.type // "Unknown")
  Status: \(.status // "Unknown")"'
fi

echo ""
echo "📊 Summary: $TOTAL total findings ($CRITICAL critical, $HIGH high severity)"
