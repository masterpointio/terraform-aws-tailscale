variable "region" {
  type        = string
  description = "The AWS Region to deploy these resources to."
}

variable "availability_zones" {
  type        = list(string)
  description = "List of Availability Zones where subnets will be created"
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
