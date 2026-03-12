# MediaPackage channel + HLS endpoint

# MediaPackage channel

resource "aws_media_package_channel" "main" {
  channel_id  = "${var.project_name}-channel"
  description = "Live streaming channel for Thmanyah assignment"

  tags = {
    Name = "${var.project_name}-channel"
  }
}

# HLS endpoint (via CloudFormation; no native TF endpoint resource)

resource "aws_cloudformation_stack" "mediapackage_endpoint" {
  name = "${var.project_name}-hls-endpoint"

  template_body = jsonencode({
    AWSTemplateFormatVersion = "2010-09-09"
    Description              = "MediaPackage HLS Origin Endpoint"

    Resources = {
      HlsEndpoint = {
        Type = "AWS::MediaPackage::OriginEndpoint"
        Properties = {
          Id          = "${var.project_name}-hls-endpoint"
          ChannelId   = aws_media_package_channel.main.channel_id
          Description = "HLS origin endpoint for live streaming"

          HlsPackage = {
            SegmentDurationSeconds = var.segment_duration_sec

            PlaylistWindowSeconds = var.hls_playlist_window_sec

            PlaylistType = "EVENT"

            IncludeIframeOnlyStream = false

            UseAudioRenditionGroup = false
          }

          StartoverWindowSeconds = 0

          TimeDelaySeconds = 0
        }
      }
    }

    Outputs = {
      EndpointUrl = {
        Value = { "Fn::GetAtt" = ["HlsEndpoint", "Url"] }
      }
    }
  })

  tags = {
    Name = "${var.project_name}-hls-endpoint"
  }
}

# Derived values for CloudFront origin settings
locals {
  mediapackage_endpoint_url = aws_cloudformation_stack.mediapackage_endpoint.outputs["EndpointUrl"]

  mediapackage_hostname = regex("https://([^/]+)", local.mediapackage_endpoint_url)[0]

  mediapackage_origin_path = regex("https://[^/]+(/.+)", local.mediapackage_endpoint_url)[0]
}
