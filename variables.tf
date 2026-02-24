#################################
## Subnet Router EC2 Instance ##
###############################

variable "vpc_id" {
  type        = string
  description = "The ID of the VPC which the Tailscale Subnet Router EC2 instance will run in."
}

variable "subnet_ids" {
  type        = list(string)
  description = "The Subnet IDs which the Tailscale Subnet Router EC2 instance will run in. These *should* be private subnets."
}

variable "additional_security_group_ids" {
  default     = []
  type        = list(string)
  description = "Additional Security Group IDs to associate with the Tailscale Subnet Router EC2 instance."
}

variable "additional_security_group_rules" {
  description = "Additional security group rules that will be attached to the primary security group"
  type = map(object({
    type      = string
    from_port = number
    to_port   = number
    protocol  = string

    description      = optional(string)
    cidr_blocks      = optional(list(string))
    ipv6_cidr_blocks = optional(list(string))
    prefix_list_ids  = optional(list(string))
    self             = optional(bool)
  }))
  default = {}
}

variable "create_run_shell_document" {
  default     = true
  type        = bool
  description = "Whether or not to create the SSM-SessionManagerRunShell SSM Document."
}

variable "session_logging_enabled" {
  default     = true
  type        = bool
  description = <<EOF
  To enable CloudWatch and S3 session logging or not.
  Note this does not apply to SSH sessions as AWS cannot log those sessions.
  EOF
}

variable "session_logging_kms_key_alias" {
  default     = "alias/session_logging"
  type        = string
  description = <<EOF
  Alias name for `session_logging` KMS Key.
  This is only applied if 2 conditions are met: (1) `session_logging_kms_key_arn` is unset,
  (2) `session_logging_encryption_enabled` = true.
  EOF
}

variable "session_logging_ssm_document_name" {
  default     = "SSM-SessionManagerRunShell-Tailscale"
  type        = string
  description = <<EOF
  Name for `session_logging` SSM document.
  This is only applied if 2 conditions are met: (1) `session_logging_enabled` = true,
  (2) `create_run_shell_document` = true.
  EOF
}

variable "allow_ssl_requests_only" {
  description = "Whether or not to allow SSL requests only. If set to `true` this will create a bucket policy that `Deny` if SSL is not used in the requests using the `aws:SecureTransport` condition."
  type        = bool
  default     = false
}

variable "allow_encrypted_uploads_only" {
  description = "Whether or not to allow encrypted uploads only. If set to `true` this will create a bucket policy that `Deny` if encryption header is missing in the requests."
  type        = bool
  default     = false
}

variable "key_pair_name" {
  default     = null
  type        = string
  description = "The name of the key-pair to associate with the Tailscale Subnet Router EC2 instance."
}

variable "user_data" {
  default     = ""
  type        = string
  description = <<EOF
  The user_data to use for the Tailscale Subnet Router EC2 instance.
  You can use this to automate installation of all the required command line tools.
  EOF
}

variable "ami" {
  default     = ""
  type        = string
  description = <<EOF
  The AMI to use for the Tailscale Subnet Router EC2 instance.
  If not provided, the latest Amazon Linux 2 AMI will be used.
  Note: This will update periodically as AWS releases updates to their AL2 AMI.
  Pin to a specific AMI if you would like to avoid these updates.
  EOF
}

variable "architecture" {
  default     = "arm64"
  type        = string
  description = "The architecture of the AMI (e.g., x86_64, arm64)"
}

variable "instance_type" {
  default     = "t4g.nano"
  type        = string
  description = "The instance type to use for the Tailscale Subnet Router EC2 instance."
}

variable "monitoring_enabled" {
  description = "Enable detailed monitoring of instances"
  type        = bool
  default     = true
}

variable "associate_public_ip_address" {
  description = "Associate public IP address with subnet router"
  type        = bool
  default     = null
}

variable "max_size" {
  description = "Maximum number of instances in the Auto Scaling Group. Must be >= desired_capacity."
  type        = number
  default     = 2
}

variable "min_size" {
  description = "Minimum number of instances in the Auto Scaling Group"
  type        = number
  default     = 1
}

variable "desired_capacity" {
  description = "Desired number of instances in the Auto Scaling Group"
  type        = number
  default     = 1
}

variable "journald_system_max_use" {
  description = "Disk space the journald may use up at most"
  type        = string
  default     = "200M"
}

variable "journald_max_retention_sec" {
  description = "The maximum time to store journal entries."
  type        = string
  default     = "7d"
}
################
## Tailscale ##
##############

variable "primary_tag" {
  default     = null
  type        = string
  description = "The primary tag to apply to the Tailscale Subnet Router machine. Do not include the `tag:` prefix. This must match the OAuth client's tag. If not provided, the module will use the module's ID as the primary tag, which is configured in context.tf"
}

variable "additional_tags" {
  default     = []
  type        = list(string)
  description = "Additional Tailscale tags to apply to the Tailscale Subnet Router machine in addition to `primary_tag`. These should not include the `tag:` prefix."
}

variable "ssh_enabled" {
  type        = bool
  default     = true
  description = "Enable SSH access to the Tailscale Subnet Router EC2 instance. Defaults to true."
}

variable "exit_node_enabled" {
  type        = bool
  default     = false
  description = "Advertise Tailscale Subnet Router EC2 instance as exit node. Defaults to false."
}

variable "advertise_routes" {
  default     = []
  type        = list(string)
  description = <<EOF
  The routes (expressed as CIDRs) to advertise as part of the Tailscale Subnet Router.
  Example: ["10.0.2.0/24", "0.0.1.0/24"]
  EOF
  validation {
    condition     = can([for route in var.advertise_routes : cidrsubnet(route, 0, 0)])
    error_message = "All elements in the list must be valid CIDR blocks."
  }
}

variable "authkey_config" {
  default = {
    "tailscale_tailnet_key" = {
      "ephemeral"     = false,
      "expiry"        = 7776000,
      "preauthorized" = true,
      "reusable"      = true,
    }
  }

  description = <<-EOT
  Configuration for the auth key used in `tailscale up` command.

  One of `tailscale_oauth_client` or `tailscale_tailnet_key` must be set.

  For both options, `tags` are configured by the module and are the same that are passed to `tailscale up` command via `--advertise-tags=<tags>` flag.

  Minimal `scopes` required for `tailscale_oauth_client` are `["auth_keys", "devices:core", "devices:routes", "dns"]`.

  For additional information, please visit:
  - [tailscale up command](https://tailscale.com/docs/reference/tailscale-cli/up)
  - [Terraform tailscale_oauth_client](https://registry.terraform.io/providers/tailscale/tailscale/latest/docs/resources/oauth_client)
  - [Terraform tailscale_tailnet_key](https://registry.terraform.io/providers/tailscale/tailscale/latest/docs/resources/tailnet_key)
  EOT

  type = object({
    tailscale_oauth_client = optional(object({
      description = string
      scopes = list(string)
    }))
    tailscale_tailnet_key = optional(object({
      description   = string
      ephemeral     = bool
      expiry        = number
      preauthorized = bool
      reusable      = bool
    }))
  })

  validation {
    condition = (
      var.authkey_config.tailscale_oauth_client == null && var.authkey_config.tailscale_tailnet_key != null || 
      var.authkey_config.tailscale_oauth_client != null && var.authkey_config.tailscale_tailnet_key == null
    )
    error_message = "Exactly one of 'tailscale_oauth_client' or 'tailscale_tailnet_key' must be defined in authkey_config."
  }

  validation {
    condition = var.authkey_config.tailscale_oauth_client == null ? true : setintersection(
      var.authkey_config.tailscale_oauth_client.scopes,
      ["auth_keys", "devices:core", "devices:routes", "dns"],
    ) == toset(["auth_keys", "devices:core", "devices:routes", "dns"])
    error_message = "The 'tailscale_oauth_client.scopes' must include at least: auth_keys, devices:core, devices:routes and dns."
  }
}

variable "tailscaled_extra_flags" {
  default     = []
  type        = list(string)
  description = <<-EOT
  Extra flags to pass to Tailscale daemon for advanced configuration. Example: ["--state=mem:"]
  See more in the [docs](https://tailscale.com/kb/1278/tailscaled#flags-to-tailscaled).
  EOT
}

variable "tailscale_up_extra_flags" {
  default     = []
  type        = list(string)
  description = <<-EOT
  Extra flags to pass to `tailscale up` for advanced configuration.
  See more in the [docs](https://tailscale.com/kb/1241/tailscale-up).
  EOT
}

variable "tailscale_set_extra_flags" {
  default     = []
  type        = list(string)
  description = <<-EOT
  Extra flags to pass to `tailscale set` after `tailscale up` for persistent preference changes that don't require reauthentication.
  See more in the [docs](https://tailscale.com/docs/reference/tailscale-cli#set).
  EOT
}

variable "ssm_state_enabled" {
  default     = false
  type        = bool
  description = <<-EOT
  Control if tailscaled state is stored in AWS SSM (including preferences and keys).
  This tells the Tailscale daemon to write + read state from SSM,
  which unlocks important features like retaining the existing tailscale machine name.
  See more in the [docs](https://tailscale.com/kb/1278/tailscaled#flags-to-tailscaled).
  EOT
}

variable "ssm_policy_name" {
  default     = "ssm"
  type        = string
  description = <<EOF
  The name of the SSM policy to create.
  This is used to attach the SSM policy to the Tailscale Subnet Router EC2 instance.
  This is only applied if `ssm_state_enabled` is true.
  Multiple instances of this module can be used in the same account by setting a unique `ssm_policy_name` for each instance.
  EOF
}
