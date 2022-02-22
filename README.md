test
# GitOps cluster and application configuration

This repository contains all the cluster and application configuration for my various lab environments.

All the applications can be customized using overlay, following the kustomize practice.

## Table of Contents

<!-- TOC -->
- [Create new cluster configuration](#create-new-cluster-configuration)
- [Required customization](#required-customization)
- [Deploy the cluster configuration](#deploy-the-cluster-configuration)
- [Helm packaging for app-of-apps](#helm-packaging-for-app-of-apps)
- [Helm chart repository](#helm-chart-repository)
- [Helm chart release process](#helm-chart-release-process)
<!-- TOC -->

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
- create the RH-SSO client-secret
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
- seal the secret
    ~~~
    kubeseal --cert ~/.bitnami/tls.crt --format yaml < rhsso-client-secret.yaml > apps/01-openshift-gitops/base/07-sealed-rhsso-client-secret.yaml
    ~~~
- create or update the kustommize overlay with the OIDC issuer URL at `/spec/oidcConfig`. 
See example [here](apps/01-openshift-gitops/overlays/default/kustomization.yaml#L17)

### sealed-secret
If you have pre-defined cert and key for sealed-secrets controller, then populate them [here](https://github.com/adetalhouet/ocp-gitops/blob/main/apps/02-sealed-secrets/bootstrap/02-sealed-secrets-secret-EXAMPLE.yaml) and they will get deployed as part of the bootstrap.
Else, retrieve your sealed-secret cert and key. [Here](https://github.com/redhat-cop/gitops-catalog/tree/main/sealed-secrets-operator/scripts) are tips on how to do so.

### letsencrypt-certs (only for Route53)
In order to update the cluster certificate, provide your AWS creds.

Create a file named aws-credentials.yaml with the following
~~~
apiVersion: v1
kind: Secret
metadata:
  name: cloud-dns-credentials
  namespace: letsencrypt-job
type: Opaque 
stringData: 
  AWS_ACCESS_KEY_ID: "YOUR_ACCESS_ID"
  AWS_SECRET_ACCESS_KEY: "YOUR_ACCESS_KEY_"
  AWS_DNS_SLOWRATE: "1"
~~~
Then seal the secret
~~~
kubeseal --cert ~/.bitnami/tls.crt --format yaml < aws-credentials.yaml > apps/03-letsencrypt-certs/05-sealed-aws-credentials.yaml
~~~

For additional details regarding this solution, see GitHub: [OpenShift Let's Encrypt Job](https://github.com/pittar/ocp-letsencrypt-job) project reference.

### Red Hat Single Sign-On
Create the realms, clients and users according to your desire setup. 
Look [here](https://github.com/adetalhouet/ocp-gitops/blob/main/apps/06-rhsso/overlays/default/config/README.md) for example on how to then seal the information.

### OpenShift OAuth
Create the RH SSO client-secret, and seal it

~~~
apiVersion: v1
kind: Secret
metadata:
  name: keycloack-openshit-client-secret
  namespace: openshift-config
type: Opaque
data:
  clientSecret: YOUR_SECRET_HERE
~~~

~~~
kubeseal --cert ~/.bitnami/tls.crt --format yaml < rhsso-client-secret.yaml > apps/07-oauth/02-sealed-rhsso-client-secret.yaml
~~~

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

## Helm packaging for app-of-apps

To achieve the app-of-apps pattern, few solutions exist:
- using `ApplicationSet` (but the [lack of SyncWaves support](https://github.com/argoproj-labs/applicationset/issues/221}) makes it difficult to adopt)
- using an `Application` for each app/overlay. This makes things very verbose due to the repetition of the `Application` + `kustomization.yaml` requirement. See the number of files removed [in this commit](https://github.com/adetalhouet/ocp-gitops/commit/d9ae7ab6fb5ed0dc2e098563ee6a1c5a154ae6d1) when I moved to helm-based app-of-apps.
- using a Helm Chart with `Application` defined as a template. In my opinion, this makes the deployment elegant and remove all the boilerplate of managing `Application` per app/overlay.

After experiencing all the above, I ended up building a Helm Chart to defined the ArgoCD `Application`. It can be found in the [helm](helm) folder.

### How it works

If you are familiar with Helm, it should be very easy, because my chart is very simple.

I have only one [template](helm/templates) to generate AgoCD `Application` manifests.

The template goes over the defined application in the [values.yaml](helm/values.yaml) file, and create an `Application` for each.

All my apps are prefixed with a number, so when helm is rendering the templates, it keeps that ordering, that I can then use as index to defined the application `sync-wave` value.

Finally, some of my application don't have any overlay, so I added the option to specify whether or not to look for overlay.

## Helm chart repository

In order to use that chart from AgoCD, it must be available through a helm repository. Hence I made this Github repository a helm repository, using Github pages.
It is serving the release charts defined in the [index.yaml](index.yaml) file.

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
