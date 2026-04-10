# 🎧 Malaysia Radio Relay (Docker + Icecast + Tailscale) for VSCode Radio Extensions

Self-hosted radio relay system that converts various radio streams (AAC / HLS / m3u8) into **MP3/Ogg**, making them compatible with tools like VS Code radio extensions.

Designed for:

* private streaming over **Tailscale**
* stable playback (no token issues on client side)
* extensible multi-station setup

---

## 🧱 Architecture

```text
[ Radio Source (AAC / HLS / m3u8) ]
                ↓
        [ FFmpeg Relay Containers ]
                ↓
          [ Icecast Server ]
                ↓
       [ Tailscale Private Network ]
                ↓
     [ VS Code / Browser / Player ]
```

---

## 📦 Features

* 🎙️ Multi-station relay (IKIM, BFM, ZAYAN, SINAR)
* 🔄 Auto-reconnect on stream failure
* 🎧 Outputs **MP3 (default)** or **Ogg**
* 🔒 Private access via **Tailscale**
* 🐳 Fully Dockerized
* ⚙️ Easily extendable (add new stations)

---

## 📁 Project Structure

```text
radio-relay/
├─ docker-compose.yml
├─ .env
├─ icecast/
│  └─ icecast.xml
└─ relay/
   ├─ Dockerfile
   ├─ entrypoint.sh
   └─ stations/
      ├─ ikim.env
      ├─ bfm.env
      ├─ zayan.env
      └─ sinar.env
```

---

## 🚀 Quick Start

### 1. Clone / prepare project

```bash
mkdir radio-relay && cd radio-relay
```

Add all files as provided.

---

### 2. Configure environment

Edit `.env`:

```bash
ICECAST_SOURCE_PASSWORD=strong-source-pass
ICECAST_ADMIN_PASSWORD=strong-admin-pass
ICECAST_RELAY_PASSWORD=strong-relay-pass

ICECAST_HOST=icecast
ICECAST_PORT=8000
ICECAST_USER=source

AUDIO_CODEC=libmp3lame
AUDIO_BITRATE=128k
AUDIO_CONTENT_TYPE=audio/mpeg
AUDIO_FORMAT=mp3
```

---

### 3. Start services

```bash
docker compose up -d --build
```

---

### 4. Verify streams

Open in browser (via Tailscale):

```text
http://YOUR-TAILSCALE-HOST:8000/ikim.mp3
http://YOUR-TAILSCALE-HOST:8000/bfm.mp3
http://YOUR-TAILSCALE-HOST:8000/zayan.mp3
http://YOUR-TAILSCALE-HOST:8000/sinar.mp3
```

---

## 🧑‍💻 VS Code Integration

Add to `settings.json`:

```json
"radioPlayer.customStations": [
    {
        "name": "IKIM FM",
        "url": "http://YOUR-TAILSCALE-HOST:8000/ikim.mp3"
    },
    {
        "name": "BFM 89.9",
        "url": "http://YOUR-TAILSCALE-HOST:8000/bfm.mp3"
    },
    {
        "name": "ZAYAN FM",
        "url": "http://YOUR-TAILSCALE-HOST:8000/zayan.mp3"
    },
    {
        "name": "SINAR FM",
        "url": "http://YOUR-TAILSCALE-HOST:8000/sinar.mp3"
    }
]
```

---

## ⚙️ Adding New Stations

Create a new file:

```bash
relay/stations/newstation.env
```

Example:

```bash
STATION_NAME=My Radio
SOURCE_URL=https://example.com/stream.m3u8
MOUNT_PATH=/myradio.mp3
```

Then duplicate a service in `docker-compose.yml`:

```yaml
relay-myradio:
  build:
    context: ./relay
  restart: unless-stopped
  depends_on:
    icecast:
      condition: service_healthy
  env_file:
    - ./.env
    - ./relay/stations/newstation.env
```

---

## 🔒 Security (Tailscale Only)

### Restrict Icecast to Tailnet

Using UFW:

```bash
sudo ufw deny 8000/tcp
sudo ufw allow in on tailscale0 to any port 8000 proto tcp
```

---

## ⚠️ Known Limitations

### 1. Tokenized Streams (IMPORTANT)

Some stations (e.g. SINAR, SYOK network):

* use **temporary HLS URLs**
* expire after a short time
* may require re-fetching

Symptoms:

* stream stops suddenly
* ffmpeg logs show HTTP 403 / expired

---

### 2. CPU Usage

* MP3 encoding is lightweight
* multiple stations are fine on most servers
* scale depends on bitrate and count

---

### 3. No Metadata (by default)

* station name is static
* song titles not forwarded
* can be extended with Icecast metadata injection

---

## 🛠 Troubleshooting

### Check container logs

```bash
docker logs -f relay-ikim
docker logs -f relay-sinar
```

---

### Check Icecast status

```bash
http://YOUR-TAILSCALE-HOST:8000
```

---

### Test source stream manually

```bash
ffmpeg -i "<SOURCE_URL>"
```

---

### Common errors

| Error              | Cause                       |
| ------------------ | --------------------------- |
| 403 Forbidden      | expired token               |
| Connection refused | Icecast not ready           |
| No audio           | wrong codec / stream format |

---

## 🔄 Restart Services

```bash
docker compose restart
```

---

## 🧠 Future Improvements

* Auto-refresh tokenized streams (Puppeteer / scraper)
* Add metadata (song titles)
* Add web UI dashboard
* Add health monitoring + auto-restart logic
* Convert to Kubernetes (if scaling)

---

## 📜 Notes

* Keep usage **private within your Tailnet**
* Do not publicly rebroadcast streams
* Respect station terms of service

---

## ✅ Summary

This setup gives you:

* stable **MP3 radio endpoints**
* full control over streaming
* compatibility with tools that don’t support HLS/AAC
