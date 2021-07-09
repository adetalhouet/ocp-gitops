# Bootstrap

The boostrap is responsible to create:
- install `openshift-gitops` operator and adequate RBAC
- sealed-secret namespace
- (optional) sealed-secret secret, with your keypair
- cluster-config-manager Argo CD application acting as app-of-apps

Start by doing 
`oc kustomize bootstrap/hub | oc apply -f-`

Then wait for ArgoCD to be ready
~~~
SLEEP=3
CSV_STATUS="Pausing $SLEEP seconds..."
while [ "$CSV_STATUS" != "Succeeded" ]; do
  echo "Waiting for the GitOps Operator to be ready. ($CSV_STATUS)"
  sleep $SLEEP
  CSV_STATUS=$( oc get csv -n openshift-operators -l operators.coreos.com/openshift-gitops-operator.openshift-operators='' -o jsonpath={..status.phase} )
done
~~~

Then apply the app-of-apps that will control everything
  `oc apply -f bootstrap/hub/app-of-apps.yaml`