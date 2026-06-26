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

  source_dest_check_disabled = var.source_dest_check == false

  # A subnet resolves to its explicit route table association, or the VPC main table when none.
  resolved_route_table_ids = distinct(concat(
    var.route_table_ids,
    [for rt in data.aws_route_table.target : rt.route_table_id],
  ))
  routes_enabled = length(local.resolved_route_table_ids) > 0 && length(var.route_destination_cidrs) > 0

  routing_iam_enabled = local.source_dest_check_disabled || local.routes_enabled

  # Routed-through (VPC -> tailnet) packets are evaluated against the router's security group at the
  # ENI, so the forwarded sources need an ingress rule or AWS drops them. Default to the VPC CIDR for
  # out-of-the-box behavior; narrow with var.route_source_cidrs.
  route_source_cidrs = local.routes_enabled ? (
    length(var.route_source_cidrs) > 0 ? var.route_source_cidrs : compact([one(data.aws_vpc.this[*].cidr_block)])
  ) : []

  routing_security_group_rules = length(local.route_source_cidrs) > 0 ? {
    tailscale-vpc-forward = {
      type             = "ingress"
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      description      = "Allow VPC sources to be forwarded into the tailnet (VPC to tailnet routing)"
      cidr_blocks      = local.route_source_cidrs
      ipv6_cidr_blocks = null
      prefix_list_ids  = null
      self             = null
    }
  } : {}

  routing_statements = concat(
    local.source_dest_check_disabled ? [{
      sid       = "DisableSourceDestCheck"
      effect    = "Allow"
      actions   = ["ec2:ModifyInstanceAttribute"]
      resources = ["arn:aws:ec2:*:*:instance/*"]
      conditions = [{
        test     = "StringEquals"
        variable = "ec2:ResourceTag/Name"
        values   = [module.this.id]
      }]
    }] : [],
    local.routes_enabled ? [
      {
        sid        = "ManageRoutes"
        effect     = "Allow"
        actions    = ["ec2:CreateRoute", "ec2:ReplaceRoute", "ec2:DeleteRoute"]
        resources  = [for id in local.resolved_route_table_ids : "arn:aws:ec2:*:*:route-table/${id}"]
        conditions = []
      },
      {
        # DescribeRouteTables has no resource-level support; the instance reads route ownership
        # before deleting so it never removes a route a replacement has already re-claimed.
        sid        = "DescribeRouteTables"
        effect     = "Allow"
        actions    = ["ec2:DescribeRouteTables"]
        resources  = ["*"]
        conditions = []
      },
    ] : [],
  )

  userdata = templatefile("${path.module}/userdata.sh.tmpl", {
    authkey = coalesce(
      one(tailscale_oauth_client.default[*].key),
      one(tailscale_tailnet_key.default[*].key),
    )
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

    source_dest_check_disabled = local.source_dest_check_disabled
    routes_enabled             = local.routes_enabled
    route_table_ids            = join(",", local.resolved_route_table_ids)
    route_destination_cidrs    = join(",", var.route_destination_cidrs)
  })
}

data "aws_route_table" "target" {
  for_each  = toset(var.route_table_subnet_ids)
  subnet_id = each.value
}

data "aws_vpc" "this" {
  count = local.routes_enabled && length(var.route_source_cidrs) == 0 ? 1 : 0
  id    = var.vpc_id
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
  additional_security_group_rules = merge(var.additional_security_group_rules, local.routing_security_group_rules)

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

resource "tailscale_oauth_client" "default" {
  count = var.authkey_config.tailscale_oauth_client != null ? 1 : 0

  description = var.authkey_config.tailscale_oauth_client.description
  scopes      = var.authkey_config.tailscale_oauth_client.scopes
  tags        = local.tailscale_tags
}

resource "tailscale_tailnet_key" "default" {
  count = var.authkey_config.tailscale_tailnet_key != null ? 1 : 0

  description   = var.authkey_config.tailscale_tailnet_key.description
  ephemeral     = var.authkey_config.tailscale_tailnet_key.ephemeral
  expiry        = var.authkey_config.tailscale_tailnet_key.expiry
  preauthorized = var.authkey_config.tailscale_tailnet_key.preauthorized
  reusable      = var.authkey_config.tailscale_tailnet_key.reusable
  tags          = local.tailscale_tags
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

module "routing_policy" {
  count   = local.routing_iam_enabled ? 1 : 0
  source  = "cloudposse/iam-policy/aws"
  version = "2.0.2"

  attributes  = ["routing"]
  description = "VPC -> tailnet routing access for ${module.this.id} subnet router (source/dest check and route table management)."

  iam_policy_enabled = true
  iam_policy = [{
    statements = local.routing_statements
  }]
  context = module.this.context
  tags    = module.this.tags
}

resource "aws_iam_role_policy_attachment" "routing" {
  count      = local.routing_iam_enabled ? 1 : 0
  role       = module.tailscale_subnet_router.role_id
  policy_arn = module.routing_policy[0].policy_arn
}
