output "boundary_vault_vsi_ip" {
  value = aws_instance.boundary_vault_vsi.public_ip
}

output "target_ip" {
  value = aws_instance.target_vsi.private_ip
}

output "boundary_init_instructions" {
  value       = <<EOT
# ----------------------
# Boundary Day 1 Instructions
# ----------------------

Boundary was just initialized. To get a usable session token for Terraform Day 2:

1. SSH to the Boundary host (from Day 1 outputs):
  export BOUNDARY_ADDR=http://${aws_instance.boundary_vault_vsi.public_ip}:9200
   ssh -i ../secrets/operator_key.pem ubuntu@${aws_instance.boundary_vault_vsi.public_ip}

2. Look at the initial login printed to ../secrets.boundary_init
   - Auth Method ID:     
   - Login Name:      
   - Password:  

3. Authenticate and save a session token locally:
   boundary authenticate password \
     -login-name admin \
     -auth-method-id ampw_p4TIl7y2s8 \
     -password <> \
     -format json > ../secrets/boundary_session_token.json

4. You can now reference this token in Day 2 Terraform:

   provider "boundary" {
     addr  = "http://${aws_instance.boundary_vault_vsi.public_ip}:9200"
     token = file("../secrets/boundary_session_token.json")
   }

EOT
  description = "Instructions for getting the initial Boundary token for Day 2 Terraform"
  sensitive   = false
}
