#!/bin/bash
# =============================================================================
# dpi.sh - DPI (Deep Packet Inspection) detection utilities
# =============================================================================

# Test TCP connection behavior (TCP 16-20 blocking detection)
# This test checks if connections are being throttled after 16-20 KB
test_tcp_throttling() {
    local host="${1:-speed.cloudflare.com}"
    local port="${2:-443}"
    local timeout="${3:-10}"
    
    # Download small chunks and measure timing
    local test_url="https://${host}/__down?bytes=65536"  # 64KB
    
    local start_time=$(date +%s%N)
    local bytes
    bytes=$(curl -s -o /dev/null -w "%{size_download}" --max-time "$timeout" "$test_url" 2>/dev/null)
    local end_time=$(date +%s%N)
    
    if [[ "$bytes" -lt 16384 ]]; then
        # Less than 16KB downloaded - possible blocking
        echo "blocked|${bytes}"
        return 0
    elif [[ "$bytes" -lt 65536 ]]; then
        # Partial download - possible throttling
        echo "throttled|${bytes}"
        return 1
    else
        echo "ok|${bytes}"
        return 2
    fi
}

# Test TLS SNI filtering
test_sni_filtering() {
    local blocked_domain="${1:-www.youtube.com}"
    local clean_domain="${2:-www.google.com}"
    local timeout="${3:-5}"
    
    local blocked_result
    local clean_result
    
    if command -v openssl &>/dev/null; then
        # Test connection with potentially blocked SNI
        blocked_result=$(echo | timeout "$timeout" openssl s_client -connect "${blocked_domain}:443" -servername "$blocked_domain" 2>&1)
        local blocked_status=$?
        
        # Test connection with clean SNI
        clean_result=$(echo | timeout "$timeout" openssl s_client -connect "${clean_domain}:443" -servername "$clean_domain" 2>&1)
        local clean_status=$?
        
        if [[ $clean_status -eq 0 && $blocked_status -ne 0 ]]; then
            echo "sni_filtered"
            return 0
        elif [[ $blocked_status -eq 0 ]]; then
            echo "ok"
            return 1
        else
            echo "both_failed"
            return 2
        fi
    else
        echo "no_openssl"
        return 3
    fi
}

# Test HTTP Host header filtering
test_http_host_filtering() {
    local ip="$1"
    local blocked_host="${2:-youtube.com}"
    local timeout="${3:-5}"
    
    if [[ -z "$ip" ]]; then
        echo "no_ip"
        return 1
    fi
    
    # Make HTTP request with specific Host header
    local result
    result=$(curl -s --max-time "$timeout" \
        -H "Host: ${blocked_host}" \
        "http://${ip}/" 2>/dev/null)
    local status=$?
    
    if [[ $status -ne 0 || -z "$result" ]]; then
        echo "filtered"
        return 0
    else
        echo "ok"
        return 1
    fi
}

# Test QUIC/UDP connectivity
test_quic_connectivity() {
    local host="${1:-quic.nginx.org}"
    local port="${2:-443}"
    local timeout="${3:-5}"
    
    # Simple UDP connectivity test
    if command -v nc &>/dev/null; then
        if echo -n "" | nc -u -w "$timeout" "$host" "$port" &>/dev/null; then
            echo "ok"
            return 0
        fi
    fi
    
    # Try HTTP/3 test with curl if supported
    local curl_version
    curl_version=$(curl --version 2>/dev/null | head -1)
    
    if echo "$curl_version" | grep -qi "http3\|quic"; then
        local result
        result=$(curl -s --max-time "$timeout" --http3 "https://${host}/" 2>&1)
        if [[ $? -eq 0 ]]; then
            echo "ok"
            return 0
        fi
    fi
    
    echo "blocked_or_unsupported"
    return 1
}

# Test common blocked services
test_blocked_services() {
    local timeout="${1:-5}"
    
    declare -A services=(
        ["google"]="https://www.google.com"
        ["youtube"]="https://www.youtube.com"
        ["telegram"]="https://telegram.org"
        ["twitter"]="https://twitter.com"
        ["facebook"]="https://www.facebook.com"
        ["instagram"]="https://www.instagram.com"
        ["tiktok"]="https://www.tiktok.com"
        ["discord"]="https://discord.com"
        ["linkedin"]="https://www.linkedin.com"
        ["whatsapp"]="https://web.whatsapp.com"
    )
    
    local results=""
    
    for name in "${!services[@]}"; do
        local url="${services[$name]}"
        local code
        code=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$timeout" "$url" 2>/dev/null)
        
        if [[ "$code" =~ ^[23] ]]; then
            results+="${name}:ok|"
        elif [[ "$code" == "000" ]]; then
            results+="${name}:timeout|"
        else
            results+="${name}:error:${code}|"
        fi
    done
    
    echo "${results%|}"
}

# Test DNS over different servers
test_dns_servers() {
    local test_domain="${1:-google.com}"
    local timeout="${2:-3}"
    
    declare -A dns_servers=(
        ["google_1"]="8.8.8.8"
        ["google_2"]="8.8.4.4"
        ["cloudflare_1"]="1.1.1.1"
        ["cloudflare_2"]="1.0.0.1"
        ["quad9"]="9.9.9.9"
        ["yandex"]="77.88.8.8"
        ["adguard"]="94.140.14.14"
    )
    
    local results=""
    
    for name in "${!dns_servers[@]}"; do
        local server="${dns_servers[$name]}"
        local resolved=""
        
        if command -v dig &>/dev/null; then
            resolved=$(dig +short +time="$timeout" "@${server}" "$test_domain" A 2>/dev/null | grep -E '^[0-9.]+$' | head -1)
        elif command -v nslookup &>/dev/null; then
            resolved=$(timeout "$timeout" nslookup "$test_domain" "$server" 2>/dev/null | awk '/^Address: / {print $2}' | tail -1)
        fi
        
        if [[ -n "$resolved" ]]; then
            results+="${name}:ok|"
        else
            results+="${name}:fail|"
        fi
    done
    
    echo "${results%|}"
}

# Full DPI detection suite
run_dpi_tests() {
    local timeout="${1:-10}"
    
    local results=()
    
    # TCP throttling test
    local tcp_result
    tcp_result=$(test_tcp_throttling "speed.cloudflare.com" 443 "$timeout")
    results+=("tcp_throttling:${tcp_result}")
    
    # SNI filtering test
    local sni_result
    sni_result=$(test_sni_filtering "www.youtube.com" "www.google.com" "$timeout")
    results+=("sni_filtering:${sni_result}")
    
    # QUIC test
    local quic_result
    quic_result=$(test_quic_connectivity "quic.nginx.org" 443 "$timeout")
    results+=("quic:${quic_result}")
    
    # DNS servers test
    local dns_result
    dns_result=$(test_dns_servers "google.com" 3)
    results+=("dns_servers:${dns_result}")
    
    printf '%s\n' "${results[@]}"
}
