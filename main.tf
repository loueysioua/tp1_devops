# terraform/main.tf
# Provisionne un cluster Kubernetes local avec KinD (Kubernetes in Docker)

terraform {
  required_version = ">= 1.0"

  required_providers {
    kind = {
      source  = "tehcyx/kind"
      version = "~> 0.5.0"
    }
  }
}

provider "kind" {}

resource "kind_cluster" "default" {
  name           = var.project_name
  wait_for_ready = true

  kind_config {
    kind       = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    node {
      role = "control-plane"
      
      # Préparation pour un Ingress Controller local
      kubeadm_config_patches = [
        "kind: InitConfiguration\nnodeRegistration:\n  kubeletExtraArgs:\n    node-labels: \"ingress-ready=true\"\n"
      ]
      
      # Mappage des ports pour pouvoir accéder à l'application depuis localhost
      extra_port_mappings {
        container_port = 80
        host_port      = 8081
      }
    }
  }
}

# Crée un fichier kubeconfig local pour qu'Ansible puisse l'utiliser
resource "local_file" "kubeconfig" {
  content  = kind_cluster.default.kubeconfig
  filename = "${path.module}/kubeconfig"
}

output "cluster_name" {
  description = "Nom du cluster KinD"
  value       = kind_cluster.default.name
}

output "cluster_endpoint" {
  description = "Endpoint de l'API Kubernetes"
  value       = kind_cluster.default.endpoint
}
