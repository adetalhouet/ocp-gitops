#!/bin/bahs

kustomize build ./ > rhsso-config.yaml

kubeseal --cert ~/.bitnami/tls.crt --format yaml < rhsso-config.yaml > ../03-sealed-rhsso-config.yaml