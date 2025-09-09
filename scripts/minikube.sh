#!/bin/env bash

export ROOT_DIR="$(git rev-parse --show-toplevel)"
source "$ROOT_DIR/scripts/include/log.sh"


function main() {
    set_log_level
    minikube start --nodes 2
    log info "Minikube started"
}

main "$@"