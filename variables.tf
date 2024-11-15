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

variable "instance_type" {
  default     = "t3.nano"
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

variable "expiry" {
  default     = 7776000
  type        = number
  description = "The expiry of the auth key in seconds."
}

variable "preauthorized" {
  default     = true
  type        = bool
  description = "Determines whether or not the machines authenticated by the key will be authorized for the tailnet by default."
}

variable "ephemeral" {
  default     = false
  type        = bool
  description = "Indicates if the key is ephemeral."
}

variable "reusable" {
  default     = true
  type        = bool
  description = "Indicates if the key is reusable or single-use."
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

variable "ssm_state_enabled" {
  default     = false
  type        = bool
  description = <<-EOT
  Control is tailscaled state (including preferences and keys) is stored in AWS SSM.
  See more in the [docs](https://tailscale.com/kb/1278/tailscaled#flags-to-tailscaled).
  EOT
}
