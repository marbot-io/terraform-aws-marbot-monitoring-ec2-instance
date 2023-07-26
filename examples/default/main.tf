terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 2.48.0"
    }
  }
}

module "marbot-monitoring-ec2-instance" {
  source = "../../"

  endpoint_id = var.endpoint_id
  instance_id = var.instance_id
}