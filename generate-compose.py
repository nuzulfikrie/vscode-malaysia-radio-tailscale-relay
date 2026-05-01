#!/usr/bin/env python3
"""
Generate docker-compose.yml from station .env files
Scans relay/stations/ for all .env files and creates services
"""

import os
import re
from pathlib import Path

def generate_compose():
    stations_dir = Path("relay/stations")
    env_files = sorted(stations_dir.glob("*.env"))
    
    compose = ["services:"]
    
    # Icecast service
    compose.append("""  icecast:
    image: libretime/icecast:2.4.4
    container_name: radio-icecast
    restart: unless-stopped
    ports:
      - "8000:8000"
    volumes:
      - ./icecast/icecast.xml:/etc/icecast.xml:ro
    healthcheck:
      test: ["CMD", "bash", "-c", "exec 3<>/dev/tcp/127.0.0.1/8000 && echo -e 'GET / HTTP/1.0\\r\\n\\r\\n' >&3 && cat <&3 | grep -q 'Icecast'"]
      interval: 30s
      timeout: 5s
      retries: 5
""")
    
    # Generate relay service for each station
    for env_file in env_files:
        station_name = env_file.stem
        compose.append(f"""  relay-{station_name}:
    build:
      context: ./relay
    container_name: relay-{station_name}
    restart: unless-stopped
    depends_on:
      icecast:
        condition: service_healthy
    env_file:
      - ./.env
      - ./relay/stations/{station_name}.env
""")
    
    return "\n".join(compose)

def main():
    compose_content = generate_compose()
    
    with open("docker-compose.yml", "w") as f:
        f.write(compose_content)
    
    # Count stations
    stations_dir = Path("relay/stations")
    count = len(list(stations_dir.glob("*.env")))
    
    print(f"Generated docker-compose.yml with {count} stations")
    print("\nStations included:")
    for env_file in sorted(stations_dir.glob("*.env")):
        print(f"  - {env_file.stem}")

if __name__ == "__main__":
    main()
