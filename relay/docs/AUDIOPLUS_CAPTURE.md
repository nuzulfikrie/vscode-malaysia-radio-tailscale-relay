# AudioPlus Stream URL Capture Guide

## Overview

Some AudioPlus radio stations (Hot FM, Kool FM, Fly FM, etc.) use **dynamic session-based URLs** that require browser automation to capture. Unlike static streams (like IKIM FM at `https://ais-sa8.cdnstream1.com/5035`), these stations generate unique URLs with time-limited tokens.

## Prerequisites

### Local Machine Requirements

You need to run the capture script on your **local laptop/desktop** (not the server):

```bash
# Install Python dependencies
pip3 install playwright

# Install browser binaries
playwright install chromium
```

## Usage

### 1. Capture All Stations

```bash
# From the relay directory
python3 capture_audioplus_streams.py
```

This will:
1. Open each station page in a headless browser
2. Click the play button
3. Capture the network requests
4. Extract the stream URLs
5. Update the `.env` files in `stations/`

### 2. Capture Single Station

```bash
python3 capture_audioplus_streams.py --station hotfm
```

### 3. Test Existing URLs

```bash
python3 capture_audioplus_streams.py --test
```

## How It Works

The script uses **Playwright** to:

1. Launch Chromium in headless mode
2. Enable network logging (DevTools Protocol)
3. Navigate to the station URL
4. Find and click the play button
5. Monitor network traffic for `.m3u8` requests
6. Extract the stream URL from the request

### Network Interception

The key part is this:

```python
# Enable network logging
page.on("request", lambda request: 
    capture_request(request)
)

# Wait for m3u8 request
def capture_request(request):
    if ".m3u8" in request.url:
        stream_urls.append(request.url)
```

## Known Stations

### Static URLs (No capture needed)
- **IKIM FM**: `https://ais-sa8.cdnstream1.com/5035`

### Dynamic URLs (Browser capture required)
- **Hot FM**: `hotfm.audioplus.audio`
- **Kool FM**: `koolfm.audioplus.audio`
- **Fly FM**: `flyfm.audioplus.audio`
- **Zayan FM**: `zayanfm.audioplus.audio`
- **Hitz FM**: `hitzfm.audioplus.audio`
- **Mix FM**: `mixfm.audioplus.audio`
- **One FM**: `onefm.audioplus.audio`
- **My FM**: `myfm.audioplus.audio`
- **Sinar FM**: `sinarfm.audioplus.audio`
- **Era FM**: `erafm.audioplus.audio`
- **Suria FM**: `suriafm.audioplus.audio`

## Updating Stations

### Automated Update

```bash
# Run the capture script
python3 capture_audioplus_streams.py

# Verify the new files
ls -la stations/

# Test a stream
./stations-updater.sh --test stations/hotfm.env
```

### Manual Update

If automation fails, you can manually capture:

1. Open browser DevTools (F12)
2. Go to Network tab
3. Navigate to `https://hotfm.audioplus.audio/`
4. Click play button
5. Look for `.m3u8` request
6. Copy the URL
7. Update `stations/hotfm.env`:

```env
STATION_NAME=Hot FM
SOURCE_URL=<captured_url>
MOUNT_PATH=/hotfm.mp3
```

## Troubleshooting

### "No stream URL found"

- The page might have changed its structure
- Try increasing the wait time in the script
- Check if the play button selector needs updating

### "Browser not found"

```bash
# Reinstall browsers
playwright install chromium --force
```

### "Permission denied"

```bash
# Make scripts executable
chmod +x capture_audioplus_streams.py
chmod +x stations-updater.sh
```

## Technical Details

### Why Session Tokens?

AudioPlus uses:
- `listeningSessionId` - Unique per session
- `rj-tok` - Authentication token
- `rj-ttl` - Time-to-live (usually 5 seconds)

These prevent direct linking and require JavaScript execution.

### Alternative: curl + grep

For stations that embed URLs in the HTML:

```bash
curl -s https://ikimfm.audioplus.audio/ | grep -oE 'https?://[^"]+\.m3u8'
```

But this won't work for dynamically loaded streams.

## Integration with stations-updater.sh

The capture script can be called from the main updater:

```bash
# In stations-updater.sh
if [[ "$1" == "--capture-audioplus" ]]; then
    python3 capture_audioplus_streams.py
    exit 0
fi
```

This way you can run:

```bash
./stations-updater.sh --capture-audioplus
```

## Maintenance

**Recommended schedule**: Run capture weekly or when streams stop working.

```bash
# Add to crontab (run every Sunday at 2am)
0 2 * * 0 cd /path/to/relay && python3 capture_audioplus_streams.py >> /var/log/stream-capture.log 2>&1
```
