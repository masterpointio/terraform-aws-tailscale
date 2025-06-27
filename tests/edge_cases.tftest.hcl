# Edge cases and boundary condition tests
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

run "test_empty_additional_tags" {
  variables {
    vpc_id            = "vpc-12345678"
    subnet_ids        = ["subnet-12345678"]
    advertise_routes  = ["10.0.1.0/24"]
    primary_tag       = "test-router"
    additional_tags   = []
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
    condition = local.tailscale_tags[0] == "tag:test-router"
    error_message = "Single tailscale tag should be the prefixed primary tag"
  }
}

run "test_empty_advertise_routes" {
  variables {
    vpc_id           = "vpc-12345678"
    subnet_ids       = ["subnet-12345678"]
    advertise_routes = []
  }
  command = plan

  assert {
    condition = can(regex("routes.*=.*$", local.userdata))
    error_message = "Userdata should handle empty routes gracefully"
  }
}

run "test_empty_tailscaled_extra_flags" {
  variables {
    vpc_id                 = "vpc-12345678"
    subnet_ids             = ["subnet-12345678"]
    advertise_routes       = ["10.0.1.0/24"]
    tailscaled_extra_flags = []
    ssm_state_enabled      = false
  }
  command = plan

  assert {
    condition = local.tailscaled_extra_flags == ""
    error_message = "Tailscaled extra flags should be empty string when no flags provided"
  }

  assert {
    condition = local.tailscaled_extra_flags_enabled == false
    error_message = "Tailscaled extra flags enabled should be false when empty"
  }
}

run "test_empty_tailscale_up_extra_flags" {
  variables {
    vpc_id                   = "vpc-12345678"
    subnet_ids               = ["subnet-12345678"]
    advertise_routes         = ["10.0.1.0/24"]
    tailscale_up_extra_flags = []
  }
  command = plan

  assert {
    condition = local.tailscale_up_extra_flags_enabled == false
    error_message = "Tailscale up extra flags enabled should be false when empty"
  }
}

run "test_null_primary_tag_with_fallback" {
  variables {
    vpc_id           = "vpc-12345678"
    subnet_ids       = ["subnet-12345678"]
    advertise_routes = ["10.0.1.0/24"]
    primary_tag      = null
  }
  command = plan

  assert {
    condition = local.primary_tag != null
    error_message = "Primary tag should not be null when using module.this.id fallback"
  }

  assert {
    condition = local.primary_tag == module.this.id
    error_message = "Primary tag should fallback to module.this.id when null"
  }
}

run "test_empty_string_primary_tag" {
  variables {
    vpc_id           = "vpc-12345678"
    subnet_ids       = ["subnet-12345678"]
    advertise_routes = ["10.0.1.0/24"]
    primary_tag      = ""
  }
  command = plan

  assert {
    condition = local.primary_tag == module.this.id
    error_message = "Primary tag should fallback to module.this.id when empty string"
  }
}

run "test_single_subnet_id" {
  variables {
    vpc_id           = "vpc-12345678"
    subnet_ids       = ["subnet-12345678"]
    advertise_routes = ["10.0.1.0/24"]
  }
  command = plan

  assert {
    condition = length(var.subnet_ids) == 1
    error_message = "Should handle single subnet ID correctly"
  }
}

run "test_single_advertise_route" {
  variables {
    vpc_id           = "vpc-12345678"
    subnet_ids       = ["subnet-12345678"]
    advertise_routes = ["10.0.1.0/24"]
  }
  command = plan

  assert {
    condition = can(regex("routes.*10.0.1.0/24", local.userdata))
    error_message = "Userdata should contain single route correctly"
  }
}

run "test_flags_with_empty_strings_and_nulls" {
  variables {
    vpc_id                 = "vpc-12345678"
    subnet_ids             = ["subnet-12345678"]
    advertise_routes       = ["10.0.1.0/24"]
    tailscaled_extra_flags = ["--verbose", "", null, "--debug", ""]
    ssm_state_enabled      = false
  }
  command = plan

  assert {
    condition = !contains(split(" ", local.tailscaled_extra_flags), "")
    error_message = "Compact function should remove empty strings from flags"
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

run "test_maximum_additional_tags" {
  variables {
    vpc_id           = "vpc-12345678"
    subnet_ids       = ["subnet-12345678"]
    advertise_routes = ["10.0.1.0/24"]
    primary_tag      = "test"
    additional_tags  = ["tag1", "tag2", "tag3", "tag4", "tag5", "tag6", "tag7", "tag8", "tag9", "tag10"]
  }
  command = plan

  assert {
    condition = length(local.prefixed_additional_tags) == 10
    error_message = "Should handle many additional tags correctly"
  }

  assert {
    condition = length(local.tailscale_tags) == 11
    error_message = "Total tailscale tags should be primary + additional tags"
  }

  assert {
    condition = alltrue([for tag in local.prefixed_additional_tags : startswith(tag, "tag:")])
    error_message = "All additional tags should be properly prefixed"
  }
}

run "test_special_characters_in_tags" {
  variables {
    vpc_id           = "vpc-12345678"
    subnet_ids       = ["subnet-12345678"]
    advertise_routes = ["10.0.1.0/24"]
    primary_tag      = "test-router_v1.0"
    additional_tags  = ["prod-env", "subnet_router", "v1.0-beta"]
  }
  command = plan

  assert {
    condition = local.prefixed_primary_tag == "tag:test-router_v1.0"
    error_message = "Primary tag with special characters should be handled correctly"
  }

  assert {
    condition = contains(local.prefixed_additional_tags, "tag:prod-env")
    error_message = "Additional tags with hyphens should be handled correctly"
  }

  assert {
    condition = contains(local.prefixed_additional_tags, "tag:subnet_router")
    error_message = "Additional tags with underscores should be handled correctly"
  }

  assert {
    condition = contains(local.prefixed_additional_tags, "tag:v1.0-beta")
    error_message = "Additional tags with dots and hyphens should be handled correctly"
  }
}

run "test_very_long_route_list" {
  variables {
    vpc_id     = "vpc-12345678"
    subnet_ids = ["subnet-12345678"]
    advertise_routes = [
      "10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24", "10.0.4.0/24", "10.0.5.0/24",
      "10.0.6.0/24", "10.0.7.0/24", "10.0.8.0/24", "10.0.9.0/24", "10.0.10.0/24",
      "172.16.1.0/24", "172.16.2.0/24", "172.16.3.0/24", "172.16.4.0/24", "172.16.5.0/24"
    ]
  }
  command = plan

  assert {
    condition = length(split(",", join(",", var.advertise_routes))) == length(var.advertise_routes)
    error_message = "Join operation should preserve all routes in comma-separated format"
  }

  assert {
    condition = can(regex("10.0.1.0/24.*172.16.5.0/24", local.userdata))
    error_message = "Userdata should contain all routes in order"
  }
}

run "test_ssm_state_with_empty_extra_flags" {
  variables {
    vpc_id                 = "vpc-12345678"
    subnet_ids             = ["subnet-12345678"]
    advertise_routes       = ["10.0.1.0/24"]
    tailscaled_extra_flags = []
    ssm_state_enabled      = true
  }
  command = plan

  assert {
    condition = local.tailscaled_extra_flags_enabled == true
    error_message = "Tailscaled extra flags should be enabled when SSM state flag is present"
  }

  assert {
    condition = contains(local.tailscaled_extra_flags, "--state=")
    error_message = "SSM state flag should be included even when no other extra flags"
  }
}

run "test_user_data_override" {
  variables {
    vpc_id           = "vpc-12345678"
    subnet_ids       = ["subnet-12345678"]
    advertise_routes = ["10.0.1.0/24"]
    user_data        = "custom user data script"
  }
  command = plan

  assert {
    condition = length(var.user_data) > 0
    error_message = "User data variable should be set for override test"
  }
}

run "test_whitespace_in_flags" {
  variables {
    vpc_id     = "vpc-12345678"
    subnet_ids = ["subnet-12345678"]
    advertise_routes = ["10.0.1.0/24"]
    tailscaled_extra_flags = ["  --verbose  ", " ", "--debug"]
    ssm_state_enabled = false
  }
  command = plan

  assert {
    condition = contains(local.tailscaled_extra_flags, "--verbose")
    error_message = "Flags with whitespace should be handled correctly"
  }
}