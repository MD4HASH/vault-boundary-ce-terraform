disable_mlock = true
hcp_boundary_cluster_id = "poc"

worker {
  name        = "worker-1"
  description = "Boundary Worker"
  controller_generated_activation_token = ""
}

listener "tcp" {
  purpose = "proxy"
  address = "0.0.0.0:9202"
}