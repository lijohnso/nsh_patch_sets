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
	
	#ovs-vsctl add-port br-int vxlan0 -- set interface vxlan0 type=vxlan \
	#                 options:dst_port=4789 options:remote_ip=192.168.50.102 \
	#                 options:key=1000

	#ovs-vsctl add-port br-int vxlan0 -- set interface vxlan0 type=vxlan \
	#                 options:dst_port=4790 options:remote_ip=192.168.50.102 \
	#                 options:key=1000 options:exts=gpe

	#ovs-vsctl add-port br-int gre0 -- set interface gre0 type=gre \
	#                 options:remote_ip=192.168.50.102 options:layer3=true

	ip addr add 172.168.60.101/24 dev br-int

	ovs-vsctl del-br br-phy
	ovs-vsctl add-br br-phy
	ovs-vsctl add-port br-phy eth0
	ip link set eth0 down
	ip addr del 192.168.50.101/24 dev eth0
	ip link set br-phy up
	ip link set eth0 up
	ip addr add 192.168.50.101/24 dev br-phy

	#ovs-ofctl add-flow br-int "table=0, priority=260, in_port=1 actions=mod_dl_src:66:11:85:9e:e4:41,output:LOCAL"
	#ovs-ofctl add-flow br-int "table=0, priority=260, in_port=1 actions=output:LOCAL"
	#ovs-ofctl add-flow br-int "table=0, priority=260, in_port=LOCAL actions=output:1"

	#ovs-ofctl add-flow br-int "table=0, priority=260, in_port=1 actions=pop_nsh,output:LOCAL"
	#ovs-ofctl add-flow br-int "table=0, priority=260, in_port=LOCAL actions=push_nsh,output:1"

	#ovs-ofctl add-flow br-phy "table=0, priority=260, in_port=LOCAL actions=pop_eth,output:1"

	# Generic VxLAN-GPE
	#ovs-ofctl add-flow br-int "table=0, priority=260, in_port=1,tun_gpe_np=3 actions=output:LOCAL"
	#ovs-ofctl add-flow br-int "table=0, priority=260, in_port=LOCAL actions=load:0x3->NXM_NX_TUN_GPE_NP[],output:1"

	#ovs-ofctl add-flow br-int "table=0, priority=260, in_port=1,tun_gpe_np=3 actions=pop_nsh,output:LOCAL"
	#ovs-ofctl add-flow br-int "table=0, priority=260, in_port=LOCAL actions=push_nsh,load:0x3->NXM_NX_TUN_GPE_NP[],output:1"

	# VxLAN-GPE + NSH
	#ovs-ofctl add-flow br-int "table=0, priority=260, in_port=1, nsh_mdtype=1, nsp=0x800001, nsi=0xFF,  actions=pop_nsh,output:LOCAL"
	#ovs-ofctl add-flow br-int "table=0, priority=260, in_port=LOCAL actions=load:0x1->NXM_NX_NSP[],load:0xFF->NXM_NX_NSI[], load:1->NXM_NX_NSH_MDTYPE[],load:0x3->NXM_NX_NSH_NP[], load:0x11223344->NXM_NX_NSH_C1[],load:0x55667788->NXM_NX_NSH_C2[], load:0x99aabbcc->NXM_NX_NSH_C3[],load:0xddeeff00->NXM_NX_NSH_C4[],push_nsh,output:1"

	#ovs-ofctl add-flow br-int "table=0, priority=260, in_port=1, nsh_mdtype=1, nsp=0x800001, nsi=0xFF,  actions=pop_nsh,output:LOCAL"
	#ovs-ofctl add-flow br-int "table=0, priority=260, in_port=LOCAL actions=load:0x1->NXM_NX_NSP[],load:0xFF->NXM_NX_NSI[], load:1->NXM_NX_NSH_MDTYPE[],load:0x3->NXM_NX_NSH_NP[], load:0x11223344->NXM_NX_NSH_C1[],load:0x55667788->NXM_NX_NSH_C2[], load:0x99aabbcc->NXM_NX_NSH_C3[],load:0xddeeff00->NXM_NX_NSH_C4[],output:1"

	#MD type 1
	#ovs-ofctl add-flow br-int "table=0, priority=260, in_port=1, nsh_mdtype=2, nsp=0x800001, nsi=0xFF,  actions=pop_nsh,output:LOCAL"
	#ovs-ofctl add-flow br-int "table=0, priority=260, in_port=LOCAL actions=load:0x1->NXM_NX_NSP[],load:0xFF->NXM_NX_NSI[], load:1->NXM_NX_NSH_MDTYPE[],load:0x3->NXM_NX_NSH_NP[], load:0x11223344->NXM_NX_NSH_C1[],load:0x55667788->NXM_NX_NSH_C2[], load:0x99aabbcc->NXM_NX_NSH_C3[],load:0xddeeff00->NXM_NX_NSH_C4[],push_nsh,output:1"

	ovs-appctl ovs/route/add 192.168.50.102/24 br-phy
}

function stop_ovs() {
	local pid_vswitchd=`pidof ovs-vswitchd`
	local pid_ovsdb=`pidof ovsdb-server`

	if [  "${pid_vswitchd}" != "" -a "${pid_ovsdb}" != "" ] ;then
		local ovs_bridges=`ovs-vsctl show | grep "Bridge" | awk '{ print $2}'`

		for bridge in ${ovs_bridges}
		do
			local ports=`ovs-ofctl show ${bridge} | grep "addr"  | sed -r 's/.*\((.*)\).*/\1/'`
			for port in ${ports}
			do
				if [ "${port}" != "${bridge}" ] ;then
					ovs-vsctl del-port ${bridge} ${port}
				fi
			done
			ovs-vsctl del-br ${bridge}
		done
	fi

	[ "${pid_vswitchd}" != "" ] && kill -9 ${pid_vswitchd}
	[ "${pid_ovsdb}" != "" ] && kill -9 ${pid_ovsdb}
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
