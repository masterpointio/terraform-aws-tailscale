output "instance_name" {
  value       = module.this.id
  description = "The name tag value of the Bastion instance."
}

output "security_group_id" {
  value       = aws_security_group.default.id
  description = "The ID of the SSM Agent Security Group."
}

output "launch_template_id" {
  value       = aws_launch_template.default.id
  description = "The ID of the SSM Agent Launch Template."
}

output "autoscaling_group_id" {
  value       = aws_autoscaling_group.default.id
  description = "The ID of the SSM Agent Autoscaling Group."
}
