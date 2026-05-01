#!/usr/bin/env bash
#
# manager-entrypoint.sh
# On-demand streaming manager - starts ffmpeg processes for requested stations
#

set -euo pipefail

STATIONS_DIR="/stations"
ICECAST_HOST="${ICECAST_HOST:-icecast}"
ICECAST_PORT="${ICECAST_PORT:-8000}"
ICECAST_USER="${ICECAST_USER:-source}"
ICECAST_SOURCE_PASSWORD="${ICECAST_SOURCE_PASSWORD:-hackme}"

echo "Starting Radio Stream Manager"
echo "============================"
echo "Icecast: ${ICECAST_HOST}:${ICECAST_PORT}"
echo "Stations dir: ${STATIONS_DIR}"
echo ""

# List available stations
list_stations() {
    echo "Available stations:"
    for env_file in "${STATIONS_DIR}"/*.env; do
        if [[ -f "${env_file}" ]]; then
            local name
            name=$(grep "^STATION_NAME=" "${env_file}" | cut -d'=' -f2-)
            echo "  - ${env_file##*/}: ${name}"
        fi
    done
}

# Start a specific station
start_station() {
    local station_key="$1"
    local env_file="${STATIONS_DIR}/${station_key}.env"
    
    if [[ ! -f "${env_file}" ]]; then
        echo "ERROR: Station not found: ${station_key}"
        echo "Available stations:"
        list_stations
        return 1
    fi
    
    # Source the env file
    source "${env_file}"
    
    echo "Starting: ${STATION_NAME}"
    echo "  Source: ${SOURCE_URL}"
    echo "  Mount:  ${MOUNT_PATH}"
    
    # Start ffmpeg in background
    ffmpeg \
        -hide_banner \
        -loglevel warning \
        -user_agent "Mozilla/5.0 (compatible; ffmpeg)" \
        -reconnect 1 \
        -reconnect_streamed 1 \
        -reconnect_on_network_error 1 \
        -reconnect_on_http_error 4xx,5xx \
        -reconnect_delay_max 10 \
        -i "${SOURCE_URL}" \
        -vn \
        -map 0:a:0 \
        -c:a libmp3lame \
        -b:a 128k \
        -content_type audio/mpeg \
        -f mp3 \
        -ice_name "${STATION_NAME}" \
        "icecast://${ICECAST_USER}:${ICECAST_SOURCE_PASSWORD}@${ICECAST_HOST}:${ICECAST_PORT}${MOUNT_PATH}" &
    
    local pid=$!
    echo "  PID: ${pid}"
    
    # Store PID
    echo "${pid}" > "/tmp/${station_key}.pid"
    
    return 0
}

# Stop a station
stop_station() {
    local station_key="$1"
    local pid_file="/tmp/${station_key}.pid"
    
    if [[ -f "${pid_file}" ]]; then
        local pid
        pid=$(cat "${pid_file}")
        
        if kill -0 "${pid}" 2>/dev/null; then
            echo "Stopping ${station_key} (PID: ${pid})"
            kill "${pid}"
            rm -f "${pid_file}"
        else
            echo "${station_key} not running"
            rm -f "${pid_file}"
        fi
    else
        echo "${station_key} not running"
    fi
}

# Start all stations
start_all() {
    echo "Starting all stations..."
    for env_file in "${STATIONS_DIR}"/*.env; do
        if [[ -f "${env_file}" ]]; then
            local station_key
            station_key=$(basename "${env_file}" .env)
            start_station "${station_key}"
            sleep 1
        fi
    done
}

# Show status
status() {
    echo "Running stations:"
    local running=0
    for pid_file in /tmp/*.pid; do
        if [[ -f "${pid_file}" ]]; then
            local station_key
            station_key=$(basename "${pid_file}" .pid)
            local pid
            pid=$(cat "${pid_file}")
            
            if kill -0 "${pid}" 2>/dev/null; then
                echo "  ✓ ${station_key} (PID: ${pid})"
                ((running++))
            else
                echo "  ✗ ${station_key} (PID: ${pid}) - dead"
            fi
        fi
    done
    echo ""
    echo "Total running: ${running}"
}

# Monitor mode - restart dead streams
monitor() {
    echo "Monitor mode: checking every 30 seconds"
    while true; do
        sleep 30
        
        for pid_file in /tmp/*.pid; do
            if [[ -f "${pid_file}" ]]; then
                local station_key
                station_key=$(basename "${pid_file}" .pid)
                local pid
                pid=$(cat "${pid_file}")
                
                if ! kill -0 "${pid}" 2>/dev/null; then
                    echo "$(date): ${station_key} died, restarting..."
                    start_station "${station_key}"
                fi
            fi
        done
    done
}

# Main command handler
case "${1:-}" in
    start)
        if [[ -z "${2:-}" ]]; then
            echo "Usage: start <station_key>"
            echo "   or: start all"
            exit 1
        fi
        
        if [[ "${2}" == "all" ]]; then
            start_all
        else
            start_station "${2}"
        fi
        ;;
    stop)
        if [[ -z "${2:-}" ]]; then
            echo "Usage: stop <station_key>"
            exit 1
        fi
        stop_station "${2}"
        ;;
    status)
        status
        ;;
    list)
        list_stations
        ;;
    monitor)
        monitor
        ;;
    *)
        echo "Radio Stream Manager"
        echo "===================="
        echo ""
        echo "Commands:"
        echo "  start <station>  Start a specific station"
        echo "  start all        Start all stations"
        echo "  stop <station>   Stop a specific station"
        echo "  status           Show running stations"
        echo "  list             List available stations"
        echo "  monitor          Monitor and restart dead streams"
        echo ""
        echo "Examples:"
        echo "  docker exec relay-manager /entrypoint.sh start ikim"
        echo "  docker exec relay-manager /entrypoint.sh start all"
        echo "  docker exec relay-manager /entrypoint.sh status"
        exit 1
        ;;
esac
