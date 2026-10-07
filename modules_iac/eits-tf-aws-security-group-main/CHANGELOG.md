# CHANGE LOG

## 3.8.1 - 14th September 2026

- Updated confluence document links

## 3.8.0 - 20th August 2026

- Updated rules for SNOW/CMDB and CyberArk *Note: this will create extra rules or modify existing ones*
- Removed BladeLogic rules as they don't apply to everyone *BladeLogic clients must ensure this rule is added in their own security group before upgrading to this version*

## 3.7.0 - 31st July 2026

- Reduced scope of Tanium client rules to specific NLB addresses and local routable VPC CIDR addresses for P2P connections. ***Note that this will create extra rule resources to accomodate the extra CIDRS and to remove the more open 10.0.0.0/8 CIDR currently used***

## 3.6.0 - 27th April 2026

- Added `cyberark_sia_rules` variable to add new rules for CyberArk SIA
- Added validation for variables `cyberark_sia_rules` and `ec2_agent_rules`
- Bumped pre-commit to version `1.4.0`

## 3.5.1 - 3rd December 2025

- Added new rule for BladeLogic

## 3.5.0 - 23rd October 2025

- Added `time` provider
- Added `time_sleep` resource for rules
- Added `sleep_timeout` variable

## 3.4.1 - 17th October 2025

- Fixed naming conflict when prefix starts with 'sg-' (Singapore) by replacing with 'sgp-' to avoid confusion with security group '-sg' suffix

## 3.4.0 - 14th October 2025

- Added `vpc_id` output

## 3.3.4 - 28th July 2025

- Added additional ports for SNOW CMDB Network Discovery in default Windows security group
- Bumped pre-commit to version `1.3.1`

## 3.3.3 - 17th April 2025

- Fixed issue with check when a port range larger than 1024 is provided
- Updated test scenario

## 3.3.2 - 16th April 2025

- Ignored Trivy rule `AVD-AWS-0104` for unrestricted egress rules

## 3.3.1 - 9th April 2025

- Fix broken check when ingress to/from ports are null

## 3.3.0 - 1st April 2025

- Updated `eits_vars` to `eits_ce_common`
- Renamed `warnings.tf` to `checks.tf`

## 3.2.0 - 6th March 2025

- Updated existing warning from 3.1.0 to include Wiz verbiage and link to rule.
- Moved logic for existing warning and all new warnings into locals, because there is a lot of repetition between checks.
- List of sensitive ports to alert on, currently includes 22,23, 3389.
- Added additional warnings:
  - Wide open (public internet, all ports)
  - Wide open sensitive ports (public internet, sensitive ports)
  - Broad private network (all of a private cidr, like 10.0.0.0/8)
  - Sensitive Ports Open
  - Broad private network and sensitive ports
  - Wide open, ports not considered (ingress from 0.0.0.0/0 with any combo of ports)

## 3.1.0 - 4th February 2025

- Created `validation_warning` for `cidr_blocks`
- Updated pre-commit version to 1.3.0
- Added new provider `tlkamp/validation`

## 3.0.6 - 4th January 2025

- Updated review date
- Updated aws provider version to 5.73.0

## 3.0.5 - 3rd January 2025

- Added default `Name` tag

## 3.0.4 - 15th November 2024

- Added CyberArk UK servers IPs to default EC2 agents rules
- Added Tanium rule to default Linux security group

## 3.0.3 - 16th September 2024

- Allow empty prefixes

## 3.0.2 - 8th August 2024

- Fixed Tanium rule

## 3.0.1 - 20th June 2024

- Fix bug when configuring empty ingress/egress rules would delete all rules on an apply. - ***This is due to backwards compatibility steps for migrating from v1. If migrating from version 1.x.x, please upgrade to to v2.0.0 first following the migration steps below.***
- Add default EEC egress rule.

## 3.0.0 - 11th June 2024

- Add `ec2_agent_rules` which will automatically add the default EITS EC2 agent rules for either `linux` or `windows`.
- Removed default RDP rule. If you need RDP access, add a new rule scoped only from the required CIDRs/IPs.
- Automatically set `from_port` and `to_port` to null if `protocol` is set to `-1` to avoid provider bug.
- Refactor how security group rules are constructed to prevent resources from moving list position. This avoids any "change of position" bugs when creating the rules resources. - ***Please be aware this refactor will cause rules to be recreated if upgrading from a previous version***
- Fully define variable type for `security_group_ingress_rules` and `security_group_egress_rules`.
- Change `prefix` default value to `null`.
- Fix bug where `tags` would not be added to rules.
- Add the following outputs:
  - `ingress_rules`
  - `egress_rules`

## 2.0.1 - 26th February 2024

- Fixed TFLint issue: Change to compare length as type check may fail
- Added pre-commit config
 
## 2.0.0 - 4th December 2023

- Removed the `ingress` and `egress` blocks from `aws_security_group` resource to dedicated `aws_vpc_security_group_ingress_rule` and `aws_vpc_security_group_egress_rule` resources ***This is a breaking change because the rules that were previously managed by `aws_security_group` need to be destroyed first, otherwise there will be an error as the rules already exist***

### Migrating to v2.0.0
- When migrating from version 1.x.x, you will first need to comment/remove the `security_group_ingress_rules` and `security_group_egress_rules` arguments before upgrading, apply the terraform, then add them back after upgrading the version to 2.0.0. This is because a new resource is used behind the scene, which is unable to update the existing rules. Running this without this workaround first would cause an error as the rules already exist. Alternatively, you can also remove the rules via CLI/Console before running this code.

## 1.1.2 - 1st November 2023

- Add CONTRIBUTING.md

## 1.1.1 - 26th October 2023

- Add benchmark table to README.md

## 1.1.0 - 19th September 2023

- Add tests directory with Jenkinsfile for pull request testing
- Merge functionality of vars, tagging and label modules
- Move locals to main.tf (as tiny)
- Add .gitignore file

## 1.0.1 - 16th August 2023

- Add standard EITS CE tags using eits_vars module

## 1.0.0 - 31st July 2023

- Initial release
