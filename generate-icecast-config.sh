#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

ENV_FILE="${PROJECT_DIR}/.env"
TEMPLATE_FILE="${PROJECT_DIR}/icecast/icecast.xml.template"
OUTPUT_FILE="${PROJECT_DIR}/icecast/icecast.xml"

if [[ ! -f "$ENV_FILE" ]]; then
    echo "Error: .env file not found at $ENV_FILE"
    echo "Please copy .env.example to .env and configure your passwords"
    exit 1
fi

if [[ ! -f "$TEMPLATE_FILE" ]]; then
    echo "Error: Template file not found at $TEMPLATE_FILE"
    exit 1
fi

echo "Generating icecast.xml from template..."

set -a
source "$ENV_FILE"
set +a

envsubst < "$TEMPLATE_FILE" > "$OUTPUT_FILE"

echo "Generated: $OUTPUT_FILE"
echo "Done!"
