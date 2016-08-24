#!/bin/bash

export PATH=$PATH:/usr/local/bin

modprobe openvswitch

function start_ovs() {
	ovsdb-server --remote=punix:/usr/local/var/run/openvswitch/db.sock \
	                 --remote=db:Open_vSwitch,Open_vSwitch,manager_options \
	                 --private-key=db:Open_vSwitch,SSL,private_key \
	                 --certificate=db:Open_vSwitch,SSL,certificate \
	                 --bootstrap-ca-cert=db:Open_vSwitch,SSL,ca_cert \
	                 --pidfile --detach
	
	ovs-vswitchd --pidfile --detach --log-file=/var/log/ovs/ovs-vswitchd.log
	
	ovs-vsctl del-br br-int
	ovs-vsctl add-br br-int
	ip link set br-int up

	#VxLAN
	#ovs-vsctl add-port br-int vxlan0 -- set interface vxlan0 type=vxlan \
	#                 options:dst_port=4789 options:remote_ip=192.168.50.101 \
	#                 options:key=1000

	#VxLAN-GBP
	#ovs-vsctl add-port br-int vxlan0 -- set interface vxlan0 type=vxlan \
	#                 options:dst_port=4790 options:remote_ip=192.168.60.21 \
	#                 options:key=1000 options:exts=gbp

	#VxLAN-GPE [+ NSH]
	#ovs-vsctl add-port br-int vxlan0 -- set interface vxlan0 type=vxlan \
	#                 options:dst_port=4790 options:remote_ip=192.168.50.101 \
	#                 options:key=1000 options:exts=gpe

	#L3-VPN
	#ovs-vsctl add-port br-int gre0 -- set interface gre0 type=gre \
	#		options:remote_ip=192.168.50.101 options:layer3=true

	#Geneve
	#ovs-vsctl add-port br-int geneve0 -- set interface geneve0 type=geneve \
	#                 options:remote_ip=192.168.50.101 \
	#                 options:key=1000

	ip addr add 172.168.60.102/24 dev br-int
	ip link set dev br-int mtu 1400
	
	ovs-vsctl del-br br-phy
	ovs-vsctl add-br br-phy
	ovs-vsctl add-port br-phy eth0
	ip link set eth0 down
	ip addr del 192.168.50.102/24 dev eth0
	ip link set br-phy up
	ip link set eth0 up
	ip addr add 192.168.50.102/24 dev br-phy
	
	#ovs-ofctl add-flow br-int "table=0, priority=260, in_port=1 actions=output:LOCAL"
	#ovs-ofctl add-flow br-int "table=0, priority=260, in_port=LOCAL actions=output:1"

	#ovs-ofctl add-flow br-int "table=0, priority=260, in_port=1,actions=pop_nsh,output:LOCAL"
	#ovs-ofctl add-flow br-int "table=0, priority=260, in_port=LOCAL actions=push_nsh:0x1,output:1"

	#ovs-ofctl add-flow br-int "table=0, priority=260, in_port=1,tun_gbp_id=0x100,actions=output:LOCAL"
	#ovs-ofctl add-flow br-int "table=0, priority=260, in_port=LOCAL actions=load:0x100->NXM_NX_TUN_GBP_ID[],output:1"

	#ovs-ofctl -Oopenflow13 add-flow br-int "table=0, priority=260, nsh, nsh_mdtype=1, nsp=0x1, nsi=0xFF actions=pop_nsh,output:LOCAL"
	#ovs-ofctl -Oopenflow13 add-flow br-int "table=0, priority=260, in_port=LOCAL actions=LOAD:0x894f->NXM_OF_ETH_TYPE[],load:0x800001->NXM_NX_NSP[],load:0xFF->NXM_NX_NSI[], load:1->NXM_NX_NSH_MDTYPE[],load:0x3->NXM_NX_NSH_NP[], load:0x11223344->NXM_NX_NSH_C4[],load:0x55667788->NXM_NX_NSH_C3[], load:0x99aabbcc->NXM_NX_NSH_C2[],load:0xddeeff00->NXM_NX_NSH_C1[],  push_nsh,output:1"

	#ovs-ofctl -Oopenflow13 add-flow br-int "table=0, priority=260, nsh_mdtype=1, nsp=0x1, nsi=0xFF actions=pop_nsh, goto_table:1"
	#ovs-ofctl -Oopenflow13 add-flow br-int "table=1, priority=260, ip, nw_dst=172.168.60.102 actions=output:local"
	#ovs-ofctl -Oopenflow13 add-flow br-int "table=1, priority=260, arp, arp_tpa=172.168.60.102 actions=output:local"
	#ovs-ofctl -Oopenflow13 add-flow br-int "table=0, priority=260, in_port=LOCAL actions=load:0x800001->NXM_NX_NSP[],load:0xFF->NXM_NX_NSI[], load:1->NXM_NX_NSH_MDTYPE[],load:0x3->NXM_NX_NSH_NP[], load:0x11223344->NXM_NX_NSH_C4[],load:0x55667788->NXM_NX_NSH_C3[], load:0x99aabbcc->NXM_NX_NSH_C2[],load:0xddeeff00->NXM_NX_NSH_C1[],push_nsh,output:1"
	#ovs-ofctl add-flow br-int "table=0, priority=260, in_port=LOCAL actions=set_vlan_vid:199,output:IN_PORT"

	#ovs-ofctl add-flow br-int "table=0, priority=260, in_port=1,tun_gpe_np=3,actions=output:LOCAL"
	#ovs-ofctl add-flow br-int "table=0, priority=260, in_port=LOCAL actions=load:0x3->NXM_NX_TUN_GPE_NP[],output:1"

	#MD type 2
	#ovs-ofctl add-tlv-map br-int "{class=0xffff,type=0,len=4}->tun_metadata0,{class=0xffff,type=1,len=8}->tun_metadata1"
	#ovs-ofctl add-flow br-int "table=0, priority=260, in_port=1, actions=pop_nsh,output:LOCAL"
	#ovs-ofctl add-flow br-int "table=0, priority=260, nsh_mdtype=2, nsp=0x1, nsi=0xFF, tun_metadata0=0x44332211, tun_metadata1=0xccbbaa9988776655 actions=pop_nsh,output:LOCAL"
	#ovs-ofctl add-flow br-int "table=0, priority=260, in_port=LOCAL actions=load:0x800001->NXM_NX_NSP[],load:0xFF->NXM_NX_NSI[], load:2->NXM_NX_NSH_MDTYPE[],load:0x3->NXM_NX_NSH_NP[], load:0x11223344->NXM_NX_TUN_METADATA0[],load:0x5566778899aabbcc->NXM_NX_TUN_METADATA1[],push_nsh,output:1"

	ovs-appctl ovs/route/add 192.168.50.101/24 br-phy
}

function stop_ovs() {
	ovs-vsctl del-br br-phy
	ovs-vsctl del-br br-int

	pidof ovs-vswitchd | xargs kill -9
	pidof ovsdb-server | xargs kill -9
}

function check_status() {
	local pid_dbserver=`pidof ovsdb-server`
	local pid_vswitchd=`pidof ovs-vswitchd`

	if [ "${pid_dbserver}" != "" -a "${pid_vswitchd}" != "" ] ;then
		echo -e "Open Virtaul Switch status: \e[32mRunning\e[0m"
	elif [ "${pid_dbserver}" == "" -a "${pid_vswitchd}" == "" ] ;then
		echo -e "Open Virtaul Switch status: \e[33mStopped\e[0m"
	else
		echo -e "Open Virtaul Switch status: \e[31mCrashed\e[0m"
	fi
}

###################### MAIN ######################
case $1 in
start)
	start_ovs
	;;
stop)
	stop_ovs
	;;
status)
	check_status
	;;
restart)
	stop_ovs
	sleep 5
	start_ovs
	;;
*)
	echo "Usage: $0 [start|stop|restart|status]"
	exit 1
	;;
esac

exit 0
