# Using GitOps to deploy a Single Node OpenShift on libvirt using RHACM ZTP capabilities

The goal is to leverage the latest capabilities from Red Hat Advanced Cluster Management (RHACM) 2.3 to deploy an Single Node OpenShift cluster using the Zero Touch Provisioning on an emulated bare metal environment.
The typical Zero Touch Provisioning flow is meant to work for bare metal environment; but if like me, you don't have a bare metal environment handy, or want to optimize the only server you have, that blog is for you.
 RHACM works in a hub and spoke manner. So the goal here is to deploy a spoke from the hub cluster.


The overall setup requires the following components:

- [Ironic](https://wiki.openstack.org/wiki/Ironic): It is the OpenStack bare metal provisioning tool that uses PXE or BMC to provision and turn on/off machines
- [Metal3](https://metal3.io/): It is the Kubernetes bare metal provisioning tool. Under the hood, it uses Ironic. And above the hood, it provides an [operator](https://github.com/metal3-io/baremetal-operator) along with the CRD it supports: `BareMetalHost`
- [Red Hat Advanced Cluster Management](https://www.openshift.com/products/advanced-cluster-management) (RHACM) provides the overall feature set to manage a fleet of cluster. It also provide all the foundational elements to create an [assisted service](https://github.com/openshift/assisted-service).

Let's align on the Zero Touch Provisioning expectation:

- the overall libvirt environment will be setup manually (although it could easily be automated).
- once the environment is correctly setup, we will apply the manifests that will automate the cluster creation.

1. [Pre-requisites](#prerequisites)
2. [ZTP flow overview](#ztpflow)
3. [Install requirements on the hub cluster](#hubcluster)
	- [Assisted Service](#assistedservice)
	- [Ironic & Metal3](#bmo)
4. [Install requirements on the spoke server](#spokecluster)
	- [Install libvirt](#libvirtinstall)
	- [Install and configure Sushy service](#sushy)
	- [Libvirt setup](#libvirtsetup)
	- - [Create a storage pool](#storage)
	- - [Create a network](#net)
  - - [Create the disk](#disk)
  - - [Create the  VM / libvirt domain](#vm)
5. [Let's deploy the spoke](#spoke)
  - - [Few debugging tips](#debug)
  - - [Accessing your cluster](#access)

## Pre-requisite <a name="prerequisites"></a>

- Red Hat OpenShift Container Platform __4.8__ for the hub cluster- see [here](https://access.redhat.com/documentation/en-us/openshift_container_platform/4.8/html/installing/index) on how to deploy
- Red Hat Advanced Cluster Management __2.3__ installed on the hub cluster- see [here](https://github.com/open-cluster-management/deploy#prepare-to-deploy-open-cluster-management-instance-only-do-once) on how to deploy
- A server with at least 32GB of RAM, 8 CPUs and 120 GB of disk - this is the machine we will use for the spoke. Mine is setup with CentOS 8.4
- Clone the git repo: `git clone https://github.com/adetalhouet/ocp-gitops`

## ZTP flow overview <a name="ztpflow"></a>

TBD

## Install requirements on the hub cluster <a name="hubcluster"></a>
The assumption is the cluster is __not__ deployed on bare metal. If that's the case, then this blog isn't for you.
In my case, my hub cluster is deployed in AWS. As it isn't a bare metal cluster, you don't have the Ironic and Metal3 pieces, so we will deploy them ourselves.

### Install the Assisted Service <a name="assistedservice"></a>

The related manifest to install this are located in `ocp-gitops/ztp/hub`. The main manifest is the one with the `AgentServiceConfig` definition, which define the base RHCOS image to use to the node install.

Add your private key in the `ocp-gitops/ztp/hub/03-assisted-deployment-ssh-private-key.yaml` file, and then apply the folder. The private key will be in the resulting VM, and you will use the corresponding public key to ssh, if needed.
~~~
oc apply -k ocp-gitops/ztp/hub

# after view seconds or minutes, check the pod is there and running
oc get pod -n open-cluster-management -l app=assisted-service
NAME                                READY   STATUS    RESTARTS   AGE
assisted-service-5df8bd68d8-b4qpw   2/2     Running   9          12d
~~~

### Install Ironic and Metal3 <a name="bmo"></a>

TBD - As a heads-up, that was one of the hardest part, because it's not very well explain how all that works.

It starts with

~~~
git clone https://github.com/metal3-io/baremetal-operator
~~~

### Create the namespace in which we will install our `BareMetalHost` manifests
That CRD is the one responsible for the ZTP flow.
~~~
oc create ns sno-ztp
~~~

## Install requirements on the spoke server <a name="spokecluster"></a>
I'm assuming you have a blank server, running CentOS 8.4.

### Install libvirt <a name="libvirtinstall"></a>
Install the required dependencies.

~~~
dnf install -y bind-utils libguestfs-tools cloud-init
dnf module install virt -y
dnf install virt-install -y
systemctl enable libvirtd --now
~~~

### Install and configure Sushy service <a name="sushy"></a>
Sushy service is a Virtual Redfish BMC emulator for libvirt or OpenStack virtualization. In our case, we will use it for libvirt, in order to add BMC capabilities to libvirt domain. That will enable remote control of the VMs.

~~~
dnf install python3 -y
pip3 install sushy-tools
~~~

Then you need to configure the service. In my case, I'm binding the sushy service on all my interfaces. But if you have a management interface providing connectivity between the hub and the spoke environments, you should use that interface instead.
Also, the port is customizable, and if you have firewall in the way, make sure to open them accordingly.

~~~
echo "SUSHY_EMULATOR_LISTEN_IP = u'0.0.0.0'
SUSHY_EMULATOR_LISTEN_PORT = 8000
SUSHY_EMULATOR_SSL_CERT = None
SUSHY_EMULATOR_SSL_KEY = None
SUSHY_EMULATOR_OS_CLOUD = None
SUSHY_EMULATOR_LIBVIRT_URI = u'qemu:///system'
SUSHY_EMULATOR_IGNORE_BOOT_DEVICE = True
# This specifies where to find the boot loader for a UEFI boot. This is what the ZTP process uses.
SUSHY_EMULATOR_BOOT_LOADER_MAP = {
    u'UEFI': {
        u'x86_64': u'/usr/share/OVMF/OVMF_CODE.secboot.fd'
    },
    u'Legacy': {
        u'x86_64': None
    }
}" > /etc/sushy.conf
~~~

There is currently an [issue](https://bugzilla.redhat.com/show_bug.cgi?id=1906500) with libvirt that basically forces the use of secure boot. Theoritically this can be disable, but the feature isn't working properly since RHEL 8.3 (so it's the same in CentOS that I'm using).
In order to mask the secure feature boot vars, [the following solution has been suggested](https://bugzilla.redhat.com/show_bug.cgi?id=1906500#c23):

~~~
mkdir -p /etc/qemu/firmware
touch /etc/qemu/firmware/40-edk2-ovmf-sb.json
~~~

Now, let's create the sushy service and start it.

~~~
echo '[Unit]
Description=Sushy Libvirt emulator
After=syslog.target

[Service]
Type=simple
ExecStart=/usr/local/bin/sushy-emulator --config /etc/sushy.conf
StandardOutput=syslog
StandardError=syslog' > /usr/lib/systemd/system/sushy.service'
systemctl start sushy
~~~

Finally, let's start the built-in firewall and allow traffic on port 8000.

~~~
systemctl start firewalld
firewall-cmd --add-port=8000/tcp
~~~

### Libvirt setup <a name="libvirtsetup"></a>

#### Create a pool <a name="storage"></a>

When Ironic will use our virtual BMC, emulated by sushy-tools, to load the ISO in the server (VM in our case), sushy-tools will host that image in the `default` storage pool, so we need to create it accordingly. (I couldn't find a way, yet, to configure the storage pool to use.)
~~~
mkdir -p /var/lib/libvirt/sno-ztp
virsh pool-define-as default --type dir --target /var/lib/libvirt/sno-ztp
virsh pool-start default
virsh pool-autostart default
~~~

#### Create a network <a name="net"></a>

OpenShift Bare Metal install has the following requirements:

- a proper hostname / domain name mapped to the MAC address of the interface to use for the provisioning
- a DNS entry for the api.$clusterName.$domainName
- a DNS entry for the *.apps.$clusterName.$domainName

So we will configure them accordingly in the libvirt network definition, using the built-in dnsmaq capability of libvirt network.

Here is my network definition (`ocp-gitops/libvirt/sno/net.xml`)
<details>
<summary>ocp-gitops/libvirt/sno/net.xml</summary>

~~~
<network xmlns:dnsmasq="http://libvirt.org/schemas/network/dnsmasq/1.0">
  <name>sno</name>
  <forward mode='nat'>
    <nat>
      <port start='1024' end='65535'/>
    </nat>
  </forward>
  <bridge name='virbr1' stp='on' delay='0'/>
  <ip address='192.168.123.1' netmask='255.255.255.0'>
    <dhcp>
      <range start='192.168.123.2' end='192.168.123.254'/>
      <host mac="02:04:00:00:00:66" name="sno.lab.adetalhouet" ip="192.168.123.5"/>
    </dhcp>
  </ip>
  <dns>
    <host ip="192.168.123.5"><hostname>api.sno.lab.adetalhouet</hostname></host>
  </dns>
  <dnsmasq:options>
    <dnsmasq:option value="auth-server=sno.lab.adetalhouet,"/>
    <dnsmasq:option value="auth-zone=sno.lab.adetalhouet"/>
    <dnsmasq:option value="host-record=lb.sno.lab.adetalhouet,192.168.123.5"/>
    <dnsmasq:option value="cname=*.apps.sno.lab.adetalhouet,lb.sno.lab.adetalhouet"/>
  </dnsmasq:options>
</network>
~~~
</details>

Now let's define and start our network

~~~
# create the file net.xml with the content above
virsh net-define net.xml
virsh net-start sno
virsh net-autostart sno
~~~

#### Create the disk <a name="disk"></a>

In order for Assisted Installer to allow the installation of the Single Node OpenShift to happen, one of the requirement is the disk size: it must be at least of 120GB. When creating a disk of 120GB, or even 150GB, for some reason I had issues and the Assisted Service wouldn't allow the installation complaining about the disk size requirepement not being met.
So let's create a disk of 200 GB to be sure.
~~~
qemu-img create -f qcow2 /var/lib/libvirt/sno-ztp/sno2.qcow2 200G
~~~

#### Create the  VM / libvirt domain <a name="vm"></a>

While creating the VM, make sure to adjust RAM and CPU, as well as the network and disk if you've made modification.
The interface configured in the domain is the one we pre-defined in the network definition, and we will identify the interface by its mac address. When the VM will boot, it will be able to resolve its hostname through the DNS entry.

(FYI - I spent hours trying to nail down the proper xml definition, more importantly the `os` bits. When the Assisted Asservice will start the provisioning, it will first start the VM, load the discovery.iso and then restart the VM to boot from the newly added disc. After the restart, the `os` section will be modified, as Assisted Service will configure an UEFI boot.)

Here is my VM definition (`ocp-gitops/libvirt/sno/vm.xml`)
<details>
<summary>ocp-gitops/libvirt/sno/vm.xml</summary>

~~~
<domain type="kvm">
  <name>sno</name>
  <uuid>b6c92bbb-1e87-4972-b17a-12def3948890</uuid>
  <metadata>
    <libosinfo:libosinfo xmlns:libosinfo="http://libosinfo.org/xmlns/libvirt/domain/1.0">
      <libosinfo:os id="http://fedoraproject.org/coreos/stable"/>
    </libosinfo:libosinfo>
  </metadata>
  <memory>33554432</memory>
  <currentMemory>33554432</currentMemory>
  <vcpu>16</vcpu>
  <os>
    <type arch="x86_64" machine="q35">hvm</type>
    <boot dev="hd"/>
    <boot dev="cdrom"/>
  </os>
  <features>
    <acpi/>
    <apic/>
    <smm state='on'/>
    <vmport state="off"/>
  </features>
  <cpu mode="host-passthrough">
    <cache mode="passthrough"/>
  </cpu>
  <clock offset="utc">
    <timer name="rtc" tickpolicy="catchup"/>
    <timer name="pit" tickpolicy="delay"/>
    <timer name="hpet" present="no"/>
  </clock>
  <pm>
    <suspend-to-mem enabled="no"/>
    <suspend-to-disk enabled="no"/>
  </pm>
  <devices>
    <emulator>/usr/libexec/qemu-kvm</emulator>
    <disk type="file" device="disk">
      <driver name="qemu" type="qcow2"/>
      <source file="/var/lib/libvirt/sno-ztp/sno.qcow2"/>
      <target dev="vda" bus="virtio"/>
    </disk>
    <controller type="usb" index="0" model="qemu-xhci" ports="15"/>
    <interface type="network">
      <source network="sno"/>
      <mac address="02:04:00:00:00:66"/>
      <model type="virtio"/>
    </interface>
    <console type="pty"/>
    <channel type="unix">
      <source mode="bind"/>
      <target type="virtio" name="org.qemu.guest_agent.0"/>
    </channel>
    <channel type="spicevmc">
      <target type="virtio" name="com.redhat.spice.0"/>
    </channel>
    <input type="tablet" bus="usb"/>
    <graphics type="spice" port="-1" tlsPort="-1" autoport="yes">
      <image compression="off"/>
    </graphics>
    <sound model="ich9"/>
    <video>
      <model type="qxl"/>
    </video>
    <redirdev bus="usb" type="spicevmc"/>
    <redirdev bus="usb" type="spicevmc"/>
    <memballoon model="virtio"/>
    <rng model="virtio">
      <backend model="random">/dev/urandom</backend>
    </rng>
  </devices>
</domain>
~~~
</details>
Now let's define our domain.

~~~
# create the file vm.xml with the content above
virsh define vm.xml
virsh autostart sno
~~~
Do not start the VM by yourself, it will be done later in the process, automatically. Moreover, your VM at this point has no CDROM to boot from.

Now the environment is ready, let's create an Single Node OpenShift cluster automagically.

## Let's deploy the spoke <a name="spoke"></a>

We will use all the manifests in the `ocp-gitops/ztp/spoke-sno/` folder. Simply apply the following command:
~~~
oc create -f ocp-gitops/ztp/spoke-sno/
~~~

It will take on average 60-ish minutes for the cluster to be ready.
That said, to validate the cluster will get deployed properly, few tests you can do.

### Few debugging tips <a name="debug"></a>
###### Storage
First, look at the storage pool folder; sometimes ISO upload isn't working properly, and the resulting ISO doesn't have all the data. See the size of both ISO; the expected size, based on my experience, is `105811968`. So if the file is not in that range, the VM won't boot properly.

~~~
[root@lab ai-ztp]# ls -ls /var/lib/libvirt/sno-ztp/
total 103536
     4 -rw------- 1 qemu qemu      3265 Jul 29 04:04 boot-072b3441-2bd9-4aaf-939c-7e4640e38935-iso-79ad9824-8110-4570-83e3-a8cd6ae9d435.img
103332 -rw------- 1 qemu qemu 105811968 Jul 29 04:07 boot-e1fcd81d-899c-47be-9c95-f6ff77c44f79-iso-79ad9824-8110-4570-83e3-a8cd6ae9d435.img
   200 -rw-r--r-- 1 qemu qemu    196616 Jul 29 03:26 sno.qcow2
~~~
###### Network
After a few minutes of having your VM running, it should get its IP from the network. Two ways to validate:
Check the network `dhcp-leases` and ensure the IP has been assigned
~~~
[root@lab sno]# virsh net-dhcp-leases sno
 Expiry Time           MAC address         Protocol   IP address         Hostname   Client ID or DUID
----------------------------------------------------------------------------------------------------------
 2021-07-30 05:52:28   02:04:00:00:00:66   ipv4       192.168.123.5/24   sno        01:02:04:00:00:00:66
 ~~~
If so, attempt to SSH using the public key that goes with the private key you configure while installing the Assisted Service. You should be able to ssh properly.
~~~
[root@lab sno]# ssh core@192.168.123.5
The authenticity of host '192.168.123.5 (192.168.123.5)' can't be established.
ECDSA key fingerprint is SHA256:RlXx0uz3Hm87wxFrgW/gPddCTslb7WhXmm/1SbLjmcU.
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
Warning: Permanently added '192.168.123.5' (ECDSA) to the list of known hosts.
Red Hat Enterprise Linux CoreOS 48.84.202107040900-0
  Part of OpenShift 4.8, RHCOS is a Kubernetes native operating system
  managed by the Machine Config Operator (`clusteroperator/machine-config`).

WARNING: Direct SSH access to machines is not recommended; instead,
make configuration changes via `machineconfig` objects:
  https://docs.openshift.com/container-platform/4.8/architecture/architecture-rhcos.html

---
[core@sno ~]$
~~~
###### Monitor the `Agent`
Assuming the above worked, then I suggest you monitor the `Agent` that was created for your cluster deployment. This will give you an URL you can use to follow the events occuring in your cluster.

<details>
<summary>oc get Agent -n sno-ztp</summary>

~~~
oc get Agent -n sno-ztp
NAME                                   CLUSTER            APPROVED   ROLE     STAGE
b6c92bbb-1e87-4972-b17a-12def3948890   sno-ztp-cluster    true       master   Done

oc describe Agent b6c92bbb-1e87-4972-b17a-12def3948890 -n sno-ztp
Name:         b6c92bbb-1e87-4972-b17a-12def3948890
Namespace:    sno-ztp
Labels:       agent-install.openshift.io/bmh=sno-ztp-bmh
              infraenvs.agent-install.openshift.io=sno-ztp-infraenv
Annotations:  <none>
API Version:  agent-install.openshift.io/v1beta1
Kind:         Agent
Metadata:
  Creation Timestamp:  2021-07-30T02:40:46Z
  Finalizers:
    agent.agent-install.openshift.io/ai-deprovision
  Generation:  2
  Resource Version:  22242465
  UID:               27e7bd79-0b28-4e66-906f-3d1c0db5e809
Spec:
  Approved:  true
  Cluster Deployment Name:
    Name:       sno-ztp-cluster
    Namespace:  sno-ztp
  Role:
Status:
  Bootstrap:  true
  Conditions:
    Last Transition Time:  2021-07-30T02:40:46Z
    Message:               The Spec has been successfully applied
    Reason:                SyncOK
    Status:                True
    Type:                  SpecSynced
    Last Transition Time:  2021-07-30T02:40:46Z
    Message:               The agent's connection to the installation service is unimpaired
    Reason:                AgentIsConnected
    Status:                True
    Type:                  Connected
    Last Transition Time:  2021-07-30T02:40:52Z
    Message:               The agent installation stopped
    Reason:                AgentInstallationStopped
    Status:                True
    Type:                  RequirementsMet
    Last Transition Time:  2021-07-30T02:40:52Z
    Message:               The agent's validations are passing
    Reason:                ValidationsPassing
    Status:                True
    Type:                  Validated
    Last Transition Time:  2021-07-30T02:59:30Z
    Message:               The installation has completed: Done
    Reason:                InstallationCompleted
    Status:                True
    Type:                  Installed
  Debug Info:
    Events URL:  https://assisted-service-open-cluster-management.apps.hub-adetalhouet.rhtelco.io/api/assisted-install/v1/clusters/e85bc2e6-ea53-4e0a-8e68-8922307a0159/events?api_key=eyJhbGciOiJFUzI1NiIsInR5cCI6IkpXVCJ9.eyJjbHVzdGVyX2lkIjoiZTg1YmMyZTYtZWE1My00ZTBhLThlNjgtODkyMjMwN2EwMTU5In0.IYV4maUrNxJBkNMkWqYU9m5IZKcai4PP21ECehjH0hnIG5OaI_2elhHp_-kFjvC7Px710y2UAdoyb_doSE88OA&host_id=b6c92bbb-1e87-4972-b17a-12def3948890
    State:       installed
    State Info:  Done
  Inventory:
    Bmc Address:   0.0.0.0
    bmcV6Address:  ::/0
    Boot:
      Current Boot Mode:  uefi
    Cpu:
      Architecture:     x86_64
      Clock Megahertz:  3491
      Count:            16
      Flags:
        fpu
        vme
        de
        pse
        tsc
        msr
        pae
        mce
        cx8
        apic
        sep
        mtrr
        pge
        mca
        cmov
        pat
        pse36
        clflush
        mmx
        fxsr
        sse
        sse2
        ss
        syscall
        nx
        pdpe1gb
        rdtscp
        lm
        constant_tsc
        arch_perfmon
        rep_good
        nopl
        xtopology
        cpuid
        tsc_known_freq
        pni
        pclmulqdq
        vmx
        ssse3
        fma
        cx16
        pdcm
        pcid
        sse4_1
        sse4_2
        x2apic
        movbe
        popcnt
        tsc_deadline_timer
        aes
        xsave
        avx
        f16c
        rdrand
        hypervisor
        lahf_lm
        abm
        cpuid_fault
        invpcid_single
        pti
        ssbd
        ibrs
        ibpb
        stibp
        tpr_shadow
        vnmi
        flexpriority
        ept
        vpid
        ept_ad
        fsgsbase
        tsc_adjust
        bmi1
        avx2
        smep
        bmi2
        erms
        invpcid
        xsaveopt
        arat
        umip
        md_clear
        arch_capabilities
      Model Name:  Intel(R) Xeon(R) CPU E5-1650 v3 @ 3.50GHz
    Disks:
      By Path:     /dev/disk/by-path/pci-0000:00:1f.2-ata-1
      Drive Type:  ODD
      Hctl:        0:0:0:0
      Id:          /dev/disk/by-path/pci-0000:00:1f.2-ata-1
      Installation Eligibility:
        Not Eligible Reasons:
          Disk is removable
          Disk is too small (disk only has 106 MB, but 120 GB are required)
          Drive type is ODD, it must be one of HDD, SSD.
      Io Perf:
      Model:       QEMU_DVD-ROM
      Name:        sr0
      Path:        /dev/sr0
      Serial:      QM00001
      Size Bytes:  105811968
      Smart:       {"json_format_version":[1,0],"smartctl":{"version":[7,1],"svn_revision":"5022","platform_info":"x86_64-linux-4.18.0-240.22.1.el8_3.x86_64","build_info":"(local build)","argv":["smartctl","--xall","--json=c","/dev/sr0"],"exit_status":4},"device":{"name":"/dev/sr0","info_name":"/dev/sr0","type":"scsi","protocol":"SCSI"},"vendor":"QEMU","product":"QEMU DVD-ROM","model_name":"QEMU QEMU DVD-ROM","revision":"2.5+","scsi_version":"SPC-3","device_type":{"scsi_value":5,"name":"CD/DVD"},"local_time":{"time_t":1627613330,"asctime":"Fri Jul 30 02:48:50 2021 UTC"},"temperature":{"current":0,"drive_trip":0}}
      Vendor:      QEMU
      Bootable:    true
      By Path:     /dev/disk/by-path/pci-0000:04:00.0
      Drive Type:  HDD
      Id:          /dev/disk/by-path/pci-0000:04:00.0
      Installation Eligibility:
        Eligible:  true
        Not Eligible Reasons:
      Io Perf:
      Name:        vda
      Path:        /dev/vda
      Size Bytes:  214748364800
      Smart:       {"json_format_version":[1,0],"smartctl":{"version":[7,1],"svn_revision":"5022","platform_info":"x86_64-linux-4.18.0-240.22.1.el8_3.x86_64","build_info":"(local build)","argv":["smartctl","--xall","--json=c","/dev/vda"],"messages":[{"string":"/dev/vda: Unable to detect device type","severity":"error"}],"exit_status":1}}
      Vendor:      0x1af4
    Hostname:      sno
    Interfaces:
      Flags:
        up
        broadcast
        multicast
      Has Carrier:  true
      ipV4Addresses:
        192.168.123.5/24
      ipV6Addresses:
      Mac Address:  02:04:00:00:00:66
      Mtu:          1500
      Name:         enp1s0
      Product:      0x0001
      Speed Mbps:   -1
      Vendor:       0x1af4
    Memory:
      Physical Bytes:  34359738368
      Usable Bytes:    33693179904
    System Vendor:
      Manufacturer:  Red Hat
      Product Name:  KVM
      Virtual:       true
  Progress:
    Current Stage:      Done
    Stage Start Time:   2021-07-30T02:59:30Z
    Stage Update Time:  2021-07-30T02:59:30Z
  Role:                 master
Events:                 <none>
~~~
</details>

### Accessing your cluster <a name="access"></a>

After enough time, your cluster should be deployed. In order to get the kubeconfig / kubeadmin password, look at the `ClusterDeployment` CR, it will contain the secret name where to find the information.
Note: the information will be populated only uppon successul deployment.

<details>
<summary>oc get ClusterDeployments -n sno-ztp</summary>

~~~
$ oc get ClusterDeployments -n sno-ztp
NAME               PLATFORM          REGION   CLUSTERTYPE   INSTALLED   INFRAID                                VERSION   POWERSTATE    AGE
sno-ztp-cluster    agent-baremetal                          true        e85bc2e6-ea53-4e0a-8e68-8922307a0159             Unsupported   59m

$ oc describe ClusterDeployments sno-ztp-cluster -n sno-ztp
Name:         sno-ztp-cluster
Namespace:    sno-ztp
Labels:       hive.openshift.io/cluster-platform=agent-baremetal
Annotations:  open-cluster-management.io/user-group: c3lzdGVtOm1hc3RlcnMsc3lzdGVtOmF1dGhlbnRpY2F0ZWQ=
              open-cluster-management.io/user-identity: c3lzdGVtOmFkbWlu
API Version:  hive.openshift.io/v1
Kind:         ClusterDeployment
Metadata:
  Creation Timestamp:  2021-07-30T02:32:25Z
  Finalizers:
    hive.openshift.io/deprovision
    clusterdeployments.agent-install.openshift.io/ai-deprovision
Spec:
  Base Domain:  rhtelco.io
  Cluster Install Ref:
    Group:    extensions.hive.openshift.io
    Kind:     AgentClusterInstall
    Name:     sno-ztp-clusteragent
    Version:  v1beta1
  Cluster Metadata:
    Admin Kubeconfig Secret Ref:
      Name:  sno-ztp-cluster-admin-kubeconfig
    Admin Password Secret Ref:
      Name:      sno-ztp-cluster-admin-password
    Cluster ID:  82f49c11-7fb0-4185-82eb-0eab243fbfd2
    Infra ID:    e85bc2e6-ea53-4e0a-8e68-8922307a0159
  Cluster Name:  lab-spoke-adetalhouet
  Control Plane Config:
    Serving Certificates:
  Installed:  true
  Platform:
    Agent Bare Metal:
      Agent Selector:
        Match Labels:
          Location:  eu/fi
  Pull Secret Ref:
    Name:  assisted-deployment-pull-secret
Status:
  Cli Image:  quay.io/openshift-release-dev/ocp-v4.0-art-dev@sha256:5917b18697edb46458d9fd39cefab191c8324561fa83da160f6fdd0b90c55fe0
  Conditions:
    Last Probe Time:          2021-07-30T03:25:00Z
    Last Transition Time:     2021-07-30T02:32:37Z
    Message:                  The installation is in progress: Finalizing cluster installation. Cluster version status: available, message: Done applying 4.8.0
    Reason:                   InstallationInProgress
    Status:                   False
    Type:                     ClusterInstallCompleted
    Last Probe Time:          2021-07-30T03:28:01Z
    Last Transition Time:     2021-07-30T03:28:01Z
    Message:                  Unsupported platform: no actuator to handle it
    Reason:                   Unsupported
    Status:                   False
    Type:                     Hibernating
    Last Probe Time:          2021-07-30T03:28:01Z
    Last Transition Time:     2021-07-30T03:28:01Z
    Message:                  ClusterSync has not yet been created
    Reason:                   MissingClusterSync
    Status:                   True
    Type:                     SyncSetFailed
    Last Probe Time:          2021-07-30T03:28:01Z
    Last Transition Time:     2021-07-30T03:28:01Z
    Message:                  Get "https://api.lab-spoke-adetalhouet.rhtelco.io:6443/api?timeout=32s": dial tcp 148.251.12.17:6443: connect: connection refused
    Reason:                   ErrorConnectingToCluster
    Status:                   True
    Type:                     Unreachable
    Last Probe Time:          2021-07-30T02:32:25Z
    Last Transition Time:     2021-07-30T02:32:25Z
    Message:                  Platform credentials passed authentication check
    Reason:                   PlatformAuthSuccess
    Status:                   False
    Type:                     AuthenticationFailure
    Last Probe Time:          2021-07-30T02:32:37Z
    Last Transition Time:     2021-07-30T02:32:37Z
    Message:                  The installation has not failed
    Reason:                   InstallationNotFailed
    Status:                   False
    Type:                     ClusterInstallFailed
    Last Probe Time:          2021-07-30T02:41:00Z
    Last Transition Time:     2021-07-30T02:41:00Z
    Message:                  The cluster requirements are met
    Reason:                   ClusterAlreadyInstalling
    Status:                   True
    Type:                     ClusterInstallRequirementsMet
    Last Probe Time:          2021-07-30T02:32:37Z
    Last Transition Time:     2021-07-30T02:32:37Z
    Message:                  The installation is waiting to start or in progress
    Reason:                   InstallationNotStopped
    Status:                   False
    Type:                     ClusterInstallStopped
    Last Probe Time:          2021-07-30T03:28:01Z
    Last Transition Time:     2021-07-30T03:28:01Z
    Message:                  Control plane certificates are present
    Reason:                   ControlPlaneCertificatesFound
    Status:                   False
    Type:                     ControlPlaneCertificateNotFound
    Last Probe Time:          2021-07-30T02:32:37Z
    Last Transition Time:     2021-07-30T02:32:37Z
    Message:                  Images required for cluster deployment installations are resolved
    Reason:                   ImagesResolved
    Status:                   False
    Type:                     InstallImagesNotResolved
    Last Probe Time:          2021-07-30T02:32:37Z
    Last Transition Time:     2021-07-30T02:32:37Z
    Message:                  InstallerImage is resolved.
    Reason:                   InstallerImageResolved
    Status:                   False
    Type:                     InstallerImageResolutionFailed
    Last Probe Time:          2021-07-30T02:32:37Z
    Last Transition Time:     2021-07-30T02:32:37Z
    Message:                  The installation has not failed
    Reason:                   InstallationNotFailed
    Status:                   False
    Type:                     ProvisionFailed
    Last Probe Time:          2021-07-30T02:32:37Z
    Last Transition Time:     2021-07-30T02:32:37Z
    Message:                  The installation is waiting to start or in progress
    Reason:                   InstallationNotStopped
    Status:                   False
    Type:                     ProvisionStopped
    Last Probe Time:          2021-07-30T02:32:25Z
    Last Transition Time:     2021-07-30T02:32:25Z
    Message:                  no ClusterRelocates match
    Reason:                   NoMatchingRelocates
    Status:                   False
    Type:                     RelocationFailed
    Last Probe Time:          2021-07-30T02:32:25Z
    Last Transition Time:     2021-07-30T02:32:25Z
    Message:                  Condition Initialized
    Reason:                   Initialized
    Status:                   Unknown
    Type:                     AWSPrivateLinkFailed
    Last Probe Time:          2021-07-30T02:32:25Z
    Last Transition Time:     2021-07-30T02:32:25Z
    Message:                  Condition Initialized
    Reason:                   Initialized
    Status:                   Unknown
    Type:                     AWSPrivateLinkReady
    Last Probe Time:          2021-07-30T02:32:25Z
    Last Transition Time:     2021-07-30T02:32:25Z
    Message:                  Condition Initialized
    Reason:                   Initialized
    Status:                   Unknown
    Type:                     ActiveAPIURLOverride
    Last Probe Time:          2021-07-30T02:32:25Z
    Last Transition Time:     2021-07-30T02:32:25Z
    Message:                  Condition Initialized
    Reason:                   Initialized
    Status:                   Unknown
    Type:                     DNSNotReady
    Last Probe Time:          2021-07-30T02:32:25Z
    Last Transition Time:     2021-07-30T02:32:25Z
    Message:                  Condition Initialized
    Reason:                   Initialized
    Status:                   Unknown
    Type:                     DeprovisionLaunchError
    Last Probe Time:          2021-07-30T02:32:25Z
    Last Transition Time:     2021-07-30T02:32:25Z
    Message:                  Condition Initialized
    Reason:                   Initialized
    Status:                   Unknown
    Type:                     IngressCertificateNotFound
    Last Probe Time:          2021-07-30T02:32:25Z
    Last Transition Time:     2021-07-30T02:32:25Z
    Message:                  Condition Initialized
    Reason:                   Initialized
    Status:                   Unknown
    Type:                     InstallLaunchError
    Last Probe Time:          2021-07-30T02:32:25Z
    Last Transition Time:     2021-07-30T02:32:25Z
    Message:                  Condition Initialized
    Reason:                   Initialized
    Status:                   Unknown
    Type:                     RequirementsMet
  Install Started Timestamp:  2021-07-30T02:41:00Z
  Install Version:            4.8.0
  Installed Timestamp:        2021-07-30T02:41:00Z
  Installer Image:            quay.io/openshift-release-dev/ocp-v4.0-art-dev@sha256:eb3e6c54c4e2e07f95a9af44a5a1839df562a843b4ac9e1d5fb5bb4df4b4f7d6
Events:                       <none>
~~~
</details>

## Some post deploy action
As I have a server with only one Interface and no console port access, I couldn't create a bridge interface for libvirt. So the poor man solution is to use iptables to forward the traffic hitting my public IP port 443 to my private VM IP.

[They are more facing way to do this.](https://wiki.libvirt.org/page/Networking#Forwarding_Incoming_Connections)

###### when the host is stopped
~~~
/sbin/iptables -D FORWARD -o virbr1 -p tcp -d 192.168.123.5 --dport 443 -j ACCEPT
/sbin/iptables -t nat -D PREROUTING -p tcp --dport 443 -j DNAT --to 192.168.123.5:443
~~~

###### when is host is up
~~~
/sbin/iptables -I FORWARD -o virbr1 -p tcp -d 192.168.123.5 --dport 443 -j ACCEPT
/sbin/iptables -t nat -I PREROUTING -p tcp --dport 443 -j DNAT --to 192.168.123.5:443
~~~

##### backup
https://www.cyberciti.biz/faq/how-to-install-kvm-on-centos-8-headless-server/

https://wiki.libvirt.org/page/Networking#Forwarding_Incoming_Connections

https://www.itix.fr/blog/deploy-openshift-single-node-in-kvm/