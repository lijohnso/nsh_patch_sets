#!/bin/bash

#################### Description ##########################
#
# This is an one-command installation script to setup
# basic test environment.
# This script is only tested on Fedora system, other
# systems may need small changes for this script to meet
# the system requirements.
#
# Author: Xunleer <xunleer@outlook.com>
# Date  : Aug. 20, 2016
# ver   : Initial version
#
#########################################################

# Proxy setup

# echo "proxy=http://<proxy-ip:port>" >> /etc/yum.conf
# export http_proxy=http://<proxy-ip:port>
# export https_proxy=https://<proxy-ip:port>

# Install basic software packages
yum install -y net-tools tcpdump pciutils \
	screen expect spawn git scp gzip gzip2 \
	make automake autoconf m4 bc bison libtool \
	flex gcc gcc-c++ patch fuse fuse-devel \
	iptables-devel grub2 python-pip

pip install six

BASE_DIR=`pwd`
PATCH_DIR=${BASE_DIR}/../../patches
if [ "${WORK_DIR}" == "" ] ;then
	WORK_DIR=/opt/
fi

[ ! -d ${WORK_DIR} ] && mkdir -p ${WORK_DIR}

# Setup Basic environmental variables
echo "export PATH=\$PATH:/usr/local/bin" >> /etc/profile
export PATH=$PATH:/usr/local/bin

# Proxy configuration for git tools
# git config --global http.proxy "http://<proxy-ip:port>"
# git config --global https.proxy "https://<proxy-ip:port>"

#Clone and install Linux kernel
git clone https://github.com/horms/linux.git ${WORK_DIR}/linux
ret=$?
if [ "${ret}" == "0" ] ;then
	cd ${WORK_DIR}/linux
	git checkout l3-vpn-v11 -b verify
	patches=`cat ${BASE_DIR}/linux_patches.list`
	for patch_file in ${patches}
	do
		patch -p1 < ${PATCH_DIR}/${patch_file}
	done
	cp -f ${BASE_DIR}/config .config
	make -j4 && make modules
	make modules_install && make install

	sed -i 's/saved_entry/#saved_entry/' \
		/boot/grub2/grubenv

	boot_entry=`cat /boot/grub2/grub.cfg | grep "menuentry '" | head -1  | sed -r "s/^menuentry '(.*)' --class.*/\1/"`
	echo "saved_entry=${boot_entry}" >> /boot/grub2/grubenv
	cd ${BASE_DIR}
fi

#Clone and install openvswitch
git clone https://github.com/horms/openvswitch.git ${WORK_DIR}/openvswitch
ret=$?
if [ "${ret}" == "0" ] ;then
	cd ${WORK_DIR}/openvswitch
	git checkout l3-vpn-v12 -b verify
	patches=`cat ${BASE_DIR}/ovs_patches.list`
	for patch_file in ${patches}
	do
		patch -p1 < ${PATCH_DIR}/${patch_file}
	done
	./boot.sh
	./configure
	make -j4
	ret=$?

	if [ "${ret}" == "0" ] ;then
		make install
		cp vswitchd/ovs-vswitchd /usr/local/bin/
		cp ovsdb/ovsdb-server /usr/local/bin/

		mkdir -p /usr/local/etc/openvswitch
		mkdir -p /usr/local/var/run/openvswitch
		rm /usr/local/etc/openvswitch/conf.db
		ovsdb-tool create /usr/local/etc/openvswitch/conf.db  \
				/usr/local/share/openvswitch/vswitch.ovsschema
	fi
	cd ${BASE_DIR}
fi
