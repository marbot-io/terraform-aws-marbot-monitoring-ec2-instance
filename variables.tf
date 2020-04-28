variable "endpoint_id" {
  type        = string
  description = "Your marbot endpoint ID (to get this value: select a Slack channel where marbot belongs to and send a message like this: \"@marbot show me my endpoint id\")."
}

variable "enabled" {
  type        = bool
  description = "Turn the module on or off"
  default     = true
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}

variable "instance_id" {
  type        = string
  description = "The instance ID of the EC2 instance that you want to monitor."
}

variable "instance_type" {
  type        = string
  description = "Deprecated, not needed anymore."
  default     = ""
}

variable "cpu_utilization_threshold" {
  type        = number
  description = "The maximum percentage of CPU utilization (set to -1 to disable)."
  default     = 80
}

variable "burst_monitoring_enabled" {
  type        = bool
  description = "Deprecated, set variable cpu_credit_balance_threshold to -1 instead"
  default     = true
}

variable "cpu_credit_balance_threshold" {
  type        = number
  description = "The minimum number of CPU credits available (t* instances only; set to -1 to disable)."
  default     = 20
}

variable "ebs_io_credit_balance_threshold" {
  type        = number
  description = "The minimum percentage of I/O credits remaining in the burst bucket (smaller instance only; set to -1 to disable)."
  default     = 20
}

variable "ebs_throughput_credit_balance_threshold" {
  type        = number
  description = "The minimum percentage of throughput credits remaining in the burst bucket (smaller instance only; set to -1 to disable)."
  default     = 20
}

variable "network_utilization_threshold" {
  type        = number
  description = "The maximum percentage of network utilization."
  default     = 80
}

variable "stage" {
  type        = string
  description = "marbot stage (never change this!)."
  default     = "v1"
}
