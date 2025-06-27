# Core locals logic validation tests
mock_provider "aws" {
  mock_data "aws_region" {
    defaults = {
      name = "us-east-1"
    }
  }
  mock_data "aws_availability_zones" {
    defaults = {
      names = ["us-east-1a", "us-east-1b", "us-east-1c"]
    }
  }
  mock_data "aws_ami" {
    defaults = {
      id = "ami-12345678"
    }
  }
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Action\":\"sts:AssumeRole\",\"Effect\":\"Allow\",\"Principal\":{\"Service\":\"ec2.amazonaws.com\"}}]}"
    }
  }
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }
  mock_data "aws_partition" {
    defaults = {
      partition = "aws"
    }
  }
}

mock_provider "tailscale" {
  mock_resource "tailscale_tailnet_key" {
    defaults = {
      key = "tskey-test-123456789"
    }
  }
}

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
  namespace   = "test"
  environment = "test"
  name        = "tailscale-router"
}

run "test_primary_tag_basic" {
  command = plan

  assert {
    condition     = local.primary_tag == var.primary_tag
    error_message = "Primary tag should match variable when provided"
  }
}

run "test_primary_tag_defaults_to_module_id" {
  variables {
    vpc_id              = "vpc-12345678"
    subnet_ids          = ["subnet-12345678"]
    advertise_routes    = ["10.0.1.0/24"]
    primary_tag         = null
    namespace           = "test"
    environment         = "test"
    name                = "tailscale-router"
  }
  command = plan

  assert {
    condition     = local.primary_tag == module.this.id
    error_message = "Primary tag should default to module.this.id when null"
  }
}

run "test_prefixed_tags_formatting" {
  command = plan

  assert {
    condition     = local.prefixed_primary_tag == "tag:${var.primary_tag}"
    error_message = "Prefixed primary tag should have 'tag:' prefix"
  }

  assert {
    condition     = length(local.prefixed_additional_tags) == length(var.additional_tags)
    error_message = "Prefixed additional tags should match input length"
  }

  assert {
    condition     = alltrue([for tag in local.prefixed_additional_tags : startswith(tag, "tag:")])
    error_message = "All prefixed additional tags should start with 'tag:'"
  }
}

run "test_tailscale_tags_concatenation" {
  command = plan

  assert {
    condition = length(local.tailscale_tags) == 1 + length(var.additional_tags)
    error_message = "Tailscale tags should contain primary tag plus additional tags"
  }

  assert {
    condition = local.tailscale_tags[0] == local.prefixed_primary_tag
    error_message = "First tailscale tag should be the prefixed primary tag"
  }

  assert {
    condition = alltrue([for tag in local.tailscale_tags : startswith(tag, "tag:")])
    error_message = "All tailscale tags should be prefixed with 'tag:'"
  }
}

run "test_ssm_state_parameter_name" {
  command = plan

  assert {
    condition = local.ssm_state_param_name == "/tailscale/${module.this.id}/state"
    error_message = "SSM state parameter name should follow expected format when enabled"
  }
}

run "test_ssm_state_flag_generation" {
  command = plan

  assert {
    condition = startswith(local.ssm_state_flag, "--state=")
    error_message = "SSM state flag should start with '--state=' when enabled"
  }

  assert {
    condition = contains(local.ssm_state_flag, local.ssm_state_param_name)
    error_message = "SSM state flag should contain the parameter name when enabled"
  }
}

run "test_ssm_state_disabled" {
  variables {
    vpc_id              = "vpc-12345678"
    subnet_ids          = ["subnet-12345678"]
    advertise_routes    = ["10.0.1.0/24"]
    ssm_state_enabled   = false
    namespace           = "test"
    environment         = "test"
    name                = "tailscale-router"
  }
  command = plan

  assert {
    condition = local.ssm_state_param_name == null
    error_message = "SSM state parameter name should be null when disabled"
  }

  assert {
    condition = local.ssm_state_flag == ""
    error_message = "SSM state flag should be empty when disabled"
  }
}

run "test_tailscaled_extra_flags_join" {
  command = plan

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
}

run "test_tailscaled_extra_flags_enabled_logic" {
  command = plan

  assert {
    condition = local.tailscaled_extra_flags_enabled == true
    error_message = "Tailscaled extra flags enabled should be true when flags present"
  }
}

run "test_tailscaled_extra_flags_disabled" {
  variables {
    vpc_id                   = "vpc-12345678"
    subnet_ids               = ["subnet-12345678"]
    advertise_routes         = ["10.0.1.0/24"]
    tailscaled_extra_flags   = []
    ssm_state_enabled        = false
    namespace                = "test"
    environment              = "test"
    name                     = "tailscale-router"
  }
  command = plan

  assert {
    condition = local.tailscaled_extra_flags_enabled == false
    error_message = "Tailscaled extra flags enabled should be false when no flags present"
  }

  assert {
    condition = local.tailscaled_extra_flags == ""
    error_message = "Tailscaled extra flags should be empty string when no flags"
  }
}

run "test_tailscale_up_extra_flags_enabled" {
  command = plan

  assert {
    condition = local.tailscale_up_extra_flags_enabled == true
    error_message = "Tailscale up extra flags enabled should be true when flags present"
  }
}

run "test_tailscale_up_extra_flags_disabled" {
  variables {
    vpc_id                     = "vpc-12345678"
    subnet_ids                 = ["subnet-12345678"]
    advertise_routes           = ["10.0.1.0/24"]
    tailscale_up_extra_flags   = []
    namespace                  = "test"
    environment                = "test"
    name                       = "tailscale-router"
  }
  command = plan

  assert {
    condition = local.tailscale_up_extra_flags_enabled == false
    error_message = "Tailscale up extra flags enabled should be false when no flags present"
  }
}

run "test_userdata_template_variables" {
  command = plan

  assert {
    condition = can(regex("authkey", local.userdata))
    error_message = "Userdata should contain authkey variable"
  }

  assert {
    condition = can(regex("hostname", local.userdata))
    error_message = "Userdata should contain hostname variable"
  }

  assert {
    condition = can(regex("routes", local.userdata))
    error_message = "Userdata should contain routes variable"
  }

  assert {
    condition = can(regex("tags", local.userdata))
    error_message = "Userdata should contain tags variable"
  }
}

run "test_routes_join_in_userdata" {
  command = plan

  assert {
    condition = can(regex("10.0.1.0/24,10.0.2.0/24", local.userdata))
    error_message = "Userdata should contain comma-separated routes"
  }
}

run "test_tags_join_in_userdata" {
  command = plan

  assert {
    condition = can(regex("tag:test-router,tag:prod,tag:subnet-router", local.userdata))
    error_message = "Userdata should contain comma-separated tags with prefixes"
  }
}

run "test_compact_function_on_flags" {
  variables {
    vpc_id                   = "vpc-12345678"
    subnet_ids               = ["subnet-12345678"]
    advertise_routes         = ["10.0.1.0/24"]
    tailscaled_extra_flags   = ["--verbose", "", "--debug", null]
    ssm_state_enabled        = false
    namespace                = "test"
    environment              = "test"
    name                     = "tailscale-router"
  }
  command = plan

  assert {
    condition = !contains(local.tailscaled_extra_flags, "")
    error_message = "Compact should remove empty strings from flags"
  }
}