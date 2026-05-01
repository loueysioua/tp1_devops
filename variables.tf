variable "image_name" {
  description = "Image Docker à déployer"
  type        = string
  default     = "loueysioua/mon-app-devops:latest"
}

variable "host_port" {
  description = "Port exposé sur la machine hôte"
  type        = number
  default     = 8081
}
