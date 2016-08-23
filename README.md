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

In order to support NSH without depending on Simon's patch, we
introduced new flow actions push_eth and pop_eth to support the
Ethernet as a NSH transport. The new actions append a new Ethenet
header to carry NSH frame or remove the Ethernet header from the
NSH frame. We reused Simon's code for the data path implementation
and added explicit flow actions in control plane.

Basic NSH steering test case:

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

Configure Node 1:
Step 1: Create VxLAN port
  $ovs-vsctl add-port br-int vxlan0 -- set interface vxlan0 \
   type=vxlan options:remote_ip=192.168.50.102 options:key=flow \
   options:dst_port=4789

Step 2: Add flows for Egress
   $ovs-ofctl add-flow br-int "table=0, priority=260, in_port=LOCAL \
    actions=load:0x1->NXM_NX_NSP[],load:0xFF->NXM_NX_NSI[],\
    load:1->NXM_NX_NSH_MDTYPE[],load:0x3->NXM_NX_NSH_NP[],\
    load:0x11223344->NXM_NX_NSH_C1[],load:0x55667788->NXM_NX_NSH_C2[],\
    load:0x99aabbcc->NXM_NX_NSH_C3[],load:0xddeeff00->NXM_NX_NSH_C4[],\
    push_nsh,push_eth(dst=00:11:22:33:44:55,src=66:77:88:99:aa:bb),\
    output:1"

Step 3: Add flow for Ingress
   $ovs-ofctl add-flow br-int "table=0, priority=260, in_port=1,\
    nsh_mdtype=1, nsp=0x800001, nsi=0xFF, nshc1=0xddeeff00,\
    nshc2=0x99aabbcc, nshc3=0x55667788, nshc4=0x11223344, \
    actions=pop_eth,pop_nsh,output:LOCAL"

Configure Node 2:
Step 1: Create VxLAN port
  $ovs-vsctl add-port br-int vxlan0 -- set interface vxlan0 \
   type=vxlan options:remote_ip=192.168.50.101 options:key=flow \
   options:dst_port=4789
Step 2: Add flows for Egress
   $ovs-ofctl add-flow br-int "table=0, priority=260, in_port=LOCAL \
    load:1->NXM_NX_NSH_MDTYPE[],load:0x3->NXM_NX_NSH_NP[],\
    load:0xddeeff00->NXM_NX_NSH_C1[],load:0x99aabbcc->NXM_NX_NSH_C2[],\
    load:0x55667788->NXM_NX_NSH_C3[],load:0x11223344->NXM_NX_NSH_C4[],\
    push_nsh,push_eth(dst=66:77:88:99:aa:bb,src=00:11:22:33:44:55),\
    output:1"
Step 3: Add flow for Ingress
   $ovs-ofctl add-flow br-int "table=0, priority=260, in_port=1,\
    nsh_mdtype=1, nsp=0x1, nsi=0xFF, nshc1=0x11223344,\
    nshc2=0x55667788, nshc3=0x99aabbcc, nshc4=0xddeeff00, \
    actions=pop_eth,pop_nsh,output:LOCAL"

