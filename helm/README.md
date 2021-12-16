This chart is used to generate all the ArgoCD Application required for a specific cluster.

### Create the package
tar -cvzf ocp-gitops-1.0.0.tgz helm .helm-chart-released

### Upload the package
cr upload -r ocp-gitops -o adetalhouet --package-path .helm-chart-released -t $AUTH_TOKEN

### Create/update index
cr index  -c https://github.com/adetalhouet/ocp-gitops/tree/ocp-gitops-1.0.0/.helm-chart-released -r ocp-gitops -o adetalhouet --package-path .helm-chart-released -i .