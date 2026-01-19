#!/bin/bash
# =============================================================================
# network.sh - Network testing utilities
# =============================================================================

# Get public IP address
get_public_ip() {
    local ip=""
    local services=(
        "https://ipv4.icanhazip.com"
        "https://api.ipify.org"
        "https://ifconfig.me/ip"
        "https://ipinfo.io/ip"
    )
    
    for service in "${services[@]}"; do
        ip=$(curl -s --max-time 5 "$service" 2>/dev/null | tr -d '[:space:]')
        if [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo "$ip"
            return 0
        fi
    done
    
    echo ""
    return 1
}

# Get IP geolocation info
get_ip_info() {
    local ip="$1"
    local json
    
    json=$(curl -s --max-time 10 "https://ipinfo.io/${ip}/json" 2>/dev/null)
    
    if [[ -n "$json" ]]; then
        echo "$json"
        return 0
    fi
    
    return 1
}

# Get reverse DNS (PTR record)
get_ptr_record() {
    local ip="$1"
    local ptr
    
    # Try dig first
    if command -v dig &>/dev/null; then
        ptr=$(dig +short -x "$ip" 2>/dev/null | head -1 | sed 's/\.$//')
    # Fall back to host
    elif command -v host &>/dev/null; then
        ptr=$(host "$ip" 2>/dev/null | awk '/domain name pointer/ {print $NF}' | sed 's/\.$//')
    # Fall back to nslookup
    elif command -v nslookup &>/dev/null; then
        ptr=$(nslookup "$ip" 2>/dev/null | awk '/name =/ {print $NF}' | sed 's/\.$//')
    fi
    
    echo "${ptr:-N/A}"
}

# Ping test
ping_test() {
    local host="$1"
    local count="${2:-3}"
    local timeout="${3:-5}"
    
    if command -v ping &>/dev/null; then
        local result
        result=$(ping -c "$count" -W "$timeout" "$host" 2>/dev/null)
        
        if [[ $? -eq 0 ]]; then
            local avg=$(echo "$result" | tail -1 | awk -F'/' '{print $5}')
            local loss=$(echo "$result" | grep -oP '\d+(?=% packet loss)')
            echo "ok|${avg:-0}|${loss:-0}"
            return 0
        fi
    fi
    
    echo "fail|0|100"
    return 1
}

# Check if port is open
check_port() {
    local host="$1"
    local port="$2"
    local timeout="${3:-3}"
    
    # Try nc (netcat) first
    if command -v nc &>/dev/null; then
        if nc -z -w "$timeout" "$host" "$port" 2>/dev/null; then
            return 0
        fi
    # Try timeout + bash
    elif command -v timeout &>/dev/null; then
        if timeout "$timeout" bash -c "echo >/dev/tcp/$host/$port" 2>/dev/null; then
            return 0
        fi
    # Try curl 
    else
        if curl -s --max-time "$timeout" --connect-timeout "$timeout" "http://${host}:${port}" &>/dev/null; then
            return 0
        fi
    fi
    
    return 1
}

# DNS resolution test
dns_resolve() {
    local domain="$1"
    local dns_server="${2:-}"
    local result
    
    if command -v dig &>/dev/null; then
        if [[ -n "$dns_server" ]]; then
            result=$(dig +short "@$dns_server" "$domain" A 2>/dev/null | grep -E '^[0-9.]+$' | head -1)
        else
            result=$(dig +short "$domain" A 2>/dev/null | grep -E '^[0-9.]+$' | head -1)
        fi
    elif command -v nslookup &>/dev/null; then
        if [[ -n "$dns_server" ]]; then
            result=$(nslookup "$domain" "$dns_server" 2>/dev/null | awk '/^Address: / {print $2}' | tail -1)
        else
            result=$(nslookup "$domain" 2>/dev/null | awk '/^Address: / {print $2}' | tail -1)
        fi
    elif command -v host &>/dev/null; then
        result=$(host "$domain" ${dns_server:+$dns_server} 2>/dev/null | awk '/has address/ {print $4}' | head -1)
    fi
    
    echo "${result:-}"
}

# HTTP connectivity test  
http_test() {
    local url="$1"
    local timeout="${2:-10}"
    local code
    
    code=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$timeout" "$url" 2>/dev/null)
    
    if [[ "$code" =~ ^[23] ]]; then
        echo "ok|$code"
        return 0
    elif [[ "$code" == "000" ]]; then
        echo "timeout|$code"
        return 1
    else
        echo "error|$code"
        return 1
    fi
}

# MTR trace (if available)
run_mtr() {
    local host="$1"
    local count="${2:-3}"
    
    if command -v mtr &>/dev/null; then
        mtr -r -c "$count" --no-dns "$host" 2>/dev/null
        return $?
    fi
    
    return 1
}

# Simple traceroute
run_traceroute() {
    local host="$1"
    local hops="${2:-15}"
    
    if command -v traceroute &>/dev/null; then
        traceroute -m "$hops" -n "$host" 2>/dev/null
        return $?
    elif command -v tracepath &>/dev/null; then
        tracepath -n "$host" 2>/dev/null | head -n "$hops"
        return $?
    fi
    
    return 1
}

# Speedtest (simplified)
run_speedtest() {
    local test_file="${1:-https://speed.cloudflare.com/__down?bytes=10000000}"
    local timeout="${2:-30}"
    
    if command -v curl &>/dev/null; then
        local start_time=$(date +%s.%N)
        local bytes=$(curl -s -o /dev/null -w "%{size_download}" --max-time "$timeout" "$test_file" 2>/dev/null)
        local end_time=$(date +%s.%N)
        
        if [[ "$bytes" -gt 0 ]]; then
            local duration=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "1")
            local speed=$(echo "scale=2; $bytes / $duration / 1024 / 1024" | bc 2>/dev/null || echo "0")
            echo "${speed:-0}"
            return 0
        fi
    fi
    
    echo "0"
    return 1
}
