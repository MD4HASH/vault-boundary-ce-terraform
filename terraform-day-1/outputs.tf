output "boundary_vault_vsi_ip" {
  value = aws_instance.boundary_vault_vsi.public_ip
}

output "target_ip" {
  value = aws_instance.target_vsi.private_ip
}

output "boundary_username" {
  value = var.boundary_username
}

output "boundary_password" {
  value     = random_password.boundary_password.result
  sensitive = true
}

output "vault_token" {
  value     = random_uuid.vault_root_token.result
  sensitive = true
}
