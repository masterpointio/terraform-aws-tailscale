# trunk-ignore-all(trivy/AVD-AWS-0178): We don't need have VPC Flow logs.
provider "aws" {
  region = var.region
}

provider "tailscale" {
  tailnet             = var.tailnet
  oauth_client_id     = var.oauth_client_id
  oauth_client_secret = var.oauth_client_secret
}

module "vpc" {
  source  = "cloudposse/vpc/aws"
  version = "2.1.1"

  ipv4_primary_cidr_block = "172.16.0.0/16"

  context = module.this.context
}

module "subnets" {
  source  = "cloudposse/dynamic-subnets/aws"
  version = "2.4.1"

  availability_zones = var.availability_zones

  vpc_id          = module.vpc.vpc_id
  igw_id          = [module.vpc.igw_id]
  ipv4_cidr_block = [module.vpc.vpc_cidr_block]

  context = module.this.context
}

module "tailscale" {
  source = "../.."

  vpc_id           = module.vpc.vpc_id
  subnet_ids       = module.subnets.private_subnet_ids
  advertise_routes = [module.vpc.vpc_cidr_block]

  context = module.this.context
}
