#!/bin/sh
set -e  # exit on any error

# Update packages
sudo apt-get update -y
sudo apt-get install -y wget gnupg lsb-release curl apt-transport-https ca-certificates software-properties-common

# Add HashiCorp repo GPG key
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
# Add HashiCorp repository
codename=$(grep '^UBUNTU_CODENAME=' /etc/os-release | cut -d= -f2 || lsb_release -cs)
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $codename main" | sudo tee /etc/apt/sources.list.d/hashicorp.list

# Install Boundary
sudo apt-get update -y
sudo apt-get install -y boundary

# Install Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable" -y
sudo apt-get update -y
sudo apt-get install -y docker-ce

# Install Vault
sudo apt-get install -y vault
# Start Boundary dev server in background
sudo sh -c "nohup sudo boundary dev \
  -login-name='dev-admin' \
  -password='${boundary_password}' \
  -api-listen-address=0.0.0.0:9200 \
  -cluster-listen-address=0.0.0.0:9201 \
  -proxy-listen-address=0.0.0.0:9202 \
  > ~/boundary.log 2>&1 </dev/null &"
# start vault dev server in background
sudo sh -c "nohup sudo vault server \
  -dev \
  -dev-root-token-id='${vault_root_token}' \
  -dev-listen-address=0.0.0.0:8200 \
  > ~/vault.log 2>&1 </dev/null &"
