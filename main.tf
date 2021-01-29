module "instance_label" {
  source = "git::https://github.com/cloudposse/terraform-null-label.git?ref=tags/0.21.0"
  name   = "tailscale-relay"

  additional_tag_map = {
    propagate_at_launch = "true"
  }

  context = module.this.context
}

locals {
  tailscale_tags = join(",", [
    for t in values(module.this.tags) : replace("tag:${t}", "_", "-")
  ])
}

# Most recent Amazon Linux 2 AMI
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

data "template_file" "userdata" {
  template = file("${path.module}/userdata.sh.tpl")
  vars = {
    yum_repo = var.yum_repo
    routes   = join(",", var.advertise_routes)
    tags     = local.tailscale_tags
    authkey  = var.authkey
    hostname = module.this.id
  }
}

resource "aws_launch_template" "default" {
  name_prefix   = module.this.id
  image_id      = var.ami != "" ? var.ami : data.aws_ami.amazon_linux_2.id
  instance_type = var.instance_type
  key_name      = var.key_pair_name
  user_data     = base64encode(data.template_file.userdata.rendered)

  monitoring {
    enabled = true
  }

  network_interfaces {
    associate_public_ip_address = var.associate_public_ip_address
    delete_on_termination       = true
    security_groups             = [aws_security_group.default.id]
  }

  iam_instance_profile {
    name = var.iam_instance_profile
  }

  tag_specifications {
    resource_type = "instance"
    tags          = module.this.tags
  }

  tag_specifications {
    resource_type = "volume"
    tags          = module.this.tags
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "default" {
  name = module.instance_label.id
  tags = module.instance_label.tags_as_list_of_maps

  launch_template {
    id      = aws_launch_template.default.id
    version = "$Latest"
  }

  max_size         = var.instance_count
  min_size         = var.instance_count
  desired_capacity = var.instance_count

  vpc_zone_identifier = var.subnet_ids

  default_cooldown          = 180
  health_check_grace_period = 180
  health_check_type         = "EC2"

  termination_policies = [
    "OldestLaunchConfiguration",
  ]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "default" {
  vpc_id      = var.vpc_id
  name        = module.this.id
  description = "Allow ALL egress from Tailscale node."
  tags        = module.this.tags
}

resource "aws_security_group_rule" "allow_all_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.default.id
}
