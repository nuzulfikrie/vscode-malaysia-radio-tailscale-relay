#!/usr/bin/env bash
#
# proxy-entrypoint.sh
# Auto-start streams on first request
# Acts as a transparent proxy to Icecast
#

set -euo pipefail

STATIONS_DIR="/stations"
ICECAST_HOST="${ICECAST_HOST:-icecast}"
ICECAST_PORT="${ICECAST_PORT:-8000}"
PROXY_PORT="${PROXY_PORT:-8080}"

declare -A ACTIVE_STREAMS

# Parse mount path from URL
get_station_from_path() {
    local path="$1"
    # Remove leading slash and .mp3 extension
    local station="${path#/}"
    station="${station%.mp3}"
    echo "$station"
}

# Start a station
start_station() {
    local station_key="$1"
    local env_file="${STATIONS_DIR}/${station_key}.env"
    
    # Check if already running
    if [[ -f "/tmp/${station_key}.pid" ]]; then
        local pid
        pid=$(cat "/tmp/${station_key}.pid" 2>/dev/null)
        if kill -0 "$pid" 2>/dev/null; then
            return 0
        fi
    fi
    
    if [[ ! -f "$env_file" ]]; then
        echo "Station not found: $station_key" >&2
        return 1
    fi
    
    source "$env_file"
    
    echo "Auto-starting: $STATION_NAME" >&2
    
    ffmpeg \
        -hide_banner \
        -loglevel warning \
        -user_agent "Mozilla/5.0" \
        -reconnect 1 \
        -reconnect_streamed 1 \
        -reconnect_on_network_error 1 \
        -reconnect_delay_max 10 \
        -i "$SOURCE_URL" \
        -vn \
        -map 0:a:0 \
        -c:a libmp3lame \
        -b:a 128k \
        -content_type audio/mpeg \
        -f mp3 \
        -ice_name "$STATION_NAME" \
        "icecast://source:hackme@$ICECAST_HOST:$ICECAST_PORT$MOUNT_PATH" &
    
    echo $! > "/tmp/${station_key}.pid"
    
    # Wait for stream to be available
    local retries=0
    while [[ $retries -lt 30 ]]; do
        if curl -s -o /dev/null -w "%{http_code}" "http://$ICECAST_HOST:$ICECAST_PORT$MOUNT_PATH" | grep -q "200\|302"; then
            echo "Stream ready: $MOUNT_PATH" >&2
            return 0
        fi
        sleep 1
        ((retries++))
    done
    
    return 0
}

# Simple HTTP proxy using netcat
start_proxy() {
    echo "Starting auto-start proxy on port $PROXY_PORT"
    
    while true; do
        # Listen for HTTP requests
        { echo -ne "HTTP/1.1 302 Found\r\nLocation: http://$ICECAST_HOST:$ICECAST_PORT\r\n\r\n"; } | nc -l -p "$PROXY_PORT" -q 1 | (
            read -r request
            path=$(echo "$request" | awk '{print $2}')
            
            if [[ "$path" =~ \.mp3$ ]]; then
                station=$(get_station_from_path "$path")
                start_station "$station"
            fi
        )
    done
}

# Alternative: Just ensure all stations are started
case "${1:-}" in
    start)
        if [[ -z "${2:-}" ]] || [[ "${2}" == "all" ]]; then
            echo "Starting all stations..."
            for env_file in "$STATIONS_DIR"/*.env; do
                if [[ -f "$env_file" ]]; then
                    station=$(basename "$env_file" .env)
                    start_station "$station"
                    sleep 0.5
                fi
            done
            echo "All stations started!"
        else
            start_station "$2"
        fi
        ;;
    status)
        for pid_file in /tmp/*.pid; do
            if [[ -f "$pid_file" ]]; then
                station=$(basename "$pid_file" .pid)
                pid=$(cat "$pid_file" 2>/dev/null)
                if kill -0 "$pid" 2>/dev/null; then
                    echo "✓ $station (PID: $pid)"
                else
                    echo "✗ $station (dead)"
                fi
            fi
        done
        ;;
    *)
        echo "Usage: $0 start [station|all] | status"
        exit 1
        ;;
esac
