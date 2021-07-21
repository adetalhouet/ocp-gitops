#### Configure libvirt
dnf install -y bind-utils libguestfs-tools cloud-init
dnf module install virt -y
dnf install virt-install -y
systemctl enable libvirtd --now

#### Configure Sushi service
dnf install python3 -y
pip3 install sushy-tools
echo '[Unit]
Description=Sushy Libvirt emulator
After=syslog.target

[Service]
Type=simple
ExecStart=/usr/local/bin/sushy-emulator --interface 0.0.0.0 --port 8000 --libvirt-uri "qemu:///system"
StandardOutput=syslog
StandardError=syslog' > /usr/lib/systemd/system/sushy.service

systemctl start sushy

systemctl start firewalld
firewall-cmd --add-port=8000/tcp

#### TBD Add Bridge
ip link add br0 type bridge
ip link show type bridge

nmcli connection add type bridge autoconnect yes con-name br1 ifname br1
nmcli connection modify br1 ipv4.addresses 192.168.225.53/24 ipv4.method manual
nmcli connection modify br1 ipv4.gateway 192.168.225.1
nmcli connection modify br1 ipv4.dns 192.168.225.1
nmcli connection add type bridge-slave autoconnect yes con-name enp0s8 ifname enp0s8 master br1

#### TBD Configure DNS
echo 'address=/#/213.133.98.98
server=/podman.lab.adetalhouet/10.88.0.1
server=/libvirt.lab.adetalhouet/192.168.122.1
host-record=host.lab.adetalhouet,192.168.122.1' > /etc/NetworkManager/dnsmasq.d/podman-libvirt-dns.conf

#### KVM playground

sudo virsh net-define net.xml
sudo virsh net-start ocp
sudo virsh net-autostart ocp

wget https://cloud.centos.org/centos/8/x86_64/images/CentOS-8-GenericCloud-8.4.2105-20210603.0.x86_64.qcow2

qemu-img create -f qcow2 -b /var/lib/libvirt/images/rhcos-4.8.0-fc.9-x86_64-qemu.x86_64.qcow2 /var/lib/libvirt/images/sno.qcow2 200

virt-install \
--name sno \
--memory 32768 \
--vcpus 16 \
--cpu host \
--network network=ocp \
--disk /tmp/sno/sno.qcow2,format=qcow2,size=150,bus=virtio \
--disk /tmp/sno/sno-ai-discovery.iso,device=cdrom \
--os-variant=fedora-coreos-stable \
--noautoconsole \
--print-xml > vm.xml

--disk /tmp/sno/cidata.iso,device=cdrom \


###### hack fwd traffic to cluster
podman run --name 443-proxy -p 443:443 -d nginx

###### when the host is stopped
/sbin/iptables -D FORWARD -o virbr1 -p tcp -d 192.168.123.5 --dport 443 -j ACCEPT
/sbin/iptables -t nat -D PREROUTING -p tcp --dport 443 -j DNAT --to 192.168.123.5:443

###### when is host is up
/sbin/iptables -I FORWARD -o virbr1 -p tcp -d 192.168.123.5 --dport 443 -j ACCEPT
/sbin/iptables -t nat -I PREROUTING -p tcp --dport 443 -j DNAT --to 192.168.123.5:443

##### backup
https://www.cyberciti.biz/faq/how-to-install-kvm-on-centos-8-headless-server/

https://wiki.libvirt.org/page/Networking#Forwarding_Incoming_Connections