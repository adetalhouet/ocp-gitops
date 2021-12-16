This chart is used to generate all the ArgoCD Application required for a specific cluster.

### Create the package
tar -cvzf ocp-gitops-1.0.0.tgz helm .helm-chart-released

### Upload the package
cr upload -r ocp-gitops -o adetalhouet --package-path .helm-chart-released -t $AUTH_TOKEN

### Create/update index
cr index  -r ocp-gitops -o adetalhouet --package-path .helm-chart-released -i .helm-chart-released/index.html -t $AUTH_TOKEN