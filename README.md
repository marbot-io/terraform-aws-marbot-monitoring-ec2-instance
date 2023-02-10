# EC2 instance monitoring

Adds alarms to monitor a particular EC2 instance's CPU, network, and EBS, and forwards them to Slack or Microsoft Teams managed by [marbot](https://marbot.io/).

## Usage

1. Create a new directory
2. Within the new directory, create a file `main.tf` with the following content:
```
provider "aws" {}

module "marbot-monitoring-ec2-instance" {
  source   = "marbot-io/marbot-monitoring-ec2-instance/aws"
  #version = "x.y.z"         # we recommend to pin the version

  endpoint_id   = "" # to get this value, select a channel where marbot belongs to and send a message like this: "@marbot show me my endpoint id"
  instance_id   = "" # the EC2 instance id (e.g, i-123456)
}
```
3. Run the following commands:
```
terraform init
terraform apply
```

## Config via tags

You can also configure this module via tags (required v0.8.0 or higher). Tags take precedence over variables (tags override variables).

| tag key                                                   | default value                                      | allowed values                               |
| --------------------------------------------------------- | -------------------------------------------------- | -------------------------------------------- |
| `marbot:enabled`                                          | true                                               | true or false                                |
| `marbot:cpu-utilization:threshold`                        | variable `cpu_utilization_threshold`               | 0-100                                        |
| `marbot:cpu-utilization:period`                           | 600                                                | <= 86400 and multiple of 60                  |
| `marbot:cpu-utilization:evaluation-periods`               | 1                                                  | >= 1 and $period*evaluation-periods <= 86400 |
| `marbot:cpu-credit-balance:threshold`                     | variable `cpu_credit_balance_threshold`            | >= 0                                         |
| `marbot:cpu-credit-balance:period`                        | 600                                                | <= 86400 and multiple of 60                  |
| `marbot:cpu-credit-balance:evaluation-periods`            | 1                                                  | >= 1 and $period*evaluation-periods <= 86400 |
| `marbot:ebs-io-credit-balance:threshold`                  | variable `ebs_io_credit_balance_threshold`         | 0-100                                        |
| `marbot:ebs-io-credit-balance:period`                     | 600                                                | <= 86400 and multiple of 60                  |
| `marbot:ebs-io-credit-balance:evaluation-periods`         | 1                                                  | >= 1 and $period*evaluation-periods <= 86400 |
| `marbot:ebs-throughput-credit-balance:threshold`          | variable `ebs_throughput_credit_balance_threshold` | 0-100                                        |
| `marbot:ebs-throughput-credit-balance:period`             | 600                                                | <= 86400 and multiple of 60                  |
| `marbot:ebs-throughput-credit-balance:evaluation-periods` | 1                                                  | >= 1 and $period*evaluation-periods <= 86400 |
| `marbot:network-utilization:threshold`                    | variable `network_utilization_threshold`           | 0-100                                        |
| `marbot:network-utilization:period`                       | 600                                                | <= 86400 and multiple of 60                  |
| `marbot:network-utilization:evaluation-periods`           | 1                                                  | >= 1 and $period*evaluation-periods <= 86400 |

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
