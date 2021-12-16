#!/bin/bash

CLUSTER_NAME=$1
DOMAIN_NAME=$2

if [[ z$CLUSTER_NAME == z ]]; then
  echo " You must provide a cluster name."
  echo "Usage: ./build-cluster-config.sh CLUSTER_NAME DOMAIN_NAME"
  exit 1
fi

if [[ z$DOMAIN_NAME == z ]]; then
  echo " You must provide a domain name."
  echo "Usage: ./build-cluster-config.sh CLUSTER_NAME DOMAIN_NAME"
  exit 1
fi

# prepare schafolding
cp -r bootstrap/default bootstrap/$CLUSTER_NAME
cp -r clusters/default clusters/$CLUSTER_NAME
cp -r apps/01-openshift-gitops/overlays/default apps/01-openshift-gitops/overlays/$CLUSTER_NAME
cp -r apps/06-rhsso/overlays/default apps/06-rhsso/overlays/$CLUSTER_NAME
cp -r apps/07-oauth/overlays/default apps/07-oauth/overlays/$CLUSTER_NAME
cp -r apps/16-acs/overlays/default apps/16-acs/overlays/$CLUSTER_NAME

# replace fqdn cluster name
find . -type f -path "*$CLUSTER_NAME*" -exec gsed -i "s/hub-adetalhouet.rhtelco.io/$CLUSTER_NAME.$DOMAIN_NAME/g" {} +

# configure bootstrap
gsed -i "s/clusters\/default/clusters\/$CLUSTER_NAME/g" bootstrap/$CLUSTER_NAME/app-of-apps.yaml

# configure cluster
gsed -i "s/cluster: default/cluster: $CLUSTER_NAME/g" clusters/$CLUSTER_NAME/applicationset.yaml
gsed -i "s/overlays\/default/overlays\/$CLUSTER_NAME/g" clusters/$CLUSTER_NAME/applicationset.yaml

# Regenerate RH SSO Sealed Secret
RH_SSO_OVERLAY=apps/06-rhsso/overlays/$CLUSTER_NAME
kustomize build $RH_SSO_OVERLAY/config > $RH_SSO_OVERLAY/config/rhsso-config.yaml
kubeseal --cert ~/.bitnami/tls.crt --format yaml < $RH_SSO_OVERLAY/config/rhsso-config.yaml > $RH_SSO_OVERLAY/01-sealed-rhsso-config.yaml