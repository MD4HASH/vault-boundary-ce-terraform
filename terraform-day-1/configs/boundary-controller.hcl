# # Ref: https://developer.hashicorp.com/boundary/docs/configuration

disable_mlock = true
hcp_boundary_cluster_id = "poc"

controller {
  name = "controller-1"
  description = "Boundary Controller"
  database {
    url = "postgresql://boundary:boundarypassword@localhost:5432/boundary?sslmode=disable"
  }
  public_cluster_addr = "127.0.0.1"
}

listener "tcp" {
  purpose = "api"
  address = "0.0.0.0:9200"
}

listener "tcp" {
  purpose = "cluster"
  address = "0.0.0.0:9201"
}

# Ref for KMS config: https://developer.hashicorp.com/boundary/docs/configuration/kms
kms "aead" {
  purpose   = "root"
  aead_type = "aes-gcm"
  key       = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  key_id    = "global_root"
}

kms "aead" {
  purpose   = "worker-auth"
  aead_type = "aes-gcm"
  key       = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
  key_id    = "global_worker-auth"
}

kms "aead" {
  purpose   = "recovery"
  aead_type = "aes-gcm"
  key       = "cccccccccccccccccccccccccccccccc"
  key_id    = "global_recovery"
}