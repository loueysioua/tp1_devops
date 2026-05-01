terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "docker" {
  host = "unix:///var/run/docker.sock"
}

# Réseau applicatif
resource "docker_network" "app_network" {
  name = "terraform-app-network"
}

# Conteneur Redis
resource "docker_container" "redis" {
  name  = "tf-db-service"
  image = "redis:alpine"

  command = ["redis-server", "--appendonly", "yes"]

  networks_advanced {
    name = docker_network.app_network.name
  }
}

# Conteneur Flask
resource "docker_container" "web" {
  name  = "tf-web"
  image = var.image_name

  ports {
    internal = 5000
    external = var.host_port
  }

  env = [
    "REDIS_HOST=tf-db-service"
  ]

  networks_advanced {
    name = docker_network.app_network.name
  }

  depends_on = [docker_container.redis]
}
