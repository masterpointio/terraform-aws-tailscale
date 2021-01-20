variable "vpc_id" {
  type        = string
  description = "The ID of the VPC which the tailscale relay instance will run in."
}

variable "subnet_ids" {
  type        = list(string)
  description = "The Subnet IDs which the tailscale relay instance will run in. These *should* be private subnets."
}

variable "instance_type" {
  default     = "t3.nano"
  type        = string
  description = "The instance type to use for the tailscale relay instance."
}

variable "ami" {
  default     = ""
  type        = string
  description = "The AMI to use for the tailscale relay instance. If not provided, the latest Amazon Linux 2 AMI will be used. Note: This will update periodically as AWS releases updates to their AL2 AMI. Pin to a specific AMI if you would like to avoid these updates."
}

variable "instance_count" {
  default     = 1
  type        = number
  description = "The number of tailscale relay instances you would like to deploy."
}

variable "key_pair_name" {
  default     = null
  type        = string
  description = "The name of the key-pair to associate with the tailscale relay instance."
}

variable "associate_public_ip_address" {
  default     = false
  type        = bool
  description = "Whether to associate a Public IP with the tailscale relay instance. Recommended against."
}

variable "iam_instance_profile" {
  default     = null
  type        = string
  description = "The name of the IAM instance profile to associate with the tailscale relay instance."
}

variable "yum_repo" {
  default     = "https://pkgs.tailscale.com/stable/amazon-linux/2/tailscale.repo"
  type        = string
  description = "The yum repo used to download tailscale. Useful if not using the Amazon Linux 2 AMI."
}

variable "advertise_routes" {
  default     = []
  type        = list(string)
  description = "The routes (expressed as CIDRs) to advertise as part of this tailscale relay instance. e.g. [ '10.0.2.0/24', '10.0.1.0/24 ]"
}

variable "authkey" {
  type        = string
  description = "The pre-auth key retrieved from the tailscale console which allows to authenticate a new device without an interactive login."
}
