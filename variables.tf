# terraform/variables.tf

variable "aws_region" {
  description = "Région AWS cible"
  type        = string
  default     = "eu-west-1"
}

variable "project_name" {
  description = "Nom du projet (utilisé pour tagger les ressources)"
  type        = string
  default     = "devops-tp"
}

variable "environment" {
  description = "Environnement (dev, staging, production)"
  type        = string
  default     = "production"
}

variable "node_instance_type" {
  description = "Type d'instance EC2 pour les nœuds EKS"
  type        = string
  default     = "t3.medium"
}
