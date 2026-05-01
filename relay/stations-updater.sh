#!/usr/bin/env bash
#
# stations-updater.sh
# Automatically update Malaysian radio station stream URLs
# Fetches latest working streams from known sources
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATIONS_DIR="${SCRIPT_DIR}/stations"
BACKUP_DIR="${SCRIPT_DIR}/.stations-backup"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[OK]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

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

# Test if a stream URL is working
test_stream() {
    local url="$1"
    local timeout_seconds=10

    # Use ffmpeg to probe the stream with timeout
    if timeout ${timeout_seconds} ffmpeg \
        -hide_banner \
        -loglevel error \
        -user_agent "Mozilla/5.0 (compatible; RadioStreamTester/1.0)" \
        -reconnect 1 \
        -reconnect_streamed 1 \
        -reconnect_delay_max 5 \
        -i "${url}" \
        -t 1 \
        -f null - 2>/dev/null; then
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
}

# Update a single station
update_station() {
    local station_key="$1"
    local station_name="$2"
    local mount_path="$3"
    shift 3
    local urls=("$@")

    log_info "Updating: ${station_name}"

    local working_url=""
    for url in "${urls[@]}"; do
        if test_stream "${url}"; then
            working_url="${url}"
            log_success "  ✓ Working URL found: ${url}"
            break
        else
            log_warn "  ✗ URL failed: ${url}"
        fi
    done

    if [[ -n "${working_url}" ]]; then
        local filename="${STATIONS_DIR}/${station_key}.env"
        create_station_file "${station_name}" "${working_url}" "${mount_path}" "${filename}"
        log_success "  ✓ Station updated: ${filename}"
        return 0
    else
        log_error "  ✗ No working URL found for ${station_name}"
        return 1
    fi
}

# Define known Malaysian radio stations and their stream URLs
declare -A STATIONS
declare -A STATION_NAMES
declare -A STATION_PATHS

# BFM 89.9 - Business radio
STATION_NAMES["bfm"]="BFM 89.9"
STATION_PATHS["bfm"]="/bfm.mp3"
STATIONS["bfm"]=$(cat << 'EOF'
https://stream.rcs.revma.com/s91qy9p0zs3vv
https://playerservices.streamtheworld.com/api/livestream-redirect/BFMRADIOAAC.aac
EOF
)

# Sinar FM - Malay adult contemporary
STATION_NAMES["sinar"]="SINAR FM"
STATION_PATHS["sinar"]="/sinar.mp3"
STATIONS["sinar"]=$(cat << 'EOF'
https://n08.rcs.revma.com/azatk0tbv4uvv/playlist.m3u8
https://stream.rcs.revma.com/azatk0tbv4uvv
https://playerservices.streamtheworld.com/api/livestream-redirect/SINAR_FM.mp3
EOF
)

# IKIM FM - Islamic radio
STATION_NAMES["ikim"]="IKIM FM"
STATION_PATHS["ikim"]="/ikim.mp3"
STATIONS["ikim"]=$(cat << 'EOF'
https://ais-sa8.cdnstream1.com/5035
https://stream.rcs.revma.com/ikimfm
https://playerservices.streamtheworld.com/api/livestream-redirect/IKIM_FM.mp3
EOF
)

# Zayan FM - Malay contemporary Islamic
STATION_NAMES["zayan"]="ZAYAN FM"
STATION_PATHS["zayan"]="/zayan.mp3"
STATIONS["zayan"]=$(cat << 'EOF'
https://stream.rcs.revma.com/7ww2a4tbv4uvv/hls.m3u8
https://stream.rcs.revma.com/7ww2a4tbv4uvv
https://playerservices.streamtheworld.com/api/livestream-redirect/ZAYAN_FM.mp3
EOF
)

# Era FM - Malay hit music
STATION_NAMES["era"]="ERA FM"
STATION_PATHS["era"]="/era.mp3"
STATIONS["era"]=$(cat << 'EOF'
https://n03.rcs.revma.com/8kpx7r4tbv4uvv/playlist.m3u8
https://stream.rcs.revma.com/8kpx7r4tbv4uvv
https://playerservices.streamtheworld.com/api/livestream-redirect/ERA_FM.mp3
EOF
)

# Hot FM - Malay music
STATION_NAMES["hot"]="HOT FM"
STATION_PATHS["hot"]="/hot.mp3"
STATIONS["hot"]=$(cat << 'EOF'
https://stream.rcs.revma.com/d1x6v4tbv4uvv
https://n11.rcs.revma.com/d1x6v4tbv4uvv/playlist.m3u8
https://playerservices.streamtheworld.com/api/livestream-redirect/HOT_FM.mp3
EOF
)

# Hitz FM - English hit music
STATION_NAMES["hitz"]="HITZ FM"
STATION_PATHS["hitz"]="/hitz.mp3"
STATIONS["hitz"]=$(cat << 'EOF'
https://stream.rcs.revma.com/yk1m744tbv4uvv
https://n05.rcs.revma.com/yk1m744tbv4uvv/playlist.m3u8
https://playerservices.streamtheworld.com/api/livestream-redirect/HITZ_FM.mp3
EOF
)

# Mix FM - English adult contemporary
STATION_NAMES["mix"]="MIX FM"
STATION_PATHS["mix"]="/mix.mp3"
STATIONS["mix"]=$(cat << 'EOF'
https://stream.rcs.revma.com/tq45a4tbv4uvv
https://playerservices.streamtheworld.com/api/livestream-redirect/MIX_FM.mp3
EOF
)

# Fly FM - English/Chinese hits
STATION_NAMES["fly"]="FLY FM"
STATION_PATHS["fly"]="/fly.mp3"
STATIONS["fly"]=$(cat << 'EOF'
https://stream.rcs.revma.com/tays94tbv4uvv
https://playerservices.streamtheworld.com/api/livestream-redirect/FLY_FM.mp3
EOF
)

# Suria FM - Malay oldies
STATION_NAMES["suria"]="SURIA FM"
STATION_PATHS["suria"]="/suria.mp3"
STATIONS["suria"]=$(cat << 'EOF'
https://stream.rcs.revma.com/gsys54tbv4uvv
https://playerservices.streamtheworld.com/api/livestream-redirect/SURIA_FM.mp3
EOF
)

# One FM - Chinese music
STATION_NAMES["one"]="ONE FM"
STATION_PATHS["one"]="/one.mp3"
STATIONS["one"]=$(cat << 'EOF'
https://stream.rcs.revma.com/5fex74tbv4uvv
https://playerservices.streamtheworld.com/api/livestream-redirect/ONE_FM.mp3
EOF
)

# Capital FM - English talk/music
STATION_NAMES["capital"]="CAPITAL FM"
STATION_PATHS["capital"]="/capital.mp3"
STATIONS["capital"]=$(cat << 'EOF'
https://stream.rcs.revma.com/4bqk94tbv4uvv
https://playerservices.streamtheworld.com/api/livestream-redirect/CAPITAL_FM.mp3
EOF
)

# Update all stations
update_all_stations() {
    log_info "Starting station update process..."
    log_info "Testing streams and updating configuration files..."
    echo ""

    mkdir -p "${STATIONS_DIR}"

    local updated=0
    local failed=0

    for station_key in "${!STATION_NAMES[@]}"; do
        # Read URLs into array
        readarray -t urls <<< "${STATIONS[$station_key]}"

        if update_station "${station_key}" "${STATION_NAMES[$station_key]}" "${STATION_PATHS[$station_key]}" "${urls[@]}"; then
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
        log_error "  Stations failed: ${failed}"
    fi
    log_info "========================================"

    return ${failed}
}

# Show current stations
show_stations() {
    log_info "Current stations configuration:"
    echo ""

    if [[ ! -d "${STATIONS_DIR}" ]]; then
        log_warn "No stations directory found"
        return 1
    fi

    for env_file in "${STATIONS_DIR}"/*.env; do
        if [[ -f "${env_file}" ]]; then
            local name
            local url
            local path
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
            local name
            local url
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

# Clean old backups (keep last 10)
clean_old_backups() {
    log_info "Cleaning old backups..."
    if [[ -d "${BACKUP_DIR}" ]]; then
        # List backups sorted by name (which includes timestamp), skip the last 10, remove the rest
        find "${BACKUP_DIR}" -maxdepth 1 -type d -name "backup-*" | sort | head -n -10 | while read -r backup; do
            rm -rf "${backup}"
            log_info "  Removed old backup: $(basename "${backup}")"
        done
        log_success "Cleanup complete"
    fi
}

# Show help
show_help() {
    cat << 'EOF'
Usage: ./stations-updater.sh [OPTION]

Automatically update and manage Malaysian radio station stream URLs
for the Icecast relay system.

Options:
    --update, -u       Update all station streams (test and update URLs)
    --verify, -v       Verify current streams without updating
    --list, -l         List all configured stations
    --backup, -b       Create backup of current station configs
    --clean            Clean old backups (keep last 10)
    --help, -h         Show this help message

Examples:
    ./stations-updater.sh --update    # Update all station URLs
    ./stations-updater.sh --verify    # Check if streams are working
    ./stations-updater.sh --list      # Show current configuration

EOF
}

# Main command dispatcher
main() {
    case "${1:-}" in
        --update|-u)
            create_backup
            update_all_stations
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
        --clean)
            clean_old_backups
            ;;
        --help|-h)
            show_help
            ;;
        "")
            # Default action: show help
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
