[![Banner][banner-image]](https://masterpoint.io/)

# terraform-aws-tailscale

[![Release][release-badge]][latest-release]

💡 Learn more about Masterpoint [below](#who-we-are-𐦂𖨆𐀪𖠋).

## Purpose and Functionality

This is a Terraform Module to create a simple, autoscaled [Tailscale Subnet Router](https://tailscale.com/kb/1019/subnets/) on EC2 instance along with generated auth key, and its corresponding IAM resources. The instance should cycle itself on a schedule.

## Usage

Here's how to invoke this example module in your projects

```hcl
module "vpc" {
  source  = "cloudposse/vpc/aws"
  version = "2.1.1"

  namespace = "eg"
  stage     = "test"
  name      = "tailscale"

  ipv4_primary_cidr_block = "172.16.0.0/16"
}

module "subnets" {
  source  = "cloudposse/dynamic-subnets/aws"
  version = "2.4.1"

  namespace = "eg"
  stage     = "test"
  name      = "tailscale"

  availability_zones = ["us-east-1a", "us-east-1b"]

  vpc_id          = module.vpc.vpc_id
  igw_id          = [module.vpc.igw_id]
  ipv4_cidr_block = [module.vpc.vpc_cidr_block]
}

module "tailscale" {
  source  = "masterpointio/tailscale/aws"
  version = "X.X.X"

  namespace = "eg"
  stage     = "test"
  name      = "tailscale"

  vpc_id           = module.vpc.vpc_id
  subnet_ids       = module.subnets.private_subnet_ids
  advertise_routes = [module.vpc.vpc_cidr_block]

  ephemeral = true
}
```

## Examples

Here is an example of using this module:

- [`examples/complete`](https://github.com/masterpointio/terraform-aws-tailscale/) - complete example of using this module

## System Logging and Monitoring Setup

On Linux and other Unix-like systems, Tailscale typically runs as a systemd service, which by default does not rotate logs - potentially allowing system logs to grow until the disk fills.

To address this, our user data script configures both a maximum journal size and a retention period to ensure logs are periodically purged. We also install the [CloudWatch Agent](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Install-CloudWatch-Agent.html) with its default configuration so that filesystem usage metrics are reported to AWS.

👀 To view these metrics, navigate in the AWS Console to “CWAgent” → “AutoScalingGroupName, ImageId, InstanceId, InstanceType, device, fstype, path” → “disk_used_percent” for the root path “/”.

## Direct and Relayed Connections

Tailscale supports two primary types of [connection types](https://tailscale.com/kb/1257/connection-types) for subnet routers:

- **Direct (peer-to-peer)**: Nodes communicate directly with each other when possible, offering better performance and reliability.
- **Relayed**: Traffic is routed through Tailscale's DERP (Designated Encrypted Relay for Packets) servers when direct connectivity isn't possible (e.g. when the subnet router is in a private VPC subnet).

### Addressing Connection Stability Issues

We've been using relayed connections for our subnet routers, but we've observed that relayed connections can sometimes cause intermittent connectivity issues, particularly when working with database connections through the Tailscale proxy (see [this issue](https://github.com/cyrilgdn/terraform-provider-postgresql/issues/495) for an example).

These issues appear as connection timeouts or SOCKS server errors:

```sh
│ Error: Error connecting to PostgreSQL server dev.example.com (scheme: postgres): socks connect tcp localhost:1055->dev.example.com:5432: unknown error general SOCKS server failure
│
│   with data.postgresql_schemas.schemas["example"],
│   on main.tf line 65, in data "postgresql_schemas" "schemas":
│   65: data "postgresql_schemas" "schemas" {
│
╵
netstack: decrementing connsInFlightByClient[100.0.108.92] because the packet was not handled; new value is 0
[RATELIMIT] format("netstack: decrementing connsInFlightByClient[%v] because the packet was not handled; new value is %d")
```

### Configuring Direct Connections

To optimize for direct connections in your Tailscale subnet router, follow this example:

```hcl
locals {
  public_subnets = ["subnet-1234567890", "subnet-0987654321"]
  vpc_id         = "vpc-1234567890"
  direct_port    = "41641"
}

module "tailscale" {
  source  = "masterpointio/tailscale/aws"
  version = "1.6.0" # Or later
  ...
  # Direct connection configuration
  subnet_ids = local.public_subnets  # Ensure subnet router is in a public subnet

  additional_security_group_ids = [module.direct_sg.id]            # Attach the security group to the subnet router
  tailscaled_extra_flags        = ["--port=${local.direct_port}"]  # Ensure `tailscaled` listens on the same port as the security group is configured

  context = module.this.context
}

module "direct_sg" {
  source  = "cloudposse/security-group/aws"
  version = "2.2.0"
  enabled = true

  vpc_id     = local.vpc_id
  attributes = ["tailscale", "direct"]

  rules = [{
    key         = "direct_ingress"
    type        = "ingress"
    from_port   = local.direct_port
    to_port     = local.direct_port
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow a direct Tailscale connection from any peer."
  }]

  context = module.this.context
}
```

The above configuration ensures that the subnet router can establish direct connections with other Tailscale nodes:

1. It is in a public subnet and gets a public IP address.
2. The security group is attached and configured to listen on a fixed port.
3. The `tailscaled` daemon is configured to listen on the same port as the security group is configured to listen on.
4. The outgoing UDP and TCP packets on port `443` are permitted. In our example, [`cloudposse/security-group/aws`](https://github.com/cloudposse/terraform-aws-security-group) module allows all egress.

<!-- prettier-ignore-start -->
<!-- markdownlint-disable MD013 -->
<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 4.0 |
| <a name="requirement_tailscale"></a> [tailscale](#requirement\_tailscale) | >= 0.13.7 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 4.0 |
| <a name="provider_tailscale"></a> [tailscale](#provider\_tailscale) | >= 0.13.7 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_ssm_policy"></a> [ssm\_policy](#module\_ssm\_policy) | cloudposse/iam-policy/aws | 2.0.1 |
| <a name="module_ssm_state"></a> [ssm\_state](#module\_ssm\_state) | cloudposse/ssm-parameter-store/aws | 0.13.0 |
| <a name="module_tailscale_subnet_router"></a> [tailscale\_subnet\_router](#module\_tailscale\_subnet\_router) | masterpointio/ssm-agent/aws | 1.4.0 |
| <a name="module_this"></a> [this](#module\_this) | cloudposse/label/null | 0.25.0 |

## Resources

| Name | Type |
|------|------|
| [aws_iam_role_policy_attachment.cw_agent](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [tailscale_tailnet_key.default](https://registry.terraform.io/providers/tailscale/tailscale/latest/docs/resources/tailnet_key) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_additional_security_group_ids"></a> [additional\_security\_group\_ids](#input\_additional\_security\_group\_ids) | Additional Security Group IDs to associate with the Tailscale Subnet Router EC2 instance. | `list(string)` | `[]` | no |
| <a name="input_additional_security_group_rules"></a> [additional\_security\_group\_rules](#input\_additional\_security\_group\_rules) | Additional security group rules that will be attached to the primary security group | <pre>map(object({<br/>    type      = string<br/>    from_port = number<br/>    to_port   = number<br/>    protocol  = string<br/><br/>    description      = optional(string)<br/>    cidr_blocks      = optional(list(string))<br/>    ipv6_cidr_blocks = optional(list(string))<br/>    prefix_list_ids  = optional(list(string))<br/>    self             = optional(bool)<br/>  }))</pre> | `{}` | no |
| <a name="input_additional_tag_map"></a> [additional\_tag\_map](#input\_additional\_tag\_map) | Additional key-value pairs to add to each map in `tags_as_list_of_maps`. Not added to `tags` or `id`.<br/>This is for some rare cases where resources want additional configuration of tags<br/>and therefore take a list of maps with tag key, value, and additional configuration. | `map(string)` | `{}` | no |
| <a name="input_additional_tags"></a> [additional\_tags](#input\_additional\_tags) | Additional Tailscale tags to apply to the Tailscale Subnet Router machine in addition to `primary_tag`. These should not include the `tag:` prefix. | `list(string)` | `[]` | no |
| <a name="input_advertise_routes"></a> [advertise\_routes](#input\_advertise\_routes) | The routes (expressed as CIDRs) to advertise as part of the Tailscale Subnet Router.<br/>  Example: ["10.0.2.0/24", "0.0.1.0/24"] | `list(string)` | `[]` | no |
| <a name="input_ami"></a> [ami](#input\_ami) | The AMI to use for the Tailscale Subnet Router EC2 instance.<br/>  If not provided, the latest Amazon Linux 2 AMI will be used.<br/>  Note: This will update periodically as AWS releases updates to their AL2 AMI.<br/>  Pin to a specific AMI if you would like to avoid these updates. | `string` | `""` | no |
| <a name="input_architecture"></a> [architecture](#input\_architecture) | The architecture of the AMI (e.g., x86\_64, arm64) | `string` | `"arm64"` | no |
| <a name="input_associate_public_ip_address"></a> [associate\_public\_ip\_address](#input\_associate\_public\_ip\_address) | Associate public IP address with subnet router | `bool` | `null` | no |
| <a name="input_attributes"></a> [attributes](#input\_attributes) | ID element. Additional attributes (e.g. `workers` or `cluster`) to add to `id`,<br/>in the order they appear in the list. New attributes are appended to the<br/>end of the list. The elements of the list are joined by the `delimiter`<br/>and treated as a single ID element. | `list(string)` | `[]` | no |
| <a name="input_context"></a> [context](#input\_context) | Single object for setting entire context at once.<br/>See description of individual variables for details.<br/>Leave string and numeric variables as `null` to use default value.<br/>Individual variable settings (non-null) override settings in context object,<br/>except for attributes, tags, and additional\_tag\_map, which are merged. | `any` | <pre>{<br/>  "additional_tag_map": {},<br/>  "attributes": [],<br/>  "delimiter": null,<br/>  "descriptor_formats": {},<br/>  "enabled": true,<br/>  "environment": null,<br/>  "id_length_limit": null,<br/>  "label_key_case": null,<br/>  "label_order": [],<br/>  "label_value_case": null,<br/>  "labels_as_tags": [<br/>    "unset"<br/>  ],<br/>  "name": null,<br/>  "namespace": null,<br/>  "regex_replace_chars": null,<br/>  "stage": null,<br/>  "tags": {},<br/>  "tenant": null<br/>}</pre> | no |
| <a name="input_create_run_shell_document"></a> [create\_run\_shell\_document](#input\_create\_run\_shell\_document) | Whether or not to create the SSM-SessionManagerRunShell SSM Document. | `bool` | `true` | no |
| <a name="input_delimiter"></a> [delimiter](#input\_delimiter) | Delimiter to be used between ID elements.<br/>Defaults to `-` (hyphen). Set to `""` to use no delimiter at all. | `string` | `null` | no |
| <a name="input_descriptor_formats"></a> [descriptor\_formats](#input\_descriptor\_formats) | Describe additional descriptors to be output in the `descriptors` output map.<br/>Map of maps. Keys are names of descriptors. Values are maps of the form<br/>`{<br/>   format = string<br/>   labels = list(string)<br/>}`<br/>(Type is `any` so the map values can later be enhanced to provide additional options.)<br/>`format` is a Terraform format string to be passed to the `format()` function.<br/>`labels` is a list of labels, in order, to pass to `format()` function.<br/>Label values will be normalized before being passed to `format()` so they will be<br/>identical to how they appear in `id`.<br/>Default is `{}` (`descriptors` output will be empty). | `any` | `{}` | no |
| <a name="input_desired_capacity"></a> [desired\_capacity](#input\_desired\_capacity) | Desired number of instances in the Auto Scaling Group | `number` | `1` | no |
| <a name="input_enabled"></a> [enabled](#input\_enabled) | Set to false to prevent the module from creating any resources | `bool` | `null` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | ID element. Usually used for region e.g. 'uw2', 'us-west-2', OR role 'prod', 'staging', 'dev', 'UAT' | `string` | `null` | no |
| <a name="input_ephemeral"></a> [ephemeral](#input\_ephemeral) | Indicates if the key is ephemeral. | `bool` | `false` | no |
| <a name="input_exit_node_enabled"></a> [exit\_node\_enabled](#input\_exit\_node\_enabled) | Advertise Tailscale Subnet Router EC2 instance as exit node. Defaults to false. | `bool` | `false` | no |
| <a name="input_expiry"></a> [expiry](#input\_expiry) | The expiry of the auth key in seconds. | `number` | `7776000` | no |
| <a name="input_id_length_limit"></a> [id\_length\_limit](#input\_id\_length\_limit) | Limit `id` to this many characters (minimum 6).<br/>Set to `0` for unlimited length.<br/>Set to `null` for keep the existing setting, which defaults to `0`.<br/>Does not affect `id_full`. | `number` | `null` | no |
| <a name="input_instance_type"></a> [instance\_type](#input\_instance\_type) | The instance type to use for the Tailscale Subnet Router EC2 instance. | `string` | `"t4g.nano"` | no |
| <a name="input_journald_max_retention_sec"></a> [journald\_max\_retention\_sec](#input\_journald\_max\_retention\_sec) | The maximum time to store journal entries. | `string` | `"7d"` | no |
| <a name="input_journald_system_max_use"></a> [journald\_system\_max\_use](#input\_journald\_system\_max\_use) | Disk space the journald may use up at most | `string` | `"200M"` | no |
| <a name="input_key_pair_name"></a> [key\_pair\_name](#input\_key\_pair\_name) | The name of the key-pair to associate with the Tailscale Subnet Router EC2 instance. | `string` | `null` | no |
| <a name="input_label_key_case"></a> [label\_key\_case](#input\_label\_key\_case) | Controls the letter case of the `tags` keys (label names) for tags generated by this module.<br/>Does not affect keys of tags passed in via the `tags` input.<br/>Possible values: `lower`, `title`, `upper`.<br/>Default value: `title`. | `string` | `null` | no |
| <a name="input_label_order"></a> [label\_order](#input\_label\_order) | The order in which the labels (ID elements) appear in the `id`.<br/>Defaults to ["namespace", "environment", "stage", "name", "attributes"].<br/>You can omit any of the 6 labels ("tenant" is the 6th), but at least one must be present. | `list(string)` | `null` | no |
| <a name="input_label_value_case"></a> [label\_value\_case](#input\_label\_value\_case) | Controls the letter case of ID elements (labels) as included in `id`,<br/>set as tag values, and output by this module individually.<br/>Does not affect values of tags passed in via the `tags` input.<br/>Possible values: `lower`, `title`, `upper` and `none` (no transformation).<br/>Set this to `title` and set `delimiter` to `""` to yield Pascal Case IDs.<br/>Default value: `lower`. | `string` | `null` | no |
| <a name="input_labels_as_tags"></a> [labels\_as\_tags](#input\_labels\_as\_tags) | Set of labels (ID elements) to include as tags in the `tags` output.<br/>Default is to include all labels.<br/>Tags with empty values will not be included in the `tags` output.<br/>Set to `[]` to suppress all generated tags.<br/>**Notes:**<br/>  The value of the `name` tag, if included, will be the `id`, not the `name`.<br/>  Unlike other `null-label` inputs, the initial setting of `labels_as_tags` cannot be<br/>  changed in later chained modules. Attempts to change it will be silently ignored. | `set(string)` | <pre>[<br/>  "default"<br/>]</pre> | no |
| <a name="input_max_size"></a> [max\_size](#input\_max\_size) | Maximum number of instances in the Auto Scaling Group. Must be >= desired\_capacity. | `number` | `2` | no |
| <a name="input_min_size"></a> [min\_size](#input\_min\_size) | Minimum number of instances in the Auto Scaling Group | `number` | `1` | no |
| <a name="input_monitoring_enabled"></a> [monitoring\_enabled](#input\_monitoring\_enabled) | Enable detailed monitoring of instances | `bool` | `true` | no |
| <a name="input_name"></a> [name](#input\_name) | ID element. Usually the component or solution name, e.g. 'app' or 'jenkins'.<br/>This is the only ID element not also included as a `tag`.<br/>The "name" tag is set to the full `id` string. There is no tag with the value of the `name` input. | `string` | `null` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | ID element. Usually an abbreviation of your organization name, e.g. 'eg' or 'cp', to help ensure generated IDs are globally unique | `string` | `null` | no |
| <a name="input_preauthorized"></a> [preauthorized](#input\_preauthorized) | Determines whether or not the machines authenticated by the key will be authorized for the tailnet by default. | `bool` | `true` | no |
| <a name="input_primary_tag"></a> [primary\_tag](#input\_primary\_tag) | The primary tag to apply to the Tailscale Subnet Router machine. Do not include the `tag:` prefix. This must match the OAuth client's tag. If not provided, the module will use the module's ID as the primary tag, which is configured in context.tf | `string` | `null` | no |
| <a name="input_regex_replace_chars"></a> [regex\_replace\_chars](#input\_regex\_replace\_chars) | Terraform regular expression (regex) string.<br/>Characters matching the regex will be removed from the ID elements.<br/>If not set, `"/[^a-zA-Z0-9-]/"` is used to remove all characters other than hyphens, letters and digits. | `string` | `null` | no |
| <a name="input_reusable"></a> [reusable](#input\_reusable) | Indicates if the key is reusable or single-use. | `bool` | `true` | no |
| <a name="input_session_logging_enabled"></a> [session\_logging\_enabled](#input\_session\_logging\_enabled) | To enable CloudWatch and S3 session logging or not.<br/>  Note this does not apply to SSH sessions as AWS cannot log those sessions. | `bool` | `true` | no |
| <a name="input_session_logging_kms_key_alias"></a> [session\_logging\_kms\_key\_alias](#input\_session\_logging\_kms\_key\_alias) | Alias name for `session_logging` KMS Key.<br/>  This is only applied if 2 conditions are met: (1) `session_logging_kms_key_arn` is unset,<br/>  (2) `session_logging_encryption_enabled` = true. | `string` | `"alias/session_logging"` | no |
| <a name="input_session_logging_ssm_document_name"></a> [session\_logging\_ssm\_document\_name](#input\_session\_logging\_ssm\_document\_name) | Name for `session_logging` SSM document.<br/>  This is only applied if 2 conditions are met: (1) `session_logging_enabled` = true,<br/>  (2) `create_run_shell_document` = true. | `string` | `"SSM-SessionManagerRunShell-Tailscale"` | no |
| <a name="input_ssh_enabled"></a> [ssh\_enabled](#input\_ssh\_enabled) | Enable SSH access to the Tailscale Subnet Router EC2 instance. Defaults to true. | `bool` | `true` | no |
| <a name="input_ssm_state_enabled"></a> [ssm\_state\_enabled](#input\_ssm\_state\_enabled) | Control if tailscaled state is stored in AWS SSM (including preferences and keys).<br/>This tells the Tailscale daemon to write + read state from SSM,<br/>which unlocks important features like retaining the existing tailscale machine name.<br/>See more in the [docs](https://tailscale.com/kb/1278/tailscaled#flags-to-tailscaled). | `bool` | `false` | no |
| <a name="input_stage"></a> [stage](#input\_stage) | ID element. Usually used to indicate role, e.g. 'prod', 'staging', 'source', 'build', 'test', 'deploy', 'release' | `string` | `null` | no |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | The Subnet IDs which the Tailscale Subnet Router EC2 instance will run in. These *should* be private subnets. | `list(string)` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Additional tags (e.g. `{'BusinessUnit': 'XYZ'}`).<br/>Neither the tag keys nor the tag values will be modified by this module. | `map(string)` | `{}` | no |
| <a name="input_tailscale_up_extra_flags"></a> [tailscale\_up\_extra\_flags](#input\_tailscale\_up\_extra\_flags) | Extra flags to pass to `tailscale up` for advanced configuration.<br/>See more in the [docs](https://tailscale.com/kb/1241/tailscale-up). | `list(string)` | `[]` | no |
| <a name="input_tailscaled_extra_flags"></a> [tailscaled\_extra\_flags](#input\_tailscaled\_extra\_flags) | Extra flags to pass to Tailscale daemon for advanced configuration. Example: ["--state=mem:"]<br/>See more in the [docs](https://tailscale.com/kb/1278/tailscaled#flags-to-tailscaled). | `list(string)` | `[]` | no |
| <a name="input_tenant"></a> [tenant](#input\_tenant) | ID element \_(Rarely used, not included by default)\_. A customer identifier, indicating who this instance of a resource is for | `string` | `null` | no |
| <a name="input_user_data"></a> [user\_data](#input\_user\_data) | The user\_data to use for the Tailscale Subnet Router EC2 instance.<br/>  You can use this to automate installation of all the required command line tools. | `string` | `""` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | The ID of the VPC which the Tailscale Subnet Router EC2 instance will run in. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_autoscaling_group_id"></a> [autoscaling\_group\_id](#output\_autoscaling\_group\_id) | The ID of the Tailscale Subnet Router EC2 instance Autoscaling Group. |
| <a name="output_instance_name"></a> [instance\_name](#output\_instance\_name) | The name tag value of the Tailscale Subnet Router EC2 instance. |
| <a name="output_launch_template_id"></a> [launch\_template\_id](#output\_launch\_template\_id) | The ID of the Tailscale Subnet Router EC2 instance Launch Template. |
| <a name="output_security_group_id"></a> [security\_group\_id](#output\_security\_group\_id) | The ID of the Tailscale Subnet Router EC2 instance Security Group. |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
<!-- markdownlint-enable MD013 -->
<!-- prettier-ignore-end -->

## Built By

Powered by the [Masterpoint team](https://masterpoint.io/who-we-are/) and driven forward by contributions from the community ❤️

[![Contributors][contributors-image]][contributors-url]

## Contribution Guidelines

Contributions are welcome and appreciated!

Found an issue or want to request a feature? [Open an issue][issues-url]

Want to fix a bug you found or add some functionality? Fork, clone, commit, push, and PR — we'll check it out.

## Who We Are 𐦂𖨆𐀪𖠋

Established in 2016, Masterpoint is a team of experienced software and platform engineers specializing in Infrastructure as Code (IaC). We provide expert guidance to organizations of all sizes, helping them leverage the latest IaC practices to accelerate their engineering teams.

### Our Mission

Our mission is to simplify cloud infrastructure so developers can innovate faster, safer, and with greater confidence. By open-sourcing tools and modules that we use internally, we aim to contribute back to the community, promoting consistency, quality, and security.

### Our Commitments

- 🌟 **Open Source**: We live and breathe open source, contributing to and maintaining hundreds of projects across multiple organizations.
- 🌎 **1% for the Planet**: Demonstrating our commitment to environmental sustainability, we are proud members of [1% for the Planet](https://www.onepercentfortheplanet.org), pledging to donate 1% of our annual sales to environmental nonprofits.
- 🇺🇦 **1% Towards Ukraine**: With team members and friends affected by the ongoing [Russo-Ukrainian war](https://en.wikipedia.org/wiki/Russo-Ukrainian_War), we donate 1% of our annual revenue to invasion relief efforts, supporting organizations providing aid to those in need. [Here's how you can help Ukraine with just a few clicks](https://masterpoint.io/updates/supporting-ukraine/).

## Connect With Us

We're active members of the community and are always publishing content, giving talks, and sharing our hard earned expertise. Here are a few ways you can see what we're up to:

[![LinkedIn][linkedin-badge]][linkedin-url] [![Newsletter][newsletter-badge]][newsletter-url] [![Blog][blog-badge]][blog-url] [![YouTube][youtube-badge]][youtube-url]

... and be sure to connect with our founder, [Matt Gowie](https://www.linkedin.com/in/gowiem/).

## License

[Apache License, Version 2.0][license-url].

[![Open Source Initiative][osi-image]][license-url]

Copyright © 2016-2025 [Masterpoint Consulting LLC](https://masterpoint.io/)

<!-- MARKDOWN LINKS & IMAGES -->

[banner-image]: https://masterpoint-public.s3.us-west-2.amazonaws.com/v2/standard-long-fullcolor.png
[license-url]: https://opensource.org/license/apache-2-0
[osi-image]: https://i0.wp.com/opensource.org/wp-content/uploads/2023/03/cropped-OSI-horizontal-large.png?fit=250%2C229&ssl=1
[linkedin-badge]: https://img.shields.io/badge/LinkedIn-Follow-0A66C2?style=for-the-badge&logoColor=white
[linkedin-url]: https://www.linkedin.com/company/masterpoint-consulting
[blog-badge]: https://img.shields.io/badge/Blog-IaC_Insights-55C1B4?style=for-the-badge&logoColor=white
[blog-url]: https://masterpoint.io/updates/
[newsletter-badge]: https://img.shields.io/badge/Newsletter-Subscribe-ECE295?style=for-the-badge&logoColor=222222
[newsletter-url]: https://newsletter.masterpoint.io/
[youtube-badge]: https://img.shields.io/badge/YouTube-Subscribe-D191BF?style=for-the-badge&logo=youtube&logoColor=white
[youtube-url]: https://www.youtube.com/channel/UCeeDaO2NREVlPy9Plqx-9JQ
[release-badge]: https://img.shields.io/github/v/release/masterpointio/terraform-aws-tailscale?color=0E383A&label=Release&style=for-the-badge&logo=github&logoColor=white
[latest-release]: https://github.com/masterpointio/terraform-aws-tailscale/releases/latest
[contributors-image]: https://contrib.rocks/image?repo=masterpointio/terraform-aws-tailscale
[contributors-url]: https://github.com/masterpointio/terraform-aws-tailscale/graphs/contributors
[issues-url]: https://github.com/masterpointio/terraform-aws-tailscale/issues
