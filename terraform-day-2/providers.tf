# terraform {
#   required_providers {
#     vault = {
#       source = "hashicorp/vault"
#     }
#   }
# }

# provider "vault" {
#   address = "http://${data.terraform_remote_state.day1.outputs.vault_address}"
#   token   = data.terraform_remote_state.day1.outputs.vault_root_token
# }


# provider "boundary" {
#   addr  = "http://${data.terraform_remote_state.day1.outputs.boundary_vault_vsi_ip}:9200"
#   token = file(".boundary_token") # if you wrote it via null_resource
# }
