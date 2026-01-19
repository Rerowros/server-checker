#!/bin/bash
# =============================================================================
# report.sh - Report generation utilities
# =============================================================================

# Global arrays to store results
declare -A REPORT_DATA
declare -a REPORT_TESTS

# Initialize report
init_report() {
    # Properly clear arrays while keeping their type
    unset REPORT_DATA
    unset REPORT_TESTS
    declare -g -A REPORT_DATA
    declare -g -a REPORT_TESTS
    
    REPORT_DATA["timestamp"]=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    REPORT_DATA["hostname"]=$(hostname 2>/dev/null || echo "unknown")
}

# Add data to report
add_report_data() {
    local key="$1"
    local value="$2"
    REPORT_DATA["$key"]="$value"
}

# Add test result
add_test_result() {
    local category="$1"
    local name="$2"
    local status="$3"  # pass, fail, warn, skip
    local details="$4"
    
    REPORT_TESTS+=("${category}|${name}|${status}|${details}")
}

# Generate console report
generate_console_report() {
    source "$(dirname "${BASH_SOURCE[0]}")/colors.sh" 2>/dev/null || true
    
    echo ""
    echo -e "${BOLD:-}╔═══════════════════════════════════════════════════════════════╗${NC:-}"
    echo -e "${BOLD:-}║               VPS SERVER TEST REPORT                          ║${NC:-}"
    echo -e "${BOLD:-}╚═══════════════════════════════════════════════════════════════╝${NC:-}"
    echo ""
    
    # Server Info Section
    echo -e "${BOLD:-}📋 Server Information${NC:-}"
    echo "─────────────────────────────────────────────"
    printf "  %-18s %s\n" "Timestamp:" "${REPORT_DATA[timestamp]:-N/A}"
    printf "  %-18s %s\n" "Hostname:" "${REPORT_DATA[hostname]:-N/A}"
    printf "  %-18s %s\n" "Public IP:" "${REPORT_DATA[public_ip]:-N/A}"
    printf "  %-18s %s\n" "Location:" "${REPORT_DATA[location]:-N/A}"
    printf "  %-18s %s\n" "Provider:" "${REPORT_DATA[provider]:-N/A}"
    printf "  %-18s %s\n" "ASN:" "${REPORT_DATA[asn]:-N/A}"
    printf "  %-18s %s\n" "PTR Record:" "${REPORT_DATA[ptr]:-N/A}"
    echo ""
    
    # Test Results Section  
    echo -e "${BOLD:-}🔍 Test Results${NC:-}"
    echo "─────────────────────────────────────────────"
    
    local current_category=""
    local pass_count=0
    local fail_count=0
    local warn_count=0
    
    for test in "${REPORT_TESTS[@]}"; do
        IFS='|' read -r category name status details <<< "$test"
        
        if [[ "$category" != "$current_category" ]]; then
            echo ""
            echo -e "  ${BOLD:-}▸ ${category}${NC:-}"
            current_category="$category"
        fi
        
        local icon
        case "$status" in
            pass) icon="✓"; ((pass_count++)) ;;
            fail) icon="✗"; ((fail_count++)) ;;
            warn) icon="!"; ((warn_count++)) ;;
            skip) icon="-" ;;
            *) icon="?" ;;
        esac
        
        printf "    [%s] %-25s %s\n" "$icon" "$name" "$details"
    done
    
    # Summary
    echo ""
    echo "─────────────────────────────────────────────"
    echo -e "${BOLD:-}📊 Summary${NC:-}"
    echo "  Passed: $pass_count  |  Failed: $fail_count  |  Warnings: $warn_count"
    echo ""
    
    # Overall verdict
    if [[ $fail_count -eq 0 && $warn_count -eq 0 ]]; then
        echo -e "${GREEN:-}✅ Server looks good! All tests passed.${NC:-}"
    elif [[ $fail_count -eq 0 ]]; then
        echo -e "${YELLOW:-}⚠️  Server has some warnings but should work.${NC:-}"
    else
        echo -e "${RED:-}❌ Server has issues. Review failed tests above.${NC:-}"
    fi
    echo ""
}

# Generate JSON report
generate_json_report() {
    local output_file="${1:-report.json}"
    
    cat > "$output_file" << EOF
{
  "report": {
    "generated": "${REPORT_DATA[timestamp]:-}",
    "hostname": "${REPORT_DATA[hostname]:-}",
    "version": "1.0"
  },
  "server": {
    "ip": "${REPORT_DATA[public_ip]:-}",
    "location": "${REPORT_DATA[location]:-}",
    "provider": "${REPORT_DATA[provider]:-}",
    "asn": "${REPORT_DATA[asn]:-}",
    "ptr": "${REPORT_DATA[ptr]:-}"
  },
  "tests": [
EOF
    
    local first=true
    for test in "${REPORT_TESTS[@]}"; do
        IFS='|' read -r category name status details <<< "$test"
        
        if [[ "$first" == "true" ]]; then
            first=false
        else
            echo "," >> "$output_file"
        fi
        
        cat >> "$output_file" << EOF
    {
      "category": "$category",
      "name": "$name",
      "status": "$status",
      "details": "$details"
    }
EOF
    done
    
    cat >> "$output_file" << EOF

  ]
}
EOF
    
    echo "JSON report saved to: $output_file"
}

# Generate HTML report
generate_html_report() {
    local output_file="${1:-report.html}"
    
    local pass_count=0
    local fail_count=0
    local warn_count=0
    
    for test in "${REPORT_TESTS[@]}"; do
        IFS='|' read -r _ _ status _ <<< "$test"
        case "$status" in
            pass) ((pass_count++)) ;;
            fail) ((fail_count++)) ;;
            warn) ((warn_count++)) ;;
        esac
    done
    
    cat > "$output_file" << 'HTMLHEAD'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>VPS Server Test Report</title>
    <style>
        :root {
            --bg: #0d1117;
            --card-bg: #161b22;
            --border: #30363d;
            --text: #c9d1d9;
            --text-muted: #8b949e;
            --green: #3fb950;
            --red: #f85149;
            --yellow: #d29922;
            --blue: #58a6ff;
        }
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
            background: var(--bg);
            color: var(--text);
            line-height: 1.6;
            padding: 2rem;
        }
        .container { max-width: 900px; margin: 0 auto; }
        h1 { 
            text-align: center; 
            margin-bottom: 2rem;
            background: linear-gradient(135deg, var(--blue), var(--green));
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            font-size: 2.5rem;
        }
        .card {
            background: var(--card-bg);
            border: 1px solid var(--border);
            border-radius: 12px;
            padding: 1.5rem;
            margin-bottom: 1.5rem;
        }
        .card h2 {
            color: var(--blue);
            margin-bottom: 1rem;
            font-size: 1.2rem;
            display: flex;
            align-items: center;
            gap: 0.5rem;
        }
        .info-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 1rem;
        }
        .info-item { padding: 0.5rem 0; }
        .info-label { color: var(--text-muted); font-size: 0.85rem; }
        .info-value { font-weight: 500; font-size: 1.1rem; }
        .test-item {
            display: flex;
            align-items: center;
            padding: 0.75rem;
            border-bottom: 1px solid var(--border);
        }
        .test-item:last-child { border-bottom: none; }
        .status-icon {
            width: 24px;
            height: 24px;
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            font-weight: bold;
            margin-right: 1rem;
            flex-shrink: 0;
        }
        .status-pass { background: var(--green); color: #000; }
        .status-fail { background: var(--red); color: #fff; }
        .status-warn { background: var(--yellow); color: #000; }
        .status-skip { background: var(--border); color: var(--text-muted); }
        .test-name { flex: 1; }
        .test-details { color: var(--text-muted); font-size: 0.9rem; }
        .summary {
            display: flex;
            justify-content: center;
            gap: 2rem;
            margin-top: 1rem;
        }
        .summary-item { text-align: center; }
        .summary-count { font-size: 2rem; font-weight: bold; }
        .summary-pass .summary-count { color: var(--green); }
        .summary-fail .summary-count { color: var(--red); }
        .summary-warn .summary-count { color: var(--yellow); }
        .verdict {
            text-align: center;
            padding: 1.5rem;
            border-radius: 12px;
            font-size: 1.2rem;
            font-weight: 500;
            margin-top: 1.5rem;
        }
        .verdict-good { background: rgba(63, 185, 80, 0.15); border: 1px solid var(--green); color: var(--green); }
        .verdict-warn { background: rgba(210, 153, 34, 0.15); border: 1px solid var(--yellow); color: var(--yellow); }
        .verdict-bad { background: rgba(248, 81, 73, 0.15); border: 1px solid var(--red); color: var(--red); }
        .category-header { 
            font-weight: 600; 
            color: var(--blue); 
            padding: 0.75rem; 
            background: rgba(88, 166, 255, 0.1);
            border-radius: 6px;
            margin: 0.5rem 0;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🖥️ VPS Server Test Report</h1>
HTMLHEAD

    # Add server info card
    cat >> "$output_file" << EOF
        <div class="card">
            <h2>📋 Server Information</h2>
            <div class="info-grid">
                <div class="info-item">
                    <div class="info-label">Public IP</div>
                    <div class="info-value">${REPORT_DATA[public_ip]:-N/A}</div>
                </div>
                <div class="info-item">
                    <div class="info-label">Location</div>
                    <div class="info-value">${REPORT_DATA[location]:-N/A}</div>
                </div>
                <div class="info-item">
                    <div class="info-label">Provider</div>
                    <div class="info-value">${REPORT_DATA[provider]:-N/A}</div>
                </div>
                <div class="info-item">
                    <div class="info-label">ASN</div>
                    <div class="info-value">${REPORT_DATA[asn]:-N/A}</div>
                </div>
                <div class="info-item">
                    <div class="info-label">PTR Record</div>
                    <div class="info-value">${REPORT_DATA[ptr]:-N/A}</div>
                </div>
                <div class="info-item">
                    <div class="info-label">Hostname</div>
                    <div class="info-value">${REPORT_DATA[hostname]:-N/A}</div>
                </div>
            </div>
        </div>
        
        <div class="card">
            <h2>🔍 Test Results</h2>
EOF

    # Add test results
    local current_category=""
    for test in "${REPORT_TESTS[@]}"; do
        IFS='|' read -r category name status details <<< "$test"
        
        if [[ "$category" != "$current_category" ]]; then
            if [[ -n "$current_category" ]]; then
                echo "</div>" >> "$output_file"
            fi
            echo "<div class=\"category-header\">$category</div><div>" >> "$output_file"
            current_category="$category"
        fi
        
        local icon
        case "$status" in
            pass) icon="✓" ;;
            fail) icon="✗" ;;
            warn) icon="!" ;;
            skip) icon="-" ;;
            *) icon="?" ;;
        esac
        
        cat >> "$output_file" << EOF
            <div class="test-item">
                <div class="status-icon status-$status">$icon</div>
                <div class="test-name">$name</div>
                <div class="test-details">$details</div>
            </div>
EOF
    done
    
    # Close last category and add summary
    echo "</div>" >> "$output_file"
    
    # Determine verdict
    local verdict_class verdict_text
    if [[ $fail_count -eq 0 && $warn_count -eq 0 ]]; then
        verdict_class="verdict-good"
        verdict_text="✅ Server looks good! All tests passed."
    elif [[ $fail_count -eq 0 ]]; then
        verdict_class="verdict-warn"
        verdict_text="⚠️ Server has some warnings but should work."
    else
        verdict_class="verdict-bad"
        verdict_text="❌ Server has issues. Review failed tests above."
    fi
    
    cat >> "$output_file" << EOF
        </div>
        
        <div class="card">
            <h2>📊 Summary</h2>
            <div class="summary">
                <div class="summary-item summary-pass">
                    <div class="summary-count">$pass_count</div>
                    <div>Passed</div>
                </div>
                <div class="summary-item summary-fail">
                    <div class="summary-count">$fail_count</div>
                    <div>Failed</div>
                </div>
                <div class="summary-item summary-warn">
                    <div class="summary-count">$warn_count</div>
                    <div>Warnings</div>
                </div>
            </div>
            <div class="verdict $verdict_class">$verdict_text</div>
        </div>
        
        <p style="text-align: center; color: var(--text-muted); margin-top: 2rem;">
            Generated: ${REPORT_DATA[timestamp]:-} | VPS Server Checker v1.0
        </p>
    </div>
</body>
</html>
EOF
    
    echo "HTML report saved to: $output_file"
}
