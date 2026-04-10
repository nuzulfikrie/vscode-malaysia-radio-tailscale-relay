#!/usr/bin/env bash
set -euo pipefail

: "${SOURCE_URL:?SOURCE_URL is required}"
: "${MOUNT_PATH:?MOUNT_PATH is required}"
: "${STATION_NAME:?STATION_NAME is required}"
: "${ICECAST_HOST:?ICECAST_HOST is required}"
: "${ICECAST_PORT:?ICECAST_PORT is required}"
: "${ICECAST_USER:?ICECAST_USER is required}"
: "${ICECAST_SOURCE_PASSWORD:?ICECAST_SOURCE_PASSWORD is required}"

AUDIO_CODEC="${AUDIO_CODEC:-libmp3lame}"
AUDIO_BITRATE="${AUDIO_BITRATE:-128k}"
AUDIO_CONTENT_TYPE="${AUDIO_CONTENT_TYPE:-audio/mpeg}"
AUDIO_FORMAT="${AUDIO_FORMAT:-mp3}"

echo "Starting relay for ${STATION_NAME}"
echo "Source: ${SOURCE_URL}"
echo "Mount:  ${MOUNT_PATH}"

exec ffmpeg \
  -hide_banner \
  -loglevel warning \
  -reconnect 1 \
  -reconnect_streamed 1 \
  -reconnect_on_network_error 1 \
  -reconnect_on_http_error 4xx,5xx \
  -reconnect_delay_max 10 \
  -i "${SOURCE_URL}" \
  -vn \
  -map 0:a:0 \
  -c:a "${AUDIO_CODEC}" \
  -b:a "${AUDIO_BITRATE}" \
  -content_type "${AUDIO_CONTENT_TYPE}" \
  -f "${AUDIO_FORMAT}" \
  "icecast://${ICECAST_USER}:${ICECAST_SOURCE_PASSWORD}@${ICECAST_HOST}:${ICECAST_PORT}${MOUNT_PATH}"
