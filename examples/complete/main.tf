provider "aws" {
  region = var.region
}

module "vpc" {
  source = "git::https://github.com/cloudposse/terraform-aws-vpc.git?ref=tags/0.17.0"

  cidr_block = "172.16.0.0/16"
  attributes = var.attributes

  context = module.this.context
}

module "subnets" {
  source = "git::https://github.com/cloudposse/terraform-aws-dynamic-subnets.git?ref=tags/0.32.0"

  attributes           = var.attributes
  availability_zones   = var.availability_zones
  vpc_id               = module.vpc.vpc_id
  igw_id               = module.vpc.igw_id
  cidr_block           = module.vpc.vpc_cidr_block
  nat_gateway_enabled  = false
  nat_instance_enabled = true

  context = module.this.context
}

module "tailscale" {
  source = "../.."

  attributes       = var.attributes
  vpc_id           = module.vpc.vpc_id
  subnet_ids       = module.subnets.public_subnet_ids
  advertise_routes = var.advertise_routes
  authkey          = var.authkey

  context = module.this.context
}
