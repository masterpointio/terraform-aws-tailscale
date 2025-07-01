plugin "terraform" {
  enabled = true
  preset  = "all"
}

config {
  format = "compact"

  # Inspect vars passed into "module" blocks. eg, lint AMI value passed into ec2 module.
  # https://github.com/terraform-linters/tflint/blob/master/docs/user-guide/calling-modules.md
  call_module_type = "all"

  # default values but keeping them here for clarity
  disabled_by_default = false
  force = false
}

# Installing tflint rulesets from Github requires setting a GITHUB_TOKEN
# environment variable. Without it, you'll get an error like this:
#   $ tflint --init
#   Installing "aws" plugin...
#   Failed to install a plugin; Failed to fetch GitHub releases: GET https://api.github.com/repos/terraform-linters/tflint-ruleset-aws/releases/tags/v0.39.0: 401 Bad credentials []
#
# The solution is to provide a github PAT via a GITHUB_TOKEN env var,
# export GITHUB_TOKEN=github_pat_120abc123def456ghi789jkl123mno456pqr789stu123vwx456yz789
#
# See docs for more info: https://github.com/terraform-linters/tflint/blob/master/docs/user-guide/plugins.md#avoiding-rate-limiting
plugin "aws" {
  enabled = true
  version = "0.39.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
  deep_check = false
}

# Allow variables to exist in more files than ONLY variables.tf
# Example use cases where we prefer for variables to exist in context,
# - context.tf (applicable to the null-label module)
# - providers.tf (when passing in secret keys from SOPs - example, github provider)
# https://github.com/terraform-linters/tflint-ruleset-terraform/blob/main/docs/rules/terraform_standard_module_structure.md
rule "terraform_standard_module_structure" {
  enabled = false
}