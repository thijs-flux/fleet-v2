#!/bin/env bash

export ROOT_DIR="$(git rev-parse --show-toplevel)"
source "$ROOT_DIR/scripts/include/log.sh"

function enable_addons() {
    log info "Enabling addons"
}

function main() {
    set_log_level
    microk8s status || log error "No microk8s on system :("
    microk8s start || log error "Could not start"
    microk8s status --wait-ready || log error "Could not start"
    if [[ ! -d ~/.kube ]]; then
        mkdir -p ~/.kube
    fi
    microk8s kubectl config view --raw > ~/.kube/config
    enable_addons
}

main "$@"