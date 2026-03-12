# MediaConnect flow (via CloudFormation; no native TF resource)

resource "aws_cloudformation_stack" "mediaconnect_flow" {
  name = "${var.project_name}-mc-flow"

  template_body = jsonencode({
    AWSTemplateFormatVersion = "2010-09-09"
    Description              = "MediaConnect SRT Ingest Flow"

    Resources = {
      SrtFlow = {
        Type = "AWS::MediaConnect::Flow"
        Properties = {
          Name = "${var.project_name}-srt-ingest"
          Source = {
            Name            = "srt-source"
            Description     = "SRT ingest source"
            Protocol        = "srt-listener"
            IngestPort      = var.srt_port
            WhitelistCidr   = "0.0.0.0/0"
          }
        }
      }
    }

    Outputs = {
      FlowArn = {
        Value = { "Fn::GetAtt" = ["SrtFlow", "FlowArn"] }
      }
      SourceIngestIp = {
        Value = { "Fn::GetAtt" = ["SrtFlow", "Source.IngestIp"] }
      }
    }
  })

  tags = {
    Name = "${var.project_name}-mediaconnect-flow"
  }
}

locals {
  # Values read from CloudFormation outputs
  mediaconnect_flow_arn  = aws_cloudformation_stack.mediaconnect_flow.outputs["FlowArn"]
  mediaconnect_ingest_ip = aws_cloudformation_stack.mediaconnect_flow.outputs["SourceIngestIp"]
}
