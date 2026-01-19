#!/bin/bash
# =============================================================================
#  ____                              _____ _               _
# / ___|  ___ _ ____   _____ _ __   |_   _| |__   ___  ___| | _____ _ __
# \___ \ / _ \ '__\ \ / / _ \ '__|    | | | '_ \ / _ \/ __| |/ / _ \ '__|
#  ___) |  __/ |   \ V /  __/ |       | | | | | |  __/ (__|   <  __/ |
# |____/ \___|_|    \_/ \___|_|       |_| |_| |_|\___|\___|_|\_\___|_|
#
# VPS Server Checker - Comprehensive testing script
# https://github.com/your-repo/server-checker
# =============================================================================

# Note: Not using set -e due to issues with bash associative arrays and error handling

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION="1.0.0"

# Default options
TIMEOUT=10
NO_SPEEDTEST=false
NO_DPI=false
OUTPUT_FORMAT="console"
OUTPUT_FILE=""
VERBOSE=false

# Source library modules
source_libs() {
    local lib_dir="${SCRIPT_DIR}/lib"
    
    if [[ ! -d "$lib_dir" ]]; then
        echo "Error: lib directory not found at $lib_dir" >&2
        exit 1
    fi
    
    source "${lib_dir}/colors.sh"
    source "${lib_dir}/network.sh"
    source "${lib_dir}/blocklist.sh"
    source "${lib_dir}/dpi.sh"
    source "${lib_dir}/report.sh"
}

# Print usage
usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

VPS Server Checker - Comprehensive testing script for VPS servers.
Checks IP geolocation, blocklists, DPI detection, connectivity, and more.

Options:
  -h, --help            Show this help message
  -v, --version         Show version
  --verbose             Verbose output
  --timeout SEC         Set timeout for network tests (default: 10)
  --no-speedtest        Skip speed test
  --no-dpi              Skip DPI detection tests
  -o, --output FILE     Save report to file
  -f, --format FORMAT   Output format: console, json, html (default: console)

Examples:
  $(basename "$0")                           # Run all tests
  $(basename "$0") --no-speedtest            # Skip speed test
  $(basename "$0") -f html -o report.html    # Generate HTML report

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                usage
                exit 0
                ;;
            -v|--version)
                echo "VPS Server Checker v${VERSION}"
                exit 0
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --timeout)
                TIMEOUT="$2"
                shift 2
                ;;
            --no-speedtest)
                NO_SPEEDTEST=true
                shift
                ;;
            --no-dpi)
                NO_DPI=true
                shift
                ;;
            --install-deps)
                source_libs
                install_deps
                exit 0
                ;;
            -o|--output)
                OUTPUT_FILE="$2"
                shift 2
                ;;
            -f|--format)
                OUTPUT_FORMAT="$2"
                shift 2
                ;;
            *)
                echo "Unknown option: $1" >&2
                usage
                exit 1
                ;;
        esac
    done
}

# Check dependencies
check_deps() {
    local required=(curl)
    local optional=(dig nc openssl jq mtr traceroute bc ipcalc)
    local missing_required=()
    local missing_optional=()
    
    for cmd in "${required[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            missing_required+=("$cmd")
        fi
    done
    
    for cmd in "${optional[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            missing_optional+=("$cmd")
        fi
    done
    
    if [[ ${#missing_required[@]} -gt 0 ]]; then
        echo "Error: Missing required dependencies: ${missing_required[*]}" >&2
        echo "You can install them using: $0 --install-deps" >&2
        exit 1
    fi
    
    if [[ ${#missing_optional[@]} -gt 0 && "$VERBOSE" == "true" ]]; then
        print_warn "Optional dependencies missing: ${missing_optional[*]}"
        print_info "Some tests may be skipped or limited."
    fi
}

# Install dependencies
install_deps() {
    print_info "Checking for package manager..."
    if command -v apt-get &>/dev/null; then
        print_info "Updating package list..."
        sudo apt-get update -y
        print_info "Installing dependencies..."
        sudo apt-get install -y curl dnsutils netcat-openbsd openssl jq mtr bc ipcalc traceroute
        print_pass "Dependencies installed successfully."
    else
        print_fail "Automatic installation only supported on Debian/Ubuntu (apt)."
        print_info "Please install manually: curl dnsutils netcat-openbsd openssl jq mtr bc ipcalc"
        exit 1
    fi
}

# Get system info
get_system_info() {
    local os_info
    if [[ -f /etc/os-release ]]; then
        os_info=$(grep -E '^(NAME|VERSION)=' /etc/os-release | tr '\n' ' ' | sed 's/NAME=//;s/VERSION=//;s/"//g')
    else
        os_info=$(uname -s)
    fi
    
    local kernel
    kernel=$(uname -r 2>/dev/null || echo "N/A")
    
    local uptime_info
    if command -v uptime &>/dev/null; then
        uptime_info=$(uptime -p 2>/dev/null || uptime | awk -F'up' '{print $2}' | awk -F',' '{print $1}')
    else
        uptime_info="N/A"
    fi
    
    echo "${os_info}|${kernel}|${uptime_info}"
}

# Main server info collection
collect_server_info() {
    print_section "Collecting Server Information"
    
    # Get public IP
    print_info "Getting public IP address..."
    local public_ip
    public_ip=$(get_public_ip)
    
    if [[ -z "$public_ip" ]]; then
        print_fail "Could not determine public IP address"
        return 1
    fi
    
    print_pass "Public IP: ${public_ip}"
    add_report_data "public_ip" "$public_ip"
    
    # Get IP info (geolocation)
    print_info "Getting IP geolocation..."
    local ip_info
    ip_info=$(get_ip_info "$public_ip")
    
    if [[ -n "$ip_info" ]]; then
        local city=$(echo "$ip_info" | grep -oP '"city":\s*"\K[^"]+' 2>/dev/null || echo "")
        local region=$(echo "$ip_info" | grep -oP '"region":\s*"\K[^"]+' 2>/dev/null || echo "")
        local country=$(echo "$ip_info" | grep -oP '"country":\s*"\K[^"]+' 2>/dev/null || echo "")
        local org=$(echo "$ip_info" | grep -oP '"org":\s*"\K[^"]+' 2>/dev/null || echo "")
        
        local location="${city:+$city, }${region:+$region, }${country:-N/A}"
        print_pass "Location: $location"
        print_pass "Provider: ${org:-N/A}"
        
        add_report_data "location" "$location"
        add_report_data "provider" "$org"
        add_report_data "asn" "$org"
    fi
    
    # Get PTR record
    print_info "Checking PTR record..."
    local ptr
    ptr=$(get_ptr_record "$public_ip")
    print_pass "PTR: $ptr"
    add_report_data "ptr" "$ptr"
    
    # System info
    local sys_info
    sys_info=$(get_system_info)
    IFS='|' read -r os_info kernel uptime_info <<< "$sys_info"
    print_kv "OS" "$os_info"
    print_kv "Kernel" "$kernel"
    print_kv "Uptime" "$uptime_info"
}

# Run blocklist checks
run_blocklist_checks() {
    print_section "Blocklist Checks"
    
    local ip="${REPORT_DATA[public_ip]:-}"
    
    if [[ -z "$ip" ]]; then
        print_fail "No IP address available for blocklist check"
        add_test_result "Blocklists" "IP Check" "skip" "No IP available"
        return
    fi
    
    # DNSBL checks
    print_info "Checking DNS blocklists..."
    local dnsbl_count=0
    local dnsbl_listed=()
    
    for dnsbl in "${DNSBL_SERVERS[@]}"; do
        if check_dnsbl "$ip" "$dnsbl"; then
            dnsbl_listed+=("$dnsbl")
            ((dnsbl_count++))
        fi
    done
    
    if [[ $dnsbl_count -eq 0 ]]; then
        print_pass "DNSBL: Clean (not listed in ${#DNSBL_SERVERS[@]} blocklists)"
        add_test_result "Blocklists" "DNSBL Check" "pass" "Clean"
    else
        print_fail "DNSBL: Listed in $dnsbl_count blocklist(s): ${dnsbl_listed[*]}"
        add_test_result "Blocklists" "DNSBL Check" "fail" "Listed in: ${dnsbl_listed[*]}"
    fi
    
    # RKN check
    print_info "Checking RKN (Roskomnadzor) blocklist..."
    local rkn_result
    rkn_result=$(check_rkn_blocklist "$ip" "$TIMEOUT")
    
    case "$rkn_result" in
        blocked)
            print_fail "RKN: IP is in the blocklist!"
            add_test_result "Blocklists" "RKN Blocklist" "fail" "IP is blocked"
            ;;
        clean)
            print_pass "RKN: IP is not in the blocklist"
            add_test_result "Blocklists" "RKN Blocklist" "pass" "Not blocked"
            ;;
        *)
            print_warn "RKN: Could not verify (list unavailable)"
            add_test_result "Blocklists" "RKN Blocklist" "warn" "Could not verify"
            ;;
    esac
}

# Run network connectivity tests
run_network_tests() {
    print_section "Network Connectivity Tests"
    
    # Ping tests
    print_info "Running ping tests..."
    local ping_targets=("8.8.8.8" "1.1.1.1" "77.88.8.8")
    local ping_names=("Google DNS" "Cloudflare DNS" "Yandex DNS")
    
    for i in "${!ping_targets[@]}"; do
        local target="${ping_targets[$i]}"
        local name="${ping_names[$i]}"
        local result
        result=$(ping_test "$target" 3 5)
        
        IFS='|' read -r status latency loss <<< "$result"
        
        if [[ "$status" == "ok" ]]; then
            print_pass "$name ($target): ${latency}ms avg, ${loss}% loss"
            add_test_result "Connectivity" "Ping $name" "pass" "${latency}ms"
        else
            print_fail "$name ($target): unreachable"
            add_test_result "Connectivity" "Ping $name" "fail" "Unreachable"
        fi
    done
    
    # Port checks
    print_info "Checking outbound ports..."
    local ports=("80" "443" "22" "53")
    local port_hosts=("google.com" "google.com" "github.com" "8.8.8.8")
    
    for i in "${!ports[@]}"; do
        local port="${ports[$i]}"
        local host="${port_hosts[$i]}"
        
        if check_port "$host" "$port" 5; then
            print_pass "Port $port ($host): Open"
            add_test_result "Ports" "Port $port" "pass" "Open"
        else
            print_fail "Port $port ($host): Blocked/Closed"
            add_test_result "Ports" "Port $port" "fail" "Blocked"
        fi
    done
    
    # HTTP tests
    print_info "Testing HTTP connectivity..."
    local http_targets=("https://google.com" "https://yandex.ru" "https://cloudflare.com")
    
    for url in "${http_targets[@]}"; do
        local result
        result=$(http_test "$url" "$TIMEOUT")
        IFS='|' read -r status code <<< "$result"
        
        local domain
        domain=$(echo "$url" | sed 's|https://||;s|/.*||')
        
        if [[ "$status" == "ok" ]]; then
            print_pass "HTTP $domain: OK ($code)"
            add_test_result "HTTP" "$domain" "pass" "HTTP $code"
        else
            print_fail "HTTP $domain: Failed ($status)"
            add_test_result "HTTP" "$domain" "fail" "$status"
        fi
    done
    
    # Speed test
    if [[ "$NO_SPEEDTEST" == "false" ]]; then
        print_info "Running speed test..."
        local speed
        speed=$(run_speedtest)
        
        if [[ "${speed:-0}" != "0" ]]; then
            print_pass "Download speed: ${speed} MB/s"
            add_test_result "Speed" "Download" "pass" "${speed} MB/s"
        else
            print_warn "Speed test: Could not measure"
            add_test_result "Speed" "Download" "warn" "Could not measure"
        fi
    else
        print_skip "Speed test: Skipped (--no-speedtest)"
        add_test_result "Speed" "Download" "skip" "Skipped by user"
    fi
}

# Run DPI detection tests
run_dpi_tests_main() {
    if [[ "$NO_DPI" == "true" ]]; then
        print_section "DPI Detection Tests (Skipped)"
        print_skip "DPI tests skipped (--no-dpi)"
        add_test_result "DPI" "All Tests" "skip" "Skipped by user"
        return
    fi
    
    print_section "DPI Detection Tests"
    
    # TCP throttling test
    print_info "Testing TCP throttling (TCP 16-20 method)..."
    local tcp_result
    tcp_result=$(test_tcp_throttling "speed.cloudflare.com" 443 "$TIMEOUT")
    IFS='|' read -r status bytes <<< "$tcp_result"
    
    case "$status" in
        ok)
            print_pass "TCP throttling: Not detected (${bytes} bytes transferred)"
            add_test_result "DPI" "TCP Throttling" "pass" "Not detected"
            ;;
        throttled)
            print_warn "TCP throttling: Possible throttling detected (${bytes} bytes)"
            add_test_result "DPI" "TCP Throttling" "warn" "Possible throttling"
            ;;
        blocked)
            print_fail "TCP throttling: Blocking detected (${bytes} bytes)"
            add_test_result "DPI" "TCP Throttling" "fail" "Blocking detected"
            ;;
    esac
    
    # SNI filtering test
    print_info "Testing TLS SNI filtering..."
    local sni_result
    sni_result=$(test_sni_filtering "www.youtube.com" "www.google.com" "$TIMEOUT")
    
    case "$sni_result" in
        ok)
            print_pass "SNI filtering: Not detected"
            add_test_result "DPI" "SNI Filtering" "pass" "Not detected"
            ;;
        sni_filtered)
            print_fail "SNI filtering: Detected (youtube blocked, google works)"
            add_test_result "DPI" "SNI Filtering" "fail" "Filtering detected"
            ;;
        both_failed)
            print_warn "SNI filtering: Could not test (both connections failed)"
            add_test_result "DPI" "SNI Filtering" "warn" "Test inconclusive"
            ;;
        no_openssl)
            print_skip "SNI filtering: Skipped (openssl not available)"
            add_test_result "DPI" "SNI Filtering" "skip" "openssl not available"
            ;;
    esac
    
    # QUIC/UDP test
    print_info "Testing QUIC/UDP connectivity..."
    local quic_result
    quic_result=$(test_quic_connectivity "quic.nginx.org" 443 "$TIMEOUT")
    
    if [[ "$quic_result" == "ok" ]]; then
        print_pass "QUIC/UDP: Working"
        add_test_result "DPI" "QUIC/UDP" "pass" "Working"
    else
        print_warn "QUIC/UDP: Blocked or unsupported"
        add_test_result "DPI" "QUIC/UDP" "warn" "Blocked or unsupported"
    fi
    
    # DNS server accessibility
    print_info "Testing DNS server accessibility..."
    local dns_result
    dns_result=$(test_dns_servers "google.com" 3)
    
    local dns_ok=0
    local dns_fail=0
    IFS='|' read -ra dns_parts <<< "$dns_result"
    
    for part in "${dns_parts[@]}"; do
        IFS=':' read -r name status <<< "$part"
        if [[ "$status" == "ok" ]]; then
            ((dns_ok++))
        else
            ((dns_fail++))
        fi
    done
    
    if [[ $dns_fail -eq 0 ]]; then
        print_pass "DNS Servers: All ${dns_ok} tested servers accessible"
        add_test_result "DPI" "DNS Servers" "pass" "All accessible"
    elif [[ $dns_ok -gt 0 ]]; then
        print_warn "DNS Servers: ${dns_ok} accessible, ${dns_fail} blocked"
        add_test_result "DPI" "DNS Servers" "warn" "${dns_ok} ok, ${dns_fail} blocked"
    else
        print_fail "DNS Servers: All tested servers blocked"
        add_test_result "DPI" "DNS Servers" "fail" "All blocked"
    fi
}

# Test service accessibility
run_service_tests() {
    print_section "Service Accessibility"
    
    print_info "Testing popular service accessibility..."
    local services_result
    services_result=$(test_blocked_services "$TIMEOUT")
    
    IFS='|' read -ra service_parts <<< "$services_result"
    
    for part in "${service_parts[@]}"; do
        IFS=':' read -r name status extra <<< "$part"
        
        case "$status" in
            ok)
                print_pass "${name^}: Accessible"
                add_test_result "Services" "${name^}" "pass" "Accessible"
                ;;
            timeout)
                print_fail "${name^}: Timeout"
                add_test_result "Services" "${name^}" "fail" "Timeout"
                ;;
            error)
                print_fail "${name^}: Error (HTTP ${extra:-?})"
                add_test_result "Services" "${name^}" "fail" "HTTP ${extra:-error}"
                ;;
        esac
    done
}

# Main function
main() {
    parse_args "$@"
    source_libs
    check_deps
    
    # Initialize report
    init_report
    
    # Print header
    print_header "VPS Server Checker v${VERSION}"
    
    # Run all checks
    collect_server_info
    run_blocklist_checks
    run_network_tests
    run_dpi_tests_main
    run_service_tests
    
    # Generate report
    case "$OUTPUT_FORMAT" in
        json)
            if [[ -n "$OUTPUT_FILE" ]]; then
                generate_json_report "$OUTPUT_FILE"
            else
                generate_json_report "report.json"
            fi
            ;;
        html)
            if [[ -n "$OUTPUT_FILE" ]]; then
                generate_html_report "$OUTPUT_FILE"
            else
                generate_html_report "report.html"
            fi
            ;;
        console|*)
            generate_console_report
            if [[ -n "$OUTPUT_FILE" ]]; then
                generate_console_report > "$OUTPUT_FILE"
                echo "Report saved to: $OUTPUT_FILE"
            fi
            ;;
    esac
}

# Run main
main "$@"
