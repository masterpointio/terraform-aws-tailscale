# Common variables used across all test runs
variables {
  vpc_id     = "vpc-test123"
  subnet_ids = ["subnet-test123"]
  namespace  = "test"
  name       = "tailscale"
}

# Mock tailscale provider because it expects a real authentication (so we provide it a fake tailscale_tailnet_key)
mock_provider "tailscale" {
  mock_resource "tailscale_tailnet_key" {
    defaults = {
      key = "fake-tailscale-tailnet-key"
    }
  }
  override_resource {
    target = tailscale_tailnet_key.default
    values = {
      key = "fake-tailscale-tailnet-key"
    }
  }
}

mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Principal\":{\"Service\":\"ec2.amazonaws.com\"},\"Action\":\"sts:AssumeRole\"}]}"
    }
  }
  mock_resource "aws_launch_template" {
    defaults = {
      id = "lt-mock123456789"
    }
  }
  mock_data "aws_route_table" {
    defaults = {
      route_table_id = "rtb-frommock"
    }
  }
  mock_data "aws_vpc" {
    defaults = {
      cidr_block = "172.16.0.0/16"
    }
  }
  mock_resource "aws_iam_policy" {
    defaults = {
      arn = "arn:aws:iam::123456789012:policy/mock"
    }
  }
}

run "test_primary_tag_provided" {
  command = plan

  variables {
    primary_tag = "test-router"
  }

  # Test that the primary_tag is set to the provided value
  assert {
    condition     = local.primary_tag == "test-router"
    error_message = "Expected local.primary_tag to be 'test-router'"
  }

  # Test that the prefixed_primary_tag is set to the provided value
  assert {
    condition     = local.prefixed_primary_tag == "tag:test-router"
    error_message = "Expected local.prefixed_primary_tag to be 'tag:test-router'"
  }
}

run "test_local_userdata_rendered_template" {
  command = apply # because we need access to the tailscale_tailnet_key.default.key value

  variables {
    primary_tag     = "test-router"
    additional_tags = ["test-tag1", "test-tag2"]
  }

  # Ensure userdata script contains `tailscale up` and tailscale key
  assert {
    condition = (
      strcontains(local.userdata, "tailscale up") &&
      strcontains(local.userdata, "--authkey=fake-tailscale-tailnet-key") &&
      strcontains(local.userdata, "SystemMaxUse=200M")
    )
    error_message = "Expected userdata to contain tailscale up command, authkey, and journald config"
  }

  # Ensure userdata script contains transformed additional tags
  assert {
    condition     = strcontains(local.userdata, "tag:test-tag1") && strcontains(local.userdata, "tag:test-tag2")
    error_message = "Expected userdata to contain additional tags"
  }
}

run "test_tailscaled_extra_flags" {
  command = apply # because we need access to the tailscale_tailnet_key.default.key value

  variables {
    tailscaled_extra_flags = ["--state=mem:", "--verbose=1"]
  }

  # Test that tailscaled_extra_flags are rendered in userdata
  assert {
    condition     = strcontains(local.userdata, "--state=mem:") && strcontains(local.userdata, "--verbose=1")
    error_message = "Expected userdata to contain tailscaled extra flags"
  }
}

run "test_routing_disabled_by_default" {
  command = apply

  # No source/dest check disable and no routing IAM policy with module defaults
  assert {
    condition     = local.routing_iam_enabled == false && length(local.routing_statements) == 0
    error_message = "Expected routing IAM to be disabled by default"
  }

  assert {
    condition     = !strcontains(local.userdata, "modify-instance-attribute")
    error_message = "Expected userdata to not touch source/dest check by default"
  }
}

run "test_source_dest_check_disabled" {
  command = apply

  variables {
    source_dest_check = false
  }

  assert {
    condition     = local.source_dest_check_disabled == true && local.routing_iam_enabled == true
    error_message = "Expected source/dest check disable to enable routing IAM"
  }

  # Without routes the policy must grant nothing beyond the instance attribute call
  assert {
    condition = (
      join(",", [for s in local.routing_statements : s.sid]) == "DisableSourceDestCheck" &&
      join(",", one(local.routing_statements).actions) == "ec2:ModifyInstanceAttribute" &&
      join(",", one(local.routing_statements).resources) == "arn:aws:ec2:*:*:instance/*"
    )
    error_message = "Expected the routing policy to carry only the source/dest check statement"
  }

  assert {
    condition     = strcontains(local.userdata, "--no-source-dest-check")
    error_message = "Expected userdata to disable source/dest check"
  }
}

run "test_routes_via_explicit_route_table_ids" {
  command = apply

  variables {
    source_dest_check       = false
    route_table_ids         = ["rtb-explicit1"]
    route_destination_cidrs = ["100.64.0.0/10"]
  }

  assert {
    condition     = local.routes_enabled == true && contains(local.resolved_route_table_ids, "rtb-explicit1")
    error_message = "Expected explicit route table id to be resolved"
  }

  assert {
    condition = (
      strcontains(local.userdata, "rtb-explicit1") &&
      strcontains(local.userdata, "100.64.0.0/10") &&
      strcontains(local.userdata, "create-route")
    )
    error_message = "Expected userdata to upsert the CGNAT route into the explicit route table"
  }

  # Routes are managed by a systemd unit whose ExecStop deletes them on graceful shutdown
  assert {
    condition = (
      strcontains(local.userdata, "tailscale-routes.service") &&
      strcontains(local.userdata, "ExecStop=/usr/local/sbin/tailscale-routes.sh down") &&
      strcontains(local.userdata, "delete-route")
    )
    error_message = "Expected a systemd unit with ExecStop cleanup of the routes"
  }

  # A Requires= dependency on tailscaled would stop this unit on every tailscaled restart,
  # firing ExecStop and permanently deleting the VPC routes (oneshot units do not restart).
  assert {
    condition = (
      length([for line in regexall("(?m)^Requires=.*$", local.userdata) : line if strcontains(line, "tailscaled.service")]) == 0 &&
      length([for line in regexall("(?m)^Wants=.*$", local.userdata) : line if strcontains(line, "tailscaled.service")]) > 0 &&
      length([for line in regexall("(?m)^Wants=.*$", local.userdata) : line if strcontains(line, "network-online.target")]) > 0
    )
    error_message = "Expected the routes unit to weakly depend on tailscaled via Wants=, not Requires="
  }

  # The route management grant must stay scoped to the resolved route tables
  assert {
    condition = (
      join(",", [for s in local.routing_statements : s.sid]) == "DisableSourceDestCheck,ManageRoutes,DescribeRouteTables" &&
      join(",", one([for s in local.routing_statements : s.actions if s.sid == "ManageRoutes"])) == "ec2:CreateRoute,ec2:ReplaceRoute,ec2:DeleteRoute" &&
      join(",", one([for s in local.routing_statements : s.resources if s.sid == "ManageRoutes"])) == "arn:aws:ec2:*:*:route-table/rtb-explicit1"
    )
    error_message = "Expected route management to be granted only on the resolved route table"
  }

  # Forwarded sources default to the VPC CIDR (mocked) and open the primary SG
  assert {
    condition = (
      join(",", local.route_source_cidrs) == "172.16.0.0/16" &&
      join(",", local.routing_security_group_rules["tailscale-vpc-forward"].cidr_blocks) == "172.16.0.0/16"
    )
    error_message = "Expected an ingress SG rule for the VPC CIDR when forwarding is enabled"
  }
}

run "test_route_source_cidrs_override" {
  command = apply

  variables {
    source_dest_check       = false
    route_table_ids         = ["rtb-explicit1"]
    route_destination_cidrs = ["100.64.0.0/10"]
    route_source_cidrs      = ["10.20.0.0/24", "10.20.1.0/24"]
  }

  assert {
    condition     = join(",", local.route_source_cidrs) == "10.20.0.0/24,10.20.1.0/24"
    error_message = "Expected explicit route_source_cidrs to override the VPC CIDR default"
  }

  assert {
    condition     = join(",", local.routing_security_group_rules["tailscale-vpc-forward"].cidr_blocks) == "10.20.0.0/24,10.20.1.0/24"
    error_message = "Expected the SG ingress rule to use the explicit source CIDRs"
  }
}

run "test_no_sg_rule_without_routes" {
  command = apply

  variables {
    source_dest_check = false
  }

  # source/dest check alone (no routes) must not open the SG
  assert {
    condition     = length(local.routing_security_group_rules) == 0
    error_message = "Expected no SG ingress rule when no routes are configured"
  }

  assert {
    condition = length(setintersection(
      toset(flatten([for s in local.routing_statements : s.actions])),
      toset(["ec2:CreateRoute", "ec2:ReplaceRoute", "ec2:DeleteRoute", "ec2:DescribeRouteTables"]),
    )) == 0
    error_message = "Expected no route management permissions when no routes are configured"
  }
}

run "test_routes_resolved_from_subnet_ids" {
  command = apply

  variables {
    route_table_subnet_ids  = ["subnet-aaa"]
    route_destination_cidrs = ["100.64.0.0/10"]
  }

  # aws_route_table data is mocked to return rtb-frommock
  assert {
    condition     = contains(local.resolved_route_table_ids, "rtb-frommock")
    error_message = "Expected subnet to resolve to its route table via data source"
  }

  assert {
    condition     = strcontains(local.userdata, "rtb-frommock")
    error_message = "Expected userdata to upsert routes into the subnet-resolved route table"
  }

  # Configuring routes must force the source/dest check off even when var.source_dest_check is true
  assert {
    condition     = local.source_dest_check_disabled == true && strcontains(local.userdata, "--no-source-dest-check")
    error_message = "Expected routes to force source/dest check disabled"
  }

  assert {
    condition     = join(",", one([for s in local.routing_statements : s.resources if s.sid == "ManageRoutes"])) == "arn:aws:ec2:*:*:route-table/rtb-frommock"
    error_message = "Expected route management to be granted on the subnet-resolved route table"
  }
}
