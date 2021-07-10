__Using Keycloack Migration tool for the configurating__

Find [here](https://mayope.github.io/keycloakmigration/) how to use it and build your manifest

__Generate RH SSO config changelog secret__

`kustomize build ./ > rhsso-config.yaml`

__Seal the RH SSO changelog secret__

`kubeseal --cert ~/.bitnami/tls.crt --format yaml < rhsso-config.yaml > ../03-sealed-rhsso-config.yaml`