IETF draft at:

    https://tools.ietf.org/html/draft-ietf-sfc-nsh-01

defines a new protocol named Network Service Header (NSH) for
Service Function Chaining. The NSH format looks like below:

    +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
    |Ver|O|C|R|R|R|R|R|R|    Length   |   MD Type   |  Next Proto   |
    +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
    |                Service Path ID                | Service Index |
    +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
    |                                                               |
    ~               Mandatory/Optional Context Header               ~
    |                                                               |
    +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
  
In this patch set, we implement the NSH support for the OVS which
then can be used as Service Function Forwarder. NSH is transport
independent by design, and VxLAN-GPE and Ethernet are targeted
transports being supported by OVS initially.

The implementation for VxLAN-GPE is upstreamed by Jiri Benc at
Linux kernel tree commit <e1e5314de08ba6003b358125eafc9ad9e75a950c>

while adding VxLAN-GPE support, the Ethernet type of the VxLAN-GPE
tunneling port is set to ARPHRD_NONE, which breaks the assumption
that all frames communicated between OVS data plane and tunneling
ports should start from a Ethernet header. Hence Simon Horman
submitted a patch set to enable the raw protocol support at:

    http://openvswitch.org/pipermail/dev/2016-June/072010.html

The patch set is based on the codes from Simon's github repository at

    https://github.com/horms/linux
    
and

    https://github.com/horms/openvswitch

For doing basic function tests easily, we provice scripts to setup
the test environment under the folder scripts.

As an example, the basic NSH steering test case's topology is:

    172.168.60.101/24                      172.168.60.102/24
    +--------------+                       +--------------+
    |    br-int    |                       |    br-int    |
    +--------------+                       +--------------+
    |    vxlan0    |                       |    vxlan0    |
    +--------------+                       +--------------+
           |                                      |
           |                                      |
           |                                      |
    192.168.50.101/24                     192.168.50.102/24
    +--------------+                      +---------------+
    |    br-eth1   |                      |     br-eth1   |
    +--------------+                      +---------------+
    |    eth1      |----------------------|      eth1     |
    +--------------+                      +---------------+

    Node 1 with OVS.                       Node 2 with OVS.

script install.sh will help to download both the kernel source 
and the ovs source from Simon's github repository and apply the
related patches under the folder patches. Then build and install
both the kernel and ovs.  nodeX-ovs.sh contains the basic commands
to setup the test environment and add flow rules to the switch
instances.

For basic NSH feature tests, we can also use the following
commands to check the NSH encapsulation/decapsulation functionality.

Configure Node 1:

Step 1: Create VxLAN port

    $ovs-vsctl add-port br-int vxlan0 -- set interface vxlan0 \
    type=vxlan options:remote_ip=192.168.50.102 options:key=flow \
    dst_port=4790 options:exts=gpe

Step 2: Add flows for Egress

    $ovs-ofctl add-flow br-int "table=0, priority=260, in_port=LOCAL \
    actions=load:0x894f->NXM_OF_ETH_TYPE[],load:0x1->NXM_NX_NSP[],\
    load:0xFF->NXM_NX_NSI[],load:1->NXM_NX_NSH_MDTYPE[],\
    load:0x3->NXM_NX_NSH_NP[],load:0x11223344->NXM_NX_NSH_C1[],\
    load:0x55667788->NXM_NX_NSH_C2[],load:0x99aabbcc->NXM_NX_NSH_C3[],\
    load:0xddeeff00->NXM_NX_NSH_C4[],push_nsh,output:1"

Step 3: Add flow for Ingress

    $ovs-ofctl add-flow br-int "table=0, priority=260, in_port=1,\
    nsh, nsh_mdtype=1, nsp=0x800001, nsi=0xFF, nshc1=0xddeeff00,\
    nshc2=0x99aabbcc, nshc3=0x55667788, nshc4=0x11223344, \
    actions=pop_nsh,output:LOCAL"

Configure Node 2:

Step 1: Create VxLAN port

    $ovs-vsctl add-port br-int vxlan0 -- set interface vxlan0 \
    type=vxlan options:remote_ip=192.168.50.101 options:key=flow \
    options:dst_port=4790 options:exts=gpe

Step 2: Add flows for Egress

    $ovs-ofctl add-flow br-int "table=0, priority=260, in_port=LOCAL \
    actions=load:0x894f->NXM_OF_ETH_TYPE[],load:0x800001->NXM_NX_NSP[],\
    load:0xFF->NXM_NX_NSI[],load:1->NXM_NX_NSH_MDTYPE[],\
    load:0x3->NXM_NX_NSH_NP[], load:0xddeeff00->NXM_NX_NSH_C1[],\
    load:0x99aabbcc->NXM_NX_NSH_C2[], load:0x55667788->NXM_NX_NSH_C3[],\
    load:0x11223344->NXM_NX_NSH_C4[], push_nsh,output:1"

Step 3: Add flow for Ingress

    $ovs-ofctl add-flow br-int "table=0, priority=260, in_port=1,\
    nsh, nsh_mdtype=1, nsp=0x1, nsi=0xFF, nshc1=0x11223344,\
    nshc2=0x55667788, nshc3=0x99aabbcc, nshc4=0xddeeff00, \
    actions=pop_nsh,output:LOCAL"
    
=== Usage

1. Clone this repository to get the basic patch files and the scripts (optional).

2. get codes from Simon's github repository and apply the patches by either do
       this manually or just run the install.sh.

3. run the basic tests.
