output "instance_name" {
  value       = module.tailscale.instance_name
  description = "The name tag value of the Bastion instance."
}

output "security_group_id" {
  value       = module.tailscale.security_group_id
  description = "The ID of the SSM Agent Security Group."
}

output "launch_template_id" {
  value       = module.tailscale.launch_template_id
  description = "The ID of the SSM Agent Launch Template."
}

output "autoscaling_group_id" {
  value       = module.tailscale.autoscaling_group_id
  description = "The ID of the SSM Agent Autoscaling Group."
}
