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

  # Flags should be written to the Debian/AL2023-style path, not the legacy sysconfig path.
  assert {
    condition     = strcontains(local.userdata, "/etc/default/tailscaled") && !strcontains(local.userdata, "/etc/sysconfig/tailscaled")
    error_message = "Expected userdata to target /etc/default/tailscaled and not /etc/sysconfig/tailscaled"
  }

  # The script must update FLAGS without truncating the existing file: write to a
  # temp file first, then atomically move it into place. This preserves the
  # package-provided defaults (PORT, comments, etc.).
  assert {
    condition     = strcontains(local.userdata, "mktemp /etc/default/tailscaled") && strcontains(local.userdata, "mv -f \"$tmpfile\" /etc/default/tailscaled")
    error_message = "Expected userdata to write FLAGS via a temp file and atomic mv into /etc/default/tailscaled"
  }

  # The new FLAGS line must be emitted via a quoted heredoc so the shell does
  # not re-interpret special characters in the user-supplied flag value.
  assert {
    condition     = strcontains(local.userdata, "<<'TS_FLAGS_EOF'")
    error_message = "Expected userdata to emit FLAGS via a quoted heredoc to avoid shell re-interpretation"
  }

  assert {
    condition     = length(regexall("[^>]> /etc/default/tailscaled", local.userdata)) == 0
    error_message = "Expected userdata not to truncate /etc/default/tailscaled with a single `>` redirect"
  }

  # We must not hardcode PORT; the package default applies, and users may override via --port=... in tailscaled_extra_flags.
  assert {
    condition     = !strcontains(local.userdata, "PORT=\"41641\"")
    error_message = "Expected userdata not to hardcode PORT=\"41641\" in /etc/default/tailscaled"
  }
}

run "test_tailscaled_extra_flags_preserves_shell_metacharacters" {
  command = apply

  # Defense-in-depth: even if a flag value contains characters that are special
  # to the shell (`|`, `$`, backtick, `\`) or to common substitution tools like
  # sed, the rendered userdata must contain the value verbatim inside the FLAGS line.
  variables {
    tailscaled_extra_flags = ["--weird=a|b$c`d\\e"]
  }

  assert {
    condition     = strcontains(local.userdata, "FLAGS=\"--weird=a|b$c`d\\e\"")
    error_message = "Expected FLAGS line to contain the user-supplied flag value verbatim, including shell metacharacters"
  }
}

run "test_tailscaled_extra_flags_user_supplied_port" {
  command = apply

  variables {
    tailscaled_extra_flags = ["--port=12345"]
  }

  # The user-supplied --port flag must reach the FLAGS line.
  assert {
    condition     = strcontains(local.userdata, "--port=12345")
    error_message = "Expected userdata to contain user-supplied --port flag"
  }

  # And we must not write a competing PORT=... line ourselves.
  assert {
    condition     = !strcontains(local.userdata, "PORT=\"41641\"")
    error_message = "Expected userdata not to write a hardcoded PORT line that would conflict with user --port flag"
  }
}

run "test_tailscaled_extra_flags_disabled_by_default" {
  command = apply

  # With no extra flags and ssm_state disabled, the whole FLAGS block should be skipped
  # so that /etc/default/tailscaled is left entirely untouched.
  variables {
    ssm_state_enabled = false
  }

  assert {
    condition     = !strcontains(local.userdata, "/etc/default/tailscaled")
    error_message = "Expected userdata not to touch /etc/default/tailscaled when no extra flags are configured"
  }
}
