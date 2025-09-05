#!/bin/env bash
kubectl get namespace "$1" -o json \
  | tr -d "\n" | sed "s/\"finalizers\": \[[^]]\+\]/\"finalizers\": []/" \
  | kubectl replace --raw /api/v1/namespaces/$1/finalize -f -

crds=$(kubectl get crd -o name | grep "flux")
for crd in $crds; do
  kubectl patch "$crd" -p '{"metadata":{"finalizers":[]}}' --type=merge
done