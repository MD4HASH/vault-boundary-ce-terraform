output "boundary_vault_vsi_ip" {
  value = aws_instance.boundary_vault_vsi.public_ip
}

output "target_ip" {
  value = aws_instance.target_vsi.private_ip
}

output "boundary_init_instructions" {
  value       = <<EOT
# Boundary day 1 instructions
use the boundar-init file in /secrets to populate the auth-id and password variables for day 2

EOT
  description = "Instructions for getting the initial Boundary token for Day 2 Terraform"
  sensitive   = false
}
