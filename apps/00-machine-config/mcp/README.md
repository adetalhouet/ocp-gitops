https://developers.redhat.com/articles/2021/12/20/prevent-auto-reboot-during-argo-cd-sync-machine-configs#

~~~
oc patch --type=merge --patch='{"spec":{"paused":false}}' machineconfigpool/worker
~~~