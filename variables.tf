variable "private_subnet_tags" {
  description = "Additional tags for the private subnets"
  type        = map(string)
  default = {
    tag1                                 = "kubernetes.io/role/internal-elb"
    tag2                                 = "kubernetes.io/cluster/dimav-tf-eks"
    "kubernetes.io/role/internal-elb"    = 1
    "kubernetes.io/cluster/dimav-tf-eks" = "shared"
  }
}

variable "public_subnet_tags" {
  description = "Additional tags for the private subnets"
  type        = map(string)
  default = {
    tag1                                 = "kubernetes.io/role/elb",
    tag2                                 = "kubernetes.io/cluster/dimav-tf-eks"
    "kubernetes.io/role/elb"             = 1
    "kubernetes.io/cluster/dimav-tf-eks" = "shared"
  }
}

variable "eks_cluster_name" {
  description = "eks_cluster_name"
  type        = string
  default     = "dimav-tf-eks"
}
