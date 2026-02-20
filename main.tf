locals {
  primary_tag              = coalesce(var.primary_tag, module.this.id)
  prefixed_primary_tag     = "tag:${local.primary_tag}"
  prefixed_additional_tags = [for tag in var.additional_tags : "tag:${tag}"]

  ssm_state_param_name = var.ssm_state_enabled ? "/tailscale/${module.this.id}/state" : null
  ssm_state_flag       = var.ssm_state_enabled ? "--state=${module.ssm_state[0].arn_map[local.ssm_state_param_name]}" : ""

  tailscale_tags = concat([local.prefixed_primary_tag], local.prefixed_additional_tags)

  tailscaled_extra_flags         = join(" ", compact(concat(var.tailscaled_extra_flags, [local.ssm_state_flag])))
  tailscaled_extra_flags_enabled = length(local.tailscaled_extra_flags) > 0

  tailscale_up_extra_flags_enabled  = length(var.tailscale_up_extra_flags) > 0
  tailscale_set_extra_flags_enabled = length(var.tailscale_set_extra_flags) > 0

  userdata = templatefile("${path.module}/userdata.sh.tmpl", {
    authkey           = tailscale_tailnet_key.default.key
    exit_node_enabled = var.exit_node_enabled
    hostname          = module.this.id
    routes            = join(",", var.advertise_routes)
    ssh_enabled       = var.ssh_enabled
    tags              = join(",", local.tailscale_tags)

    tailscaled_extra_flags_enabled    = local.tailscaled_extra_flags_enabled
    tailscaled_extra_flags            = local.tailscaled_extra_flags
    tailscale_up_extra_flags_enabled  = local.tailscale_up_extra_flags_enabled
    tailscale_up_extra_flags          = join(" ", var.tailscale_up_extra_flags)
    tailscale_set_extra_flags_enabled = local.tailscale_set_extra_flags_enabled
    tailscale_set_extra_flags         = join(" ", var.tailscale_set_extra_flags)

    journald_system_max_use    = var.journald_system_max_use
    journald_max_retention_sec = var.journald_max_retention_sec
  })
}

# Note: `trunk` ignores that this rule is already listed in `.trivyignore` file.
# Bucket does not have versioning enabled
# trivy:ignore:AVD-AWS-0090
module "tailscale_subnet_router" {
  source  = "masterpointio/ssm-agent/aws"
  version = "1.8.0"

  context = module.this.context
  tags    = module.this.tags

  vpc_id                    = var.vpc_id
  subnet_ids                = var.subnet_ids
  key_pair_name             = var.key_pair_name
  create_run_shell_document = var.create_run_shell_document

  additional_security_group_ids   = var.additional_security_group_ids
  additional_security_group_rules = var.additional_security_group_rules

  session_logging_kms_key_alias     = var.session_logging_kms_key_alias
  session_logging_enabled           = var.session_logging_enabled
  session_logging_ssm_document_name = var.session_logging_ssm_document_name

  allow_ssl_requests_only      = var.allow_ssl_requests_only
  allow_encrypted_uploads_only = var.allow_encrypted_uploads_only

  ami              = var.ami
  architecture     = var.architecture
  instance_type    = var.instance_type
  max_size         = var.max_size
  min_size         = var.min_size
  desired_capacity = var.desired_capacity

  monitoring_enabled          = var.monitoring_enabled
  associate_public_ip_address = var.associate_public_ip_address

  user_data = base64encode(length(var.user_data) > 0 ? var.user_data : local.userdata)
}

resource "tailscale_tailnet_key" "default" {
  reusable      = var.reusable
  ephemeral     = var.ephemeral
  preauthorized = var.preauthorized
  expiry        = var.expiry

  # A device is automatically tagged when it is authenticated with this key.
  tags = local.tailscale_tags
}

module "ssm_state" {
  count                = var.ssm_state_enabled ? 1 : 0
  source               = "cloudposse/ssm-parameter-store/aws"
  version              = "0.13.0"
  ignore_value_changes = true

  parameter_write = [
    {
      name        = local.ssm_state_param_name
      type        = "SecureString"
      overwrite   = "true"
      value       = "{}"
      description = "Tailscaled state of ${module.this.id} subnet router."
    }
  ]
  context = module.this.context
  tags    = module.this.tags
}

module "ssm_policy" {
  count   = var.ssm_state_enabled ? 1 : 0
  source  = "cloudposse/iam-policy/aws"
  version = "2.0.2"

  name        = var.ssm_policy_name
  description = "Additional SSM access for SSM Agent of ${module.this.id} subnet router."

  iam_policy_enabled = true
  iam_policy = [{
    statements = [
      {
        sid     = "SSMAgentPutParameter"
        effect  = "Allow"
        actions = ["ssm:PutParameter"]
        resources = [
          module.ssm_state[0].arn_map[local.ssm_state_param_name],
        ]
      },
    ]
  }]
  context = module.this.context
  tags    = module.this.tags
}

resource "aws_iam_role_policy_attachment" "default" {
  count      = var.ssm_state_enabled ? 1 : 0
  role       = module.tailscale_subnet_router.role_id
  policy_arn = module.ssm_policy[0].policy_arn
}

resource "aws_iam_role_policy_attachment" "cw_agent" {
  role       = module.tailscale_subnet_router.role_id
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}
