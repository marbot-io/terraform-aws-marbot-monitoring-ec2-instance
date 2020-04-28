# EC2 instance monitoring

Adds alarms to monitor a particular EC2 instance's CPU, network, and EBS, and forwards them to Slack managed by [marbot](https://marbot.io/).

## Usage

1. Create a new directory
2. Within the new directory, create a file `main.tf` with the following content:
```
provider "aws" {}

module "marbot-monitoring-ec2-instance" {
  source   = "marbot-io/marbot-monitoring-ec2-instance/aws"
  #version = "x.y.z"         # we recommend to pin the version

  endpoint_id   = "" # to get this value, select a Slack channel where marbot belongs to and send a message like this: "@marbot show me my endpoint id"
  instance_id   = "" # the EC2 instance id (e.g, i-123456)
}
```
3. Run the following commands:
```
terraform init
terraform apply
```

## Update procedure

1. Update the `version`
2. Run the following commands:
```
terraform get
terraform apply
```

## License
All modules are published under Apache License Version 2.0.

## About
A [marbot.io](https://marbot.io/) project. Engineered by [widdix](https://widdix.net).
