### Installation

Use terraform. There are some old scripts for manual bootstrapping, but these do not work with the flux operator.

Sample command: `terraform apply -var-file=x.tfvars

Terraform variables:
# nodes
The amount of nodes in the minikube cluster
# proxmox credentials (if using proxmox)
See the proxmox vars.tf
# nfs_server_addr
The NFS serveer


### Repository layout

# /cluster
Flux file and main cluster definitions. flux.yaml gets loaded directly by terraform, which should bootstrap all other files.
# /apps
Apps in the cluster
# /monitoring
Monitoring apps
# /networking
Cilium and other networking components
# /routing
Gateway definitions and such. Should be independent of the underlying netwokring components.
# /nfs
Persistent storage setup
# /cluster-policies
Policies used by cilium and such
# /scripts
Utility scripts
# /test-deployments
Deployments that are not part of the cluster, but which are useful for debugging/testing during development.

### Troubleshooting
It may take some time for flux to fully apply all configs. If you see errors around L2Advertisement CRD not being available,
just wait a bit as this should be smoothed out by a hack in the terraform (the terraform flux provider cannot handle resources
introducing CRDs and using them at the same time).

## Debugging script
scripts/debug.sh looks through some common resources and lists those that are not up. By all means add more if any others prove problematic.

## Changing gateway classes
The gateway class cannot be changed by flux reconciliation; it will report an imutable value: string of some kind. 
Solution: delete the gatewayclass (kubectl delete -n networking ...) and reapply the kustomization (kubectl apply -k ...).

## Resources stuck terminating
Sometimes resources get stuck in the status "Terminating"; this mainly applies to namespaces. Use scrips/stuck-namespace.sh to attempt a fix. Only do this after you are VERY sure that it's stuck and not just taking a long time.

## Terraform errors at startup 
If starting from a clean slate (i.e. no cluster deployed) make sure to delete the terraform state, i.e. `rm terraform.tfstate`, and `terraform init`. 
If the state suggests a cluster exists the kubectl provider will try to work with the kube api (which does not exist without a cluster) or otherwise contact non-existing sockets.
This can happen when powering down the machine (and thus the cluster) without destroying the terraform state properly (i.e. `terraform destroy -var ...` with the same variables as starting the cluster).
These errors can list some addresses being unavailable, or some GRPC provider error.

## Useful proxmox targets
In case of errors it can be useful to run terraform with a specific target.
The usefule ones are:
 - module.vms: spin up proxmox vms (these are non-bootstrapped talos)
 - local_file.kubeconfig: bootstraps talos and gives a kubeconfig

### Talos
Find the ISO at the [Talos image factory](https://factory.talos.dev/?arch=amd64&cmdline=-talos.halt_if_installed&cmdline-set=true&extensions=-&extensions=siderolabs%2Fqemu-guest-agent&platform=metal&target=metal&version=1.11.3).