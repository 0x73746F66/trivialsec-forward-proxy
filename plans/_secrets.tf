variable "linode_token" {
  description = "The linode api token"
  type        = string
  sensitive   = true
}
variable "public_key" {
  description = "The linode authorized_key"
  type        = string
  default     = ""
}
variable "aws_secret_access_key" {
  description = "AWS_SECRET_ACCESS_KEY"
  type        = string
  sensitive   = true
}
variable "aws_access_key_id" {
  description = "AWS_ACCESS_KEY_ID"
  type        = string
}
