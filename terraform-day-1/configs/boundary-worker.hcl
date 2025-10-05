worker {
  auth_storage_path = "/tmp/"
  initial_upstreams = ["127.0.0.1:9201"]
  controller_generated_activation_token = "3M2qF8vT5bXzRkYp"
}

listener "tcp" {
  purpose = "proxy"
  address = "0.0.0.0:9202"
}