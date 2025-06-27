# Real-world complex scenarios tests
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

run "test_production_environment_scenario" {
  variables {
    vpc_id     = "vpc-prod-12345678"
    subnet_ids = ["subnet-prod-private-1", "subnet-prod-private-2", "subnet-prod-private-3"]
    advertise_routes = [
      "10.1.0.0/16",     # Production VPC CIDR
      "10.2.0.0/16",     # Staging VPC CIDR
      "10.3.0.0/16",     # Development VPC CIDR
      "172.16.0.0/12"    # On-premises network
    ]
    primary_tag    = "prod-subnet-router"
    additional_tags = ["production", "critical", "subnet-router", "us-east-1", "team-platform"]
    
    # Advanced Tailscale configuration
    tailscaled_extra_flags = [
      "--verbose=2",
      "--port=41641",
      "--socks5-server=localhost:1055",
      "--netfilter-mode=on"
    ]
    tailscale_up_extra_flags = [
      "--accept-routes",
      "--accept-dns",
      "--shields-up",
      "--operator=platform-team"
    ]
    
    # State persistence for production
    ssm_state_enabled = true
    
    # Production instance settings
    instance_type    = "t4g.small"
    max_size         = 3
    min_size         = 2
    desired_capacity = 2
    
    # Security and monitoring
    monitoring_enabled              = true
    associate_public_ip_address     = false
    session_logging_enabled         = true
    
    # Extended journald settings for production
    journald_system_max_use    = "500M"
    journald_max_retention_sec = "30d"
  }
  command = plan

  assert {
    condition = length(local.tailscale_tags) == 6
    error_message = "Production scenario should have primary tag plus 5 additional tags"
  }

  assert {
    condition = contains(local.tailscale_tags, "tag:prod-subnet-router")
    error_message = "Should contain the primary production tag"
  }

  assert {
    condition = contains(local.tailscale_tags, "tag:production")
    error_message = "Should contain production environment tag"
  }

  assert {
    condition = contains(local.tailscale_tags, "tag:critical")
    error_message = "Should contain criticality tag"
  }

  assert {
    condition = can(regex("10.1.0.0/16,10.2.0.0/16,10.3.0.0/16,172.16.0.0/12", local.userdata))
    error_message = "Should contain all production route advertisements"
  }

  assert {
    condition = contains(local.tailscaled_extra_flags, "--verbose=2")
    error_message = "Should contain production logging level"
  }

  assert {
    condition = contains(local.tailscaled_extra_flags, "--netfilter-mode=on")
    error_message = "Should contain security hardening flags"
  }

  assert {
    condition = local.tailscaled_extra_flags_enabled == true
    error_message = "Extra flags should be enabled for production configuration"
  }

  assert {
    condition = local.tailscale_up_extra_flags_enabled == true
    error_message = "Up flags should be enabled for production configuration"
  }

  assert {
    condition = can(regex("--accept-routes.*--accept-dns.*--shields-up", join(" ", var.tailscale_up_extra_flags)))
    error_message = "Should contain production security flags for tailscale up"
  }

  assert {
    condition = local.ssm_state_param_name != null
    error_message = "SSM state should be enabled for production"
  }

  assert {
    condition = contains(local.tailscaled_extra_flags, "--state=")
    error_message = "Should include SSM state flag in production configuration"
  }
}

run "test_development_environment_scenario" {
  variables {
    vpc_id     = "vpc-dev-87654321"
    subnet_ids = ["subnet-dev-private-1"]
    advertise_routes = ["10.100.0.0/16"]
    primary_tag      = "dev-subnet-router"
    additional_tags  = ["development", "temporary"]
    
    # Minimal configuration for development
    tailscaled_extra_flags   = ["--verbose"]
    tailscale_up_extra_flags = ["--accept-routes"]
    
    # No state persistence for dev
    ssm_state_enabled = false
    
    # Smaller instance for dev
    instance_type    = "t4g.nano"
    max_size         = 1
    min_size         = 1
    desired_capacity = 1
    
    # Less monitoring for dev
    monitoring_enabled = false
    session_logging_enabled = false
    
    # Shorter retention for dev
    journald_system_max_use    = "100M"
    journald_max_retention_sec = "3d"
  }
  command = plan

  assert {
    condition = length(local.tailscale_tags) == 3
    error_message = "Development scenario should have primary tag plus 2 additional tags"
  }

  assert {
    condition = contains(local.tailscale_tags, "tag:dev-subnet-router")
    error_message = "Should contain the primary development tag"
  }

  assert {
    condition = contains(local.tailscale_tags, "tag:development")
    error_message = "Should contain development environment tag"
  }

  assert {
    condition = can(regex("10.100.0.0/16", local.userdata))
    error_message = "Should contain development route advertisement"
  }

  assert {
    condition = local.ssm_state_param_name == null
    error_message = "SSM state should be disabled for development"
  }

  assert {
    condition = local.ssm_state_flag == ""
    error_message = "SSM state flag should be empty for development"
  }

  assert {
    condition = !contains(local.tailscaled_extra_flags, "--state=")
    error_message = "Should not include SSM state flag in development configuration"
  }
}

run "test_multi_region_hub_scenario" {
  variables {
    vpc_id     = "vpc-hub-11223344"
    subnet_ids = ["subnet-hub-us-east-1a", "subnet-hub-us-east-1b", "subnet-hub-us-east-1c"]
    advertise_routes = [
      "10.0.0.0/8",      # All private Class A
      "172.16.0.0/12",   # All private Class B
      "192.168.0.0/16"   # All private Class C
    ]
    primary_tag    = "hub-router"
    additional_tags = ["hub", "multi-region", "exit-node", "high-availability"]
    
    # Exit node configuration
    exit_node_enabled = true
    
    # Hub-specific flags
    tailscaled_extra_flags = [
      "--verbose=1",
      "--port=41641",
      "--netfilter-mode=on"
    ]
    tailscale_up_extra_flags = [
      "--accept-routes",
      "--accept-dns",
      "--advertise-exit-node",
      "--operator=network-team"
    ]
    
    # High availability configuration
    ssm_state_enabled = true
    max_size          = 5
    min_size          = 3
    desired_capacity  = 3
    
    # Robust instance for hub
    instance_type = "t4g.medium"
    
    # Enhanced monitoring
    monitoring_enabled          = true
    associate_public_ip_address = true
    session_logging_enabled     = true
    
    # Extended logging for hub
    journald_system_max_use    = "1G"
    journald_max_retention_sec = "90d"
  }
  command = plan

  assert {
    condition = length(local.tailscale_tags) == 5
    error_message = "Hub scenario should have primary tag plus 4 additional tags"
  }

  assert {
    condition = contains(local.tailscale_tags, "tag:hub-router")
    error_message = "Should contain the primary hub tag"
  }

  assert {
    condition = contains(local.tailscale_tags, "tag:exit-node")
    error_message = "Should contain exit-node tag"
  }

  assert {
    condition = contains(local.tailscale_tags, "tag:high-availability")
    error_message = "Should contain high availability tag"
  }

  assert {
    condition = can(regex("10.0.0.0/8,172.16.0.0/12,192.168.0.0/16", local.userdata))
    error_message = "Should advertise all major private network ranges"
  }

  assert {
    condition = can(regex("exit_node_enabled.*true", local.userdata))
    error_message = "Should enable exit node functionality"
  }

  assert {
    condition = can(regex("--advertise-exit-node", join(" ", var.tailscale_up_extra_flags)))
    error_message = "Should include exit node advertisement flag"
  }

  assert {
    condition = local.ssm_state_param_name == "/tailscale/${module.this.id}/state"
    error_message = "Should have proper SSM state parameter for hub"
  }
}

run "test_minimal_configuration_scenario" {
  variables {
    vpc_id           = "vpc-minimal-99887766"
    subnet_ids       = ["subnet-minimal-1"]
    advertise_routes = ["192.168.1.0/24"]
  }
  command = plan

  assert {
    condition = local.primary_tag == module.this.id
    error_message = "Should use module ID as primary tag when not specified"
  }

  assert {
    condition = length(local.tailscale_tags) == 1
    error_message = "Minimal configuration should only have primary tag"
  }

  assert {
    condition = local.tailscaled_extra_flags == ""
    error_message = "Should have no extra tailscaled flags in minimal config"
  }

  assert {
    condition = local.tailscaled_extra_flags_enabled == false
    error_message = "Extra flags should be disabled in minimal config"
  }

  assert {
    condition = local.tailscale_up_extra_flags_enabled == false
    error_message = "Up flags should be disabled in minimal config"
  }

  assert {
    condition = local.ssm_state_param_name == null
    error_message = "SSM state should be disabled by default"
  }

  assert {
    condition = can(regex("192.168.1.0/24", local.userdata))
    error_message = "Should contain the single route advertisement"
  }
}

run "test_mixed_flag_types_scenario" {
  variables {
    vpc_id     = "vpc-mixed-55443322"
    subnet_ids = ["subnet-mixed-1", "subnet-mixed-2"]
    advertise_routes = ["10.50.0.0/16", "10.60.0.0/16"]
    primary_tag      = "mixed-router"
    additional_tags  = ["testing", "experimental"]
    
    # Mix of different flag types
    tailscaled_extra_flags = [
      "--verbose=2",
      "--port=41642",
      "",                    # Empty string to test compact
      "--socks5-server=localhost:1056",
      null,                  # Null value to test compact
      "--netfilter-mode=off"
    ]
    tailscale_up_extra_flags = [
      "--accept-routes",
      "--operator=test-team",
      "--hostname=custom-hostname"
    ]
    
    ssm_state_enabled = true
  }
  command = plan

  assert {
    condition = !contains(split(" ", local.tailscaled_extra_flags), "")
    error_message = "Compact should remove empty strings from mixed flags"
  }

  assert {
    condition = contains(local.tailscaled_extra_flags, "--verbose=2")
    error_message = "Should preserve valid flags after compact"
  }

  assert {
    condition = contains(local.tailscaled_extra_flags, "--port=41642")
    error_message = "Should preserve port configuration"
  }

  assert {
    condition = contains(local.tailscaled_extra_flags, "--netfilter-mode=off")
    error_message = "Should preserve netfilter configuration"
  }

  assert {
    condition = contains(local.tailscaled_extra_flags, "--state=")
    error_message = "Should include SSM state flag with mixed configuration"
  }

  assert {
    condition = local.tailscaled_extra_flags_enabled == true
    error_message = "Should enable extra flags when valid flags present"
  }

  assert {
    condition = local.tailscale_up_extra_flags_enabled == true
    error_message = "Should enable up flags when present"
  }
}

run "test_cross_environment_reference_scenario" {
  variables {
    vpc_id     = "vpc-cross-env-12345"
    subnet_ids = ["subnet-prod-shared", "subnet-stage-shared", "subnet-dev-shared"]
    advertise_routes = [
      "10.1.0.0/16",   # Production
      "10.2.0.0/16",   # Staging  
      "10.3.0.0/16",   # Development
      "10.4.0.0/16"    # Shared services
    ]
    primary_tag    = "cross-env-router"
    additional_tags = ["shared-services", "cross-environment", "bridge"]
    
    # Configuration for cross-environment connectivity
    tailscaled_extra_flags = ["--verbose=1"]
    tailscale_up_extra_flags = [
      "--accept-routes",
      "--accept-dns",
      "--operator=platform-team"
    ]
    
    ssm_state_enabled = true
    
    # Medium instance for cross-env workload
    instance_type    = "t4g.small"
    max_size         = 2
    min_size         = 1
    desired_capacity = 2
  }
  command = plan

  assert {
    condition = length(local.tailscale_tags) == 4
    error_message = "Cross-environment scenario should have 4 total tags"
  }

  assert {
    condition = contains(local.tailscale_tags, "tag:cross-env-router")
    error_message = "Should contain cross-environment router tag"
  }

  assert {
    condition = contains(local.tailscale_tags, "tag:shared-services")
    error_message = "Should contain shared services tag"
  }

  assert {
    condition = contains(local.tailscale_tags, "tag:bridge")
    error_message = "Should contain bridge functionality tag"
  }

  assert {
    condition = can(regex("10.1.0.0/16,10.2.0.0/16,10.3.0.0/16,10.4.0.0/16", local.userdata))
    error_message = "Should advertise all environment networks"
  }

  assert {
    condition = length(var.subnet_ids) == 3
    error_message = "Should span multiple environment subnets"
  }

  assert {
    condition = local.ssm_state_param_name != null
    error_message = "Should enable state persistence for cross-environment router"
  }
}