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
    override_during = plan
  }
}

run "test_primary_tag_provided" {
  command = plan

  variables {
    vpc_id      = "vpc-test123"
    subnet_ids  = ["subnet-test123"]
    namespace   = "test"
    name        = "tailscale"
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
  command = plan

  variables {
    vpc_id      = "vpc-test123"
    subnet_ids  = ["subnet-test123"]
    namespace   = "test"
    name        = "tailscale"
    primary_tag = "test-router"
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
    condition = strcontains(local.userdata, "tag:test-tag1") && strcontains(local.userdata, "tag:test-tag2")
    error_message = "Expected userdata to contain additional tags"
  }
}

run "test_tailscaled_extra_flags" {
  command = plan

  variables {
    vpc_id      = "vpc-test123"
    subnet_ids  = ["subnet-test123"]
    namespace   = "test"
    name        = "tailscale"
    tailscaled_extra_flags = ["--state=mem:", "--verbose=1"]
  }

  # Test that tailscaled_extra_flags are rendered in userdata
  assert {
    condition = strcontains(local.userdata, "--state=mem:") && strcontains(local.userdata, "--verbose=1")
    error_message = "Expected userdata to contain tailscaled extra flags"
  }

  # Test that tailscaled_extra_flags are rendered in userdata
  assert {
    condition = strcontains(local.userdata, "--state=mem:") && strcontains(local.userdata, "--verbose=1")
    error_message = "Expected userdata to contain tailscaled extra flags"
  }
}
