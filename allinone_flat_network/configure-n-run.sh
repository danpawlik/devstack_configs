# Part of rhis script is taken from:
# https://trickycloud.wordpress.com/2013/11/12/setting-up-a-flat-network-with-neutron/

adduser stack

apt-get install sudo -y || yum install -y sudo
echo "stack ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

sudo apt-get install git -y || sudo yum install -y git
su - stack
git clone https://git.openstack.org/openstack-dev/devstack -b stable/liberty

git clone https://github.com/dduuch/devstack_configs

cp devstack_configs//allinone_flat_network/local.conf devstack/

cd devstack

ln -s local.conf localrc


################## SET NETWORK #########################

cat > /etc/network/interfaces

cat > /etc/network/interfaces << EOF 

# The loopback network interface
auto lo
iface lo inet loopback

# The primary network interface - public address IP
auto eth0
iface eth0 inet dhcp

# Local network interface - network address 10.0.0.0/24
auto eth1
iface eth1 inet manual
    up ifconfig $IFACE 0.0.0.0 up
    up ip link set $IFACE promisc on
    down ip link set $IFACE promisc off
    down ifconfig $IFACE down

auto br-eth1
iface br-eth1 inet static
    address 10.0.0.2
    netmask 255.255.255.0
    up ip link set $IFACE promisc on
    down ip link set $IFACE promisc off

EOF

service networking restart


script /dev/null
screen ./stack.sh


sudo ovs-vsctl add-br br-eth1
sudo ovs-vsctl add-port br-eth1 eth1


# get admin credentials. If you don't want to create extra file, you can
# replace demo user to admin user and read openrc file.

sed -i -e "s/demo/admin/g" openrc
source openrc


### ADD into [OVS] section values: ####

vim /etc/neutron/plugins/ml2/ml2_conf.ini

[ovs]
network_vlan_ranges = physnet1
bridge_mappings = physnet1:br-eth1


# add into /etc/nova/nova.conf : ###

echo "service_neutron_metadata_proxy=false" >> /etc/nova/nova.conf


neutron net-create flat-provider-network --shared  --provider:network_type flat --provider:physical_network physnet1

neutron subnet-create --name flat-provider-subnet --gateway 10.0.0.1 --dns-nameserver 8.8.8.8  --allocation-pool start=10.0.0.100,end=10.0.0.150  flat-provider-network 10.0.0.0/24

./unstack.sh

./rejoin-stack.sh

neutron net-list

## If you see this message:

No handlers could be found for logger "keystoneclient.auth.identity.generic.base"
ERROR (ConnectionRefused): Unable to establish connection to http://92.222.XXX.XXX:5000/v2.0/tokens

# probably keystone service is down. Type this:
screen /usr/local/bin/keystone-all


# If you have problem like this:
##+ kill_spinner
##+ '[' '!' -z '' ']'
##+ [[ 1 -ne 0 ]]
##+ echo 'Error on exit'
##Error on exit
##+ [[ -z '' ]]
##+ ./tools/worlddump.py
##World dumping... see ./worlddump-.... for details
##

# to this:

#./clean.sh
#sudo rm -rf /opt/stack
#shutdown -r now 

# after reboot, try again ./stack.sh ;)



nova boot --flavor m1.small --image cirros-0.3.4-x86_64-uec --nic net-id=`neutron net-list | grep flat-provider-network | awk '{print $2}'` Flat-instance-test

# Now when you sign in into instance Flat-instance-test for example: 

nova get-vnc-console Flat-instance-test novnc

# You should ping to another host in local network.
