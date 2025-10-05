# vault-boundary-poc

This repository is a work in progress effort to automate the deploy and configuraiton of boundary and vault in terraform.  

It contains two projecss

## terraform-day-1

- deploys a VPC, two EC2 instances, and security groups
- Creates ssh keys for the VSIs and stores them in AWS, such that the servers can be accessed at
  - `ssh ../secrets/operator_key.pem ubuntu@<public ip>`
- Renders service files and configuration files to start the boundary services
- Exports information required for the configuration of vault and boundary to the /secrets directory (which is excluded from the git repository)

## terraform-day-1

- ingests information from the state of `terraform-day-1` in order to configure Boundary and vault.
- Creates a static key store to store the targets ssh key
- Creates a transit store to facilitate boundary controller/worker kms communication
- Creates a target in boundary and associates it to the ssh key configured in vault

# improvements

- Currenly this POC does not work due to the boundary -> transit kms integration
 ![transit error](images/Screenshot%202025-10-05%20at%2011.45.23 AM.png)
- Additionally, once this is configured, I suspect that the boundary/worker communication will not work until it is configured with certificates for TLS communication

- store secrets in base directory
- front boundary with an LB
