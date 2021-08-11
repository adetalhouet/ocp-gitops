__Deploy__

~~~
./build-cluster-config.sh $CLUSTER_NAME
./bootstrap/bootstrap.sh $CLUSTER_NAME
~~~

The first script is to generate new overlay folders based on the existing ones, and adjust:
- the FDQN in the various configuration to reflect that new cluster name. The FQDN is as follow: `$CLUSTER_NAME.rhtelco.io`
- the cluster name in the applicationset

The second script deploys [few key elements](https://github.com/adetalhouet/ocp-gitops/blob/main/bootstrap/README.md) in the cluster and then, once ready, deploy the ArgoCD appliction acting as an apps-of-app.

__Notes__

Required customization:

- openshift-gitops
    - The installation assumes OIDC will be use as external SSO provider (in this case, keycloak - see rhsso app)
    - Create the RH SSO client-secret, and seal it, as explained [here](https://github.com/adetalhouet/ocp-gitops/blob/main/apps/01-openshift-gitops/base/README.md)
    - Make sure to update the /spec/oidcConfig using the overlay folder
- sealed-secrets
    - If you have pre-defined cert and key for sealed-secrets controller, then populate them [here](https://github.com/adetalhouet/ocp-gitops/blob/main/apps/02-sealed-secrets/bootstrap/02-sealed-secrets-secret-EXAMPLE.yaml) and they will get deployed as part of the bootstrap.
    - Else, retrieve your sealed-secret cert and key. [Here](https://github.com/redhat-cop/gitops-catalog/tree/main/sealed-secrets-operator/scripts) are tips on how to do so.
- letsencrypt-certs (only for Route53)
    - In order to update the cluster certificate, provide your AWS creds as explained [here](https://github.com/adetalhouet/ocp-gitops/blob/main/apps/03-letsencrypt-certs/README.md). 
    - See GitHub: [OpenShift Let's Encrypt Job](https://github.com/pittar/ocp-letsencrypt-job) project reference.
- rhsso
    - Create the realms, clients and users according to your desire setup. Look [here](https://github.com/adetalhouet/ocp-gitops/blob/main/apps/06-rhsso/overlay/default/config/README.md) for example on how to then seal the information
- oauth
    - Create the RH SSO client-secret, and seal it, as explained [here](https://github.com/adetalhouet/ocp-gitops/blob/main/apps/07-oauth/base/README.md)
- ansible-automation-platform
    - Create the inventory file and then seal it. More information [here](https://github.com/adetalhouet/ocp-gitops/blob/main/apps/10-ansible-automation-platform/overlay/default/config/README.md)
