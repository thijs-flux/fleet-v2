#!/bin/env bash

export ROOT_DIR="$(git rev-parse --show-toplevel)"

LOG_LEVEL=1

function log() {
    local lvl="${1:?}" msg="${2:?}"
    local lvl_n
    case "$lvl" in
        "debug")
            lvl_n=0
            ;;
        "info")
            lvl_n=1
            ;;
        "warn")
            lvl_n=2
            ;;
        "error")
            lvl_n=3
            ;;
        *)
            echo Unknown log level "$lvl"
            lvl_n=3
            ;;
    esac
    if ((lvl_n>=LOG_LEVEL)); then
        echo "[${lvl^^}]" "$msg"
    fi
    if [[ $lvl == error ]]; then
        echo "exiting..."
        exit -1 
    fi
}

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
    while getopts "hdq:" flag; do
    case $flag in
        h) 
        echo "use -q to suppress info and warning, use -d for debug"
        exit 0
        ;;
        d) 
        LOG_LEVEL=debug
        ;;
        q) 
        LOG_LEVEL=error
        ;;
        \?)
        echo "invalid option"
        exit 0
        ;;
    esac
    done
    check
    # apply_namespaces
    # apply_apps
    flux bootstrap github \
        --owner=thijs-flux \
        --repository=fleet-v2 \
        --branch=main \
        --personal \
        --path=cluster
}

main "$@"