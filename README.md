[![Masterpoint Logo](https://i.imgur.com/RDLnuQO.png)](https://masterpoint.io)

# terraform-aws-tailscale [![Latest Release](https://img.shields.io/github/release/masterpointio/terraform-aws-tailscale.svg)](https://github.com/masterpointio/terraform-aws-tailscale/releases/latest)

[![README Header][readme_header_img]][readme_header_link]


This is a Terraform Module to create a simple, autoscaled [Tailscale Subnet Router](https://tailscale.com/kb/1019/subnets/) on EC2 instance along with generated auth key, and its corresponding IAM resources. The instance should cycle itself on a schedule.

It's 100% Open Source and licensed under the [APACHE2](LICENSE).

## Usage

Here's how to invoke this example module in your projects

```hcl
module "example" {
  source  = "masterpointio/ssm-agent/aws"
  version = "0.16.1"

  vpc_id           = var.vpc_id
  advertise_routes = [var.vpc_cidr_block]
  subnet_ids       = var.private_subnet_ids
  key_pair_name    = var.tailscale_existing_ssh_key_name
}
```

## Examples

Here is an example of using this module:
- [`examples/complete`](https://github.com/masterpointio/terraform-aws-tailscale/) - complete example of using this module

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 4.0 |
| <a name="requirement_local"></a> [local](#requirement\_local) | >= 1.2 |
| <a name="requirement_null"></a> [null](#requirement\_null) | >= 2.0 |
| <a name="requirement_tailscale"></a> [tailscale](#requirement\_tailscale) | >= 0.13.7 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_tailscale"></a> [tailscale](#provider\_tailscale) | >= 0.13.7 |
| <a name="provider_template"></a> [template](#provider\_template) | n/a |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_tailscale_subnet_router"></a> [tailscale\_subnet\_router](#module\_tailscale\_subnet\_router) | masterpointio/ssm-agent/aws | 0.16.1 |
| <a name="module_this"></a> [this](#module\_this) | cloudposse/label/null | 0.25.0 |

## Resources

| Name | Type |
|------|------|
| [tailscale_tailnet_key.default](https://registry.terraform.io/providers/tailscale/tailscale/latest/docs/resources/tailnet_key) | resource |
| [template_file.userdata](https://registry.terraform.io/providers/hashicorp/template/latest/docs/data-sources/file) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_additional_tag_map"></a> [additional\_tag\_map](#input\_additional\_tag\_map) | Additional key-value pairs to add to each map in `tags_as_list_of_maps`. Not added to `tags` or `id`.<br>This is for some rare cases where resources want additional configuration of tags<br>and therefore take a list of maps with tag key, value, and additional configuration. | `map(string)` | `{}` | no |
| <a name="input_advertise_routes"></a> [advertise\_routes](#input\_advertise\_routes) | The routes (expressed as CIDRs) to advertise as part of the Tailscale Subnet Router. e.g. [ '10.0.2.0/24', '10.0.1.0/24 ] | `list(string)` | `[]` | no |
| <a name="input_ami"></a> [ami](#input\_ami) | The AMI to use for the  Tailscale Subnet Router EC2 instance. If not provided, the latest Amazon Linux 2 AMI will be used. Note: This will update periodically as AWS releases updates to their AL2 AMI. Pin to a specific AMI if you would like to avoid these updates. | `string` | `""` | no |
| <a name="input_attributes"></a> [attributes](#input\_attributes) | ID element. Additional attributes (e.g. `workers` or `cluster`) to add to `id`,<br>in the order they appear in the list. New attributes are appended to the<br>end of the list. The elements of the list are joined by the `delimiter`<br>and treated as a single ID element. | `list(string)` | `[]` | no |
| <a name="input_context"></a> [context](#input\_context) | Single object for setting entire context at once.<br>See description of individual variables for details.<br>Leave string and numeric variables as `null` to use default value.<br>Individual variable settings (non-null) override settings in context object,<br>except for attributes, tags, and additional\_tag\_map, which are merged. | `any` | <pre>{<br>  "additional_tag_map": {},<br>  "attributes": [],<br>  "delimiter": null,<br>  "descriptor_formats": {},<br>  "enabled": true,<br>  "environment": null,<br>  "id_length_limit": null,<br>  "label_key_case": null,<br>  "label_order": [],<br>  "label_value_case": null,<br>  "labels_as_tags": [<br>    "unset"<br>  ],<br>  "name": null,<br>  "namespace": null,<br>  "regex_replace_chars": null,<br>  "stage": null,<br>  "tags": {},<br>  "tenant": null<br>}</pre> | no |
| <a name="input_create_run_shell_document"></a> [create\_run\_shell\_document](#input\_create\_run\_shell\_document) | Whether or not to create the SSM-SessionManagerRunShell SSM Document. | `bool` | `true` | no |
| <a name="input_delimiter"></a> [delimiter](#input\_delimiter) | Delimiter to be used between ID elements.<br>Defaults to `-` (hyphen). Set to `""` to use no delimiter at all. | `string` | `null` | no |
| <a name="input_descriptor_formats"></a> [descriptor\_formats](#input\_descriptor\_formats) | Describe additional descriptors to be output in the `descriptors` output map.<br>Map of maps. Keys are names of descriptors. Values are maps of the form<br>`{<br>   format = string<br>   labels = list(string)<br>}`<br>(Type is `any` so the map values can later be enhanced to provide additional options.)<br>`format` is a Terraform format string to be passed to the `format()` function.<br>`labels` is a list of labels, in order, to pass to `format()` function.<br>Label values will be normalized before being passed to `format()` so they will be<br>identical to how they appear in `id`.<br>Default is `{}` (`descriptors` output will be empty). | `any` | `{}` | no |
| <a name="input_enabled"></a> [enabled](#input\_enabled) | Set to false to prevent the module from creating any resources | `bool` | `null` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | ID element. Usually used for region e.g. 'uw2', 'us-west-2', OR role 'prod', 'staging', 'dev', 'UAT' | `string` | `null` | no |
| <a name="input_ephemeral"></a> [ephemeral](#input\_ephemeral) | Indicates if the key is ephemeral. | `bool` | `false` | no |
| <a name="input_expiry"></a> [expiry](#input\_expiry) | The expiry of the auth key in seconds. | `number` | `7776000` | no |
| <a name="input_id_length_limit"></a> [id\_length\_limit](#input\_id\_length\_limit) | Limit `id` to this many characters (minimum 6).<br>Set to `0` for unlimited length.<br>Set to `null` for keep the existing setting, which defaults to `0`.<br>Does not affect `id_full`. | `number` | `null` | no |
| <a name="input_instance_count"></a> [instance\_count](#input\_instance\_count) | The number of  Tailscale Subnet Router EC2 instances you would like to deploy. | `number` | `1` | no |
| <a name="input_instance_type"></a> [instance\_type](#input\_instance\_type) | The instance type to use for the Tailscale Subnet Router EC2 instance. | `string` | `"t3.nano"` | no |
| <a name="input_key_pair_name"></a> [key\_pair\_name](#input\_key\_pair\_name) | The name of the key-pair to associate with the Tailscale Subnet Router EC2 instance. | `string` | `null` | no |
| <a name="input_label_key_case"></a> [label\_key\_case](#input\_label\_key\_case) | Controls the letter case of the `tags` keys (label names) for tags generated by this module.<br>Does not affect keys of tags passed in via the `tags` input.<br>Possible values: `lower`, `title`, `upper`.<br>Default value: `title`. | `string` | `null` | no |
| <a name="input_label_order"></a> [label\_order](#input\_label\_order) | The order in which the labels (ID elements) appear in the `id`.<br>Defaults to ["namespace", "environment", "stage", "name", "attributes"].<br>You can omit any of the 6 labels ("tenant" is the 6th), but at least one must be present. | `list(string)` | `null` | no |
| <a name="input_label_value_case"></a> [label\_value\_case](#input\_label\_value\_case) | Controls the letter case of ID elements (labels) as included in `id`,<br>set as tag values, and output by this module individually.<br>Does not affect values of tags passed in via the `tags` input.<br>Possible values: `lower`, `title`, `upper` and `none` (no transformation).<br>Set this to `title` and set `delimiter` to `""` to yield Pascal Case IDs.<br>Default value: `lower`. | `string` | `null` | no |
| <a name="input_labels_as_tags"></a> [labels\_as\_tags](#input\_labels\_as\_tags) | Set of labels (ID elements) to include as tags in the `tags` output.<br>Default is to include all labels.<br>Tags with empty values will not be included in the `tags` output.<br>Set to `[]` to suppress all generated tags.<br>**Notes:**<br>  The value of the `name` tag, if included, will be the `id`, not the `name`.<br>  Unlike other `null-label` inputs, the initial setting of `labels_as_tags` cannot be<br>  changed in later chained modules. Attempts to change it will be silently ignored. | `set(string)` | <pre>[<br>  "default"<br>]</pre> | no |
| <a name="input_name"></a> [name](#input\_name) | ID element. Usually the component or solution name, e.g. 'app' or 'jenkins'.<br>This is the only ID element not also included as a `tag`.<br>The "name" tag is set to the full `id` string. There is no tag with the value of the `name` input. | `string` | `null` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | ID element. Usually an abbreviation of your organization name, e.g. 'eg' or 'cp', to help ensure generated IDs are globally unique | `string` | `null` | no |
| <a name="input_preauthorized"></a> [preauthorized](#input\_preauthorized) | Determines whether or not the machines authenticated by the key will be authorized for the tailnet by default. | `bool` | `true` | no |
| <a name="input_regex_replace_chars"></a> [regex\_replace\_chars](#input\_regex\_replace\_chars) | Terraform regular expression (regex) string.<br>Characters matching the regex will be removed from the ID elements.<br>If not set, `"/[^a-zA-Z0-9-]/"` is used to remove all characters other than hyphens, letters and digits. | `string` | `null` | no |
| <a name="input_reusable"></a> [reusable](#input\_reusable) | Indicates if the key is reusable or single-use. | `bool` | `true` | no |
| <a name="input_session_logging_enabled"></a> [session\_logging\_enabled](#input\_session\_logging\_enabled) | To enable CloudWatch and S3 session logging or not. Note this does not apply to SSH sessions as AWS cannot log those sessions. | `bool` | `true` | no |
| <a name="input_session_logging_kms_key_alias"></a> [session\_logging\_kms\_key\_alias](#input\_session\_logging\_kms\_key\_alias) | Alias name for `session_logging` KMS Key. This is only applied if 2 conditions are met: (1) `session_logging_kms_key_arn` is unset, (2) `session_logging_encryption_enabled` = true. | `string` | `"alias/session_logging"` | no |
| <a name="input_session_logging_ssm_document_name"></a> [session\_logging\_ssm\_document\_name](#input\_session\_logging\_ssm\_document\_name) | Name for `session_logging` SSM document. This is only applied if 2 conditions are met: (1) `session_logging_enabled` = true, (2) `create_run_shell_document` = true. | `string` | `"SSM-SessionManagerRunShell-Tailscale"` | no |
| <a name="input_stage"></a> [stage](#input\_stage) | ID element. Usually used to indicate role, e.g. 'prod', 'staging', 'source', 'build', 'test', 'deploy', 'release' | `string` | `null` | no |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | The Subnet IDs which the Tailscale Subnet Router EC2 instance will run in. These *should* be private subnets. | `list(string)` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Additional tags (e.g. `{'BusinessUnit': 'XYZ'}`).<br>Neither the tag keys nor the tag values will be modified by this module. | `map(string)` | `{}` | no |
| <a name="input_tenant"></a> [tenant](#input\_tenant) | ID element \_(Rarely used, not included by default)\_. A customer identifier, indicating who this instance of a resource is for | `string` | `null` | no |
| <a name="input_user_data"></a> [user\_data](#input\_user\_data) | The user\_data to use for the Tailscale Subnet Router EC2 instance. You can use this to automate installation of all the required command line tools. | `string` | `""` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | The ID of the VPC which the Tailscale Subnet Router EC2 instance will run in. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_autoscaling_group_id"></a> [autoscaling\_group\_id](#output\_autoscaling\_group\_id) | The ID of the Tailscale Subnet Router EC2 instance Autoscaling Group. |
| <a name="output_instance_name"></a> [instance\_name](#output\_instance\_name) | The name tag value of the Tailscale Subnet Router EC2 instance. |
| <a name="output_launch_template_id"></a> [launch\_template\_id](#output\_launch\_template\_id) | The ID of the Tailscale Subnet Router EC2 instance Launch Template. |
| <a name="output_security_group_id"></a> [security\_group\_id](#output\_security\_group\_id) | The ID of the Tailscale Subnet Router EC2 instance Security Group. |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
