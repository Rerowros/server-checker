#!/bin/bash
# =============================================================================
# blocklist.sh - Blocklist checking utilities
# =============================================================================

# DNSBL servers to check
DNSBL_SERVERS=(
    "zen.spamhaus.org"
    "bl.spamcop.net"
    "b.barracudacentral.org"
    "dnsbl.sorbs.net"
    "spam.dnsbl.sorbs.net"
)

# Check if IP is in a DNSBL
check_dnsbl() {
    local ip="$1"
    local dnsbl="$2"
    
    # Reverse IP octets
    local reversed=$(echo "$ip" | awk -F. '{print $4"."$3"."$2"."$1}')
    local query="${reversed}.${dnsbl}"
    
    local result
    if command -v dig &>/dev/null; then
        result=$(dig +short "$query" A 2>/dev/null)
    elif command -v host &>/dev/null; then
        result=$(host "$query" 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')
    elif command -v nslookup &>/dev/null; then
        result=$(nslookup "$query" 2>/dev/null | grep -oE 'Address: [0-9.]+' | tail -1)
    fi
    
    if [[ -n "$result" && "$result" =~ ^127\. ]]; then
        return 0  # Listed
    fi
    
    return 1  # Not listed
}

# Check all DNSBLs
check_all_dnsbl() {
    local ip="$1"
    local listed=()
    local clean=()
    
    for dnsbl in "${DNSBL_SERVERS[@]}"; do
        if check_dnsbl "$ip" "$dnsbl"; then
            listed+=("$dnsbl")
        else
            clean+=("$dnsbl")
        fi
    done
    
    echo "listed:${#listed[@]}|clean:${#clean[@]}|names:${listed[*]}"
}

# Check RKN blocklist (Russia)
# Uses runetfreedom/russia-blocked-geoip data
check_rkn_blocklist() {
    local ip="$1"
    local timeout="${2:-10}"
    
    # Download and check against RKN list
    local rkn_list_url="https://raw.githubusercontent.com/runetfreedom/russia-blocked-geoip/main/lists/russia-blocked-geoip.txt"
    
    local ip_list
    ip_list=$(curl -s --max-time "$timeout" "$rkn_list_url" 2>/dev/null)
    
    if [[ -z "$ip_list" ]]; then
        echo "error"
        return 2
    fi
    
    # Check if IP is in the list (exact match or CIDR)
    if echo "$ip_list" | grep -q "^${ip}$"; then
        echo "blocked"
        return 0
    fi
    
    # Check CIDR ranges (requires more complex logic)
    if command -v ipcalc &>/dev/null; then
        while IFS= read -r cidr; do
            [[ -z "$cidr" || "$cidr" =~ ^# ]] && continue
            if [[ "$cidr" =~ / ]]; then
                if ipcalc -c "$ip" "$cidr" 2>/dev/null | grep -q "NETWORK"; then
                    echo "blocked"
                    return 0
                fi
            fi
        done <<< "$ip_list"
    fi
    
    echo "clean"
    return 1
}

# Check against Roskomnadzor API (unofficial)
check_rkn_api() {
    local ip="$1"
    local timeout="${2:-10}"
    
    # Try using isitblockedinrussia.com API
    local result
    result=$(curl -s --max-time "$timeout" "https://isitblockedinrussia.com/api.php?q=${ip}" 2>/dev/null)
    
    if [[ -n "$result" ]]; then
        if echo "$result" | grep -qi "blocked\|true"; then
            echo "blocked"
            return 0
        elif echo "$result" | grep -qi "not blocked\|false"; then
            echo "clean"
            return 1
        fi
    fi
    
    echo "unknown"
    return 2
}

# Check multiple blocklists
check_all_blocklists() {
    local ip="$1"
    local results=""
    
    # Check DNSBL
    local dnsbl_result
    dnsbl_result=$(check_all_dnsbl "$ip")
    results+="dnsbl:${dnsbl_result}|"
    
    # Check RKN
    local rkn_result
    rkn_result=$(check_rkn_blocklist "$ip")
    results+="rkn:${rkn_result}"
    
    echo "$results"
}

# Get ASN info for IP
get_asn_info() {
    local ip="$1"
    local timeout="${2:-5}"
    
    local result
    result=$(curl -s --max-time "$timeout" "https://ipinfo.io/${ip}/json" 2>/dev/null)
    
    if [[ -n "$result" ]]; then
        local org=$(echo "$result" | grep -oP '"org":\s*"\K[^"]+' 2>/dev/null)
        echo "${org:-N/A}"
    else
        echo "N/A"
    fi
}

# Check if ASN is commonly blocked
check_asn_reputation() {
    local asn="$1"
    
    # Known problematic ASNs for Russia connectivity
    local problematic_asns=(
        "AS13335"   # Cloudflare (partially blocked)
        "AS15169"   # Google
        "AS32934"   # Facebook
        "AS14618"   # Amazon
    )
    
    for prob_asn in "${problematic_asns[@]}"; do
        if [[ "$asn" == *"$prob_asn"* ]]; then
            echo "warning"
            return 1
        fi
    done
    
    echo "ok"
    return 0
}
