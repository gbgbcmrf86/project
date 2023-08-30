variable "region" {
  description = "AWS Region"
  type        = string
  default     = "us-east-1"
}

variable "instance_types" {
  description = "Instance Type"
  type        = list(string)
  default     = ["t2.micro"]

}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default = {
    Owner       = "dimav"
    Environment = "dev"
  }
}

# ------------- VPC -------------
variable "azs" {
  description = "A list of availability zones names or ids in the region"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "VPC_name" {
  description = "VPC name"
  type        = string
  default     = "dimav-eks-vpc"
}

variable "private_subnet_tags" {
  description = "Additional tags for the private subnets"
  type        = map(string)
  default = {
    "kubernetes.io/role/internal-elb"    = 1
    "kubernetes.io/cluster/dimav-tf-eks" = "shared"
  }
}

variable "public_subnet_tags" {
  description = "Additional tags for the private subnets"
  type        = map(string)
  default = {
    "kubernetes.io/role/elb"             = 1
    "kubernetes.io/cluster/dimav-tf-eks" = "shared"
  }
}

variable "VPC_CIDR" {
  description = "VPC CIDR"
  type        = string
  default     = "192.168.0.0/16"
}

variable "public_subnets" {
  description = "A list of public subnets inside the VPC"
  type        = list(string)
  default     = ["192.168.129.0/24", "192.168.130.0/24"]
}

variable "private_subnets" {
  description = "A list of private subnets inside the VPC"
  type        = list(string)
  default     = ["192.168.0.0/24", "192.168.1.0/24"]
}

variable "enable_nat_gateway" {
  description = "Should be true if you want to provision NAT Gateways for each of your private networks"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Should be true if you want to provision a single shared NAT Gateway across all of your private networks"
  type        = bool
  default     = true
}

variable "enable_vpn_gateway" {
  description = "Should be true if you want to create a new VPN Gateway resource and attach it to the VPC"
  type        = bool
  default     = false
}

variable "map_public_ip_on_launch" {
  description = "Specify true to indicate that instances launched into the subnet should be assigned a public IP address. Default is `false`"
  type        = bool
  default     = true
}


#-------- EKS ----------
variable "eks_cluster_name" {
  description = "AWS Kubernetes cluster name"
  type        = string
  default     = "dimav-tf-eks"
}

variable "eks_cluster_version" {
  description = "AWS Kubernetes cluster version"
  type        = string
  default     = "1.27"
}

variable "cluster_encryption_config" {
  description = "AWS Kubernetes cluster encryprtion"
  default     = {}
}

variable "create_kms_key" {
  description = "AWS Kubernetes cluster create kms key"
  type        = bool
  default     = false
}

variable "cluster_endpoint_public_access" {
  description = "AWS Kubernetes cluster endpoint public access"
  type        = bool
  default     = true
}

variable "cluster_service_ipv4_cidr" {
  description = "AWS Kubernetes cluster service ipv4cidr"
  type        = string
  default     = "10.200.0.0/16"
}

variable "create_cloudwatch_log_group" {
  description = "AWS Kubernetes cluster create cloudwatch log group"
  type        = bool
  default     = false
}

variable "ng_min_size" {
  description = "AWS Kubernetes cluster ng min size"
  type        = number
  default     = 1
}

variable "ng_max_size" {
  description = "AWS Kubernetes cluster ng max size"
  type        = number
  default     = 3
}

variable "ng_desired_size" {
  description = "AWS Kubernetes cluster ng desired size"
  type        = number
  default     = 2
}

#-------- Deployment -----------
variable "deployment_name" {
  description = "EKS Deployment name"
  type        = string
  default     = "dimav-php-web"
}

variable "deployment_image" {
  description = "EKS Deployment image"
  type        = string
  default     = "gbgbcmrf86/lesson20:v1"
}

variable "deployment_container_name" {
  description = "EKS Deployment container name"
  type        = string
  default     = "dimav-php-container"
}

#-------- Service -----------
variable "eks_service_name" {
  description = "EKS service name"
  type        = string
  default     = "dimav-php-web-service"
}


# --------ECR Repostory---------
variable "repository_name" {
  description = "ECR Lifecycle name"
  type        = string
  default     = "dimav-ecr"
}

variable "ecr_lifecycle_policy" {
  description = "ECR Lifecycle policy"
  type        = string
  default     = "{\r\n    \"rules\": [\r\n        {\r\n            \"rulePriority\": 1,\r\n            \"description\": \"Keep only one image, expire all others\",\r\n            \"selection\": {\r\n                \"tagStatus\": \"any\",\r\n                \"countType\": \"imageCountMoreThan\",\r\n                \"countNumber\": 1\r\n            },\r\n            \"action\": {\r\n                \"type\": \"expire\"\r\n            }\r\n        }\r\n    ]\r\n}"
}

variable "repository_image_scan_on_push" {
  description = "ECR repository image scan on push"
  type        = bool
  default     = false
}
