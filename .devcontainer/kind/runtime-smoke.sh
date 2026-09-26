#!/usr/bin/env bash
set -euo pipefail
test "$(id -u)" -ne 0
docker version
docker run --rm hello-world
kind create cluster --name runtime-validation --wait 180s
trap 'kind delete cluster --name runtime-validation' EXIT
kubectl --context kind-runtime-validation get nodes
kubectl --context kind-runtime-validation wait --for=condition=Ready nodes --all --timeout=120s
