terraform{
    required_version = ">= 1.7"
    required_providers {
        minikube = {
            source = "scott-the-programmer/minikube"
            version = "~> 0.5"
        }
        flux = {
            source = "fluxcd/flux"
            version = "1.6.4"
        }
        github = {
            source  = "integrations/github"
            version = ">= 6.1"
        }
    }
}
provider "minikube" {
    kubernetes_version = "v1.30.0"
}
resource "minikube_cluster" "docker" {
    driver       = "docker"
    cluster_name = "tcluster"
    nodes = var.nodes
}

variable "nodes" {
    description = "The amount of nodes in the cluster"
    type = number
    default = 1
}

provider "flux" {
    kubernetes = {
        host                   = minikube_cluster.docker.host
        client_certificate     = minikube_cluster.docker.client_certificate
        client_key             = minikube_cluster.docker.client_key
        cluster_ca_certificate = minikube_cluster.docker.cluster_ca_certificate
    }
    git = {
        url = "https://github.com/${var.github_org}/${var.github_repository}.git"
        http = {
        username = "git" # This can be any string when using a personal access token
        password = var.github_token
        }
    }
}
variable "github_token" {
  description = "GitHub token"
  sensitive   = true
  type        = string
  default     = ""
}

variable "github_org" {
  description = "GitHub organization"
  type        = string
  default     = "thijs-flux"
}

variable "github_repository" {
  description = "GitHub repository"
  type        = string
  default     = "fleet-v2"
}

resource "github_repository" "this" {
  name        = var.github_repository
  description = var.github_repository
  visibility  = "private"
  auto_init   = true # This is extremely important as flux_bootstrap_git will not work without a repository that has been initialised
}

resource "flux_bootstrap_git" "this" {
  depends_on = [github_repository.this,minikube_cluster.docker]
  embedded_manifests = true
  path               = "cluster"
}