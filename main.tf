terraform {
  required_version = ">= 0.12.0"
  required_providers {
    aws    = ">= 2.48.0"
    random = ">= 2.2"
  }
}

data "aws_partition" "current" {}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "http" "network" {
  url = "https://s3-eu-west-1.amazonaws.com/monitoring-jump-start/data/network.json"
}
  
data "aws_instance" "instance" {
  instance_id = var.instance_id
}

data "aws_ec2_instance_type" "instance" {
  instance_type = data.aws_instance.instance.instance_type
}

locals {
  topic_arn                = var.create_topic == false ? var.topic_arn : join("", aws_sns_topic.marbot.*.arn)
  network                  = lookup(jsondecode(data.http.network.response_body), data.aws_instance.instance.instance_type, {})
  network_baseline         = lookup(local.network, "baseline", -1)
  network_burst            = lookup(local.network, "burst", -1)
  instance_name            = lookup(data.aws_instance.instance.tags, "Name", "")
  alarm_description_prefix = (local.instance_name == "") ? "" : "${local.instance_name}'s "
  enabled                  = var.enabled && lookup(data.aws_instance.instance.tags, "marbot", "on") != "off" && lookup(data.aws_instance.instance.tags, "marbot:enabled", "true") != "false"

  cpu_utilization                        = (local.cpu_utilization_threshold < -1.5) ? "anomaly_detection" : ((local.cpu_utilization_threshold < -0.5) ? "off" : lookup(data.aws_instance.instance.tags, "marbot:cpu-utilization", var.cpu_utilization))
  cpu_utilization_threshold              = try(tonumber(lookup(data.aws_instance.instance.tags, "marbot:cpu-utilization:threshold", var.cpu_utilization_threshold)), var.cpu_utilization_threshold)
  cpu_utilization_period_raw             = try(tonumber(lookup(data.aws_instance.instance.tags, "marbot:cpu-utilization:period", var.cpu_utilization_period)), var.cpu_utilization_period)
  cpu_utilization_period                 = min(max(floor(local.cpu_utilization_period_raw / 60) * 60, 60), 86400)
  cpu_utilization_evaluation_periods_raw = try(tonumber(lookup(data.aws_instance.instance.tags, "marbot:cpu-utilization:evaluation-periods", var.cpu_utilization_evaluation_periods)), var.cpu_utilization_evaluation_periods)
  cpu_utilization_evaluation_periods     = min(max(local.cpu_utilization_evaluation_periods_raw, 1), floor(86400 / local.cpu_utilization_period))

  cpu_credit_balance                        = (local.cpu_credit_balance_threshold < -1.5) ? "anomaly_detection" : ((local.cpu_credit_balance_threshold < -0.5) ? "off" : lookup(data.aws_instance.instance.tags, "marbot:cpu-credit-balance", var.cpu_credit_balance))
  cpu_credit_balance_threshold              = try(tonumber(lookup(data.aws_instance.instance.tags, "marbot:cpu-credit-balance:threshold", var.cpu_credit_balance_threshold)), var.cpu_credit_balance_threshold)
  cpu_credit_balance_period_raw             = try(tonumber(lookup(data.aws_instance.instance.tags, "marbot:cpu-credit-balance:period", var.cpu_credit_balance_period)), var.cpu_credit_balance_period)
  cpu_credit_balance_period                 = min(max(floor(local.cpu_credit_balance_period_raw / 60) * 60, 60), 86400)
  cpu_credit_balance_evaluation_periods_raw = try(tonumber(lookup(data.aws_instance.instance.tags, "marbot:cpu-credit-balance:evaluation-periods", var.cpu_credit_balance_evaluation_periods)), var.cpu_credit_balance_evaluation_periods)
  cpu_credit_balance_evaluation_periods     = min(max(local.cpu_credit_balance_evaluation_periods_raw, 1), floor(86400 / local.cpu_credit_balance_period))

  ebs_io_credit_balance                        = (local.ebs_io_credit_balance_threshold < -1.5) ? "anomaly_detection" : ((local.ebs_io_credit_balance_threshold < -0.5) ? "off" : lookup(data.aws_instance.instance.tags, "marbot:ebs-io-credit-balance", var.ebs_io_credit_balance))
  ebs_io_credit_balance_threshold              = try(tonumber(lookup(data.aws_instance.instance.tags, "marbot:ebs-io-credit-balance:threshold", var.ebs_io_credit_balance_threshold)), var.ebs_io_credit_balance_threshold)
  ebs_io_credit_balance_period_raw             = try(tonumber(lookup(data.aws_instance.instance.tags, "marbot:ebs-io-credit-balance:period", var.ebs_io_credit_balance_period)), var.ebs_io_credit_balance_period)
  ebs_io_credit_balance_period                 = min(max(floor(local.ebs_io_credit_balance_period_raw / 60) * 60, 60), 86400)
  ebs_io_credit_balance_evaluation_periods_raw = try(tonumber(lookup(data.aws_instance.instance.tags, "marbot:ebs-io-credit-balance:evaluation-periods", var.ebs_io_credit_balance_evaluation_periods)), var.ebs_io_credit_balance_evaluation_periods)
  ebs_io_credit_balance_evaluation_periods     = min(max(local.ebs_io_credit_balance_evaluation_periods_raw, 1), floor(86400 / local.ebs_io_credit_balance_period))

  ebs_throughput_credit_balance                        = (local.ebs_throughput_credit_balance_threshold < -1.5) ? "anomaly_detection" : ((local.ebs_throughput_credit_balance_threshold < -0.5) ? "off" : lookup(data.aws_instance.instance.tags, "marbot:ebs-throughput-credit-balance", var.ebs_throughput_credit_balance))
  ebs_throughput_credit_balance_threshold              = try(tonumber(lookup(data.aws_instance.instance.tags, "marbot:ebs-throughput-credit-balance:threshold", var.ebs_throughput_credit_balance_threshold)), var.ebs_throughput_credit_balance_threshold)
  ebs_throughput_credit_balance_period_raw             = try(tonumber(lookup(data.aws_instance.instance.tags, "marbot:ebs-throughput-credit-balance:period", var.ebs_throughput_credit_balance_period)), var.ebs_throughput_credit_balance_period)
  ebs_throughput_credit_balance_period                 = min(max(floor(local.ebs_throughput_credit_balance_period_raw / 60) * 60, 60), 86400)
  ebs_throughput_credit_balance_evaluation_periods_raw = try(tonumber(lookup(data.aws_instance.instance.tags, "marbot:ebs-throughput-credit-balance:evaluation-periods", var.ebs_throughput_credit_balance_evaluation_periods)), var.ebs_throughput_credit_balance_evaluation_periods)
  ebs_throughput_credit_balance_evaluation_periods     = min(max(local.ebs_throughput_credit_balance_evaluation_periods_raw, 1), floor(86400 / local.ebs_throughput_credit_balance_period))

  network_utilization                        = (local.network_utilization_threshold < -1.5) ? "anomaly_detection" : ((local.network_utilization_threshold < -0.5) ? "off" : lookup(data.aws_instance.instance.tags, "marbot:network-utilization", var.network_utilization))
  network_utilization_threshold              = try(tonumber(lookup(data.aws_instance.instance.tags, "marbot:network-utilization:threshold", var.network_utilization_threshold)), var.network_utilization_threshold)
  network_utilization_period_raw             = try(tonumber(lookup(data.aws_instance.instance.tags, "marbot:network-utilization:period", var.network_utilization_period)), var.network_utilization_period)
  network_utilization_period                 = min(max(floor(local.network_utilization_period_raw / 60) * 60, 60), 86400)
  network_utilization_evaluation_periods_raw = try(tonumber(lookup(data.aws_instance.instance.tags, "marbot:network-utilization:evaluation-periods", var.network_utilization_evaluation_periods)), var.network_utilization_evaluation_periods)
  network_utilization_evaluation_periods     = min(max(local.network_utilization_evaluation_periods_raw, 1), floor(86400 / local.network_utilization_period))
}

##########################################################################
#                                                                        #
#                                 TOPIC                                  #
#                                                                        #
##########################################################################

resource "aws_sns_topic" "marbot" {
  count = (var.create_topic && local.enabled) ? 1 : 0

  name_prefix = "marbot"
  tags        = var.tags
}

resource "aws_sns_topic_policy" "marbot" {
  count = (var.create_topic && local.enabled) ? 1 : 0

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
      type = "Service"
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
  count      = (var.create_topic && local.enabled) ? 1 : 0

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
  count      = local.enabled ? 1 : 0

  name                = "marbot-ec2-instance-connection-${random_id.id8.hex}"
  description         = "Monitoring Jump Start connection. (created by marbot)"
  schedule_expression = "rate(30 days)"
  tags                = var.tags
}

resource "aws_cloudwatch_event_target" "monitoring_jump_start_connection" {
  count = local.enabled ? 1 : 0

  rule      = join("", aws_cloudwatch_event_rule.monitoring_jump_start_connection.*.name)
  target_id = "marbot"
  arn       = local.topic_arn
  input     = <<JSON
{
  "Type": "monitoring-jump-start-tf-connection",
  "Module": "ec2-instance",
  "Version": "1.0.0",
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
  count      = (local.cpu_utilization == "static" && local.enabled) ? 1 : 0

  alarm_name          = "marbot-ec2-instance-cpu-utilization-${random_id.id8.hex}"
  alarm_description   = "${local.alarm_description_prefix}Average CPU utilization too high. (created by marbot)"
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = local.cpu_utilization_period
  evaluation_periods  = local.cpu_utilization_evaluation_periods
  comparison_operator = "GreaterThanThreshold"
  threshold           = local.cpu_utilization_threshold
  alarm_actions       = [local.topic_arn]
  ok_actions          = [local.topic_arn]
  dimensions = {
    InstanceId = var.instance_id
  }
  treat_missing_data = "notBreaching"
  tags               = var.tags
}

resource "aws_cloudwatch_metric_alarm" "cpu_utilization_anomaly_detection" {
  depends_on = [aws_sns_topic_subscription.marbot]
  count      = ((local.cpu_utilization == "anomaly_detection" || local.cpu_utilization == "static_anomaly_detection") && local.enabled) ? 1 : 0

  alarm_name          = "marbot-ec2-instance-cpu-utilization-${random_id.id8.hex}"
  alarm_description   = "${local.alarm_description_prefix}Average CPU utilization unexpected. (created by marbot)"
  evaluation_periods  = local.cpu_utilization_evaluation_periods
  comparison_operator = "GreaterThanUpperThreshold"
  threshold_metric_id = "e1"
  alarm_actions       = [local.topic_arn]
  ok_actions          = [local.topic_arn]
  treat_missing_data  = "notBreaching"
  tags                = var.tags

  metric_query {
    id          = "e1"
    expression  = (local.cpu_utilization == "static_anomaly_detection") ? "ANOMALY_DETECTION_BAND(m2)" : "ANOMALY_DETECTION_BAND(m1)"
    label       = "CPUUtilization (expected)"
    return_data = "true"
  }

  dynamic "metric_query" {
    for_each = (local.cpu_utilization == "static_anomaly_detection") ? { enabled = true } : {}

    content {
      id          = "m2"
      expression  = "IF(m1<${local.cpu_utilization_threshold}, ${local.cpu_utilization_threshold}, m1)"
      label       = "CPUUtilization (threshold)"
      return_data = "true"
    }
  }

  metric_query {
    id          = "m1"
    return_data = (local.cpu_utilization == "anomaly_detection") ? "true" : null
    metric {
      metric_name = "CPUUtilization"
      namespace   = "AWS/EC2"
      period      = local.cpu_utilization_period
      stat        = "Average"

      dimensions = {
        InstanceId = var.instance_id
      }
    }
  }
}



resource "aws_cloudwatch_metric_alarm" "cpu_credit_balance" {
  depends_on = [aws_sns_topic_subscription.marbot]
  count      = (local.cpu_credit_balance == "static" && data.aws_ec2_instance_type.instance.burstable_performance_supported && local.enabled) ? 1 : 0

  alarm_name          = "marbot-ec2-instance-cpu-credit-balance-${random_id.id8.hex}"
  alarm_description   = "${local.alarm_description_prefix}Average CPU credit balance too low, expect a significant performance drop soon. (created by marbot)"
  namespace           = "AWS/EC2"
  metric_name         = "CPUCreditBalance"
  statistic           = "Average"
  period              = local.cpu_credit_balance_period
  evaluation_periods  = local.cpu_credit_balance_evaluation_periods
  comparison_operator = "LessThanThreshold"
  threshold           = local.cpu_credit_balance_threshold
  alarm_actions       = [local.topic_arn]
  ok_actions          = [local.topic_arn]
  dimensions = {
    InstanceId = var.instance_id
  }
  treat_missing_data = "notBreaching"
  tags               = var.tags
}

resource "aws_cloudwatch_metric_alarm" "cpu_credit_balance_anomaly_detection" {
  depends_on = [aws_sns_topic_subscription.marbot]
  count      = (local.cpu_credit_balance == "anomaly_detection" && data.aws_ec2_instance_type.instance.burstable_performance_supported && local.enabled) ? 1 : 0

  alarm_name          = "marbot-ec2-instance-cpu-credit-balance-${random_id.id8.hex}"
  alarm_description   = "${local.alarm_description_prefix}Average CPU credit balance unexpected, expect a significant performance drop soon. (created by marbot)"
  evaluation_periods  = local.cpu_credit_balance_evaluation_periods
  comparison_operator = "LessThanLowerThreshold"
  threshold_metric_id = "e1"
  alarm_actions       = [local.topic_arn]
  ok_actions          = [local.topic_arn]
  treat_missing_data  = "notBreaching"
  tags                = var.tags

  metric_query {
    id          = "e1"
    expression  = "ANOMALY_DETECTION_BAND(m1)"
    label       = "CPUCreditBalance (expected)"
    return_data = "true"
  }

  metric_query {
    id          = "m1"
    return_data = "true"
    metric {
      metric_name = "CPUCreditBalance"
      namespace   = "AWS/EC2"
      period      = local.cpu_credit_balance_period
      stat        = "Average"

      dimensions = {
        InstanceId = var.instance_id
      }
    }
  }
}



resource "aws_cloudwatch_metric_alarm" "ebs_io_credit_balance" {
  depends_on = [aws_sns_topic_subscription.marbot]
  count      = (local.ebs_io_credit_balance == "static" && (data.aws_ec2_instance_type.instance.ebs_optimized_support == "default" || (data.aws_ec2_instance_type.instance.ebs_optimized_support == "supported" && data.aws_instance.instance.ebs_optimized)) && data.aws_ec2_instance_type.instance.ebs_performance_baseline_bandwidth != data.aws_ec2_instance_type.instance.ebs_performance_maximum_bandwidth && local.enabled) ? 1 : 0

  alarm_name          = "marbot-ec2-instance-ebs-io-credit-balance-${random_id.id8.hex}"
  alarm_description   = "${local.alarm_description_prefix}Average EBS IO credit balance too low, expect a significant performance drop soon. (created by marbot)"
  namespace           = "AWS/EC2"
  metric_name         = "EBSIOBalance%"
  statistic           = "Average"
  period              = local.ebs_io_credit_balance_period
  evaluation_periods  = local.ebs_io_credit_balance_evaluation_periods
  comparison_operator = "LessThanThreshold"
  threshold           = local.ebs_io_credit_balance_threshold
  alarm_actions       = [local.topic_arn]
  ok_actions          = [local.topic_arn]
  dimensions = {
    InstanceId = var.instance_id
  }
  treat_missing_data = "notBreaching"
  tags               = var.tags
}

resource "aws_cloudwatch_metric_alarm" "ebs_io_credit_balance_anomaly_detection" {
  depends_on = [aws_sns_topic_subscription.marbot]
  count      = (local.ebs_io_credit_balance == "anomaly_detection" && (data.aws_ec2_instance_type.instance.ebs_optimized_support == "default" || (data.aws_ec2_instance_type.instance.ebs_optimized_support == "supported" && data.aws_instance.instance.ebs_optimized)) && data.aws_ec2_instance_type.instance.ebs_performance_baseline_bandwidth != data.aws_ec2_instance_type.instance.ebs_performance_maximum_bandwidth && local.enabled) ? 1 : 0

  alarm_name          = "marbot-ec2-instance-ebs-io-credit-balance-${random_id.id8.hex}"
  alarm_description   = "${local.alarm_description_prefix}Average EBS IO credit balance unexpected, expect a significant performance drop soon. (created by marbot)"
  evaluation_periods  = local.ebs_io_credit_balance_evaluation_periods
  comparison_operator = "LessThanLowerThreshold"
  threshold_metric_id = "e1"
  alarm_actions       = [local.topic_arn]
  ok_actions          = [local.topic_arn]
  treat_missing_data  = "notBreaching"
  tags                = var.tags

  metric_query {
    id          = "e1"
    expression  = "ANOMALY_DETECTION_BAND(m1)"
    label       = "EBSIOBalance% (expected)"
    return_data = "true"
  }

  metric_query {
    id          = "m1"
    return_data = "true"
    metric {
      metric_name = "EBSIOBalance%"
      namespace   = "AWS/EC2"
      period      = local.ebs_io_credit_balance_period
      stat        = "Average"

      dimensions = {
        InstanceId = var.instance_id
      }
    }
  }
}



resource "aws_cloudwatch_metric_alarm" "ebs_throughput_credit_balance" {
  depends_on = [aws_sns_topic_subscription.marbot]
  count      = (local.ebs_throughput_credit_balance == "static" && (data.aws_ec2_instance_type.instance.ebs_optimized_support == "default" || (data.aws_ec2_instance_type.instance.ebs_optimized_support == "supported" && data.aws_instance.instance.ebs_optimized)) && data.aws_ec2_instance_type.instance.ebs_performance_baseline_bandwidth != data.aws_ec2_instance_type.instance.ebs_performance_maximum_bandwidth && local.enabled) ? 1 : 0

  alarm_name          = "marbot-ec2-instance-ebs-throughput-credit-balance-${random_id.id8.hex}"
  alarm_description   = "${local.alarm_description_prefix}Average EBS throughput credit balance too low, expect a significant performance drop soon. (created by marbot)"
  namespace           = "AWS/EC2"
  metric_name         = "EBSByteBalance%"
  statistic           = "Average"
  period              = local.ebs_throughput_credit_balance_period
  evaluation_periods  = local.ebs_throughput_credit_balance_evaluation_periods
  comparison_operator = "LessThanThreshold"
  threshold           = local.ebs_throughput_credit_balance_threshold
  alarm_actions       = [local.topic_arn]
  ok_actions          = [local.topic_arn]
  dimensions = {
    InstanceId = var.instance_id
  }
  treat_missing_data = "notBreaching"
  tags               = var.tags
}

resource "aws_cloudwatch_metric_alarm" "ebs_throughput_credit_balance_anomaly_detection" {
  depends_on = [aws_sns_topic_subscription.marbot]
  count      = (local.ebs_throughput_credit_balance == "anomaly_detection" && (data.aws_ec2_instance_type.instance.ebs_optimized_support == "default" || (data.aws_ec2_instance_type.instance.ebs_optimized_support == "supported" && data.aws_instance.instance.ebs_optimized)) && data.aws_ec2_instance_type.instance.ebs_performance_baseline_bandwidth != data.aws_ec2_instance_type.instance.ebs_performance_maximum_bandwidth && local.enabled) ? 1 : 0

  alarm_name          = "marbot-ec2-instance-ebs-throughput-credit-balance-${random_id.id8.hex}"
  alarm_description   = "${local.alarm_description_prefix}Average EBS throughput credit balance unexpected, expect a significant performance drop soon. (created by marbot)"
  evaluation_periods  = local.ebs_throughput_credit_balance_evaluation_periods
  comparison_operator = "LessThanLowerThreshold"
  threshold_metric_id = "e1"
  alarm_actions       = [local.topic_arn]
  ok_actions          = [local.topic_arn]
  treat_missing_data  = "notBreaching"
  tags                = var.tags

  metric_query {
    id          = "e1"
    expression  = "ANOMALY_DETECTION_BAND(m1)"
    label       = "EBSByteBalance% (expected)"
    return_data = "true"
  }

  metric_query {
    id          = "m1"
    return_data = "true"
    metric {
      metric_name = "EBSByteBalance%"
      namespace   = "AWS/EC2"
      period      = local.ebs_throughput_credit_balance_period
      stat        = "Average"

      dimensions = {
        InstanceId = var.instance_id
      }
    }
  }
}



resource "aws_cloudwatch_metric_alarm" "status_check" {
  depends_on = [aws_sns_topic_subscription.marbot]
  count      = local.enabled ? 1 : 0

  alarm_name          = "marbot-ec2-instance-status-check-${random_id.id8.hex}"
  alarm_description   = "${local.alarm_description_prefix}instance status check or the system status check has failed. (created by marbot)"
  namespace           = "AWS/EC2"
  metric_name         = "StatusCheckFailed"
  statistic           = "Sum"
  period              = 600
  evaluation_periods  = 1
  comparison_operator = "GreaterThanThreshold"
  threshold           = 0
  alarm_actions       = [local.topic_arn]
  ok_actions          = [local.topic_arn]
  dimensions = {
    InstanceId = var.instance_id
  }
  treat_missing_data = "notBreaching"
  tags               = var.tags
}



resource "aws_cloudwatch_metric_alarm" "network_burst_utilization" {
  depends_on = [aws_sns_topic_subscription.marbot]
  count      = ((local.network_utilization == "static" || local.network_utilization == "anomaly_detection" || local.network_utilization == "static_anomaly_detection") && local.network_baseline >= 0 && local.network_burst >= 0 && local.enabled) ? 1 : 0

  alarm_name          = "marbot-ec2-instance-network-burst-utilization-${random_id.id8.hex}"
  alarm_description   = "${local.alarm_description_prefix}Average Network In+Out burst utilization too high, expect a significant performance drop soon. (created by marbot)"
  evaluation_periods  = local.network_utilization_evaluation_periods
  comparison_operator = (local.network_utilization == "static") ? "GreaterThanThreshold" : "GreaterThanUpperThreshold"
  threshold           = (local.network_utilization == "static") ? floor(local.network_burst * local.network_utilization_threshold) / 100 : null
  threshold_metric_id = (local.network_utilization == "static") ? null : "e1"
  alarm_actions       = [local.topic_arn]
  ok_actions          = [local.topic_arn]
  treat_missing_data  = "notBreaching"
  tags                = var.tags

  metric_query {
    id    = "in"
    label = "In"

    metric {
      namespace   = "AWS/EC2"
      metric_name = "NetworkIn" # bytes per minute
      period      = local.network_utilization_period
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
      period      = local.network_utilization_period
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
    return_data = "true"
  }

  dynamic "metric_query" {
    for_each = (local.network_utilization == "anomaly_detection") ? { enabled = true } : {}

    content {
      id          = "e1"
      expression  = "ANOMALY_DETECTION_BAND(inout)"
      label       = "NetworkUtilization (expected)"
      return_data = "true"
    }
  }

  dynamic "metric_query" {
    for_each = (local.network_utilization == "static_anomaly_detection") ? { enabled = true } : {}

    content {
      id          = "inout2"
      expression  = "IF(inout<${local.network_utilization_threshold}, ${local.network_utilization_threshold}, inout)"
      label       = "NetworkUtilization (threshold)"
    }
  }

  dynamic "metric_query" {
    for_each = (local.network_utilization == "static_anomaly_detection") ? { enabled = true } : {}

    content {
      id          = "e1"
      expression  = "ANOMALY_DETECTION_BAND(inout2)"
      label       = "NetworkUtilization (expected)"
      return_data = "true"
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "network_baseline_utilization" {
  depends_on = [aws_sns_topic_subscription.marbot]
  count      = ((local.network_utilization == "static" || local.network_utilization == "anomaly_detection" || local.network_utilization == "static_anomaly_detection") && local.network_baseline >= 0 && local.network_burst >= 0 && local.enabled) ? 1 : 0

  alarm_name          = "marbot-ec2-instance-network-baseline-utilization-${random_id.id8.hex}"
  alarm_description   = "${local.alarm_description_prefix}Average Network In+Out baseline utilization too high, you might can burst. (created by marbot)"
  evaluation_periods  = local.network_utilization_evaluation_periods
  comparison_operator = (local.network_utilization == "static") ? "GreaterThanThreshold" : "GreaterThanUpperThreshold"
  threshold           = (local.network_utilization == "static") ? floor(local.network_baseline * local.network_utilization_threshold) / 100 : null
  threshold_metric_id = (local.network_utilization == "static") ? null : "e1"
  alarm_actions       = [local.topic_arn]
  ok_actions          = [local.topic_arn]
  treat_missing_data  = "notBreaching"
  tags                = var.tags

  metric_query {
    id    = "in"
    label = "In"

    metric {
      namespace   = "AWS/EC2"
      metric_name = "NetworkIn" # bytes per minute
      period      = local.network_utilization_period
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
      period      = local.network_utilization_period
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
    return_data = "true"
  }

  dynamic "metric_query" {
    for_each = (local.network_utilization == "anomaly_detection") ? { enabled = true } : {}

    content {
      id          = "e1"
      expression  = "ANOMALY_DETECTION_BAND(inout)"
      label       = "NetworkUtilization (expected)"
      return_data = "true"
    }
  }

  dynamic "metric_query" {
    for_each = (local.network_utilization == "static_anomaly_detection") ? { enabled = true } : {}

    content {
      id          = "inout2"
      expression  = "IF(inout<${local.network_utilization_threshold}, ${local.network_utilization_threshold}, inout)"
      label       = "NetworkUtilization (threshold)"
    }
  }

  dynamic "metric_query" {
    for_each = (local.network_utilization == "static_anomaly_detection") ? { enabled = true } : {}

    content {
      id          = "e1"
      expression  = "ANOMALY_DETECTION_BAND(inout2)"
      label       = "NetworkUtilization (expected)"
      return_data = "true"
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "network_utilization" {
  depends_on = [aws_sns_topic_subscription.marbot]
  count      = ((local.network_utilization == "static" || local.network_utilization == "anomaly_detection" || local.network_utilization == "static_anomaly_detection") && local.network_baseline >= 0 && local.network_burst < 0 && local.enabled) ? 1 : 0

  alarm_name          = "marbot-ec2-instance-network-utilization-${random_id.id8.hex}"
  alarm_description   = "${local.alarm_description_prefix}Average Network In+Out utilization too high. (created by marbot)"
  evaluation_periods  = local.network_utilization_evaluation_periods
  comparison_operator = (local.network_utilization == "static") ? "GreaterThanThreshold" : "GreaterThanUpperThreshold"
  threshold           = (local.network_utilization == "static") ? floor(local.network_baseline * local.network_utilization_threshold) / 100 : null
  threshold_metric_id = (local.network_utilization == "static") ? null : "e1"
  alarm_actions       = [local.topic_arn]
  ok_actions          = [local.topic_arn]
  treat_missing_data  = "notBreaching"
  tags                = var.tags

  metric_query {
    id    = "in"
    label = "In"

    metric {
      namespace   = "AWS/EC2"
      metric_name = "NetworkIn" # bytes per minute
      period      = local.network_utilization_period
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
      period      = local.network_utilization_period
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
    return_data = "true"
  }

  dynamic "metric_query" {
    for_each = (local.network_utilization == "anomaly_detection") ? { enabled = true } : {}

    content {
      id          = "e1"
      expression  = "ANOMALY_DETECTION_BAND(inout)"
      label       = "NetworkUtilization (expected)"
      return_data = "true"
    }
  }

  dynamic "metric_query" {
    for_each = (local.network_utilization == "static_anomaly_detection") ? { enabled = true } : {}

    content {
      id          = "inout2"
      expression  = "IF(inout<${local.network_utilization_threshold}, ${local.network_utilization_threshold}, inout)"
      label       = "NetworkUtilization (threshold)"
    }
  }

  dynamic "metric_query" {
    for_each = (local.network_utilization == "static_anomaly_detection") ? { enabled = true } : {}

    content {
      id          = "e1"
      expression  = "ANOMALY_DETECTION_BAND(inout2)"
      label       = "NetworkUtilization (expected)"
      return_data = "true"
    }
  }
}
