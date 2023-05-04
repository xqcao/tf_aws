variable "aws_access_key" {
  type        = string
  description = "AWS access key"
}
variable "aws_secret_key" {
  type        = string
  description = "AWS secret key"
}
variable "aws_region" {
  type        = string
  description = "AWS region"
}

variable "eks_user" {
  type        = string
  description = "create user for this eks"
  default     = "eks_user"
}

variable "ec2_user" {
  type        = string
  description = "create user for this eks"
  default     = "ec2_user"
}
