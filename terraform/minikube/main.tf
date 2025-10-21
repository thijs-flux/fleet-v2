terraform {
  required_version = ">= 1.7"
  required_providers {
    minikube = {
      source  = "scott-the-programmer/minikube"
      version = "~> 0.5"
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
  apiserver_port = 6443
}
module "cluster"{
    source = "../cluster"
  client_certificate =  minikube_cluster.docker.client_certificate
  client_key = minikube_cluster.docker.client_key
  cluster_ca_certificate = minikube_cluster.docker.cluster_ca_certificate
  host = minikube_cluster.docker.host
  cluster = minikube_cluster.docker
  sops_secret = var.sops_secret
  config_path = null
}