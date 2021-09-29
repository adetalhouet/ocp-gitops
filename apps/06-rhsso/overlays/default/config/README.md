__Using Keycloack Migration tool for the configurating__

Find [here](https://mayope.github.io/keycloakmigration/) how to use it and build your manifest

_Create Client_

~~~
id: add-openshift-client
author: adetalhouet
realm: openshift
changes:
# OpenShift client
- addSimpleClient:
    clientId: openshift
    publicClient: false
    secret: " " # change client secret accordingly in oauth app
    redirectUris:
      - "https://oauth-openshift.apps.hub-adetalhouet.rhtelco.io/oauth2callback/keycloak"
- updateClient:
    clientId: openshift
    standardFlowEnabled: true
    implicitFlowEnabled: false
    directAccessGrantEnabled: true
# Stackrox
- addSimpleClient:
    clientId: stackrox
    publicClient: false
    secret: " " # change client secret accordingly in oauth app
    redirectUris:
      - "https://central-stackrox.apps.hub-adetalhouet.rhtelco.io/sso/providers/oidc/callback"
      - "https://central-stackrox.apps.hub-adetalhouet.rhtelco.io/auth/response/oidc"
- updateClient:
    clientId: stackrox
    standardFlowEnabled: true
    implicitFlowEnabled: false
    directAccessGrantEnabled: true
- addClientScope:
    name: groups
- addGroupMembershipMapper:
    clientId: stackrox
    name: groups
    addToAccessToken: true
    claimName: groups
- assignDefaultClientScope:
    clientId: stackrox
    clientScopeName: groups
# Argocd client
- addSimpleClient:
    clientId: argocd
    publicClient: false
    secret: " " # change client secret accordingly in argocd app
    redirectUris:
      - "https://openshift-gitops-server-openshift-gitops.apps.hub-adetalhouet.rhtelco.io/auth/callback"
- updateClient:
    clientId: argocd
    standardFlowEnabled: true
    implicitFlowEnabled: false
    directAccessGrantEnabled: true
    baseUrl: /applications
    rootUrl: https://openshift-gitops-server-openshift-gitops.apps.hub-adetalhouet.rhtelco.io
- addClientScope:
    name: groups
- addGroupMembershipMapper:
    clientId: argocd
    name: groups
    addToAccessToken: true
    claimName: groups
- assignDefaultClientScope:
    clientId: argocd
    clientScopeName: groups
~~~

_Create Users_

~~~
id: add-users
author: adetalhouet
changes:
- addUser:
    realm: openshift
    name: adetalhouet
    enabled: true
    firstName: Alexis
    lastName: de Talhouët
- updateUserPassword:
    realm: openshift
    name: adetalhouet
    password: "blah"
~~~

__Generate RH SSO config changelog secret__

`kustomize build ./ > rhsso-config.yaml`

__Seal the RH SSO changelog secret__

`kubeseal --cert ~/.bitnami/tls.crt --format yaml < rhsso-config.yaml > ../01-sealed-rhsso-config.yaml`