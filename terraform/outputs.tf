# Useful outputs

output "srt_ingest_endpoint" {
  description = "SRT ingest URL for OBS"
  value       = "srt://${local.mediaconnect_ingest_ip}:${var.srt_port}"
}

output "mediaconnect_flow_arn" {
  description = "MediaConnect Flow ARN"
  value       = local.mediaconnect_flow_arn
}

output "mediapackage_channel_id" {
  description = "MediaPackage Channel ID"
  value       = aws_media_package_channel.main.channel_id
}

output "mediapackage_hls_endpoint_url" {
  description = "MediaPackage HLS origin endpoint URL (used by CloudFront)"
  value       = local.mediapackage_endpoint_url
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name"
  value       = aws_cloudfront_distribution.live_stream.domain_name
}

output "hls_playback_url" {
  description = "Final HLS playback URL"
  value       = "https://${aws_cloudfront_distribution.live_stream.domain_name}${local.mediapackage_origin_path}"
}

