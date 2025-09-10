terraform {
  required_version = ">= 1.7"
  required_providers {
    minikube = {
      source  = "scott-the-programmer/minikube"
      version = "~> 0.5"
    }
    flux = {
      source  = "fluxcd/flux"
      version = "1.6.4"
    }
    github = {
      source  = "integrations/github"
      version = ">= 6.1"
    }
    kubectl = {
      # The official kubernetes provider requires the cluster to be up before planning,
      # so use the kubectl one (which can fail at applying).
      source  = "gavinbunney/kubectl"
      version = "1.19.0"
    }
    http = {
      source = "hashicorp/http"
    }

  }
}
provider "minikube" {
  kubernetes_version = "v1.33.0"
}
resource "minikube_cluster" "docker" {
  driver       = "docker"
  cluster_name = "minikube"
  nodes        = var.nodes
}

variable "nodes" {
  description = "The amount of nodes in the cluster"
  type        = number
  default     = 1
}

provider "flux" {
  kubernetes = {
    host                   = minikube_cluster.docker.host
    client_certificate     = minikube_cluster.docker.client_certificate
    client_key             = minikube_cluster.docker.client_key
    cluster_ca_certificate = minikube_cluster.docker.cluster_ca_certificate
  }
  git = {
    url    = "https://github.com/${var.github_org}/${var.github_repository}.git"
    branch = "main"

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


resource "flux_bootstrap_git" "this" {
  depends_on         = [minikube_cluster.docker, kubectl_manifest.gateway-crd]
  embedded_manifests = true
  path               = "cluster"
}

data "http" "gateway-crd" {
  url = "https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.3.0/standard-install.yaml "
  request_headers = {
    Accept = "text/plain"
  }
}

locals {
  gateway-crds-raw = [for d in split("---", data.http.gateway-crd.response_body) : d]
  # The remote file contains a information header before the first ---, which gets treated as an empty yaml object which kubectl_manifest can't handle
  gateway-crds     = slice(local.gateway-crds-raw, 1, length(local.gateway-crds-raw))
}
resource "kubectl_manifest" "gateway-crd" {
  depends_on = [minikube_cluster.docker]
  count      = length(local.gateway-crds)
  yaml_body  = local.gateway-crds[count.index]
}


provider "kubectl" {
  host = minikube_cluster.docker.host

  client_certificate     = minikube_cluster.docker.client_certificate
  client_key             = minikube_cluster.docker.client_key
  cluster_ca_certificate = minikube_cluster.docker.cluster_ca_certificate
  load_config_file       = false
}