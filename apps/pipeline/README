## Load the github-set-status tekton task

```
kubectl apply -f https://raw.githubusercontent.com/tektoncd/catalog/main/task/github-set-status/0.4/github-set-status.yaml -n pipeline-demo
```

## Create your github secret

```
kubectl create secret generic github --from-literal token="***" -n pipeline-demo
```

## Properly create webhook in github

### Webhook sending Push events
![](docs/push-trigger.png)

### Webhook sending Pull Request events
![](docs/pr-trigger.png)