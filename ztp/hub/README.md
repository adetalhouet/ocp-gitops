This folder contains what is needed to configure the `assisted-service` in the hub cluster.

Adjust the various files based on the release you want to deploy.

After applying these manifest, a new `deployment` named `assisted-service` will be created in the `open-cluster-management`. Along with the deployment, there will be a `service` that will be the API endpoint the spoke cluster will use to interact with the hub.

That agent will be the main interface between the hub and spoke cluster.