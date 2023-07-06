variable "tailnet_name" {
  type        = string
  description = <<EOF
  This unique name of the Tailnet that is used when registering DNS entries, e.g. 'cat-crocodile.ts.net'.
  See https://tailscale.com/kb/1217/tailnet-name/ for more information.
  EOF
}

check "device" {
  data "tailscale_device" "default" {
    name     = format("%s.%s", module.this.id, var.tailnet_name)
    wait_for = "30s"
  }

  assert {
    condition     = length(data.tailscale_device.default.tags) > 0
    error_message = "Device ${data.tailscale_device.default.name} is not tagged."
  }

  assert {
    condition     = sort(data.tailscale_device.default.tags) == sort(tolist(local.tailscale_tags))
    error_message = <<EOF
    Device ${data.tailscale_device.default.name} is not tagged with the correct tags.
    The list of expected tags is: [${join(", ", formatlist("\"%s\"", local.tailscale_tags))}]
    EOF
  }
}
