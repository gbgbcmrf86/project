provider "aws" {
  region = var.region
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

terraform {
  backend "s3" {
    bucket         = "dimav-terraform"
    key            = "project/dev/dimav.tfstate"
    region         = "us-east-1"
    dynamodb_table = "dimav-lockstate"
  }
}

locals {
  vpc_id              = module.vpc.vpc_id
  vpc_cidr            = module.vpc.vpc_cidr_block
  public_subnets_ids  = module.vpc.public_subnets
  private_subnets_ids = module.vpc.private_subnets
  subnets_ids         = concat(local.public_subnets_ids, local.private_subnets_ids)
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name                    = var.VPC_name
  cidr                    = var.VPC_CIDR
  azs                     = var.azs
  private_subnets         = var.private_subnets
  public_subnets          = var.public_subnets
  private_subnet_tags     = var.private_subnet_tags
  public_subnet_tags      = var.public_subnet_tags
  enable_nat_gateway      = var.enable_nat_gateway
  single_nat_gateway      = var.single_nat_gateway
  enable_vpn_gateway      = var.enable_vpn_gateway
  map_public_ip_on_launch = var.map_public_ip_on_launch
  tags                    = var.tags
}

module "ecr" {
  source  = "terraform-aws-modules/ecr/aws"
  version = "1.6.0"

  repository_name               = var.repository_name
  repository_lifecycle_policy   = var.ecr_lifecycle_policy
  repository_image_scan_on_push = var.repository_image_scan_on_push
  tags                          = var.tags
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name                   = var.eks_cluster_name
  cluster_version                = var.eks_cluster_version
  cluster_endpoint_public_access = var.cluster_endpoint_public_access
  cluster_encryption_config      = var.cluster_encryption_config
  create_cloudwatch_log_group    = var.create_cloudwatch_log_group
  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
#fgfdgd
  }
  vpc_id                    = local.vpc_id
  subnet_ids                = concat(local.public_subnets_ids, local.private_subnets_ids)
  cluster_service_ipv4_cidr = var.cluster_service_ipv4_cidr

  # EKS Managed Node Group(s)
  eks_managed_node_group_defaults = {
    instance_types = var.instance_types
  }
  eks_managed_node_groups = {
    dimav_tf_ng = {
      min_size     = var.ng_min_size
      max_size     = var.ng_max_size
      desired_size = var.ng_desired_size

      instance_types = var.instance_types
    }
  }
  create_kms_key = var.create_kms_key

  tags = var.tags
}
