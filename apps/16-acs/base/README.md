__Create the RH SSO client secret__

`kubeseal --cert ~/.bitnami/tls.crt --format yaml < rhsso-client-secret.yaml > 02-sealed-rhsso-client-secret.yaml`