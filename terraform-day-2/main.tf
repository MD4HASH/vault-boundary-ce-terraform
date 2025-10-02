terraform {
  required_providers {
    vault = {
      source = "hashicorp/vault"
    }
    boundary = {
      source = "hashicorp/boundary"
    }
  }
}

# ----------------------
# Remote state from day1
# ----------------------
data "terraform_remote_state" "day1" {
  backend = "local"
  config = {
    path = "../terraform-day-1/terraform.tfstate"
  }
}

resource "null_resource" "boundary_auth" {
  provisioner "local-exec" {
    command = <<EOT
export BOUNDARY_ADDR=http://${data.terraform_remote_state.day1.outputs.boundary_vault_vsi_ip}:9200

# write password to a temp file
echo '${data.terraform_remote_state.day1.outputs.boundary_password}' > /tmp/boundary_pw.txt

# get auth-method ID
AMPW_ID=$(boundary auth-methods list -format=json -scope-id=global | jq -r '.items[] | select(.type=="password") | .id')

# authenticate using file://
BOUNDARY_AUTH_TOKEN=$(boundary authenticate password \
  -login-name dev-admin \
  -auth-method-id "$AMPW_ID" \
  -password file:///tmp/boundary_pw.txt \
  -format=json | jq -r '.item.attributes.token')

# write token without newline
printf '%s' "$BOUNDARY_AUTH_TOKEN" > ./boundary_token

EOT
  }
  depends_on = [data.terraform_remote_state.day1]
}




# ----------------------
# Boundary provider setup
# ----------------------
provider "boundary" {
  addr  = "http://${data.terraform_remote_state.day1.outputs.boundary_vault_vsi_ip}:9200"
  token = file("./boundary_token")
}

# ----------------------
# Vault provider setup
# ----------------------
provider "vault" {
  address = "http://${data.terraform_remote_state.day1.outputs.boundary_vault_vsi_ip}:8200"
  token   = data.terraform_remote_state.day1.outputs.vault_token
}

# ----------------------
# Vault KV mount
# ----------------------
resource "vault_mount" "boundary" {
  path = "secrets"
  type = "kv"
  options = {
    version = "2" # KV v2
  }
}

# ----------------------
# Store SSH key in Vault
# ----------------------
resource "vault_kv_secret_v2" "target_key" {
  mount = vault_mount.boundary.path
  name  = "target_key"

  data_json = jsonencode({
    private_key = file("../secrets/target_key.pem")
    user        = "ubuntu"
  })
}

resource "vault_policy" "boundary" {
  name   = "boundary"
  policy = <<EOT
path "sys/leases/*" {
  capabilities = ["create", "update", "delete", "list", "read"]
}
path "secrets/data/*" {
  capabilities = ["read"]
}
path "secrets/metadata/*" {
  capabilities = ["list"]
}
EOT
}



resource "boundary_scope" "dev-org" {
  name                     = "dev-scope"
  scope_id                 = "global"
  auto_create_admin_role   = true
  auto_create_default_role = true

  depends_on = [null_resource.boundary_auth]
}

resource "boundary_scope" "dev-project" {
  name                   = "dev-project"
  scope_id               = boundary_scope.dev-org.id
  auto_create_admin_role = true
}


resource "vault_token" "boundary" {
  policies  = [vault_policy.boundary.name]
  no_parent = true
  renewable = true
  period    = "24h"
}

output "boundary_vault_token" {
  value     = vault_token.boundary.client_token
  sensitive = true
}



# ----------------------
# Vault credential store in Boundary
# ----------------------
resource "boundary_credential_store_vault" "vault" {
  name     = "vault-store"
  scope_id = boundary_scope.dev-project.id
  address  = "http://${data.terraform_remote_state.day1.outputs.boundary_vault_vsi_ip}:8200"
  token    = vault_token.boundary.client_token
}


# ----------------------
# Target host in Boundary
# ----------------------
resource "boundary_target" "target_host" {
  name         = "target-host"
  scope_id     = boundary_scope.dev-project.id
  type         = "tcp"
  address      = data.terraform_remote_state.day1.outputs.target_ip
  default_port = 22

  brokered_credential_source_ids = [
    boundary_credential_library_vault.ssh_key.id
  ]
}


resource "boundary_credential_library_vault" "ssh_key" {
  name                = "ssh-key-library"
  description         = "Library to fetch SSH key for target host"
  credential_store_id = boundary_credential_store_vault.vault.id

  path = "secrets/data/target_key" # full Vault path
}



output "boundary_ssh_instructions" {
  value       = <<EOT
# ----------------------
# Boundary SSH Instructions
# ----------------------

# Set Boundary address
export BOUNDARY_ADDR=http://${data.terraform_remote_state.day1.outputs.boundary_vault_vsi_ip}:9200

# Set your dev-admin password for authentication
export BOUNDARY_AUTHENTICATE_PASSWORD_PASSWORD='${data.terraform_remote_state.day1.outputs.boundary_password}'

# Authenticate with Boundary
AMPW_ID=$(boundary auth-methods list -format=json -scope-id=global | jq -r '.items[] | select(.type=="password") | .id')
boundary authenticate password \
  -login-name dev-admin \
  -auth-method-id "$AMPW_ID" \
  -password env://BOUNDARY_AUTHENTICATE_PASSWORD_PASSWORD

# Connect to target host via Boundary
boundary connect ssh --target-id ${boundary_target.target_host.id}

EOT
  description = "Copy/paste these commands to authenticate and connect via Boundary SSH"
  sensitive   = false
}


# resource "boundary_credential_ssh_private_key" "example" {
#   name                = "ssh_account"
#   description         = "private key for target host"
#   credential_store_id = boundary_credential_store_vault.vault.id
#   username            = "ubuntu"
#   private_key         = "vault_mount.boundary.path/private_key"
# }


# # # Export boundary access token

# # resource "null_resource" "boundary_auth" {
# #   provisioner "local-exec" {
# #     command = <<EOT
# #       export BOUNDARY_ADDR=http://${data.terraform_remote_state.day1.outputs.boundary_vault_vsi_ip}:9200
# #       export BOUNDARY_PASSWORD=${data.terraform_remote_state.day1.outputs.boundary_password}
# #       BOUNDARY_AUTH_TOKEN=$(boundary authenticate password \
# #         -login-name dev-admin \
# #         -password "${BOUNDARY_PASSWORD}" \
# #         -auth-method-id ampw_1234... \
# #         -format=json | jq -r '.token.value')
# #       echo $BOUNDARY_AUTH_TOKEN > .boundary_token
# #     EOT
# #   }
# # }



# # data "terraform_remote_state" "day1" {
# #   backend = "local"
# #   config = {
# #     path = "../day1/terraform.tfstate"
# #   }
# # }

# # resource "vault_mount" "boundary" {
# #   path = "secrets"
# #   type = "kv"
# #   options = {
# #     version = "1"
# #   }
# # }

# # resource "vault_kv_secret" "target_key" {
# #   path = "${vault_mount.boundary.path}/target_key"
# #   data_json = jsonencode(
# #     {
# #       private_key = file("${path.module}/../day1/target_key.pem")
# #       user        = "ubuntu"
# #     }
# #   )
# # }

# # resource "boundary_scope" "dev" {
# #   name = "dev-scope"
# # }

# # # Vault credential store in Boundary
# # resource "boundary_credential_store" "vault" {
# #   name     = "vault-store"
# #   type     = "vault"
# #   scope_id = boundary_scope.dev.id

# #   vault {
# #     address = data.terraform_remote_state.day1.outputs.vault_address
# #     token   = data.terraform_remote_state.day1.outputs.vault_root_token
# #     path    = "boundary"
# #   }
# # }

# # # Target host in Boundary
# # resource "boundary_target" "target_host" {
# #   name                 = "target-host"
# #   scope_id             = boundary_scope.dev.id
# #   type                 = "ssh"
# #   address              = data.terraform_remote_state.day1.outputs.target_ip
# #   port                 = 22
# #   credential_store_ids = [boundary_credential_store.vault.id]
# # }

# # resource "boundary_account" "ssh_account" {
# #   name                 = "ssh-account"
# #   type                 = "ssh"
# #   credential_store_id  = boundary_credential_store.vault.id
# #   scope_id             = boundary_scope.dev.id
# #   ssh_user             = "ubuntu"
# #   ssh_private_key_path = "target_ssh_key/private_key" # path in Vault KV
# # }
