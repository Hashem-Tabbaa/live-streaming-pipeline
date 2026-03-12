# CloudFront distribution for HLS delivery

resource "aws_cloudfront_distribution" "live_stream" {
  enabled         = true
  is_ipv6_enabled = true
  comment         = "Thmanyah live streaming CDN distribution"

  # MediaPackage origin
  origin {
    domain_name = local.mediapackage_hostname
    origin_id   = "mediapackage-origin"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  # Default behavior: manifests
  default_cache_behavior {
    target_origin_id       = "mediapackage-origin"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]

    forwarded_values {
      query_string = true
      headers      = ["Origin"]

      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = var.manifest_ttl_sec
    max_ttl     = var.manifest_ttl_sec

    compress = true
  }

  # Segment behavior (.ts)
  ordered_cache_behavior {
    path_pattern           = "*.ts"
    target_origin_id       = "mediapackage-origin"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]

    forwarded_values {
      query_string = true
      headers      = ["Origin"]

      cookies {
        forward = "none"
      }
    }

    min_ttl     = var.segment_ttl_sec
    default_ttl = var.segment_ttl_sec
    max_ttl     = var.segment_ttl_sec

    compress = false
  }

  # Segment behavior (.m4s)
  ordered_cache_behavior {
    path_pattern           = "*.m4s"
    target_origin_id       = "mediapackage-origin"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]

    forwarded_values {
      query_string = true
      headers      = ["Origin"]

      cookies {
        forward = "none"
      }
    }

    min_ttl     = var.segment_ttl_sec
    default_ttl = var.segment_ttl_sec
    max_ttl     = var.segment_ttl_sec

    compress = false
  }

  # No geo restrictions
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # Default CloudFront certificate
  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Name = "${var.project_name}-cdn"
  }
}
