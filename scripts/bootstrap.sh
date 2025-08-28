#!/bin/env bash

export ROOT_DIR="$(git rev-parse --show-toplevel)"
source "$ROOT_DIR/scripts/include/log.sh"

# function apply_namespaces() {
#     log info "Applying namespaces"

#     local namespaces=$(find "$ROOT_DIR"/apps -mindepth 1 -maxdepth 1 -type d -printf "%f\n")

#     for ns in $namespaces; do
#         log debug "Creating namespace $ns"
#         kubectl create namespace $ns
#     done 
# }

# function apply_apps() {
#     log info "Applying apps"
#     local ks=$(find ${ROOT_DIR}/apps -iregex ".*kustomization.ya?ml")
#     for kustomization in ks; do
#         log debug "Applying app $ks"
#         kubectl apply -f "$ks"
#     done
# }

function check() {
    if ! flux check --pre; then 
        log error "Flux check not successfull :("
    fi
    if ! kubectl version>/dev/null; then 
        log error "kubectl not available"
    fi
    log info "Passed checks!"
}

function main() {
    set_log_level
    check
    # apply_namespaces
    # apply_apps
    flux bootstrap github \
        --owner=thijs-flux \
        --repository=fleet-v2 \
        --branch=main \
        --personal \
        --token-auth \
        --path=cluster
}

main "$@"