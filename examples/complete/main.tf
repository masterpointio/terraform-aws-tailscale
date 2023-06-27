provider "aws" {
  region = var.region
}

module "vpc" {
  source  = "cloudposse/vpc/aws"
  version = "2.1.0"

  namespace = var.namespace
  stage     = var.stage
  name      = var.name

  ipv4_primary_cidr_block = "172.16.0.0/16"

  context = module.this.context
}

module "subnets" {
  source  = "cloudposse/dynamic-subnets/aws"
  version = "2.3.0"

  namespace = var.namespace
  stage     = var.stage

  availability_zones = var.availability_zones
  vpc_id             = module.vpc.vpc_id
  igw_id             = [module.vpc.igw_id]
  ipv4_cidr_block    = [module.vpc.vpc_cidr_block]
  ipv6_enabled       = var.ipv6_enabled

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
