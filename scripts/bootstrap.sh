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

function wait_ready() {
    printf "\n"
    while true; do
        kustomizations_total=$(flux get kustomizations -A --no-header | wc -l)
        kustomizations_ready=$(flux get kustomizations -A --no-header --status-selector ready=True | wc -l)

        pods_total=$(kubectl get po -A -o custom-columns=READY:.status.phase --no-headers=true | wc -l)
        pods_running=$(kubectl get po -A -o custom-columns=READY:.status.phase --no-headers=true | grep Running | wc -l)

        printf "\rkustomizations ready: ${kustomizations_ready}/${kustomizations_total}, pods running: ${pods_running}/${pods_total}"
        if ((kustomizations_ready==kustomizations_total&&pods_running==pods_total)); then break; fi
        sleep 1
    done 

}

function main() {
    set_log_level
    check
    local cluster
    cluster=staging
    while getopts "p:" flag; do
    case $flag in
        p) 
        cluster=production
        ;;
    esac
    done
    flux bootstrap github \
        --owner=thijs-flux \
        --repository=fleet-v2 \
        --branch=main \
        --personal \
        --token-auth \
        --path=cluster/$cluster
    l=$(log_level)
    if (( l <= 1 )); then
        wait_ready
    fi
}

main "$@"