variable "repository_name" {
  description = "ECR repository name"
  type        = string
}

variable "image_count" {
  description = "Number of images to keep"
  type        = number
  default     = 10
}

variable "tags" {
  description = "Tags for ECR repository"
  type        = map(string)
  default     = {}
}
