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
  # Needed so `module.ssm_state[0].arn_map[...]` resolves to a known value
  # during `apply` in the SSM-state tests below.
  mock_resource "aws_ssm_parameter" {
    defaults = {
      arn = "arn:aws:ssm:us-east-1:000000000000:parameter/mock"
    }
  }
  # `cloudposse/iam-policy/aws` produces an `aws_iam_policy` whose `arn` is
  # consumed by `aws_iam_role_policy_attachment.default`. The attachment
  # validates ARN format, so the random default mock value isn't acceptable.
  mock_resource "aws_iam_policy" {
    defaults = {
      arn = "arn:aws:iam::000000000000:policy/mock"
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

# When `ssm_state_enabled = false` (the default), the module must NOT inject
# `--state` or `--statedir`; only caller-provided flags should appear.
run "test_tailscaled_extra_flags_no_ssm_state" {
  command = apply

  variables {
    tailscaled_extra_flags = ["--verbose=1"]
  }

  assert {
    condition     = local.ssm_state_flag == "" && local.ssm_statedir_flag == ""
    error_message = "Expected no SSM state flags when ssm_state_enabled is false"
  }

  assert {
    condition     = local.tailscaled_extra_flags == "--verbose=1"
    error_message = "Expected only caller-provided flags when ssm_state_enabled is false, got: ${local.tailscaled_extra_flags}"
  }
}

# When `ssm_state_enabled = true`, the module must inject both `--state=<arn>`
# and `--statedir=/var/lib/tailscale` (the latter is required so SSH host keys,
# taildrop, TKA, and the per-profile cache keep working -- see the comment on
# `local.ssm_statedir_flag` in main.tf).
run "test_tailscaled_extra_flags_ssm_state_injects_statedir" {
  command = apply

  variables {
    ssm_state_enabled = true
  }

  assert {
    condition     = strcontains(local.tailscaled_extra_flags, "--state=arn:aws:ssm:")
    error_message = "Expected module to inject --state=<ssm arn>, got: ${local.tailscaled_extra_flags}"
  }

  assert {
    condition     = strcontains(local.tailscaled_extra_flags, "--statedir=/var/lib/tailscale")
    error_message = "Expected module to inject --statedir=/var/lib/tailscale, got: ${local.tailscaled_extra_flags}"
  }

  assert {
    condition     = strcontains(local.userdata, "--statedir=/var/lib/tailscale")
    error_message = "Expected rendered userdata to contain --statedir=/var/lib/tailscale"
  }
}

# Ordering contract: module-injected flags come FIRST, caller flags come LAST.
# tailscaled uses Go's standard `flag` package (last-wins for repeated flags),
# so this ordering means caller-supplied flags take precedence over module
# defaults -- except for `--state`/`--statedir`, which the precondition below
# forbids when `ssm_state_enabled = true`.
run "test_tailscaled_extra_flags_caller_wins_ordering" {
  command = apply

  variables {
    ssm_state_enabled      = true
    tailscaled_extra_flags = ["--verbose=2"]
  }

  # `--statedir=...` must appear before `--verbose=2` in the joined string,
  # i.e. module flag is emitted first and caller flag is emitted last.
  assert {
    condition = (
      length(regexall("--statedir=/var/lib/tailscale.*--verbose=2", local.tailscaled_extra_flags)) == 1
    )
    error_message = "Expected module flags to precede caller flags (caller-wins under tailscaled last-wins parsing), got: ${local.tailscaled_extra_flags}"
  }
}

# Precondition guard: when `ssm_state_enabled = true`, the caller MUST NOT
# supply `--state` via `tailscaled_extra_flags`. Because caller flags now win
# under last-wins parsing, allowing this would silently break the SSM-state
# contract (the module-provisioned SSM parameter would be ignored).
run "test_tailscaled_extra_flags_precondition_rejects_state" {
  command = plan

  variables {
    ssm_state_enabled      = true
    tailscaled_extra_flags = ["--state=mem:"]
  }

  expect_failures = [
    aws_iam_role_policy_attachment.default,
  ]
}

# Same guard for `--statedir`: required to be `/var/lib/tailscale` whenever
# `--state` points at the portable SSM store.
run "test_tailscaled_extra_flags_precondition_rejects_statedir" {
  command = plan

  variables {
    ssm_state_enabled      = true
    tailscaled_extra_flags = ["--statedir=/tmp/custom"]
  }

  expect_failures = [
    aws_iam_role_policy_attachment.default,
  ]
}

# Sanity: when `ssm_state_enabled = false`, the precondition does not apply
# (the guarded resource has count = 0), so a caller IS allowed to pass
# `--state` / `--statedir` freely.
run "test_tailscaled_extra_flags_state_allowed_without_ssm" {
  command = apply

  variables {
    ssm_state_enabled      = false
    tailscaled_extra_flags = ["--state=mem:", "--statedir=/tmp/custom"]
  }

  assert {
    condition     = local.tailscaled_extra_flags == "--state=mem: --statedir=/tmp/custom"
    error_message = "Expected caller --state/--statedir to pass through when ssm_state_enabled is false, got: ${local.tailscaled_extra_flags}"
  }
}
