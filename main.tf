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

# ── Réseau ────────────────────────────────────────────────────────────────────
resource "docker_network" "app_network" {
  name = "terraform-app-network"
}

# ── Image (pull depuis Docker Hub) ────────────────────────────────────────────
resource "docker_image" "app" {
  name         = "${var.image_name}:${var.image_tag}"
  keep_locally = true   # ne pas supprimer l'image lors d'un destroy
}

# ── Redis ─────────────────────────────────────────────────────────────────────
resource "docker_image" "redis" {
  name         = "redis:alpine"
  keep_locally = true
}

resource "docker_container" "redis" {
  name    = "tf-db-service"
  image   = docker_image.redis.image_id
  restart = "unless-stopped"

  command = ["redis-server", "--appendonly", "yes"]

  networks_advanced {
    name = docker_network.app_network.name
  }
}

# ── Flask App ─────────────────────────────────────────────────────────────────
resource "docker_container" "web" {
  name    = "tf-web"
  image   = docker_image.app.image_id
  restart = "unless-stopped"

  ports {
    internal = 5000
    external = var.host_port
  }

  # Le nom du conteneur Redis est utilisé comme hostname dans app.py
  env = ["REDIS_HOST=tf-db-service"]

  networks_advanced {
    name = docker_network.app_network.name
  }

  depends_on = [docker_container.redis]
}
