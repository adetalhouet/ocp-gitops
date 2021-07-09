# Bootstrap

The boostrap is responsible to create:
- install `openshift-gitops` operator and adequate RBAC
- sealed-secret namespace
- (optional) sealed-secret secret, with your keypair
- cluster-config-manager Argo CD application acting as app-of-apps

`oc kustomize bootstrap/hub | oc apply -f-`