variable "region" {
  description = "AWS Region"
  type        = string
  default     = "us-east-1"
}

variable "instance_types" {
  description = "Instance Type"
  type        = list(string)
  default     = ["t3.medium"]

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
