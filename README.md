# Thmanyah Live Streaming Pipeline

This repository contains a Terraform-based live streaming pipeline on AWS.

## Architecture Diagram

![Architecture Diagram](Thmanyah.png)

## Documentation

- PDF: [Live-Streaming-Pipline-Documentation.pdf](Live-Streaming-Pipline-Documentation.pdf)

## Demo Video

- YouTube: [Project Demo](https://www.youtube.com/watch?v=sgwHCokzAyg)

## Repository Contents

- `terraform/`: Infrastructure code for MediaConnect, MediaLive, MediaPackage, CloudFront, and IAM
- `web-player/`: Simple HLS player (`index.html`)

## Prerequisites

- Terraform 1.5+
- AWS CLI v2
- OBS Studio
- AWS account with permissions for Media services, IAM, CloudFormation, and CloudFront

Set up AWS credentials:

- Run `aws configure`
- Use region `us-east-1`

## Setup

From the project root:

- `cd terraform`
- `terraform init`
- `terraform validate`
- `terraform plan`

## Deploy

- `cd terraform`
- `terraform apply`

After deployment, use these outputs:

- `srt_ingest_endpoint` for OBS stream server
- `hls_playback_url` for browser playback

## Stream Test

1. Open OBS Studio.
2. Go to `Settings > Stream`.
3. Set `Service` to `Custom`.
4. Set `Server` to the `srt_ingest_endpoint` output.
5. Start streaming in OBS.
6. Open `web-player/index.html` in a browser.
7. Paste `hls_playback_url` and play.

## Destroy Resources

Media services continue billing while running.

- `cd terraform`
- `terraform destroy -auto-approve`

## Notes

- MediaConnect flow and MediaPackage endpoint are provisioned through CloudFormation stacks from Terraform.
- If playback fails, check that MediaConnect is `ACTIVE` and MediaLive channel is `RUNNING`.

## Technical Parameters Used

### 1) Ingest - SRT / Latency Mode

- **Latency mode value:** `1000 ms`
- **Why:** Balance between low delay and packet-loss recovery over public internet.
- **Meaning:** SRT uses this buffer window to retransmit lost packets before dropping them.

Why this latency mode:
- `1000ms` works well for public internet tests.
- Lower values reduce delay but reduce packet-loss tolerance.
- Higher values improve stability but increase end-to-end latency.

### 2) Transcoding (MediaLive) - ABR Ladder

The ABR ladder includes:

| Rendition | Resolution | Video Bitrate | Codec | GOP | Segment Duration |
|---|---|---|---|---|---|
| 1080p | 1920x1080 | 5 Mbps | H.264/AVC | 2s | 6s |
| 720p  | 1280x720  | 3 Mbps | H.264/AVC | 2s | 6s |
| 480p  | 854x480   | 1.5 Mbps | H.264/AVC | 2s | 6s |

Why these parameters:
- **Bitrate ladder:** Covers high/medium/low bandwidth users.
- **GOP = 2s:** Good switching behavior for adaptive streaming.
- **Segment = 6s:** Stable and common HLS live setting.
- **Codec = H.264:** Broad browser/device compatibility.

### 3) Packaging (MediaPackage)

- **HLS Endpoint:** Created and connected to MediaLive output.
- **Segment duration:** `6 seconds`
- **Manifest structure:** Master `.m3u8` + variant playlists per rendition + media segments.
- **Packaging type used:** HLS (MPEG-TS segments).

Packaging summary:
- HLS endpoint created with segment duration = `6s`.
- Manifest structure: master playlist + rendition playlists + media segments.
- Packaging type: `HLS`.

### 4) Distribution (CloudFront CDN)

- **Broadcast distribution:** Stream delivered via CloudFront CDN.
- **Cache strategy:**
	- Manifests (`.m3u8`) TTL = `1s`
	- Segments (`.ts`, `.m4s`) TTL = `86400s` (24h)
- **Why:** Manifest changes frequently, segments are immutable.

CDN distribution summary:
- Stream is delivered through CloudFront.
- Cache policy is file-type based (short for manifests, long for segments).
- TTL values: `1s` for manifests and `24h` for segments.

### Playback Link

- Use Terraform output `hls_playback_url` as the playback URL.
