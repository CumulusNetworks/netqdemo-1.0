# NetQ 1.0 Demo

This demo will install Cumulus Linux [NetQ](https://docs.cumulusnetworks.com/display/DOCS/Using+netq+to+Troubleshoot+the+Network) Fabric Validation System using the Cumulus [reference topology](https://github.com/cumulusnetworks/cldemo-vagrant). Please vist the reference topology github page for detailed instructions on using Cumulus Vx with Vagrant.

![Cumulus Reference Topology](https://github.com/CumulusNetworks/cldemo-vagrant/raw/master/cldemo_topology.png)

Quickstart
------------------------
* Download the NetQ Telemetry Server from https://cumulusnetworks.com/downloads/#product=NetQ%20Virtual&version=1.0. You need to be logged in to the site to access this.
* Pick the Vagrant hypervisor. This assumes the Virtualbox hypervisor. See note on libvirt below.
* Add the downloaded box to vagrant via: vagrant box add cumulus-netq-telemetry-server-amd64-1.0.0-vagrant.box --name=cumulus/ts
* The Telemetry Server will be the oob-mgmt-server in the picture.
* If you do not have the telemetry sever already installed, vagrant will refuse to spin up
* git clone https://github.com/cumulusnetworks/netqdemo-1.0 netqdemo
* cd netqdemo
* vagrant up
* vagrant ssh oob-mgmt-server
* sudo su - cumulus
* cd netqdemo
* ansible-playbook -s RUNME.yml
* Log out and log back in to enable command completion for netq.
* netq help
* netq check bgp
* netq trace l3 10.1.20.1 from 10.3.20.3
* ip route | netq resolve | less -R

Details
------------------------

This demo will:
* configure the customer reference topology with BGP unnumbered
* configure CLAG on the leaves for the servers to be dual-attached and bonded. 
* install NetQ on all nodes including servers and routers 
* configure NetQ agents to start pushing data to the telemetry server

The servers are assumed to be Ubuntu 16.04 hosts, and the version of Cumulus VX is at least 3.3.0. The hypervisor used is assumed to be Virtualbox by default. If you want to use the libvirt version, copy Vagrantfile-kvm to Vagrantfile.

When the playbook RUNME.yml is run, it assumes the network is up and running (via `vagrant up`) but it **has not** yet been configured. If the network has been configured already, run the reset.yml playbook to reset the configuration state of the network. Once the netq demo has been configured with `RUNME.yml` you can either log into any node in the network or use the oob-mgmt-server directly to interact with the netq service. Use the `netq` command to interact with the NetQ system.

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

Libvirt Vagrant Box
-------------------
The NetQ Telemetry Server isn't officially supported on KVM. However, I personally use it all the time. Install the vagrant mutate plugin and run `vagrant mutate cumulus/ts libvirt` to get the libvirt version.

Caveats
-------
If a node is deemed unreachable during the playbook run, and this happens if the servers haven't finished rebooting after setup, ensure the node is reachable via `ansible <nodename> -m ping` and just rerun the netq playbook again for that node via `ansible-playbook -s --limit <nodename>  netq.yml` where <nodename> in each case is replaced by the node in question. For servers, for example, you can run `ansible-playbook -s --limit 'server*' netq.yml`.
