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
    condition     = local.routing_iam_enabled == false
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
}
