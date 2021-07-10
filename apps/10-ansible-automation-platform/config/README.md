__Using Ansible Tower OpenShit Install__

Find [here](https://docs.ansible.com/ansible-tower/3.4.3/html/administration/openshift_configuration.html) how to use it 

__Generate Ansible Tower inventory secret__

`kustomize build ./ > ansible-tower-inventory.yaml`

__Seal the Ansible Tower secret__

`kubeseal --cert ~/.bitnami/tls.crt --format yaml < ansible-tower-inventory.yaml > ../05-sealed-ansible-tower-inventory.yaml`