#!/usr/bin/env python3
import json
from pathlib import Path

def parse_env_file(filepath):
    config = {}
    with open(filepath, 'r') as f:
        for line in f:
            line = line.strip()
            if line and '=' in line:
                key, value = line.split('=', 1)
                config[key] = value
    return config

def generate_vscode_config():
    stations_dir = Path("relay/stations")
    env_files = sorted(stations_dir.glob("*.env"))
    
    custom_stations = []
    
    for env_file in env_files:
        config = parse_env_file(env_file)
        name = config.get('STATION_NAME', env_file.stem)
        mount_path = config.get('MOUNT_PATH', f"/{env_file.stem}.mp3")
        url = f"http://internal-dc:8000{mount_path}"
        
        custom_stations.append({
            "name": name,
            "url": url
        })
    
    return {"radioPlayer.customStations": custom_stations}

def main():
    vscode_config = generate_vscode_config()
    
    vscode_dir = Path(".vscode")
    vscode_dir.mkdir(exist_ok=True)
    
    settings_file = vscode_dir / "settings.json"
    
    existing_config = {}
    if settings_file.exists():
        try:
            with open(settings_file, 'r') as f:
                existing_config = json.load(f)
        except:
            pass
    
    merged_config = {**existing_config, **vscode_config}
    
    with open(settings_file, 'w') as f:
        json.dump(merged_config, f, indent=4)
    
    print(f"Generated: {settings_file}")
    print(f"Total stations: {len(vscode_config['radioPlayer.customStations'])}")
    print()
    print(json.dumps(vscode_config, indent=4))

if __name__ == "__main__":
    main()
