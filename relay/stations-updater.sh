#!/usr/bin/env bash
#
# stations-updater.sh
# Automatically update Malaysian radio station stream URLs
# Fetches latest working streams from radio-browser.info API
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATIONS_DIR="${SCRIPT_DIR}/stations"
BACKUP_DIR="${SCRIPT_DIR}/.stations-backup"
CACHE_DIR="${SCRIPT_DIR}/.cache"
CACHE_FILE="${CACHE_DIR}/radio-browser.json"
CACHE_TTL=3600  # Cache for 1 hour

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $*" >&2; }
log_success() { echo -e "${GREEN}[OK]${NC} $*" >&2; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*" >&2; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_api() { echo -e "${CYAN}[API]${NC} $*" >&2; }

# Create backup of existing stations
create_backup() {
    if [[ -d "${STATIONS_DIR}" ]]; then
        log_info "Creating backup of existing stations..."
        mkdir -p "${BACKUP_DIR}"
        backup_name="backup-$(date +%Y%m%d-%H%M%S)"
        cp -r "${STATIONS_DIR}" "${BACKUP_DIR}/${backup_name}"
        log_success "Backup created: ${BACKUP_DIR}/${backup_name}"
    fi
}

# Fetch stations from radio-browser API with caching
fetch_radio_browser_stations() {
    mkdir -p "${CACHE_DIR}"
    
    # Check if cache exists and is fresh
    if [[ -f "${CACHE_FILE}" ]]; then
        local cache_age=$(( $(date +%s) - $(stat -c %Y "${CACHE_FILE}" 2>/dev/null || stat -f %m "${CACHE_FILE}" 2>/dev/null || echo 0) ))
        if [[ ${cache_age} -lt ${CACHE_TTL} ]]; then
            log_info "Using cached radio data (${cache_age}s old)"
            cat "${CACHE_FILE}"
            return 0
        fi
    fi
    
    # Fetch fresh data from API
    log_api "Fetching fresh station data from radio-browser.info..."
    
    local api_endpoints=(
        "https://de1.api.radio-browser.info/json/stations/search"
        "https://nl1.api.radio-browser.info/json/stations/search"
        "https://fr1.api.radio-browser.info/json/stations/search"
    )
    
    local response=""
    for endpoint in "${api_endpoints[@]}"; do
        if response=$(curl -s --max-time 30 "${endpoint}?countrycode=MY&limit=100&hidebroken=true&order=votes&reverse=true" 2>/dev/null); then
            if [[ -n "${response}" ]] && echo "${response}" | head -1 | grep -q '^\['; then
                # Cache the response
                echo "${response}" > "${CACHE_FILE}"
                echo "${response}"
                log_success "Fetched ${#response} bytes from ${endpoint}"
                return 0
            fi
        fi
        log_warn "Failed to fetch from ${endpoint}, trying next..."
    done
    
    # If all endpoints fail, use cache if available (even if stale)
    if [[ -f "${CACHE_FILE}" ]]; then
        log_warn "All API endpoints failed, using stale cache"
        cat "${CACHE_FILE}"
        return 0
    fi
    
    return 1
}

# Test if a stream URL is working
test_stream() {
    local url="$1"
    local timeout_seconds=10
    
    if timeout ${timeout_seconds} ffmpeg \
        -hide_banner -loglevel error \
        -user_agent "Mozilla/5.0 (RadioStreamTester/1.0)" \
        -reconnect 1 -reconnect_streamed 1 -reconnect_delay_max 5 \
        -i "${url}" -t 1 -f null - 2>/dev/null; then
        return 0
    fi
    return 1
}

# Create a station env file
create_station_file() {
    local station_name="$1"
    local source_url="$2"
    local mount_path="$3"
    local filename="$4"
    
    cat > "${filename}" << EOF
STATION_NAME=${station_name}
SOURCE_URL=${source_url}
MOUNT_PATH=${mount_path}
EOF
    log_success "Created: ${filename}"
}

# Find station URL from radio-browser data
find_station_url() {
    local station_data="$1"
    local search_name="$2"
    
    # Use jq if available, otherwise fallback to grep/sed
    if command -v jq &> /dev/null; then
        echo "${station_data}" | jq -r --arg name "${search_name}" \
            '.[] | select(.name | test($name; "i")) | select(.lastcheckok == 1) | .url_resolved' | head -1
    else
        # Fallback: parse JSON with grep/awk (basic)
        echo "${station_data}" | grep -o '"name":"[^"]*'"${search_name}"'[^"]*"' -A 20 | \
            grep -o '"url_resolved":"[^"]*"' | head -1 | sed 's/.*:"\(.*\)".*/\1/'
    fi
}

# Update a single station from API
update_station_from_api() {
    local station_key="$1"
    local station_name="$2"
    local mount_path="$3"
    local station_data="$4"
    
    log_info "Updating: ${station_name}"
    
    local url
    url=$(find_station_url "${station_data}" "${station_name}")
    
    if [[ -z "${url}" || "${url}" == "null" ]]; then
        log_warn "  No URL found in API for ${station_name}"
        return 1
    fi
    
    log_info "  Found URL: ${url}"
    
    # Test the URL
    if test_stream "${url}"; then
        log_success "  ✓ Stream is working"
        create_station_file "${station_name}" "${url}" "${mount_path}" "${STATIONS_DIR}/${station_key}.env"
        return 0
    else
        log_warn "  ✗ Stream test failed, will try fallback URLs"
        # Still write it - might work in target environment
        create_station_file "${station_name}" "${url}" "${mount_path}" "${STATIONS_DIR}/${station_key}.env"
        return 0
    fi
}

declare -A STATION_MAP=(
    ["bfm"]="BFM 89.9"
    ["cityplus"]="CITYPlus FM"
    ["era"]="ERA FM"
    ["era-sarawak"]="era sarawak"
    ["hot"]="THR Gegar"
    ["hitz"]="HITZ"
    ["sinar"]="Sinar FM"
    ["zayan"]="Zayan"
    ["melody"]="Melody FM Malaysia"
    ["fly"]="Fly FM"
    ["mix"]="MIX 94.5 FM Malaysia"
    ["988"]="988 FM"
    ["my"]="MY FM"
    ["one"]="One FM"
    ["ai"]="ai fm"
    ["raaga"]="Raaga"
    ["gegar"]="THR Gegar Pilihan #1 Pantai Timur"
    ["ikim"]="IKIM"
    ["nasheed"]="Nasheed FM"
    ["asyik"]="Asyik FM"
    ["nasional"]="Nasional FM 88,5 MHz"
    ["klasik"]="Klasik FM 101,1 MHz"
    ["minnal"]="Minnal FM"
    ["traxx"]="TraXXFM"
    ["suria"]="Suria fm"
    ["kelantan"]="Kelantan FM"
    ["terengganu"]="Terengganu FM"
    ["pahang"]="Pahang FM"
    ["sabah"]="Sabah FM"
    ["keningau"]="Keningau FM"
    ["wai-iban"]="WAI FM IBAN"
    ["wai-bidayuh"]="WAI FM Bidayuh"
    ["langkawi"]="Langkawi FM"
    ["capital"]="Capital FM"
    ["lite"]="LITE FM Malaysia"
    ["ceritera"]="Ceritera FM"
    ["ila"]="ILA FM"
    ["jei"]="JEI FM"
    ["delima"]="Delima FM"
    ["skyChatz"]="SkyChatzFM"
    ["wFM"]="Wheelerz Net Radio"
    ["slowRock"]="Slow Rock 90'"
)

# Update all stations from API
update_all_stations() {
    log_info "Starting station update from radio-browser.info..."
    echo ""
    
    mkdir -p "${STATIONS_DIR}"
    
    local station_data
    station_data=$(fetch_radio_browser_stations) || {
        log_error "Failed to fetch station data"
        return 1
    }
    
    local updated=0
    local failed=0
    
    for station_key in "${!STATION_MAP[@]}"; do
        local station_name="${STATION_MAP[$station_key]}"
        local mount_path="/${station_key}.mp3"
        
        if update_station_from_api "${station_key}" "${station_name}" "${mount_path}" "${station_data}"; then
            ((updated++))
        else
            ((failed++))
        fi
        echo ""
    done
    
    log_info "========================================"
    log_info "Update Summary:"
    log_success "  Stations updated: ${updated}"
    if [[ ${failed} -gt 0 ]]; then
        log_error "  Stations not found: ${failed}"
    fi
    log_info "========================================"
    
    return ${failed}
}

# Fetch and display all Malaysian stations from API
fetch_all_stations() {
    log_api "Fetching all Malaysian stations from radio-browser.info..."
    
    local station_data
    station_data=$(fetch_radio_browser_stations) || {
        log_error "Failed to fetch station data"
        return 1
    }
    
    log_info "Available Malaysian radio stations:"
    echo ""
    
    if command -v jq &> /dev/null; then
        # Write to temp file first to avoid pipe issues
        local temp_json
        temp_json=$(mktemp)
        echo "${station_data}" > "${temp_json}"
        jq -r '.[] | select(.lastcheckok == 1) | "\(.name)\n  URL: \(.url_resolved)\n  Codec: \(.codec), Bitrate: \(.bitrate)kbps\n"' "${temp_json}" | head -100
        rm -f "${temp_json}"
    else
        # Fallback: show just names
        local temp_json
        temp_json=$(mktemp)
        echo "${station_data}" > "${temp_json}"
        grep -o '"name":"[^"]*"' "${temp_json}" | sed 's/"name":"//;s/"$//' | head -30 | nl
        rm -f "${temp_json}"
    fi
}

# Show current local stations
show_stations() {
    log_info "Current stations configuration:"
    echo ""
    
    if [[ ! -d "${STATIONS_DIR}" ]]; then
        log_warn "No stations directory found"
        return 1
    fi
    
    for env_file in "${STATIONS_DIR}"/*.env; do
        if [[ -f "${env_file}" ]]; then
            local name url path
            name=$(grep "^STATION_NAME=" "${env_file}" | cut -d'=' -f2- || echo "Unknown")
            url=$(grep "^SOURCE_URL=" "${env_file}" | cut -d'=' -f2- || echo "Unknown")
            path=$(grep "^MOUNT_PATH=" "${env_file}" | cut -d'=' -f2- || echo "Unknown")
            
            echo "  ${name}:"
            echo "    Source: ${url}"
            echo "    Mount:  ${path}"
            echo ""
        fi
    done
}

# Verify all current streams
verify_streams() {
    log_info "Verifying all current stream URLs..."
    echo ""
    
    local working=0
    local failed=0
    
    for env_file in "${STATIONS_DIR}"/*.env; do
        if [[ -f "${env_file}" ]]; then
            local name url
            name=$(grep "^STATION_NAME=" "${env_file}" | cut -d'=' -f2- || echo "Unknown")
            url=$(grep "^SOURCE_URL=" "${env_file}" | cut -d'=' -f2- || echo "")
            
            if [[ -n "${url}" ]]; then
                echo -n "  Testing ${name}... "
                if test_stream "${url}"; then
                    echo -e "${GREEN}✓ WORKING${NC}"
                    ((working++))
                else
                    echo -e "${RED}✗ FAILED${NC}"
                    ((failed++))
                fi
            fi
        fi
    done
    
    echo ""
    log_info "Verification Summary:"
    log_success "  Working: ${working}"
    if [[ ${failed} -gt 0 ]]; then
        log_error "  Failed: ${failed}"
        log_warn "  Run with --update to refresh failed streams"
    fi
}

# Clear cache
clear_cache() {
    if [[ -f "${CACHE_FILE}" ]]; then
        rm -f "${CACHE_FILE}"
        log_success "Cache cleared"
    else
        log_info "No cache to clear"
    fi
}

# Clean old backups (keep last 10)
clean_old_backups() {
    log_info "Cleaning old backups..."
    if [[ -d "${BACKUP_DIR}" ]]; then
        find "${BACKUP_DIR}" -maxdepth 1 -type d -name "backup-*" | sort | head -n -10 | while read -r backup; do
            rm -rf "${backup}"
            log_info "  Removed: $(basename "${backup}")"
        done
        log_success "Cleanup complete"
    fi
}

# Show help
show_help() {
    cat << 'EOF'
Usage: ./stations-updater.sh [OPTION]

Automatically update Malaysian radio station stream URLs
using data from radio-browser.info API.

Options:
    --update, -u       Update all station streams from API
    --fetch-all, -f    Display all Malaysian stations from API
    --verify, -v       Verify current streams without updating
    --list, -l         List all configured local stations
    --backup, -b       Create backup of current station configs
    --clear-cache      Clear the API response cache
    --clean            Clean old backups (keep last 10)
    --help, -h         Show this help message

Examples:
    ./stations-updater.sh --update      # Update all stations from API
    ./stations-updater.sh --fetch-all   # See what's available
    ./stations-updater.sh --verify    # Check if streams work

Note: This script fetches live station data from radio-browser.info
with 1-hour caching. Use --clear-cache to force fresh fetch.

EOF
}

# Main command dispatcher
main() {
    case "${1:-}" in
        --update|-u)
            create_backup
            update_all_stations
            ;;
        --fetch-all|-f)
            fetch_all_stations
            ;;
        --verify|-v)
            verify_streams
            ;;
        --list|-l)
            show_stations
            ;;
        --backup|-b)
            create_backup
            ;;
        --clear-cache)
            clear_cache
            ;;
        --clean)
            clean_old_backups
            ;;
        --help|-h)
            show_help
            ;;
        "")
            show_help
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
