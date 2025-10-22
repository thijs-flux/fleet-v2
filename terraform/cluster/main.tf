terraform {
  required_version = ">= 1.7"
  required_providers {
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
    cilium = {
      source = "littlejo/cilium"
      version = "0.3.2"
    }
  }
}
provider "kubernetes" {
  host = var.host
  client_certificate =  var.client_certificate
  client_key = var.client_key
  cluster_ca_certificate = var.cluster_ca_certificate
  config_path = var.config_path
}
provider "helm" {
  kubernetes = {
    host = var.host
    client_certificate =  var.client_certificate
    client_key = var.client_key
    cluster_ca_certificate = var.cluster_ca_certificate
    config_path = var.config_path
  }
}
provider "kubectl" {
  host = var.host
  client_certificate =  var.client_certificate
  client_key = var.client_key
  cluster_ca_certificate = var.cluster_ca_certificate
  config_path = var.config_path
  
}
provider "cilium" {
  config_path = var.config_path
  namespace = "networking"
}
##########################################
### Flux startup procedure             ### 
##########################################
# These all need to happen in order, which is a bit ugly. 
# The helm release installs half of the flux system.
# The deployment and crd's can then be used to run flux.
data "kubectl_file_documents" "namespaces" {
    content = file("../../cluster/namespaces.yaml")
}
resource "kubectl_manifest" "namespaces" {
  for_each = data.kubectl_file_documents.namespaces.manifests
  yaml_body = each.value
}
resource "cilium" "network"{
  depends_on = [ kubectl_manifest.namespaces ]
  set = [
    "ipam.mode=kubernetes",
    "kubeProxyReplacement=true",
    "securityContext.capabilities.ciliumAgent={CHOWN,KILL,NET_ADMIN,NET_RAW,IPC_LOCK,SYS_ADMIN,SYS_RESOURCE,DAC_OVERRIDE,FOWNER,SETGID,SETUID}",
    "securityContext.capabilities.cleanCiliumState={NET_ADMIN,SYS_ADMIN,SYS_RESOURCE}",
    "cgroup.autoMount.enabled=false",
    "cgroup.hostRoot=/sys/fs/cgroup",
    "k8sServicePort=6443",
  ]
}
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
resource "kubernetes_secret" "gpg" {
  metadata {
    name = "sops-gpg"
    namespace = "flux-system"
  }
  data = {
    "sops.asc" = var.sops_secret
  }
}
resource "kubernetes_config_map" "cluster_vars" {
  metadata {
    name = "cluster-vars"
  }
  data = {
    nfs_server = var.nfs_server_addr
  }
}
resource "helm_release" "flux_operator" {
  depends_on = [ cilium.network, var.cluster, kubernetes_secret.gpg, kubernetes_secret.token, kubernetes_config_map.cluster_vars ]
  name       = "flux-operator"
  namespace  = "flux-system"
  repository = "oci://ghcr.io/controlplaneio-fluxcd/charts"
  chart      = "flux-operator"
  wait       = true
}
# There needs to be a GITHUB_TOKEN environment variable.
# Flux needs this to communicate with the non-public repo.

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
  count      = length(local.gateway-crds)
  yaml_body  = local.gateway-crds[count.index]
}

# Apply the flux instance file.
# This links to the actual git repo and branch, and starts flux. 
resource "kubectl_manifest" "flux" {
  depends_on = [helm_release.flux_operator, kubectl_manifest.gateway-crd, kubernetes_secret.token]
  yaml_body = file("../../cluster/flux.yaml")
}
# Bit of a hack: we apply the metallb release explicitly as well.
# The way flux gets started from terraform involves a dry-run, which fails as the metallb helm chart involves crd's which are not loaded in the dry-run.
# We also need the networking namespace to be present for this, which should get started by flux, but may not be alive yet when the flux provider is done.
# The release file also contains the repository, so we need to split that.
# data "kubectl_file_documents" "metallb" {
#     content = file("../../networking/metallb/release.yaml")
# }
# resource "kubectl_manifest" "metallb" {
#   depends_on = [kubectl_manifest.flux, kubernetes_namespace.networking]
#   for_each = data.kubectl_file_documents.metallb.manifests
#   yaml_body = each.value
#   validate_schema = false # otherwise we get some errors about metallb not reaching some local address for validation
# }
data "kubectl_file_documents" "cilium" {
    content = file("../../networking/metallb/release.yaml")
}
resource "kubectl_manifest" "cilium" {
  depends_on = [kubectl_manifest.flux]
  for_each = data.kubectl_file_documents.cilium.manifests
  yaml_body = each.value
  validate_schema = false # otherwise we get some errors about metallb not reaching some local address for validation
}