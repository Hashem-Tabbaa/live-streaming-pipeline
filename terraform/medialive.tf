# MediaLive input + channel

# MediaConnect input

resource "aws_medialive_input" "mediaconnect_input" {
  name     = "${var.project_name}-mediaconnect-input"
  type     = "MEDIACONNECT"
  role_arn = aws_iam_role.medialive_role.arn

  media_connect_flows {
    flow_arn = local.mediaconnect_flow_arn
  }

  tags = {
    Name = "${var.project_name}-mediaconnect-input"
  }
}

# Transcoding channel

resource "aws_medialive_channel" "live_channel" {
  name          = "${var.project_name}-channel"
  channel_class = "SINGLE_PIPELINE"
  role_arn      = aws_iam_role.medialive_role.arn

  input_specification {
    codec           = "AVC"
    input_resolution = "HD"
    maximum_bitrate = "MAX_20_MBPS"
  }

  input_attachments {
    input_id              = aws_medialive_input.mediaconnect_input.id
    input_attachment_name = "mediaconnect-attachment"
  }

  destinations {
    id = "mediapackage-dest"
    media_package_settings {
      channel_id = aws_media_package_channel.main.channel_id
    }
  }

  # ABR ladder settings

  encoder_settings {

    timecode_config {
      source = "SYSTEMCLOCK"
    }

    # Shared audio
    audio_descriptions {
      audio_selector_name = "default"
      name                = "audio_1"
      codec_settings {
        aac_settings {
          bitrate           = var.audio_bitrate
          coding_mode       = "CODING_MODE_2_0"
          rate_control_mode = "CBR"
          sample_rate       = 48000
        }
      }
    }

    # 1080p
    video_descriptions {
      name   = "video_1080p"
      width  = 1920
      height = 1080
      codec_settings {
        h264_settings {
          bitrate               = 5000000
          framerate_control     = "SPECIFIED"
          framerate_numerator   = var.framerate
          framerate_denominator = 1
          gop_size              = var.gop_size_sec
          gop_size_units        = "SECONDS"
          par_control           = "SPECIFIED"
          par_numerator         = 1
          par_denominator       = 1
          profile               = "HIGH"
          level                 = "H264_LEVEL_AUTO"
          rate_control_mode     = "CBR"
          scene_change_detect   = "ENABLED"
          adaptive_quantization = "HIGH"
        }
      }
    }

    # 720p
    video_descriptions {
      name   = "video_720p"
      width  = 1280
      height = 720
      codec_settings {
        h264_settings {
          bitrate               = 3000000
          framerate_control     = "SPECIFIED"
          framerate_numerator   = var.framerate
          framerate_denominator = 1
          gop_size              = var.gop_size_sec
          gop_size_units        = "SECONDS"
          par_control           = "SPECIFIED"
          par_numerator         = 1
          par_denominator       = 1
          profile               = "MAIN"
          level                 = "H264_LEVEL_AUTO"
          rate_control_mode     = "CBR"
          scene_change_detect   = "ENABLED"
          adaptive_quantization = "HIGH"
        }
      }
    }

    # 480p
    video_descriptions {
      name   = "video_480p"
      width  = 854
      height = 480
      codec_settings {
        h264_settings {
          bitrate               = 1500000
          framerate_control     = "SPECIFIED"
          framerate_numerator   = var.framerate
          framerate_denominator = 1
          gop_size              = var.gop_size_sec
          gop_size_units        = "SECONDS"
          par_control           = "SPECIFIED"
          par_numerator         = 1
          par_denominator       = 1
          profile               = "MAIN"
          level                 = "H264_LEVEL_AUTO"
          rate_control_mode     = "CBR"
          scene_change_detect   = "ENABLED"
          adaptive_quantization = "HIGH"
        }
      }
    }

    # HLS output group to MediaPackage

    output_groups {
      name = "hls-mediapackage"

      output_group_settings {
        media_package_group_settings {
          destination {
            destination_ref_id = "mediapackage-dest"
          }
        }
      }

      # 1080p output
      outputs {
        output_name            = "1080p"
        video_description_name = "video_1080p"
        audio_description_names = ["audio_1"]
        output_settings {
          media_package_output_settings {}
        }
      }

      # 720p output
      outputs {
        output_name            = "720p"
        video_description_name = "video_720p"
        audio_description_names = ["audio_1"]
        output_settings {
          media_package_output_settings {}
        }
      }

      # 480p output
      outputs {
        output_name            = "480p"
        video_description_name = "video_480p"
        audio_description_names = ["audio_1"]
        output_settings {
          media_package_output_settings {}
        }
      }
    }
  }

  tags = {
    Name = "${var.project_name}-channel"
  }
}
