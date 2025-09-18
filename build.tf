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
      # so for manifests use the kubectl one (which can fail at applying).
      source  = "gavinbunney/kubectl"
      version = "1.19.0"
    }
    http = {
      source = "hashicorp/http"
    }
    helm = {
      source = "hashicorp/helm"
      version = "3.0.2"
    }    
    kubernetes = {
      # For kubernetes secrets, namespaces, etc. Use the kubectl provider for manifests.
      source = "hashicorp/kubernetes"
      version = "2.38.0"
    }

  }
}

##########################################
### Provider settings                  ### 
##########################################
provider "minikube" {
  kubernetes_version = "v1.33.0"
}
provider "kubernetes" {
  host = minikube_cluster.docker.host
  client_certificate =  minikube_cluster.docker.client_certificate
  client_key = minikube_cluster.docker.client_key
  cluster_ca_certificate = minikube_cluster.docker.cluster_ca_certificate
}
provider "helm" {
  kubernetes = {
    host = minikube_cluster.docker.host
    client_certificate =  minikube_cluster.docker.client_certificate
    client_key = minikube_cluster.docker.client_key
    cluster_ca_certificate = minikube_cluster.docker.cluster_ca_certificate
  }
  
}
provider "kubectl" {
  host = minikube_cluster.docker.host

  client_certificate     = minikube_cluster.docker.client_certificate
  client_key             = minikube_cluster.docker.client_key
  cluster_ca_certificate = minikube_cluster.docker.cluster_ca_certificate
  load_config_file       = false
}
##########################################
### Cluster definition                 ### 
##########################################
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
##########################################
### Flux startup procedure             ### 
##########################################
# These all need to happen in order, which is a bit ugly. 
# We first need the namespace, in which we will install the helm chart.
# There is an alternative provider that calls flux bootstrap, but the flux 
# operator approach has the benefit that this updates flux automatically.
resource "kubernetes_namespace" "flux_system" {
  metadata {
    name = "flux-system"
  }
  lifecycle {
    ignore_changes = [metadata]
  }
}
# The helm release installs half of the flux system.
# The deployment and crd's can then be used to run flux.
resource "helm_release" "flux_operator" {
  depends_on = [minikube_cluster.docker]

  name       = "flux-operator"
  namespace  = "flux-system"
  repository = "oci://ghcr.io/controlplaneio-fluxcd/charts"
  chart      = "flux-operator"
  wait       = true
}
# There needs to be a GITHUB_TOKEN environment variable.
# Flux needs this to communicate with the non-public repo.
resource "kubernetes_secret" "token" {
  metadata {
    name = "git-token"
    namespace = "flux-system"
  }
  data = {
    username = "thijs-flux"
    password = "git-token" # the password does not matter 
  }

}
# Apply the custom resource definitions for the gateway API.
# These are pulled from the github source; there is no official/well-maintained helm chart.
data "http" "gateway-crd" {
  url = "https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.3.0/standard-install.yaml "
  request_headers = {
    Accept = "text/plain"
  }
}
# Shenanigans to split the yaml file into multiply parts.
# The official kubernetes provider can also apply manifests, but it has two fatal erorrs:
#  - It cannot plan, as it asks for stuff from the kubernetes api (which we have to start first)
#  - It forbids keys named "status" in manifests for some reason, but this is present in the official gateway crd's.
#    This can be filtered out (very ugly, not really what terraform is for).
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

# Apply the flux instance file.
# This links to the actual git repo and branch, and starts flux. 
resource "kubectl_manifest" "flux" {
  depends_on = [helm_release.flux_operator, kubectl_manifest.gateway-crd, kubernetes_secret.token]
  yaml_body = file("${path.module}/cluster/flux.yaml")
}
# Bit of a hack: we apply the metallb release explicitly as well.
# The way flux gets started from terraform involves a dry-run, which fails as the metallb helm chart involves crd's which are not loaded in the dry-run.
# We also need the networking namespace to be present for this, which should get started by flux, but may not be alive yet when the flux provider is done.
resource "kubernetes_namespace" "networking" {
  metadata {
    name = "networking"
  }
  lifecycle {
    ignore_changes = [metadata]
  }
}
# The release file also contains the repository, so we need to split that.
data "kubectl_file_documents" "metallb" {
    content = file("${path.module}/networking/metallb/release.yaml")
}
resource "kubectl_manifest" "metallb" {
  depends_on = [kubectl_manifest.flux, kubernetes_namespace.networking]
  for_each = data.kubectl_file_documents.metallb.manifests
  yaml_body = each.value
  validate_schema = false # otherwise we get some errors about metallb not reaching some local address for validation
}
