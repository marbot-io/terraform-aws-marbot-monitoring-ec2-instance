terraform {
  required_version = "~> 0.12"
  required_providers {
    aws = ">= 2.48.0, < 3"
    random = "~> 2.2"
  }
}

data "aws_partition" "current" {}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

##########################################################################
#                                                                        #
#                                 TOPIC                                  #
#                                                                        #
##########################################################################

resource "aws_sns_topic" "marbot" {
  count = var.enabled ? 1 : 0

  tags = var.tags
}

resource "aws_sns_topic_policy" "marbot" {
  count  = var.enabled ? 1 : 0

  arn    = join("", aws_sns_topic.marbot.*.arn)
  policy = data.aws_iam_policy_document.topic_policy.json
}

data "aws_iam_policy_document" "topic_policy" {
  statement {
    sid       = "Sid1"
    effect    = "Allow"
    actions   = ["sns:Publish"]
    resources = [join("", aws_sns_topic.marbot.*.arn)]

    principals {
      type        = "Service"
      identifiers = [
        "events.amazonaws.com",
      ]
    }
  }

  statement {
    sid       = "Sid2"
    effect    = "Allow"
    actions   = ["sns:Publish"]
    resources = [join("", aws_sns_topic.marbot.*.arn)]

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceOwner"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_sns_topic_subscription" "marbot" {
  depends_on = [aws_sns_topic_policy.marbot]
  count      = var.enabled ? 1 : 0

  topic_arn              = join("", aws_sns_topic.marbot.*.arn)
  protocol               = "https"
  endpoint               = "https://api.marbot.io/${var.stage}/endpoint/${var.endpoint_id}"
  endpoint_auto_confirms = true
  delivery_policy        = <<JSON
{
  "healthyRetryPolicy": {
    "minDelayTarget": 1,
    "maxDelayTarget": 60,
    "numRetries": 100,
    "numNoDelayRetries": 0,
    "backoffFunction": "exponential"
  },
  "throttlePolicy": {
    "maxReceivesPerSecond": 1
  }
}
JSON
}



resource "aws_cloudwatch_event_rule" "monitoring_jump_start_connection" {
  depends_on = [aws_sns_topic_subscription.marbot]
  count      = var.enabled ? 1 : 0

  name                = "marbot-ec2-instance-connection-${random_id.id8.hex}"
  description         = "Monitoring Jump Start connection. (created by marbot)"
  schedule_expression = "rate(30 days)"
  tags                = var.tags
}

resource "aws_cloudwatch_event_target" "monitoring_jump_start_connection" {
  count = var.enabled ? 1 : 0

  rule      = join("", aws_cloudwatch_event_rule.monitoring_jump_start_connection.*.name)
  target_id = "marbot"
  arn       = join("", aws_sns_topic.marbot.*.arn)
  input     = <<JSON
{
  "Type": "monitoring-jump-start-tf-connection",
  "Module": "ec2-instance",
  "Version": "0.1.0",
  "Partition": "${data.aws_partition.current.partition}",
  "AccountId": "${data.aws_caller_identity.current.account_id}",
  "Region": "${data.aws_region.current.name}"
}
JSON
}

##########################################################################
#                                                                        #
#                                 ALARMS                                 #
#                                                                        #
##########################################################################

resource "random_id" "id8" {
  byte_length = 8
}



resource "aws_cloudwatch_metric_alarm" "cpu_utilization" {
  depends_on = [aws_sns_topic_subscription.marbot]
  count      = (var.cpu_utilization_threshold >= 0 && var.enabled) ? 1 : 0

  alarm_name          = "marbot-ec2-instance-cpu-utilization-${random_id.id8.hex}"
  alarm_description   = "Average CPU utilization over last 10 minutes too high. (created by marbot)"
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 600
  evaluation_periods  = 1
  comparison_operator = "GreaterThanThreshold"
  threshold           = var.cpu_utilization_threshold
  alarm_actions       = [join("", aws_sns_topic.marbot.*.arn)]
  ok_actions          = [join("", aws_sns_topic.marbot.*.arn)]
  dimensions          = {
    InstanceId = var.instance_id
  }
  treat_missing_data  = "notBreaching"
  tags                = var.tags
}



resource "aws_cloudwatch_metric_alarm" "cpu_credit_balance" {
  depends_on = [aws_sns_topic_subscription.marbot]
  count      = (var.cpu_credit_balance_threshold >= 0 && var.enabled) ? 1 : 0

  alarm_name          = "marbot-ec2-instance-cpu-credit-balance-${random_id.id8.hex}"
  alarm_description   = "Average CPU credit balance over last 10 minutes too low, expect a significant performance drop soon. (created by marbot)"
  namespace           = "AWS/EC2"
  metric_name         = "CPUCreditBalance"
  statistic           = "Average"
  period              = 600
  evaluation_periods  = 1
  comparison_operator = "LessThanThreshold"
  threshold           = var.cpu_credit_balance_threshold
  alarm_actions       = [join("", aws_sns_topic.marbot.*.arn)]
  ok_actions          = [join("", aws_sns_topic.marbot.*.arn)]
  dimensions          = {
    InstanceId = var.instance_id
  }
  treat_missing_data  = "notBreaching"
  tags                = var.tags
}



resource "aws_cloudwatch_metric_alarm" "ebs_io_credit_balance" {
  depends_on = [aws_sns_topic_subscription.marbot]
  count      = (var.ebs_io_credit_balance_threshold >= 0 && var.enabled) ? 1 : 0

  alarm_name          = "marbot-ec2-instance-ebs-io-credit-balance-${random_id.id8.hex}"
  alarm_description   = "Average EBS IO credit balance over last 10 minutes too low, expect a significant performance drop soon. (created by marbot)"
  namespace           = "AWS/EC2"
  metric_name         = "EBSIOBalance%"
  statistic           = "Average"
  period              = 600
  evaluation_periods  = 1
  comparison_operator = "LessThanThreshold"
  threshold           = var.ebs_io_credit_balance_threshold
  alarm_actions       = [join("", aws_sns_topic.marbot.*.arn)]
  ok_actions          = [join("", aws_sns_topic.marbot.*.arn)]
  dimensions          = {
    InstanceId = var.instance_id
  }
  treat_missing_data  = "notBreaching"
  tags                = var.tags
}



resource "aws_cloudwatch_metric_alarm" "ebs_throughput_credit_balance" {
  depends_on = [aws_sns_topic_subscription.marbot]
  count      = (var.ebs_throughput_credit_balance_threshold >= 0 && var.enabled) ? 1 : 0

  alarm_name          = "marbot-ec2-instance-ebs-throughput-credit-balance-${random_id.id8.hex}"
  alarm_description   = "Average EBS throughput credit balance over last 10 minutes too low, expect a significant performance drop soon. (created by marbot)"
  namespace           = "AWS/EC2"
  metric_name         = "EBSByteBalance%"
  statistic           = "Average"
  period              = 600
  evaluation_periods  = 1
  comparison_operator = "LessThanThreshold"
  threshold           = var.ebs_throughput_credit_balance_threshold
  alarm_actions       = [join("", aws_sns_topic.marbot.*.arn)]
  ok_actions          = [join("", aws_sns_topic.marbot.*.arn)]
  dimensions          = {
    InstanceId = var.instance_id
  }
  treat_missing_data  = "notBreaching"
  tags                = var.tags
}



resource "aws_cloudwatch_metric_alarm" "status_check" {
  depends_on = [aws_sns_topic_subscription.marbot]
  count      = var.enabled ? 1 : 0

  alarm_name          = "marbot-ec2-instance-status-check-${random_id.id8.hex}"
  alarm_description   = "EC2 instance status check or the system status check has failed. (created by marbot)"
  namespace           = "AWS/EC2"
  metric_name         = "StatusCheckFailed"
  statistic           = "Sum"
  period              = 600
  evaluation_periods  = 1
  comparison_operator = "GreaterThanThreshold"
  threshold           = 0
  alarm_actions       = [join("", aws_sns_topic.marbot.*.arn)]
  ok_actions          = [join("", aws_sns_topic.marbot.*.arn)]
  dimensions          = {
    InstanceId = var.instance_id
  }
  treat_missing_data  = "notBreaching"
  tags                = var.tags
}



data "http" "network" {
  url = "https://s3-eu-west-1.amazonaws.com/monitoring-jump-start/data/network.json"
}

locals {
  network          = lookup(jsondecode(data.http.network.body), var.instance_type, {})
  network_baseline = lookup(local.network, "baseline", -1)
  network_burst    = lookup(local.network, "burst", -1)
}

resource "aws_cloudwatch_metric_alarm" "network_burst_utilization" {
  depends_on = [aws_sns_topic_subscription.marbot]
  count      = (var.network_utilization_threshold >= 0 && local.network_baseline >= 0 && local.network_burst >= 0 && var.enabled) ? 1 : 0

  alarm_name          = "marbot-ec2-instance-network-burst-utilization-${random_id.id8.hex}"
  alarm_description   = "Average Network In+Out burst utilization over last 10 minutes too high, expect a significant performance drop soon. (created by marbot)"
  evaluation_periods  = 1
  comparison_operator = "GreaterThanThreshold"
  threshold           = floor(local.network_burst * var.cpu_utilization_threshold) / 100
  alarm_actions       = [join("", aws_sns_topic.marbot.*.arn)]
  ok_actions          = [join("", aws_sns_topic.marbot.*.arn)]
  treat_missing_data  = "notBreaching"
  tags                = var.tags

  metric_query {
    id    = "in"
    label = "In"

    metric {
      namespace   = "AWS/EC2"
      metric_name = "NetworkIn" # bytes per minute
      period      = "600"
      stat        = "Average"
      unit        = "Bytes"

      dimensions = {
        InstanceId = var.instance_id
      }
    }
  }

  metric_query {
    id    = "out"
    label = "Out"

    metric {
      namespace   = "AWS/EC2"
      metric_name = "NetworkOut" # bytes per minute
      period      = "600"
      stat        = "Average"
      unit        = "Bytes"

      dimensions = {
        InstanceId = var.instance_id
      }
    }
  }

  metric_query {
    id          = "inout"
    label       = "In-Out"
    expression  = "(in+out)/60*8/1000/1000/1000" # to Gbit/s
    return_data = true
  }
}

resource "aws_cloudwatch_metric_alarm" "network_baseline_utilization" {
  depends_on = [aws_sns_topic_subscription.marbot]
  count      = (var.network_utilization_threshold >= 0 && local.network_baseline >= 0 && local.network_burst >= 0 && var.enabled) ? 1 : 0

  alarm_name          = "marbot-ec2-instance-network-baseline-utilization-${random_id.id8.hex}"
  alarm_description   = "Average Network In+Out baseline utilization over last 10 minutes too high, you might can burst. (created by marbot)"
  evaluation_periods  = 1
  comparison_operator = "GreaterThanThreshold"
  threshold           = floor(local.network_baseline * var.cpu_utilization_threshold) / 100
  alarm_actions       = [join("", aws_sns_topic.marbot.*.arn)]
  ok_actions          = [join("", aws_sns_topic.marbot.*.arn)]
  treat_missing_data  = "notBreaching"
  tags                = var.tags

  metric_query {
    id    = "in"
    label = "In"

    metric {
      namespace   = "AWS/EC2"
      metric_name = "NetworkIn" # bytes per minute
      period      = "600"
      stat        = "Average"
      unit        = "Bytes"

      dimensions = {
        InstanceId = var.instance_id
      }
    }
  }

  metric_query {
    id    = "out"
    label = "Out"

    metric {
      namespace   = "AWS/EC2"
      metric_name = "NetworkOut" # bytes per minute
      period      = "600"
      stat        = "Average"
      unit        = "Bytes"

      dimensions = {
        InstanceId = var.instance_id
      }
    }
  }

  metric_query {
    id          = "inout"
    label       = "In-Out"
    expression  = "(in+out)/60*8/1000/1000/1000" # to Gbit/s
    return_data = true
  }
}

resource "aws_cloudwatch_metric_alarm" "network_utilization" {
  depends_on = [aws_sns_topic_subscription.marbot]
  count      = (var.network_utilization_threshold >= 0 && local.network_baseline >= 0 && local.network_burst < 0 && var.enabled) ? 1 : 0

  alarm_name          = "marbot-ec2-instance-network-utilization-${random_id.id8.hex}"
  alarm_description   = "Average Network In+Out utilization over last 10 minutes too high. (created by marbot)"
  evaluation_periods  = 1
  comparison_operator = "GreaterThanThreshold"
  threshold           = floor(local.network_baseline * var.cpu_utilization_threshold) / 100 
  alarm_actions       = [join("", aws_sns_topic.marbot.*.arn)]
  ok_actions          = [join("", aws_sns_topic.marbot.*.arn)]
  treat_missing_data  = "notBreaching"
  tags                = var.tags

  metric_query {
    id    = "in"
    label = "In"

    metric {
      namespace   = "AWS/EC2"
      metric_name = "NetworkIn" # bytes per minute
      period      = "600"
      stat        = "Average"
      unit        = "Bytes"

      dimensions = {
        InstanceId = var.instance_id
      }
    }
  }

  metric_query {
    id    = "out"
    label = "Out"

    metric {
      namespace   = "AWS/EC2"
      metric_name = "NetworkOut" # bytes per minute
      period      = "600"
      stat        = "Average"
      unit        = "Bytes"

      dimensions = {
        InstanceId = var.instance_id
      }
    }
  }

  metric_query {
    id          = "inout"
    label       = "In-Out"
    expression  = "(in+out)/60*8/1000/1000/1000" # to Gbit/s
    return_data = true
  }
}
