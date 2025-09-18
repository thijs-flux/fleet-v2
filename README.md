### Installation

Use terraform. The alternative is to set up a cluster manually, and use scripts/bootstrap.sh. 

Sample command: `terraform apply -var "nodes=2" -var "github_token=$(cat token)"`

Terraform variables:
# nodes
The amount of nodes in the minikube cluster

# github_token
The github token for authentication. If this is not set flux will fail.

### Repository layout

# /cluster
Flux files and main cluster definitions. These are hard to move, as flux is somewhat unwieldy about this. cluster.yaml lists all the other directories. namespaces.yaml contains all namespaces.
# /apps
Apps in the cluster
# /monitoring
Monitoring apps
# /networking
Cilium and other networking components
# /routing
Gateway definitions and such
# /nfs
Persistent storage setup
# /cluster-policies
Policies used by cilium
# /scripts
Utility scripts
# /test-deployments
Deployments that are not part of the cluster, but which are useful for debugging/testing during development.

### Troubleshooting

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