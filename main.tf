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

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
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

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name                   = var.eks_cluster_name
  cluster_version                = var.eks_cluster_version
  cluster_endpoint_public_access = true
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
  }
  vpc_id     = local.vpc_id
  subnet_ids = concat(local.public_subnets_ids, local.private_subnets_ids)

  # EKS Managed Node Group(s)
  eks_managed_node_group_defaults = {
    instance_types = var.instance_types
  }
  eks_managed_node_groups = {
    dimav_tf_ng = {
      min_size     = 1
      max_size     = 3
      desired_size = 2

      instance_types = var.instance_types
      #capacity_type  = "SPOT"
    }
  }
  create_kms_key = false
  # AWS-Auth configmap
  manage_aws_auth_configmap = true
  aws_auth_users = [
    {
      userarn  = "arn:aws:iam::097084951758:user/alex_b"
      username = "alex_b"
      groups   = ["system:masters"]
    },
    {
      userarn  = "arn:aws:iam::097084951758:user/varapai_d"
      username = "varapai_d"
      groups   = ["system:masters"]
    },
  ]
  tags = var.tags
}

resource "kubernetes_deployment" "dimav-php-web" {
  metadata {
    name = var.deployment_name
    labels = {
      App = var.deployment_name
    }
  }
  spec {
    replicas = 2
    selector {
      match_labels = {
        App = var.deployment_name
      }
    }
    template {
      metadata {
        labels = {
          App = var.deployment_name
        }
      }
      spec {
        container {
          image = var.deployment_image
          name  = var.deployment_container_name

          port {
            container_port = 80
          }
          resources {
            limits = {
              memory = "200Mi"
            }
            requests = {
              memory = "50Mi"
            }
          }
        }
      }
    }
  }
}

/* module "iam_iam-role-for-service-accounts-eks" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.29.0"

  role_name                              = "dimav_eks_lb"
  attach_load_balancer_controller_policy = true
  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
  tags = var.tags
}

resource "kubernetes_service_account" "service-account" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    labels = {
      "app.kubernetes.io/name"      = "aws-load-balancer-controller"
      "app.kubernetes.io/component" = "controller"
    }
    annotations = {
      "eks.amazonaws.com/role-arn"               = module.iam_iam-role-for-service-accounts-eks.iam_role_arn
      "eks.amazonaws.com/sts-regional-endpoints" = "true"
    }
  }
}

resource "helm_release" "lb" {
  name       = "dimav-aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  depends_on = [
    kubernetes_service_account.service-account
  ]
  set {
    name  = "region"
    value = var.region
  }
  set {
    name  = "vpcId"
    value = local.vpc_id
  }
  set {
    name  = "image.repository"
    value = "602401143452.dkr.ecr.us-east-1.amazonaws.com/amazon/aws-load-balancer-controller"
  }
  set {
    name  = "serviceAccount.create"
    value = "false"
  }
  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }
  set {
    name  = "clusterName"
    value = var.eks_cluster_name
  }
}

resource "kubernetes_service" "dimav-php-web-service" {
  metadata {
    name = var.eks_service_name
  }
  spec {
    selector = {
      App = var.deployment_name
    }
    port {
      port        = 80
      name        = "http"
      target_port = 80
    }
    type = "NodePort"
  }
}

resource "kubernetes_ingress_v1" "dimav-ingress" {
  metadata {
    name      = "dimav-deploy-ingress"
    namespace = "default"
    annotations = {
      "alb.ingress.kubernetes.io/scheme"       = "internet-facing"
      "alb.ingress.kubernetes.io/listen-ports" = "[{\"HTTP\": 80}]"
    }
  }
  spec {
    ingress_class_name = "alb"
    rule {
      host = "dimav.ddns.net"
      http {
        path {
          path      = "/"
          path_type = "Exact"
          backend {
            service {
              name = var.eks_service_name
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }
} */

# Update kubectl config file for Lens
resource "null_resource" "kubectl" {
  provisioner "local-exec" {
    command = "aws eks update-kubeconfig --region us-east-1 --name dimav-tf-eks"
  }
  depends_on = [module.eks]
}
