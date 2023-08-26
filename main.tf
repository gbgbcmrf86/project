provider "aws" {
  region = "us-east-1"
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    # This requires the awscli to be installed locally where Terraform is executed
    args = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
      command     = "aws"
    }
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
  source                  = "terraform-aws-modules/vpc/aws"
  name                    = "dimav-eks-vpc"
  cidr                    = "192.168.0.0/16"
  azs                     = ["us-east-1b", "us-east-1c"]
  private_subnets         = ["192.168.0.0/24", "192.168.1.0/24"]
  public_subnets          = ["192.168.129.0/24", "192.168.130.0/24"]
  private_subnet_tags     = var.private_subnet_tags
  public_subnet_tags      = var.public_subnet_tags
  enable_nat_gateway      = true
  single_nat_gateway      = true
  enable_vpn_gateway      = false
  map_public_ip_on_launch = true
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name    = var.eks_cluster_name
  cluster_version = "1.27"

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
    instance_types = ["t3.medium"]
  }

  eks_managed_node_groups = {
    dimav_tf_ng = {
      min_size     = 1
      max_size     = 3
      desired_size = 2

      instance_types = ["t3.medium"]
      #capacity_type  = "SPOT"
    }
  }

  create_kms_key = false

  # aws-auth configmap
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
}

resource "kubernetes_deployment" "dimav-php-web" {
  #depends_on = [resource.null_resource.kubectl]
  metadata {
    name = "dimav-php-web"
    labels = {
      App = "dimav-php-web"
    }
  }

  spec {
    replicas = 2
    selector {
      match_labels = {
        App = "dimav-php-web"
      }
    }
    template {
      metadata {
        labels = {
          App = "dimav-php-web"
        }
      }
      spec {
        container {
          image = "gbgbcmrf86/lesson20:v1"
          name  = "dimav-php-docker"

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

module "iam_iam-role-for-service-accounts-eks" {
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
    value = "us-east-1"
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
    value = "dimav-tf-eks"
  }
}

resource "kubernetes_service" "web-service" {
  metadata {
    name = "dimav-php-web-service"
  }
  spec {
    selector = {
      App = "dimav-php-web"
    }
    port {
      port        = 80
      name        = "http"
      target_port = 80
    }

    type = "NodePort"
  }
}

/* # Display load balancer hostname (typically present in AWS)
output "load_balancer_hostname" {
  value = kubernetes_ingress_v1.example.status.0.load_balancer.0.ingress.0.hostname
}

# Display load balancer IP (typically present in GCP, or using Nginx ingress controller)
output "load_balancer_ip" {
  value = kubernetes_ingress_v1.example.status.0.load_balancer.0.ingress.0.ip
}
 */
resource "kubernetes_ingress_v1" "dimav-ingress" {
  wait_for_load_balancer = true
  metadata {
    name      = "name-virtual-host-ingress"
    namespace = "default"
    annotations = {
      "alb.ingress.kubernetes.io/scheme"       = "internet-facing"
      "alb.ingress.kubernetes.io/listen-ports" = "[{\"HTTP\": 80}]"
    }
  }
  spec {
    #controller         = "aws-load-balancer-controller"
    ingress_class_name = "alb"
    rule {
      host = "dimav.ddns.net"
      http {
        path {
          path      = "/"
          path_type = "Exact"
          backend {
            service {
              name = "dimav-php-web-service"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }
}

resource "null_resource" "kubectl" {
  provisioner "local-exec" {
    command = "aws eks update-kubeconfig --region us-east-1 --name dimav-tf-eks"
  }
  depends_on = [module.eks]
}
