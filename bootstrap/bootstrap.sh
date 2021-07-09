#!/bin/bash

# Install Argo, create sealed-secret namespace, and add sealed-secret-key
oc kustomize bootstrap/hub | oc apply -f-

# Wait for ArgoCD to be ready
SLEEP=3
CSV_STATUS="Pausing $SLEEP seconds..."
while [ "$CSV_STATUS" != "Succeeded" ]; do
  echo "Waiting for the GitOps Operator to be ready. ($CSV_STATUS)"
  sleep $SLEEP
  CSV_STATUS=$( oc get csv -n openshift-operators -l operators.coreos.com/openshift-gitops-operator.openshift-operators='' -o jsonpath={..status.phase} )
done

#Then apply the app-of-apps that will control everything
oc apply -f bootstrap/hub/app-of-apps.yaml