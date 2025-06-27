# Simplified test focused only on locals logic without full module execution
variables {
  # Basic required variables
  vpc_id              = "vpc-12345678"
  subnet_ids          = ["subnet-12345678", "subnet-87654321"]
  advertise_routes    = ["10.0.1.0/24", "10.0.2.0/24"]
  primary_tag         = "test-router"
  additional_tags     = ["prod", "subnet-router"]
  tailscaled_extra_flags = ["--verbose", "--debug"]
  tailscale_up_extra_flags = ["--accept-routes", "--accept-dns"]
  ssm_state_enabled   = true

  # Context variables for proper ID generation
  namespace   = "test-namespace"
  environment = "test-env"
  name        = "tailscale-subnet-router"
}

# Test only the locals logic - use validate command instead of plan
run "test_locals_basic_transformations" {
  command = plan
  
  # Check primary tag logic
  assert {
    condition     = local.primary_tag == var.primary_tag
    error_message = "Primary tag should match variable when provided"
  }

  # Check tag prefixing
  assert {
    condition     = local.prefixed_primary_tag == "tag:${var.primary_tag}"
    error_message = "Prefixed primary tag should have 'tag:' prefix"
  }

  # Check additional tags prefixing
  assert {
    condition     = length(local.prefixed_additional_tags) == length(var.additional_tags)
    error_message = "Prefixed additional tags should match input length"
  }

  assert {
    condition     = alltrue([for tag in local.prefixed_additional_tags : startswith(tag, "tag:")])
    error_message = "All prefixed additional tags should start with 'tag:'"
  }

  # Check tailscale tags concatenation
  assert {
    condition = length(local.tailscale_tags) == 1 + length(var.additional_tags)
    error_message = "Tailscale tags should contain primary tag plus additional tags"
  }

  assert {
    condition = local.tailscale_tags[0] == local.prefixed_primary_tag
    error_message = "First tailscale tag should be the prefixed primary tag"
  }

  # Check SSM state configuration
  assert {
    condition = local.ssm_state_param_name == "/tailscale/${module.this.id}/state"
    error_message = "SSM state parameter name should follow expected format when enabled"
  }

  assert {
    condition = startswith(local.ssm_state_flag, "--state=")
    error_message = "SSM state flag should start with '--state=' when enabled"
  }

  # Check flags joining
  assert {
    condition = contains(local.tailscaled_extra_flags, "--verbose")
    error_message = "Tailscaled extra flags should contain provided flags"
  }

  assert {
    condition = contains(local.tailscaled_extra_flags, "--debug")
    error_message = "Tailscaled extra flags should contain all provided flags"
  }

  assert {
    condition = contains(local.tailscaled_extra_flags, "--state=")
    error_message = "Tailscaled extra flags should include SSM state flag when enabled"
  }

  # Check enabled flags
  assert {
    condition = local.tailscaled_extra_flags_enabled == true
    error_message = "Tailscaled extra flags enabled should be true when flags present"
  }

  assert {
    condition = local.tailscale_up_extra_flags_enabled == true
    error_message = "Tailscale up extra flags enabled should be true when flags present"
  }
}

run "test_locals_empty_conditions" {
  variables {
    vpc_id              = "vpc-12345678"
    subnet_ids          = ["subnet-12345678"]
    advertise_routes    = ["10.0.1.0/24"]
    primary_tag         = "test-router"
    additional_tags     = []
    tailscaled_extra_flags = []
    tailscale_up_extra_flags = []
    ssm_state_enabled   = false
    namespace           = "test-namespace"
    environment         = "test-env"
    name                = "tailscale-subnet-router"
  }
  command = plan

  assert {
    condition = length(local.prefixed_additional_tags) == 0
    error_message = "Prefixed additional tags should be empty when no additional tags provided"
  }

  assert {
    condition = length(local.tailscale_tags) == 1
    error_message = "Tailscale tags should only contain primary tag when no additional tags"
  }

  assert {
    condition = local.tailscaled_extra_flags == ""
    error_message = "Tailscaled extra flags should be empty string when no flags provided"
  }

  assert {
    condition = local.tailscaled_extra_flags_enabled == false
    error_message = "Tailscaled extra flags enabled should be false when empty"
  }

  assert {
    condition = local.tailscale_up_extra_flags_enabled == false
    error_message = "Tailscale up extra flags enabled should be false when empty"
  }

  assert {
    condition = local.ssm_state_param_name == null
    error_message = "SSM state parameter name should be null when disabled"
  }

  assert {
    condition = local.ssm_state_flag == ""
    error_message = "SSM state flag should be empty when disabled"
  }
}

run "test_locals_primary_tag_fallback" {
  variables {
    vpc_id           = "vpc-12345678"
    subnet_ids       = ["subnet-12345678"]
    advertise_routes = ["10.0.1.0/24"]
    primary_tag      = null
    namespace        = "test-namespace"
    environment      = "test-env"
    name             = "tailscale-subnet-router"
  }
  command = plan

  assert {
    condition = local.primary_tag == module.this.id
    error_message = "Primary tag should fallback to module.this.id when null"
  }

  assert {
    condition = local.primary_tag != null
    error_message = "Primary tag should not be null when using module.this.id fallback"
  }
}

run "test_locals_compact_function" {
  variables {
    vpc_id                 = "vpc-12345678"
    subnet_ids             = ["subnet-12345678"]
    advertise_routes       = ["10.0.1.0/24"]
    tailscaled_extra_flags = ["--verbose", "", "--debug", null]
    ssm_state_enabled      = false
    namespace              = "test-namespace"
    environment            = "test-env"
    name                   = "tailscale-subnet-router"
  }
  command = plan

  assert {
    condition = !contains(split(" ", local.tailscaled_extra_flags), "")
    error_message = "Compact should remove empty strings from flags"
  }

  assert {
    condition = contains(local.tailscaled_extra_flags, "--verbose")
    error_message = "Valid flags should be preserved after compact"
  }

  assert {
    condition = contains(local.tailscaled_extra_flags, "--debug")
    error_message = "All valid flags should be preserved after compact"
  }
}