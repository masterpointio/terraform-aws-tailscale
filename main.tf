locals {

  primary_tag           = coalesce(var.primary_tag, "tag:${module.this.id}")
  prefixed_machine_tags = [for tag in var.machine_tags : "tag:${tag}"]
  tailscale_tags        = concat([local.primary_tag], local.prefixed_machine_tags)

  userdata = templatefile("${path.module}/userdata.sh.tmpl", {
    routes      = join(",", var.advertise_routes)
    authkey     = tailscale_tailnet_key.default.key
    hostname    = module.this.id
    tags        = join(",", local.prefixed_machine_tags)
    ssh_enabled = var.ssh_enabled
  })
}

module "tailscale_subnet_router" {
  source  = "masterpointio/ssm-agent/aws"
  version = "1.0.0"

  context = module.this.context
  tags    = module.this.tags

  vpc_id                    = var.vpc_id
  subnet_ids                = var.subnet_ids
  key_pair_name             = var.key_pair_name
  create_run_shell_document = var.create_run_shell_document

  additional_security_group_ids = var.additional_security_group_ids

  session_logging_kms_key_alias     = var.session_logging_kms_key_alias
  session_logging_enabled           = var.session_logging_enabled
  session_logging_ssm_document_name = var.session_logging_ssm_document_name

  ami           = var.ami
  instance_type = var.instance_type

  monitoring_enabled          = var.monitoring_enabled
  associate_public_ip_address = var.associate_public_ip_address

  user_data = base64encode(length(var.user_data) > 0 ? var.user_data : local.userdata)
}

resource "tailscale_tailnet_key" "default" {
  reusable      = var.reusable
  ephemeral     = var.ephemeral
  preauthorized = var.preauthorized
  expiry        = var.expiry

  # A device is automatically tagged when it is authenticated with this key.
  tags = local.tailscale_tags
}
