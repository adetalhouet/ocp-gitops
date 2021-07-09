__Using Keycloack Migration tool for the configurating__

Find [here](https://mayope.github.io/keycloakmigration/) how to use it and build your manifest

__Generate RH SSO config changelog secret__

`kustomize build ./ > rhsso-config.yaml`

__Seal the RH SSO changelog secret__

`kubeseal --cert ~/.bitnami/tls.crt --format yaml < rhsso-config.yaml > ../02-sealed-rhsso-config.yaml`

__Create the RH SSO client secret__

`kubeseal --cert ~/.bitnami/tls.crt --format yaml < rhsso-client-secret.yaml > ../03-sealed-rhsso-client-secret.yaml`