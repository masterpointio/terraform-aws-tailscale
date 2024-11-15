enabled = true

namespace = "eg"
stage     = "test"
name      = "tailscale"

region                  = "us-east-1"
availability_zones      = ["us-east-1a", "us-east-1b"]
ipv4_primary_cidr_block = "172.16.0.0/16"

ssm_state_enabled = true

# Replace these values with your own
tailnet             = "orgname.org.github"
oauth_client_id     = "OAUTH_CLIENT_ID"
oauth_client_secret = "OAUTH_CLIENT_SECRET"
