output "instance_name" {
  value       = module.this.id
  description = "The name tag value of the Tailscale Subnet Router EC2 instance."
}

output "security_group_id" {
  value       = module.tailscale_subnet_router.security_group_id
  description = "The ID of the Tailscale Subnet Router EC2 instance Security Group."
}

output "launch_template_id" {
  value       = module.tailscale_subnet_router.launch_template_id
  description = "The ID of the Tailscale Subnet Router EC2 instance Launch Template."
}

output "autoscaling_group_id" {
  value       = module.tailscale_subnet_router.autoscaling_group_id
  description = "The ID of the Tailscale Subnet Router EC2 instance Autoscaling Group."
}
