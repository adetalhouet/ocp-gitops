
To create a bridge network

~~~
$ cat /etc/sysconfig/network-scripts/ifcfg-br0
STP=no
TYPE=Bridge
PROXY_METHOD=none
BROWSER_ONLY=no
BOOTPROTO=none
DEFROUTE=yes
IPV4_FAILURE_FATAL=no
IPV6INIT=no
IPV6_DEFROUTE=yes
IPV6_FAILURE_FATAL=no
IPV6_ADDR_GEN_MODE=stable-privacy
NAME=br0
DEVICE=br0
ONBOOT=yes
IPADDR=148.251.12.17
PREFIX=32
GATEWAY=148.251.12.1
IPV6_DISABLED=yes
DOMAIN=lab.adetalhouet
~~~

~~~
$ cat /etc/sysconfig/network-scripts/ifcfg-bridge-slave-enp4s0
DEVICE=enp4s0
ONBOOT=yes
BOOTPROTO=none
IPADDR=148.251.12.17
PREFIX=32
GATEWAY=148.251.12.1
DEFROUTE=yes
~~~