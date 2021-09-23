__Create the RH SSO client secret__

Create a file named rhsso-client-secret.yaml with the following

~~~
apiVersion: v1
data:
  oidc.keycloak.clientSecret: YOUR_SECRET_HERE
kind: Secret
metadata:
  name: argocd-secret-oidc
  namespace: openshift-gitops
type: Opaque
~~~

Then seal the secret

`kubeseal --cert ~/.bitnami/tls.crt --format yaml < rhsso-client-secret.yaml > 07-sealed-rhsso-client-secret.yaml`