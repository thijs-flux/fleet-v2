#!/bin/env bash
export ROOT_DIR="$(git rev-parse --show-toplevel)"
source "$ROOT_DIR/scripts/include/log.sh"
function kc() {
    kubectl --no-headers=true "$@"
}

function main() {
    set_log_level

    log info "Pods:" 
    kc get po -A | while read line; do
        if [[ $(echo $line | awk '{print $4}') != "Running" ]]; then echo $line; fi
    done
    log info "Helm repositories:" 
    kc get helmrepositories.source.toolkit.fluxcd.io -A | while read line; do
        if [[ $(echo $line | awk '{print $5}') != "True" ]]; then echo $line; fi
    done
    log info "Helm charts:" 
    kc get helmcharts.source.toolkit.fluxcd.io -A | while read line; do
        if [[ $(echo $line | awk '{print $8}') != "True" ]]; then echo $line; fi
    done
    log info "Helm releases:" 
    kc get helmreleases.helm.toolkit.fluxcd.io -A | while read line; do
        if [[ $(echo $line | awk '{print $4}') != "True" ]]; then echo $line; fi
    done
}

main "$@"