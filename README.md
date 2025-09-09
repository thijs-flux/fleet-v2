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

## Changing gateway classes
The gateway class cannot be changed by flux reconciliation; it will report an imutable value: string of some kind. 
Solution: delete the gatewayclass (kubectl delete -n networking ...) and reapply the kustomization (kubectl apply -k ...).

## Resources stuck terminating
Sometimes resources get stuck in the status "Terminating"; this mainly applies to namespaces. Use scrips/stuck-namespace.sh to attempt a fix. Only do this after you are VERY sure that it's stuck and not just taking a long time.