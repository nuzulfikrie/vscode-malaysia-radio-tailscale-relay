#!/usr/bin/env bash
#
# reload-stations.sh
# Regenerate docker-compose.yml and restart all streaming containers
# Use this after adding/updating station .env files
#

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[OK]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

log_info "Regenerating docker-compose.yml..."

if [[ ! -f "generate-compose.py" ]]; then
    log_error "generate-compose.py not found"
    exit 1
fi

if command -v python3 &> /dev/null; then
    python3 generate-compose.py
elif command -v python &> /dev/null; then
    python generate-compose.py
else
    log_error "Python not found"
    exit 1
fi

log_info "Stopping existing containers..."
docker-compose down || true

log_info "Starting updated containers..."
docker-compose up -d --build

log_info "Waiting for services to start..."
sleep 5

log_info "Checking container status..."
docker-compose ps

log_success "Reload complete!"
log_info ""
log_info "Icecast admin: http://localhost:8000"
log_info "To view logs: docker-compose logs -f"
log_info "To stop: docker-compose down"
