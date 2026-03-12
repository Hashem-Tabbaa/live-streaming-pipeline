# Variables

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "thmanyah-live"
}

# Ingest

variable "srt_port" {
  description = "SRT ingest port"
  type        = number
  default     = 9000
}

variable "srt_latency_ms" {
  description = "SRT latency buffer in milliseconds"
  type        = number
  default     = 1000
}

# Transcoding

variable "segment_duration_sec" {
  description = "HLS segment duration in seconds"
  type        = number
  default     = 6
}

variable "gop_size_sec" {
  description = "GOP size in seconds"
  type        = number
  default     = 2
}

variable "framerate" {
  description = "Video framerate (frames per second)"
  type        = number
  default     = 30
}

# ABR ladder

variable "abr_renditions" {
  description = "ABR renditions"
  type = list(object({
    name       = string
    width      = number
    height     = number
    bitrate    = number
    profile    = string
  }))
  default = [
    {
      name    = "1080p"
      width   = 1920
      height  = 1080
      bitrate = 5000000 # 5 Mbps
      profile = "HIGH"
    },
    {
      name    = "720p"
      width   = 1280
      height  = 720
      bitrate = 3000000 # 3 Mbps
      profile = "MAIN"
    },
    {
      name    = "480p"
      width   = 854
      height  = 480
      bitrate = 1500000 # 1.5 Mbps
      profile = "MAIN"
    }
  ]
}

variable "audio_bitrate" {
  description = "AAC audio bitrate"
  type        = number
  default     = 128000
}

# MediaPackage

variable "hls_playlist_window_sec" {
  description = "Duration of the HLS live manifest window in seconds"
  type        = number
  default     = 60
}

# CloudFront

variable "manifest_ttl_sec" {
  description = "CloudFront TTL for manifests"
  type        = number
  default     = 1
}

variable "segment_ttl_sec" {
  description = "CloudFront TTL for segments"
  type        = number
  default     = 86400
}
