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