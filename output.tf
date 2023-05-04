output "access_key" {
  value = var.aws_access_key
}


output "aws_region" {
  value = var.aws_region
}

output "secret_key" {
  value = var.aws_secret_key
}


output "aws_vpc" {
  value = aws_vpc.eks_vpc.id
}
