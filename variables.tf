variable "image_name" {
  description = "Nom de l'image Docker à déployer"
  type        = string
  default     = "loueysioua/mon-app-devops"
}

variable "image_tag" {
  description = "Tag de l'image Docker"
  type        = string
  default     = "latest"
}

variable "host_port" {
  description = "Port exposé sur la machine hôte"
  type        = number
  default     = 8081
}
