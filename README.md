# GitOps cluster and application configuration

This repository contains all the cluster and application configuration for my various lab environments.

All the applications can be customized using overlay, following the kustomize practice.

## Create new cluster configuration

In order to provision a new cluster, few things needs to be adjusted in the various applications. In order to do so, the script `build-cluster.config.sh` can be used.

It will create new overlay folders based on the `default` one, and adjust the following:
- the FDQN in the various configuration to reflect that new cluster name and domain name. The FQDN is as follow: `$CLUSTER_NAME.$DOMAIN_NAME`
- create the necessary boostrap elements so you can kick-start the provisioning
- regenerate all the SealedSecret

The script can be used as follow:
~~~
./build-cluster-config.sh $CLUSTER_NAME $DOMAIN_NAME
~~~

Once the boilerplate is created, I recommand going over the required customization below.

## Required customization

### openshift-gitops
The installation assumes OIDC will be use as external SSO provider (in this case, RH-SSO). So the user of this application needs to:
- create the RH-SSO client-secret, and seal it, as explained [here](https://github.com/adetalhouet/ocp-gitops/blob/main/apps/01-openshift-gitops/base/README.md)
- create or update the kustommize oveerlay with the OIDC issuer URL at `/spec/oidcConfig`. See example [here](https://github.com/adetalhouet/ocp-gitops/blob/main/apps/01-openshift-gitops/overlays/default/kustomization.yaml#L17)

### sealed-secret
If you have pre-defined cert and key for sealed-secrets controller, then populate them [here](https://github.com/adetalhouet/ocp-gitops/blob/main/apps/02-sealed-secrets/bootstrap/02-sealed-secrets-secret-EXAMPLE.yaml) and they will get deployed as part of the bootstrap.
Else, retrieve your sealed-secret cert and key. [Here](https://github.com/redhat-cop/gitops-catalog/tree/main/sealed-secrets-operator/scripts) are tips on how to do so.

### letsencrypt-certs (only for Route53)
In order to update the cluster certificate, provide your AWS creds as explained [here](https://github.com/adetalhouet/ocp-gitops/blob/main/apps/03-letsencrypt-certs/README.md). 
See GitHub: [OpenShift Let's Encrypt Job](https://github.com/pittar/ocp-letsencrypt-job) project reference.

### Red Hat Single Sign-On
Create the realms, clients and users according to your desire setup. 
Look [here](https://github.com/adetalhouet/ocp-gitops/blob/main/apps/06-rhsso/overlays/default/config/README.md) for example on how to then seal the information.

### oauth
Create the RH SSO client-secret, and seal it, as explained [here](https://github.com/adetalhouet/ocp-gitops/blob/main/apps/07-oauth/base/README.md)

## Deploy the cluster configuration

To start the initial provisioning, the following script can be used:
Note: this operation is to be done once only.

The bootstrap will take care of the following:
- install `openshift-gitops` operator and adequate RBAC
- sealed-secret namespace
- (optional) sealed-secret secret, with your keypair, if configured
- deply the cluster-config-manager Argo CD application acting as app-of-apps. This is what is pointing to the helm chart

~~~
./bootstrap/bootstrap.sh $CLUSTER_NAME
~~~

## Helm packing for app-of-apps

To achieve the app-of-apps pattern, few solutions exist:
- using `ApplicationSet` (but the [lack of SyncWaves support](https://github.com/argoproj-labs/applicationset/issues/221}) makes it difficult to adopt)
- using an `Application` for each app/overlay. This makes things very verbose due to the repetition of the `Application` + `kustomization.yaml` requirement.
- using a Helm Chart with `Application` defined as a template. In my opinion, this makes the deployment elegant and remove all the boilerplate of managing `Application` per app/overlay.

After experiencing all the above, I ended up building a Helm Chart to defined the ArgoCD `Application`. It can be found in the [helm](helm) folder.

## Helm chart repository

In order to use that chart from AgoCD, it must be available through a helm repository. Hence I made this Github repository a helm repository, using Github pages.
It is serving the release charts defined in the [index.yaml](https://github.com/adetalhouet/ocp-gitops/blob/main/index.yaml) file.

In order to consume the helm chart, simply add the following dependency in yours:

~~~
dependencies:
  - name: ocp-gitops
    version: 1.0.0
    repository: https://adetalhouet.github.io/ocp-gitops/
~~~

And as you typically do, customize the helm chart with the `values.yaml` file. It will let you pick and choose the applications to deploy.

## Helm chart release process

To release helm chart, I'm using [chart-releaser](https://github.com/helm/chart-releaser/tree/main).

1. make your Github repo a helm chart repo, [follow this guide](https://medium.com/@mattiaperi/create-a-public-helm-chart-repository-with-github-pages-49b180dbb417)
2. create the package: create the chart and put it in the [.helm-chart-released](.helm-chart-released) folder
~~~
tar -cvzf ocp-gitops-1.0.0.tgz helm`
~~~
3. upload the package: this will create a new branch and a new release with the latest chart.
~~~
cr upload -r ocp-gitops -o adetalhouet --package-path .helm-chart-released -t $AUTH_TOKEN
~~~
4. create/update index: this will regenerate the [index.yaml](index.yaml) file that serves as the chart catalog served by our helm repo.
~~~
cr index  -c https://github.com/adetalhouet/ocp-gitops/tree/ocp-gitops-1.0.0/.helm-chart-released -r ocp-gitops -o adetalhouet --package-path .helm-chart-released -i .
~~~
