#!/bin/sh
set -e  # exit on any error

# Update packages
sudo apt-get update -y
sudo apt-get install -y wget gnupg lsb-release curl apt-transport-https ca-certificates software-properties-common


# Add HashiCorp repo GPG key
# https://developer.hashicorp.com/boundary/tutorials/enterprise/ent-deployment-guide
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
# Add HashiCorp repository
codename=$(grep '^UBUNTU_CODENAME=' /etc/os-release | cut -d= -f2 || lsb_release -cs)
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $codename main" | sudo tee /etc/apt/sources.list.d/hashicorp.list

# Install Boundary
sudo apt-get update -y
sudo apt-get install -y boundary

# Install Vault
# https://developer.hashicorp.com/vault/downloads#linux
sudo apt-get install -y vault

# Install Postgress
# https://www.postgresql.org/download/linux/ubuntu/
sudo apt-get install -y postgresql postgresql-contrib
