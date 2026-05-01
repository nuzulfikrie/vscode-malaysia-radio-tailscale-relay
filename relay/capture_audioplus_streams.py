#!/usr/bin/env python3
"""
Capture AudioPlus stream URLs using browser automation.
Integrates with stations-updater.sh to refresh dynamic stream URLs.
"""

import json
import sys
import os
import re
import time
import argparse
from pathlib import Path

SCRIPT_DIR = Path(__file__).parent.absolute()
STATIONS_DIR = SCRIPT_DIR / "stations"

STATIONS = {
    "hotfm": "Hot FM",
    "koolfm": "Kool FM",
    "flyfm": "Fly FM",
    "zayanfm": "Zayan FM",
    "hitzfm": "Hitz FM",
    "mixfm": "Mix FM",
    "onefm": "One FM",
    "myfm": "My FM",
    "sinarfm": "Sinar FM",
    "erafm": "Era FM",
    "suriafm": "Suria FM",
    "traxxfm": "Traxx FM",
    "kupikupifm-sarawak": "Kupi Kupi FM Sarawak",
}

STATIC_STREAMS = {
    "ikimfm": "https://ais-sa8.cdnstream1.com/5035",
}

def log_info(msg):
    print(f"[INFO] {msg}", file=sys.stderr)

def log_success(msg):
    print(f"[OK] {msg}", file=sys.stderr)

def log_error(msg):
    print(f"[ERROR] {msg}", file=sys.stderr)

def log_warn(msg):
    print(f"[WARN] {msg}", file=sys.stderr)

def ensure_playwright():
    """Check if playwright is available."""
    try:
        from playwright.sync_api import sync_playwright
        return True
    except ImportError:
        log_error("Playwright not installed. Run: pip3 install playwright")
        log_error("Then: playwright install chromium")
        return False

def capture_stream_url(station_key, station_name, timeout=30):
    """Capture stream URL using Playwright browser automation."""
    try:
        from playwright.sync_api import sync_playwright, TimeoutError as PlaywrightTimeout
        
        url = f"https://{station_key}.audioplus.audio/"
        stream_urls = []
        
        log_info(f"Capturing: {station_name} ({url})")
        
        with sync_playwright() as p:
            browser = p.chromium.launch(headless=True)
            context = browser.new_context(
                user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
            )
            
            page = context.new_page()
            
            # Capture network requests
            def handle_route(route, request):
                if ".m3u8" in request.url or "playlist" in request.url:
                    if "cdnstream" in request.url or "das-edge" in request.url:
                        stream_urls.append(request.url)
                route.continue_()
            
            page.route("**/*", handle_route)
            
            # Navigate to page
            page.goto(url, wait_until="networkidle", timeout=timeout*1000)
            
            # Wait for player to load
            time.sleep(2)
            
            # Try to find and click play button
            play_selectors = [
                "button[class*='play']",
                "[class*='audio-player'] button",
                "[class*='player'] button",
                "button[aria-label*='play' i]",
                "button",
            ]
            
            for selector in play_selectors:
                try:
                    buttons = page.query_selector_all(selector)
                    for button in buttons:
                        if button.is_visible():
                            button.click()
                            log_info(f"  Clicked play button")
                            time.sleep(5)  # Wait for stream to load
                            break
                except Exception:
                    continue
            
            browser.close()
        
        if stream_urls:
            return stream_urls[0]
        return None
        
    except PlaywrightTimeout:
        log_error(f"  Timeout while loading {station_key}")
        return None
    except Exception as e:
        log_error(f"  Error: {e}")
        return None

def create_station_file(station_key, station_name, stream_url):
    """Create or update station env file."""
    STATIONS_DIR.mkdir(exist_ok=True)
    
    env_file = STATIONS_DIR / f"{station_key}.env"
    
    content = f"""STATION_NAME={station_name}
SOURCE_URL={stream_url}
MOUNT_PATH=/{station_key}.mp3
"""
    
    with open(env_file, "w") as f:
        f.write(content)
    
    log_success(f"  Created: {env_file}")

def test_stream(url):
    """Test if stream URL is working."""
    import subprocess
    try:
        result = subprocess.run(
            ["timeout", "5", "ffmpeg", "-hide_banner", "-loglevel", "error",
             "-i", url, "-t", "1", "-f", "null", "-"],
            capture_output=True,
            timeout=10
        )
        return result.returncode == 0
    except:
        return False

def capture_all():
    """Capture all AudioPlus stations."""
    log_info("="*60)
    log_info("AudioPlus Stream Capture")
    log_info("="*60)
    
    if not ensure_playwright():
        log_error("Please install Playwright first:")
        log_error("  pip3 install playwright")
        log_error("  playwright install chromium")
        sys.exit(1)
    
    updated = 0
    failed = 0
    
    # Handle static streams first
    log_info("\nStatic Streams (no capture needed):")
    for key, url in STATIC_STREAMS.items():
        log_info(f"  {key}: {url}")
        create_station_file(key, "IKIM FM", url)
        updated += 1
    
    # Capture dynamic streams
    log_info("\nDynamic Streams (browser capture required):")
    for key, name in STATIONS.items():
        stream_url = capture_stream_url(key, name)
        
        if stream_url:
            log_success(f"  Found: {stream_url[:60]}...")
            
            if test_stream(stream_url):
                log_success(f"  ✓ Stream verified")
            else:
                log_warn(f"  ⚠ Stream not responding (saving anyway)")
            
            create_station_file(key, name, stream_url)
            updated += 1
        else:
            log_error(f"  ✗ Failed to capture {key}")
            failed += 1
        
        print()
    
    log_info("="*60)
    log_info("Capture Summary:")
    log_success(f"  Updated: {updated}")
    if failed > 0:
        log_error(f"  Failed: {failed}")
    log_info("="*60)
    
    return failed == 0

def capture_single(station_key):
    """Capture single station."""
    if station_key in STATIC_STREAMS:
        log_info(f"{station_key} uses static URL")
        create_station_file(station_key, "IKIM FM", STATIC_STREAMS[station_key])
        return True
    
    if station_key not in STATIONS:
        log_error(f"Unknown station: {station_key}")
        return False
    
    if not ensure_playwright():
        return False
    
    stream_url = capture_stream_url(station_key, STATIONS[station_key])
    
    if stream_url:
        create_station_file(station_key, STATIONS[station_key], stream_url)
        return True
    return False

def list_stations():
    """List all available stations."""
    print("Available AudioPlus stations:")
    print()
    print("Static (no capture needed):")
    for key in STATIC_STREAMS:
        print(f"  - {key}")
    print()
    print("Dynamic (browser capture required):")
    for key in STATIONS:
        print(f"  - {key}")

def main():
    parser = argparse.ArgumentParser(
        description="Capture AudioPlus stream URLs using browser automation"
    )
    parser.add_argument(
        "--station",
        help="Capture specific station only"
    )
    parser.add_argument(
        "--list",
        action="store_true",
        help="List available stations"
    )
    parser.add_argument(
        "--test",
        metavar="URL",
        help="Test a stream URL"
    )
    
    args = parser.parse_args()
    
    if args.list:
        list_stations()
        return 0
    
    if args.test:
        if test_stream(args.test):
            log_success("Stream is working")
            return 0
        else:
            log_error("Stream failed")
            return 1
    
    if args.station:
        success = capture_single(args.station)
        return 0 if success else 1
    
    success = capture_all()
    return 0 if success else 1

if __name__ == "__main__":
    sys.exit(main())
