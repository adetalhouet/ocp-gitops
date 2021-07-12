# Work in Progress

Required customization:

- openshift-gitops
    - Create the RH SSO client-secret, and seal it, as explained [here](https://github.com/adetalhouet/ocp-gitops/blob/main/apps/01-openshift-gitops/base/README.md)
- sealed-secrets
    - Retrieve your sealed-secret cert and key. [Here](https://github.com/redhat-canada-gitops/catalog/tree/master/sealed-secrets-operator/scripts) are tips on how to do so.
- letsencrypt-certs (only for Route53)
    - In order to update the cluster certificate, provide your AWS creds as explained [here](https://github.com/adetalhouet/ocp-gitops/blob/main/apps/03-letsencrypt-certs/README.md). 
    - See GitHub: [OpenShift Let's Encrypt Job](https://github.com/pittar/ocp-letsencrypt-job) project reference.
- rhsso
    - Create the various elements according to your desire setup. Look [here](https://github.com/adetalhouet/ocp-gitops/blob/main/apps/06-rhsso/config/README.md) for example on how to then seal the information
- oauth
    - Create the RH SSO client-secret, and seal it, as explained [here](https://github.com/adetalhouet/ocp-gitops/blob/main/apps/07-oauth/config/README.md)
- ansible-automation-platform
    - Create the inventory file and then seal it. More information [here](https://github.com/adetalhouet/ocp-gitops/blob/main/apps/10-ansible-automation-platform/config/README.md)