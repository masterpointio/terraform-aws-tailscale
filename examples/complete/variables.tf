variable "availability_zones" {
  type        = list(string)
  description = "List of Availability Zones where subnets will be created"
}

variable "oauth_client_id" {
  type        = string
  description = <<-EOF
  The OAuth application's ID when using OAuth client credentials.
  Can be set via the TAILSCALE_OAUTH_CLIENT_ID environment variable.
  Both 'oauth_client_id' and 'oauth_client_secret' must be set.
  Conflicts with 'api_key'.
  EOF
}

variable "oauth_client_secret" {
  type        = string
  description = <<-EOF
  (Sensitive) The OAuth application's secret when using OAuth client credentials.
  Can be set via the TAILSCALE_OAUTH_CLIENT_SECRET environment variable.
  Both 'oauth_client_id' and 'oauth_client_secret' must be set.
  Conflicts with 'api_key'.
  EOF
}

variable "region" {
  type        = string
  description = "The AWS Region to deploy these resources to."
}

variable "tailnet" {
  type        = string
  description = <<-EOF
  The organization name of the Tailnet in which to perform actions.
  Can be set via the TAILSCALE_TAILNET environment variable.
  Default is the tailnet that owns API credentials passed to the provider.
  EOF
}
