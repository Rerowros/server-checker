#!/bin/bash
# =============================================================================
# colors.sh - Terminal color utilities
# =============================================================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m' # No Color

# Status indicators
PASS="[${GREEN}✓${NC}]"
FAIL="[${RED}✗${NC}]"
WARN="[${YELLOW}!${NC}]"
INFO="[${BLUE}i${NC}]"
SKIP="[${DIM}-${NC}]"

# Print functions
print_header() {
    echo -e "\n${BOLD}${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${CYAN}  $1${NC}"
    echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════${NC}\n"
}

print_section() {
    echo -e "\n${BOLD}${BLUE}▸ $1${NC}"
    echo -e "${DIM}───────────────────────────────────────────────────────────────${NC}"
}

print_pass() {
    echo -e "${PASS} $1"
}

print_fail() {
    echo -e "${FAIL} $1"
}

print_warn() {
    echo -e "${WARN} $1"
}

print_info() {
    echo -e "${INFO} $1"
}

print_skip() {
    echo -e "${SKIP} $1"
}

print_kv() {
    local key="$1"
    local value="$2"
    printf "  ${DIM}%-20s${NC} %s\n" "$key:" "$value"
}

print_result() {
    local test_name="$1"
    local status="$2"  # pass, fail, warn, skip
    local details="$3"
    
    case "$status" in
        pass) echo -e "${PASS} ${test_name} ${DIM}${details}${NC}" ;;
        fail) echo -e "${FAIL} ${test_name} ${DIM}${details}${NC}" ;;
        warn) echo -e "${WARN} ${test_name} ${DIM}${details}${NC}" ;;
        skip) echo -e "${SKIP} ${test_name} ${DIM}${details}${NC}" ;;
    esac
}

# Progress spinner
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    while kill -0 "$pid" 2>/dev/null; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "      \b\b\b\b\b\b"
}
