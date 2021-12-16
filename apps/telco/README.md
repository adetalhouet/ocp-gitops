__This is still TBD__

docker run -v /Users/adetalhouet/.kube/configs/:/kubeconfig -e KUBECONFIG=/kubeconfig/apps-adetalhouet-kubeconfig.yaml -e ROLE_WORKER_CNF=worker-pao registry.redhat.io/openshift4/cnf-tests-rhel8:v4.6 /usr/bin/test-run.sh


https://docs.openshift.com/container-platform/4.7/networking/ovn_kubernetes_network_provider/migrate-from-openshift-sdn.html