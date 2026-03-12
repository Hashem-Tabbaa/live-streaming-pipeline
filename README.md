# Thmanyah Live Streaming Pipeline

End-to-end live streaming pipeline built with AWS Media Services and Infrastructure as Code (Terraform).

## Architecture

```
┌──────────────┐    SRT (encrypted)    ┌──────────────────┐    Raw Stream    ┌─────────────────┐
│  OBS Studio  │ ───────────────────── │  MediaConnect    │ ──────────────── │   MediaLive     │
│  (Source)    │    Port 9000          │  (SRT Ingest)    │                  │  (Transcoding)  │
└──────────────┘    Latency: 1000ms    └──────────────────┘                  └─────┬───┬───┬───┘
                                                                                   │   │   │
                                                                          1080p/5M │ 720p │ 480p/1.5M
                                                                                   │  /3M │
                                                                                   ▼   ▼   ▼
┌──────────────┐    HTTPS              ┌──────────────────┐    HLS          ┌─────────────────┐
│  Web Player  │ ◄──────────────────── │  CloudFront      │ ◄───────────── │  MediaPackage   │
│  (hls.js)    │    Cached globally    │  (CDN)           │    .m3u8+.ts   │  (HLS Packaging)│
└──────────────┘                       └──────────────────┘                  └─────────────────┘
```

> Full Mermaid diagram: [architecture/diagram.mmd](architecture/diagram.mmd)

## Table of Contents

- [Quick Start](#quick-start)
- [Prerequisites](#prerequisites)
- [Deployment](#deployment)
- [Signal Source (SRT Ingest)](#signal-source-srt-ingest)
- [Transcoding Configuration](#transcoding-configuration)
- [Packaging Configuration](#packaging-configuration)
- [CDN Configuration](#cdn-configuration)
- [Web Player](#web-player)
- [Teardown](#teardown)
- [Cost Estimate](#cost-estimate)
- [Bonus: HLS vs DASH](#bonus-hls-vs-dash)
- [Bonus: LL-HLS Analysis](#bonus-ll-hls-analysis)
- [Troubleshooting](#troubleshooting)

---

## Quick Start

```bash
# 1. Deploy infrastructure
cd terraform
terraform init
terraform plan
terraform apply

# 2. Copy the SRT endpoint from output
# Example: srt://54.x.x.x:9000

# 3. Open OBS Studio → Settings → Stream
#    Service: Custom
#    Server: srt://54.x.x.x:9000

# 4. Start streaming in OBS

# 5. Open web-player/index.html in a browser
#    Paste the HLS playback URL from terraform output

# 6. ⚠️ TEAR DOWN WHEN DONE:
cd terraform
terraform destroy
```

---

## Prerequisites

| Tool | Version | Purpose |
|------|---------|---------|
| [Terraform](https://terraform.io) | >= 1.5.0 | Infrastructure as Code |
| [AWS CLI](https://aws.amazon.com/cli/) | v2 | AWS authentication |
| [OBS Studio](https://obsproject.com/) | >= 30.0 | SRT stream source |
| [A modern browser](https://caniuse.com/mediasource) | Chrome/Firefox/Safari | HLS playback |

### AWS Account Setup

```bash
# Configure AWS credentials
aws configure
# Region: us-east-1 (recommended for Media Services)
```

Required IAM permissions:
- `mediaconnect:*`
- `medialive:*`
- `mediapackage:*`
- `cloudfront:*`
- `iam:CreateRole`, `iam:PutRolePolicy`, `iam:PassRole`
- `cloudformation:*` (for MediaPackage endpoint)
- `logs:*` (for MediaLive logging)

---

## Deployment

```bash
cd terraform

# Initialize Terraform (downloads AWS provider)
terraform init

# Preview what will be created
terraform plan

# Deploy (creates all resources — takes ~3-5 minutes)
terraform apply

# Save the outputs — you'll need them for OBS and the web player
terraform output
```

### Terraform Outputs

| Output | Description |
|--------|-------------|
| `srt_ingest_endpoint` | SRT URL for OBS Studio |
| `hls_playback_url` | HLS stream URL for the web player |
| `cloudfront_domain_name` | CloudFront distribution domain |
| `mediapackage_hls_endpoint_url` | Direct MediaPackage origin URL |

---

## Signal Source (SRT Ingest)

### Protocol: SRT (Secure Reliable Transport)

We use **SRT** as the ingest protocol because it is purpose-built for live video transport over the public internet:

| Feature | SRT | RTMP (legacy) |
|---------|-----|---------------|
| Encryption | AES-128/256 built-in | None (requires RTMPS wrapper) |
| Packet loss recovery | ARQ (Automatic Repeat reQuest) | TCP retransmission (head-of-line blocking) |
| Latency control | Configurable latency buffer | No control |
| Firewall traversal | UDP-based, configurable ports | TCP port 1935, often blocked |
| Codec support | Any codec | Limited to H.264 + AAC |
| Status | Active development (open source) | Deprecated by Adobe |

### SRT Configuration

| Setting | Value | Explanation |
|---------|-------|-------------|
| **Mode** | Listener | MediaConnect listens on port 9000, OBS pushes to it |
| **Port** | 9000 | Standard SRT port (configurable) |
| **Latency** | 1000ms | Buffer for packet retransmission. Higher = more resilient to packet loss but adds latency |
| **Encryption** | None (demo) | In production, enable AES-256 with a passphrase |

### Latency Mode Explanation

SRT latency is a **retransmission buffer**, not a delay:

```
Source sends packet → [1000ms window] → Receiver

If a packet is lost:
  1. Receiver detects gap (missing sequence number)
  2. Receiver sends NAK (Negative Acknowledgment) to source
  3. Source retransmits the packet
  4. If retransmit arrives within 1000ms → success, no visible glitch
  5. If retransmit doesn't arrive within 1000ms → packet declared lost, visible glitch
```

**1000ms** is a good default for internet delivery. For LAN, you could use 120ms. For international links with high jitter, use 2000ms+.

### Setting Up OBS Studio

1. Install OBS Studio: `brew install --cask obs`
2. Open OBS → **Settings** → **Stream**
3. Set:
   - **Service:** Custom
   - **Server:** `srt://[IP_FROM_TERRAFORM_OUTPUT]:9000`
4. Go to **Settings** → **Output**:
   - **Encoder:** x264 (or Apple VT H264 on macOS)
   - **Rate Control:** CBR
   - **Bitrate:** 6000 Kbps
5. Go to **Settings** → **Video**:
   - **Base Resolution:** 1920x1080
   - **Output Resolution:** 1920x1080
   - **FPS:** 30
6. Add a source (Screen Capture, Video File, or Test Pattern)
7. Click **Start Streaming**

---

## Transcoding Configuration

### ABR Ladder (Adaptive Bitrate)

MediaLive transcodes the single input stream into multiple quality levels:

| Rendition | Resolution | Video Bitrate | H.264 Profile | Use Case |
|-----------|-----------|---------------|---------------|----------|
| **1080p** | 1920×1080 | 5 Mbps | High | Good connections (WiFi, fiber) |
| **720p** | 1280×720 | 3 Mbps | Main | Average connections (4G, DSL) |
| **480p** | 854×480 | 1.5 Mbps | Main | Poor connections (3G, congested) |

**Audio:** AAC stereo at 128 kbps for all renditions.

### Codec: H.264/AVC

- **Why H.264?** Universal compatibility — every browser, phone, smart TV, and set-top box can decode it
- **Why not H.265 (HEVC)?** Requires licensing fees, limited browser support (no Chrome/Firefox)
- **Why not AV1?** Encoding is CPU-intensive for real-time; hardware encoder support still limited

### GOP Structure

| Setting | Value | Explanation |
|---------|-------|-------------|
| **GOP Size** | 2 seconds | New keyframe every 60 frames (at 30fps) |
| **GOP Units** | Seconds | Ensures consistent keyframe interval regardless of framerate |
| **Keyframe alignment** | Yes | All renditions have keyframes at the same timestamps |

**Why 2 seconds?**
- Must divide evenly into segment duration: 6s ÷ 2s = 3 GOPs per segment ✓
- Enables fast channel switching (max 2s wait for next keyframe)
- Standard industry practice for live streaming

```
GOP Structure (2 seconds at 30fps):
Frame: I P P P P P P P P P P P P P P P P P P P P P P P P P P P P P I P P...
       ^                                                             ^
       Keyframe (full image)                                         Next keyframe
       |←─────────────── 60 frames (2 seconds) ──────────────────→|
```

### Segment Duration

| Setting | Value | Explanation |
|---------|-------|-------------|
| **Duration** | 6 seconds | Standard HLS segment duration |
| **GOPs per segment** | 3 | Each segment contains exactly 3 GOPs |
| **Segments in manifest** | 10 | 60-second playlist window |

**Why 6 seconds?**
- Apple's recommended default for HLS
- Good balance between latency (~20s total) and efficiency (fewer HTTP requests)
- Each segment is large enough to handle network jitter
- For lower latency, see [LL-HLS comparison](docs/ll-hls-comparison.md)

---

## Packaging Configuration

### MediaPackage HLS Endpoint

MediaPackage receives the transcoded streams and packages them into HLS format:

| Setting | Value | Explanation |
|---------|-------|-------------|
| **Segment duration** | 6 seconds | Matches MediaLive segment output |
| **Playlist window** | 60 seconds | 10 segments visible in the live manifest |
| **Playlist type** | EVENT | Manifest grows (allows limited DVR/rewind) |
| **Segment format** | MPEG-TS (.ts) | Traditional HLS, maximum compatibility |
| **I-frame only stream** | Disabled | Not needed (used for trick play/thumbnails) |

### Manifest Structure

The HLS manifest is a hierarchy:

```
Master Manifest (index.m3u8)
├── Variant: 1080p (bandwidth=5128000)
│   └── Media Playlist → seg_001.ts, seg_002.ts, ...
├── Variant: 720p (bandwidth=3128000)
│   └── Media Playlist → seg_001.ts, seg_002.ts, ...
└── Variant: 480p (bandwidth=1628000)
    └── Media Playlist → seg_001.ts, seg_002.ts, ...
```

The player requests the master manifest, reads the available variants and their bandwidths, then selects the appropriate variant based on current network conditions.

---

## CDN Configuration

### CloudFront Cache Strategy

CDN caching is critical for live streaming — thousands of viewers request the same segments simultaneously.

| Content Type | Path Patern | TTL | Rationale |
|-------------|-------------|-----|-----------|
| **Manifests** | `*.m3u8` (default) | 1 second | Must refresh frequently — manifest updates every segment duration to point to new segments |
| **TS Segments** | `*.ts` | 24 hours | Immutable — once a segment is created, its content never changes. URL contains sequence number. |
| **CMAF Segments** | `*.m4s` | 24 hours | Same as TS — immutable content, safe to cache aggressively |

### Why These TTLs?

**Manifests (1s TTL):**
- The manifest is the live stream's "table of contents"
- Every 6 seconds, a new segment appears and the oldest drops off
- Viewers must get the latest manifest to know about new segments
- 1s TTL means at worst, a viewer is 1 second behind the live edge

**Segments (24h TTL):**
- Segment URLs look like: `segment_1234.ts`
- Once segment 1234 is written, it never changes
- Different viewers requesting segment 1234 all get the exact same content
- Only needs to be fetched from origin once, then served from cache to all viewers

> **Backend analogy:** It's like caching a paginated API. The "next page" URL changes frequently (short cache), but each individual page's content is immutable once published (long cache).

### Additional Settings

- **HTTPS only** — redirect HTTP to HTTPS
- **CORS headers forwarded** — allows the web player to load from a different domain
- **Compression** — enabled for manifests (text), disabled for segments (already compressed video)

---

## Web Player

### Technology: hls.js

The web player is a single HTML file (`web-player/index.html`) using [hls.js](https://github.com/video-dev/hls.js/) — an open-source JavaScript library for HLS playback.

**How it works:**
1. **Safari/iOS:** Uses native `<video>` element with HLS support (no library needed)
2. **Chrome/Firefox:** hls.js intercepts, parses the manifest, downloads segments, and feeds them to the browser's [MediaSource Extensions (MSE)](https://developer.mozilla.org/en-US/docs/Web/API/MediaSource) API

### Features

- Configurable stream URL input
- Adaptive bitrate with manual quality override
- Real-time stats panel (resolution, bandwidth, buffer, latency, dropped frames)
- Responsive design
- LL-HLS ready (`lowLatencyMode: true` enabled)

### Usage

1. Open `web-player/index.html` in a browser
2. Paste the `hls_playback_url` from Terraform output
3. Click **Play**

---

## Teardown

**⚠️ CRITICAL: Run this immediately after testing to avoid ongoing charges.**

```bash
cd terraform
terraform destroy
```

Type `yes` when prompted. This deletes:
- MediaConnect Flow
- MediaLive Channel + Input
- MediaPackage Channel + Endpoint (via CloudFormation stack)
- CloudFront Distribution
- IAM Roles and Policies

### Verify Cleanup

```bash
# Check no resources remain
aws mediaconnect list-flows --region us-east-1
aws medialive list-channels --region us-east-1
aws mediapackage list-channels --region us-east-1
aws cloudfront list-distributions
```

---

## Cost Estimate

For a **10-minute test session:**

| Service | Pricing | Estimated Cost |
|---------|---------|---------------|
| MediaConnect | $0.16/GB | ~$0.02 |
| MediaLive (SINGLE_PIPELINE, 3 outputs) | ~$0.018/min | ~$0.18 |
| MediaPackage | $0.10/GB | ~$0.01 |
| CloudFront | $0.085/GB | ~$0.01 |
| **Total** | | **~$0.22** |

**⚠️ If left running for 1 hour:** ~$1.30  
**⚠️ If left running for 24 hours:** ~$31

---

## Bonus: HLS vs DASH

See [docs/hls-vs-dash.md](docs/hls-vs-dash.md) for a detailed comparison covering:
- Protocol differences and manifest formats
- Segment formats (MPEG-TS vs fMP4/CMAF)
- Browser compatibility and DRM support
- When to use which protocol

---

## Bonus: LL-HLS Analysis

See [docs/ll-hls-comparison.md](docs/ll-hls-comparison.md) for a detailed analysis covering:
- Why traditional HLS has 15-30s latency
- How LL-HLS reduces it to 2-5s (partial segments, blocking playlist reload, preload hints)
- Configuration differences in MediaPackage
- Tradeoffs and when to use each

---

## Troubleshooting

### OBS can't connect to SRT endpoint
- Verify the SRT URL format: `srt://IP:PORT`
- Check that MediaConnect Flow is in "ACTIVE" state
- Ensure your IP isn't blocked (whitelist is set to 0.0.0.0/0 for demo)

### No video in web player
- Confirm MediaLive channel is started: `aws medialive describe-channel --channel-id <id>`
- Check the CloudFront distribution is deployed (status: "Deployed")
- Open browser DevTools → Network tab → look for .m3u8 requests and their status codes
- Try the direct MediaPackage URL instead of CloudFront to isolate CDN issues

### Buffering / poor quality
- Check OBS output settings — ensure bitrate matches or exceeds the expected input
- The ABR player needs a few segments to stabilize its bandwidth estimate
- Check the info panel in the web player for bandwidth and buffer stats

### Terraform destroy fails
- Some resources (especially CloudFront) take time to delete
- Run `terraform destroy` again if it times out
- Manually check the AWS console for orphaned resources tagged with `thmanyah-streaming-assignment`

---

## Project Structure

```
.
├── README.md                          # This file
├── streeming-engineer-assignment.md   # Original assignment brief
├── architecture/
│   └── diagram.mmd                    # Mermaid architecture diagram
├── terraform/
│   ├── main.tf                        # Provider config, tags
│   ├── variables.tf                   # All configurable parameters
│   ├── outputs.tf                     # SRT endpoint, playback URLs
│   ├── iam.tf                         # IAM roles for MediaLive/MediaConnect
│   ├── mediaconnect.tf                # SRT ingest flow
│   ├── medialive.tf                   # Transcoding channel (ABR ladder)
│   ├── mediapackage.tf                # HLS packaging endpoint
│   └── cloudfront.tf                  # CDN distribution
├── web-player/
│   └── index.html                     # HLS player (hls.js)
└── docs/
    ├── hls-vs-dash.md                 # HLS vs DASH comparison
    └── ll-hls-comparison.md           # LL-HLS analysis
```

---

## License

This project was created as an assignment for Thmanyah's Streaming Engineer position.
