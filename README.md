# NetQ 1.0 Demo

This demo will install Cumulus Linux [NetQ](https://docs.cumulusnetworks.com/display/DOCS/Using+netq+to+Troubleshoot+the+Network) Fabric Validation System using the Cumulus [reference topology](https://github.com/cumulusnetworks/cldemo-vagrant). Please vist the reference topology github page for detailed instructions on using Cumulus Vx with Vagrant.

![Cumulus Reference Topology](https://github.com/CumulusNetworks/cldemo-vagrant/raw/master/cldemo_topology.png)

Quickstart
------------------------
* git clone https://github.com/cumulusnetworks/cldemo-netq-1.0 cldemo-netq
* cd cldemo-netq
* vagrant up
* vagrant ssh oob-mgmt-server
* sudo su - cumulus
* cd cldemo-netq
* ansible-playbook -s RUNME.yml
* ssh leaf01
* netq
* netq check bgp
* netq trace l3 10.1.20.1 from 10.3.20.3
* ip route | netq resolve | less -R

Details
------------------------

This demo will configure a layer 3 BGP network as well as the netq agent and server components. The demo is downloaded onto the `oob-mgmt-server` under the `cumulus` user. It assumes the network is up and running (via `vagrant up`) but it **has not** yet been configured. The playbook `RUNME.yml` will configure BGP on all spine and leafs, clag on all the ToR switches, bonds on the servers, as well as install the necessary netq components. Once the netq demo has been configured with `RUNME.yml` you can log into any node in the network to interact with the netq service or use netq directly from the oob-mgmt-server itself. Use the `netq` command to interact with the netq agent.

cumulus@oob-mgmt-server:~/cldemo-netq-l3$ ssh leaf01

    Welcome to Cumulus VX (TM)

    Cumulus VX (TM) is a community supported virtual appliance designed for
    experiencing, testing and prototyping Cumulus Networks' latest technology.
    For any questions or technical support, visit our community site at:
    http://community.cumulusnetworks.com
    
    The registered trademark Linux (R) is used pursuant to a sublicense from LMI,
    the exclusive licensee of Linus Torvalds, owner of the mark on a world-wide
    basis.
    Last login: Sun Nov 20 10:15:25 2016 from 192.168.0.254
    
    cumulus@leaf01:~$ netq
    Node Name    Connect Time         Last Connect    Status
    -----------  -------------------  --------------  --------
    leaf01       2016-11-20 17:54:02  24 seconds ago  Fresh
    leaf02       2016-11-20 17:54:02  23 seconds ago  Fresh
    leaf03       2016-11-20 17:54:02  24 seconds ago  Fresh
    leaf04       2016-11-20 17:54:02  24 seconds ago  Fresh
    spine01      2016-11-20 17:54:02  24 seconds ago  Fresh
    spine02      2016-11-20 17:54:02  22 seconds ago  Fresh```


Hitting TAB after typing 'netq' will show you commands available along with help text.

    cumulus@leaf01:~$ netq
        add      :  Update configuration
        agent    :  Netq agent
        check    :  check health of services or correctness of parameter
        help     :  Show usage info
        resolve  :  Annotate input with names and interesting info
        server   :  IP address of DB server
        show     :  Show fabric-wide info
        trace    :  Control plane trace path across fabric
        view     :  Show output of pre-defined commands on specific node```

Some useful examples to get you going
    netq check bgp
    netq check vlan
    netq trace l3 10.1.20.1 from 10.3.20.3
    netq show ip routes 10.1.20.1 origin
    netq show macs leaf01
    netq show changes between 1s and 2m
    ip route | netq resolve | less -R

Resetting The Topology
------------------------
If a previous configuration was applied to the reference topology, it can be reset with the `reset.yml` playbook provided. This can be run before configuring netq to ensure a clean starting state.

    ansible-playbook -s reset.yml
