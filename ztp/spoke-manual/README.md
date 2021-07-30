This folder contains what is needed to configure the spoke cluster on KVM.

__Manual Spoke cluster deployment__

1. Get the ISO URL from the InfraEnv CR
    ~~~
    oc get infraenv lab-env -n open-cluster-management -o jsonpath={.status.isoDownloadURL}
    ~~~
2. Download and host it on the server hosting the KVM machine
3. Add the ISO in the KVM definition of the SNO VM.
4. Boot the node and wait for it to be self-registered against the Assisted Service.
5. Validate from the AgentClusterInstall CR on the .status.conditions all the requirements are met
    ~~~
    oc describe AgentClusterInstall lab-cluster-aci -n open-cluster-management
    ~~~
    You should read somewhere in the status _The installation is pending on the approval of 1 agents_ If that is the case, go step #6.
6. Edit the created agent by approving it
    ~~~
    # edit the lab to match the name of your infraenv CR
    AGENT=`oc get Agent -l infraenvs.agent-install.openshift.io=lab-env -n open-cluster-management -o name`
    oc patch $AGENT -n open-cluster-management --type='json' -p='[{"op" : "replace" ,"path": "/spec/approved" ,"value": true}]'
    ~~~


Once the deployment is done, you can find the `kubeadmin` password through the secrets created and referenced in the AgentClusterInstall CR; that is held in the hub cluster.

~~~
oc describe AgentClusterInstall lab-cluster-aci -n open-cluster-management
Name:         lab-cluster-aci
Namespace:    open-cluster-management
Labels:       <none>
Annotations:  <none>
API Version:  extensions.hive.openshift.io/v1beta1
Kind:         AgentClusterInstall
Metadata:
  Creation Timestamp:  2021-07-20T23:35:29Z
  Finalizers:
    agentclusterinstall.agent-install.openshift.io/ai-deprovision
  Generation:  3
  Owner References:
    API Version:     hive.openshift.io/v1
    Kind:            ClusterDeployment
    Name:            lab-cluster
    UID:             85777df5-201f-4a4d-aeaf-c2313448aaec
  Resource Version:  4179210
  UID:               080eb67e-17bd-4960-abc0-e2035a586ece
Spec:
  Cluster Deployment Ref:
    Name:  lab-cluster
  Cluster Metadata:
    Admin Kubeconfig Secret Ref:
      Name:  lab-cluster-admin-kubeconfig
    Admin Password Secret Ref:
      Name:      lab-cluster-admin-password
    Cluster ID:  575d4038-25cd-41c7-8744-f8aba3b19d80
    Infra ID:    24b2e5a7-6443-47ad-bbd3-61edf1e335f5
  Image Set Ref:
    Name:  openshift-v4.8.0
  Networking:
    Cluster Network:
      Cidr:         10.128.0.0/14
      Host Prefix:  23
    Machine Network:
      Cidr:  192.168.123.0/24
    Service Network:
      172.30.0.0/16
  Provision Requirements:
    Control Plane Agents:  1
  Ssh Public Key:          ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPwyNH/qkYcqkKk5MiNjKHxnoadME6crIJ8aIs3R6TZQ root@lab.adetalhouet
Status:
  Conditions:
    Last Probe Time:             2021-07-20T23:35:37Z
    Last Transition Time:        2021-07-20T23:35:37Z
    Message:                     SyncOK
    Reason:                      SyncOK
    Status:                      True
    Type:                        SpecSynced
    Last Probe Time:             2021-07-20T23:37:56Z
    Last Transition Time:        2021-07-20T23:37:56Z
    Message:                     The cluster's validations are passing
    Reason:                      ValidationsPassing
    Status:                      True
    Type:                        Validated
    Last Probe Time:             2021-07-21T00:15:06Z
    Last Transition Time:        2021-07-21T00:15:06Z
    Message:                     The cluster installation stopped
    Reason:                      ClusterInstallationStopped
    Status:                      True
    Type:                        RequirementsMet
    Last Probe Time:             2021-07-21T00:15:06Z
    Last Transition Time:        2021-07-21T00:15:06Z
    Message:                     The installation has completed: Cluster is installed
    Reason:                      InstallationCompleted
    Status:                      True
    Type:                        Completed
    Last Probe Time:             2021-07-20T23:35:37Z
    Last Transition Time:        2021-07-20T23:35:37Z
    Message:                     The installation has not failed
    Reason:                      InstallationNotFailed
    Status:                      False
    Type:                        Failed
    Last Probe Time:             2021-07-21T00:15:06Z
    Last Transition Time:        2021-07-21T00:15:06Z
    Message:                     The installation has stopped because it completed successfully
    Reason:                      InstallationCompleted
    Status:                      True
    Type:                        Stopped
  Connectivity Majority Groups:  {"192.168.123.0/24":[]}
  Debug Info:
    Events URL:  https://assisted-service-open-cluster-management.apps.hub-adetalhouet.rhtelco.io/api/assisted-install/v1/clusters/24b2e5a7-6443-47ad-bbd3-61edf1e335f5/events?api_key=eyJhbGciOiJFUzI1NiIsInR5cCI6IkpXVCJ9.eyJjbHVzdGVyX2lkIjoiMjRiMmU1YTctNjQ0My00N2FkLWJiZDMtNjFlZGYxZTMzNWY1In0.k5AYDPBtWTI1JbZESnATMxh6vqyLjeq7M7D5iglRzmnwArF9y_a4RQZFUzV9zctPDgV69fp4x8Hau_VQJoJmDg
    Logs URL:    https://assisted-service-open-cluster-management.apps.hub-adetalhouet.rhtelco.io/api/assisted-install/v1/clusters/24b2e5a7-6443-47ad-bbd3-61edf1e335f5/logs?api_key=eyJhbGciOiJFUzI1NiIsInR5cCI6IkpXVCJ9.eyJjbHVzdGVyX2lkIjoiMjRiMmU1YTctNjQ0My00N2FkLWJiZDMtNjFlZGYxZTMzNWY1In0.NWq1oVTO2jaWvtyS3WSvUUSW_oRkx4_8YQ3cNtspYDhJvAnSuHFYakImx6OS9vk7zOJnKv8uPM2PSzg0096UMQ
    State:       installed
    State Info:  Cluster is installed
Events:          <none>
~~~