

# Create a private key to access the management server

resource "tls_private_key" "operator_key" {
  algorithm = "RSA"
}

# Save private file in secrets directory (ensure "secrets/*" is included in .gitignore)
resource "local_file" "operator_private_key_pem" {
  content  = tls_private_key.operator_key.private_key_pem
  filename = "../secrets/operator_key.pem"
}

# Create keypair in aws
resource "aws_key_pair" "operator_key" {
  key_name   = "operator_key"
  public_key = tls_private_key.operator_key.public_key_openssh
}


resource "tls_private_key" "target_key" {
  algorithm = "RSA"
}

# Save private file in secrets directory (ensure "secrets/*" is included in .gitignore)
resource "local_file" "target_private_key_pem" {
  content  = tls_private_key.target_key.private_key_pem
  filename = "../secrets/target_key.pem"
}

# Create keypair in aws
resource "aws_key_pair" "target_key" {
  key_name   = "target_key"
  public_key = tls_private_key.target_key.public_key_openssh
}

# Look up current avaialbility zones

data "aws_availability_zones" "available" {}
data "aws_region" "current" {}

# look up latest ubuntu version for EC2 instances
# Took this from, https://github.com/btkrausen/hashicorp/blob/master/terraform/Hands-On%20Labs/Section%2004%20-%20Understand%20Terraform%20Basics/08%20-%20Intro_to_the_Terraform_Data_Block.md#step-511

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical’s official AWS account ID
}


# Security Groups

resource "aws_security_group" "ingress-ssh" {
  name   = "allow-all-ssh"
  vpc_id = module.main.vpc_id
  ingress {
    cidr_blocks = [
      "0.0.0.0/0"
    ]
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "boundary" {
  name   = "boundary"
  vpc_id = module.main.vpc_id
  ingress {
    cidr_blocks = [
      "0.0.0.0/0"
    ]
    from_port = 9200
    to_port   = 9203
    protocol  = "tcp"
  }
}


resource "aws_security_group" "vault" {
  name   = "allow 8200"
  vpc_id = module.main.vpc_id
  ingress {
    cidr_blocks = [
      "0.0.0.0/0"
    ]
    from_port = 8200
    to_port   = 8200
    protocol  = "tcp"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


module "main" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.3.0"

  name = "main-vpc"
  cidr = var.vpc_cidr
  azs  = [data.aws_availability_zones.available.names[0]]


  public_subnets  = [var.public_subnet_1]
  private_subnets = [var.private_subnet_1]

  enable_nat_gateway = true

  enable_flow_log                                 = true
  flow_log_destination_type                       = "cloud-watch-logs"
  create_flow_log_cloudwatch_iam_role             = true
  create_flow_log_cloudwatch_log_group            = true
  flow_log_cloudwatch_log_group_name_prefix       = "/aws/vpc/flowlogs/"
  flow_log_cloudwatch_log_group_retention_in_days = 30
  flow_log_max_aggregation_interval               = 60

}


resource "aws_instance" "target_vsi" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_size
  subnet_id                   = module.main.public_subnets[0]
  vpc_security_group_ids      = [aws_security_group.ingress-ssh.id, aws_security_group.boundary.id]
  associate_public_ip_address = false
  key_name                    = aws_key_pair.target_key.key_name
}

resource "aws_instance" "boundary_vault_vsi" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_size
  subnet_id                   = module.main.public_subnets[0]
  vpc_security_group_ids      = [aws_security_group.ingress-ssh.id, aws_security_group.boundary.id, aws_security_group.vault.id]
  associate_public_ip_address = true
  key_name                    = aws_key_pair.operator_key.key_name
  connection {
    user        = "ubuntu"
    private_key = tls_private_key.operator_key.private_key_pem
    host        = self.public_ip
  }

  provisioner "local-exec" {
    command = "chmod 600 ${local_file.operator_private_key_pem.filename}"
  }


  # Render configuration and service files from templates

  provisioner "file" {
    source      = "configs/boundary-controller.hcl"
    destination = "/tmp/boundary-controller.hcl"
  }

  provisioner "file" {
    source      = "configs/boundary-worker.hcl"
    destination = "/tmp/boundary-worker.hcl"
  }

  provisioner "file" {
    source      = "configs/vault.hcl"
    destination = "/tmp/vault.hcl"
  }

  provisioner "file" {
    source      = "configs/vault.service"
    destination = "/tmp/vault.service"
  }

  provisioner "file" {
    source      = "configs/boundary-controller.service"
    destination = "/tmp/boundary-controller.service"
  }

  provisioner "file" {
    source      = "configs/boundary-worker.service"
    destination = "/tmp/boundary-worker.service"
  }

  # Install and initialize boundary and vault

  provisioner "remote-exec" {
    inline = [
      templatefile("${path.module}/init.sh.tpl", {
      })
    ]
  }
  # Copy init outputs to secrets directory to reference in day 2
  provisioner "local-exec" {
    command = "scp -o StrictHostKeyChecking=no -i ../secrets/operator_key.pem ubuntu@${self.public_ip}:~/vault_init.json ../secrets/vault_init.json"
  }
  provisioner "local-exec" {
    command = "scp -o StrictHostKeyChecking=no -i ../secrets/operator_key.pem ubuntu@${self.public_ip}:~/boundary_init ../secrets/boundary_init"
  }
}
