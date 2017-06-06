# Created by Topology-Converter v4.5.0
#    https://github.com/cumulusnetworks/topology_converter
#    using topology data from: topology_kvm.dot
#
#    NOTE: in order to use this Vagrantfile you will need:
#       -Vagrant(v1.8.1+) installed: http://www.vagrantup.com/downloads
#       -Cumulus Plugin for Vagrant installed: $ vagrant plugin install vagrant-cumulus
#       -the "helper_scripts" directory that comes packaged with topology-converter.py
#        -Libvirt Installed -- guide to come
#       -Vagrant-Libvirt Plugin installed: $ vagrant plugin install vagrant-libvirt
#       -Boxes which have been mutated to support Libvirt -- see guide below:
#            https://community.cumulusnetworks.com/cumulus/topics/converting-cumulus-vx-virtualbox-vagrant-box-gt-libvirt-vagrant-box
#       -Start with \"vagrant up --provider=libvirt --no-parallel\n")

#Set the default provider to libvirt in the case they forget --provider=libvirt or if someone destroys a machine it reverts to virtualbox
ENV['VAGRANT_DEFAULT_PROVIDER'] = 'libvirt'

# Check required plugins
REQUIRED_PLUGINS_LIBVIRT = %w(vagrant-libvirt vagrant-mutate)
exit unless REQUIRED_PLUGINS_LIBVIRT.all? do |plugin|
  Vagrant.has_plugin?(plugin) || (
    puts "The #{plugin} plugin is required. Please install it with:"
    puts "$ vagrant plugin install #{plugin}"
    false
  )
end

# Check required plugins
REQUIRED_PLUGINS = %w(vagrant-cumulus)
exit unless REQUIRED_PLUGINS.all? do |plugin|
  Vagrant.has_plugin?(plugin) || (
    puts "The #{plugin} plugin is required. Please install it with:"
    puts "$ vagrant plugin install #{plugin}"
    false
  )
end

$script = <<-SCRIPT
if grep -q -i 'cumulus' /etc/lsb-release &> /dev/null; then
    echo "### RUNNING CUMULUS EXTRA CONFIG ###"
    source /etc/lsb-release
    if [[ $DISTRIB_RELEASE =~ ^2.* ]]; then
        echo "  INFO: Detected a 2.5.x Based Release"
        echo "  adding fake cl-acltool..."
        echo -e "#!/bin/bash\nexit 0" > /bin/cl-acltool
        chmod 755 /bin/cl-acltool

        echo "  adding fake cl-license..."
        cat > /bin/cl-license <<'EOF'
#! /bin/bash
#-------------------------------------------------------------------------------
#
# Copyright 2013 Cumulus Networks, Inc.  All rights reserved
#

URL_RE='^http://.*/.*'

#Legacy symlink
if echo "$0" | grep -q "cl-license-install$"; then
    exec cl-license -i $*
fi

LIC_DIR="/etc/cumulus"
PERSIST_LIC_DIR="/mnt/persist/etc/cumulus"

#Print current license, if any.
if [ -z "$1" ]; then
    if [ ! -f "$LIC_DIR/.license.txt" ]; then
        echo "No license installed!" >&2
        exit 20
    fi
    cat "$LIC_DIR/.license.txt"
    exit 0
fi

#Must be root beyond this point
if (( EUID != 0 )); then
   echo "You must have root privileges to run this command." 1>&2
   exit 100
fi

#Delete license
if [ x"$1" == "x-d" ]; then
    rm -f "$LIC_DIR/.license.txt"
    rm -f "$PERSIST_LIC_DIR/.license.txt"

    echo License file uninstalled.
    exit 0
fi

function usage {
    echo "Usage: $0 (-i (license_file | URL) | -d)" >&2
    echo "    -i  Install a license, via stdin, file, or URL." >&2
    echo "    -d  Delete the current installed license." >&2
    echo >&2
    echo " cl-license prints, installs or deletes a license on this switch." >&2
}

if [ x"$1" != 'x-i' ]; then
    usage
    exit 100
fi
shift
if [ ! -f "$1" ]; then
    if [ -n "$1" ]; then
        if ! echo "$1" | grep -q "$URL_RE"; then
            usage
            echo "file $1 not found or not readable." >&2
            exit 100
        fi
    fi
fi

function clean_tmp {
    rm $1
}

if [ -z "$1" ]; then
    LIC_FILE=`mktemp lic.XXXXXX`
    trap "clean_tmp $LIC_FILE" EXIT
    echo "Paste license text here, then hit ctrl-d" >&2
    cat >$LIC_FILE
else
    if echo "$1" | grep -q "$URL_RE"; then
        LIC_FILE=`mktemp lic.XXXXXX`
        trap "clean_tmp $LIC_FILE" EXIT
        if ! wget "$1" -O $LIC_FILE; then
            echo "Couldn't download $1 via HTTP!" >&2
            exit 10
        fi
    else
        LIC_FILE="$1"
    fi
fi

/usr/sbin/switchd -lic "$LIC_FILE"
SWITCHD_RETCODE=$?
if [ $SWITCHD_RETCODE -eq 99 ]; then
    more /usr/share/cumulus/EULA.txt
    echo "I (on behalf of the entity who will be using the software) accept"
    read -p "and agree to the EULA  (yes/no): "
    if [ "$REPLY" != "yes" -a "$REPLY" != "y" ]; then
        echo EULA not agreed to, aborting. >&2
        exit 2
    fi
elif [ $SWITCHD_RETCODE -ne 0 ]; then
    echo '******************************' >&2
    echo ERROR: License file not valid. >&2
    echo ERROR: No license installed. >&2
    echo '******************************' >&2
    exit 1
fi

mkdir -p "$LIC_DIR"
cp "$LIC_FILE" "$LIC_DIR/.license.txt"
chmod 644 "$LIC_DIR/.license.txt"

mkdir -p "$PERSIST_LIC_DIR"
cp "$LIC_FILE" "$PERSIST_LIC_DIR/.license.txt"
chmod 644 "$PERSIST_LIC_DIR/.license.txt"

echo License file installed.
echo Reboot to enable functionality.
EOF
        chmod 755 /bin/cl-license

        echo "  Disabling default remap on Cumulus VX..."
        mv -v /etc/init.d/rename_eth_swp /etc/init.d/rename_eth_swp.backup

        echo "  Replacing fake switchd"
        rm -rf /usr/bin/switchd
        cat > /usr/sbin/switchd <<'EOF'
#!/bin/bash
PIDFILE=$1
LICENSE_FILE=/etc/cumulus/.license
RC=0

# Make sure we weren't invoked with "-lic"
if [ "$PIDFILE" == "-lic" ]; then
  if [ "$2" != "" ]; then
        LICENSE_FILE=$2
  fi
  if [ ! -e $LICENSE_FILE ]; then
    echo "No license file." >&2
    RC=1
  fi
  RC=0
else
  tail -f /dev/null & CPID=$!
  echo -n $CPID > $PIDFILE
  wait $CPID
fi

exit $RC
EOF
        chmod 755 /usr/sbin/switchd

        cat > /etc/init.d/switchd <<'EOF'
#! /bin/bash
### BEGIN INIT INFO
# Provides:          switchd
# Required-Start:
# Required-Stop:
# Should-Start:
# Should-Stop:
# X-Start-Before
# Default-Start:     S
# Default-Stop:
# Short-Description: Controls fake switchd process
### END INIT INFO

# Author: Kristian Van Der Vliet <kristian@cumulusnetworks.com>
#
# Please remove the "Author" lines above and replace them
# with your own name if you copy and modify this script.

PATH=/sbin:/bin:/usr/bin

NAME=switchd
SCRIPTNAME=/etc/init.d/$NAME
PIDFILE=/var/run/switchd.pid

. /lib/init/vars.sh
. /lib/lsb/init-functions

do_start() {
  echo "[ ok ] Starting Cumulus Networks switch chip daemon: switchd"
  /usr/sbin/switchd $PIDFILE 2>/dev/null &
}

do_stop() {
  if [ -e $PIDFILE ];then
    kill -TERM $(cat $PIDFILE)
    rm $PIDFILE
  fi
}

do_status() {
  if [ -e $PIDFILE ];then
    echo "[ ok ] switchd is running."
  else
    echo "[FAIL] switchd is not running ... failed!" >&2
    exit 3
  fi
}

case "$1" in
  start|"")
	log_action_begin_msg "Starting switchd"
	do_start
	log_action_end_msg 0
	;;
  stop)
  log_action_begin_msg "Stopping switchd"
  do_stop
  log_action_end_msg 0
  ;;
  status)
  do_status
  ;;
  restart)
	log_action_begin_msg "Re-starting switchd"
  do_stop
	do_start
	log_action_end_msg 0
	;;
  reload|force-reload)
	echo "Error: argument '$1' not supported" >&2
	exit 3
	;;
  *)
	echo "Usage: $SCRIPTNAME [start|stop|restart|status]" >&2
	exit 3
	;;
esac

:
EOF
        chmod 755 /etc/init.d/switchd
        reboot

    elif [[ $DISTRIB_RELEASE =~ ^3.* ]]; then
        echo "  INFO: Detected a 3.x Based Release"
        echo "  Disabling default remap on Cumulus VX..."
        mv -v /etc/hw_init.d/S10rename_eth_swp.sh /etc/S10rename_eth_swp.sh.backup
        echo "### Disabling ZTP service..."
        systemctl stop ztp.service
        ztp -d 2>&1
        echo "### Resetting ZTP to work next boot..."
        ztp -R 2>&1
        echo "### Rebooting Switch to Apply Remap..."
        reboot
    fi
    echo "### DONE ###"
else
    reboot
fi
SCRIPT

Vagrant.configure("2") do |config|
  wbid = 1
  offset = 0

  config.vm.provider :libvirt do |domain|
    # increase nic adapter count to be greater than 8 for all VMs.
    domain.management_network_address = "10.255.#{wbid}.0/24"
    domain.management_network_name = "wbr#{wbid}"
    domain.nic_adapter_count = 55
  end



  ##### DEFINE VM for oob-mgmt-server #####
  config.vm.define "oob-mgmt-server", primary: true do |device|
    device.vm.hostname = "oob-mgmt-server"
    device.vm.box = "cumulus/ts"
    

    # disabling sync folder support on all VMs
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder '.', '/vagrant', :disabled => true
    device.vm.provider :libvirt do |v|
      v.memory = 8*1024
    end
    device.vm.network "forwarded_port", guest: 9000, host: 9002, gateway_ports: true, host_ip: '*', adapter: 'eno1' # portainer
 
    # NETWORK INTERFACES
    # link for eth1 --> oob-mgmt-switch:swp1
    device.vm.network "private_network",
          :mac => "44383900005f",
          :libvirt__tunnel_type => 'udp',
          :libvirt__tunnel_local_ip => '127.0.0.1',
          :libvirt__tunnel_local_port => "#{ 8054 + offset }",
          :libvirt__tunnel_ip => '127.0.0.1',
          :libvirt__tunnel_port => "#{ 9054 + offset }",
          :libvirt__iface_name => 'eth1',
          auto_config: false

    # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
    device.vm.provision :shell , inline: "(grep -q 'mesg n' /root/.profile 2>/dev/null && sed -i '/mesg n/d' /root/.profile  2>/dev/null && echo 'Ignore the previous error, fixing this now...') || true;"

    # Shorten Boot Process - Applies to Ubuntu Only - remove \"Wait for Network\"
    #device.vm.provision :shell , inline: "sed -i 's/sleep [0-9]*/sleep 1/' /etc/init/failsafe.conf || true"

    # Run Any Extra Config
    device.vm.provision :shell , path: "./helper_scripts/config_oob_server.sh"

    extravars = {wbench_hosts: {
        exit02: {ip: "192.168.0.42", mac: "a0:00:00:00:00:42"},
        exit01: {ip: "192.168.0.41", mac: "a0:00:00:00:00:41"},
        spine02: {ip: "192.168.0.22", mac: "a0:00:00:00:00:22"},
        spine01: {ip: "192.168.0.21", mac: "a0:00:00:00:00:21"},
        leaf04: {ip: "192.168.0.14", mac: "a0:00:00:00:00:14"},
        leaf02: {ip: "192.168.0.12", mac: "a0:00:00:00:00:12"},
        leaf03: {ip: "192.168.0.13", mac: "a0:00:00:00:00:13"},
        leaf01: {ip: "192.168.0.11", mac: "a0:00:00:00:00:11"},
        edge01: {ip: "192.168.0.51", mac: "a0:00:00:00:00:51"},
        server01: {ip: "192.168.0.31", mac: "a0:00:00:00:00:31"},
        server03: {ip: "192.168.0.33", mac: "a0:00:00:00:00:33"},
        server02: {ip: "192.168.0.32", mac: "a0:00:00:00:00:32"},
        server04: {ip: "192.168.0.34", mac: "a0:00:00:00:00:34"},
        }}
    device.vm.provision :shell , path: "oob-mgmt-server-provision.sh"
    device.vm.provision :shell , inline: "ansible-playbook cldemo-provision-ts/site.yml --extra-vars '#{extravars.to_json}'  --connection=local -i localhost,"
    device.vm.provision :shell , path: "oob-mgmt-server-netq-setup.sh"

  end

  ##### DEFINE VM for oob-mgmt-switch #####
  config.vm.define "oob-mgmt-switch" do |device|
    device.vm.hostname = "oob-mgmt-switch"
    device.vm.box = "CumulusCommunity/cumulus-vx"
    device.vm.box_version = ">=3.3.0"

    # disabling sync folder support on all VMs
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder '.', '/vagrant', :disabled => true
    device.vm.provider :libvirt do |v|
      v.memory = 256
    end
    device.vm.synced_folder ".", "/vagrant", disabled: true

      # NETWORK INTERFACES
      # link for swp1 --> oob-mgmt-server:eth1
      device.vm.network "private_network",
            :mac => "443839000060",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9054 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8054 + offset }",
            :libvirt__iface_name => 'swp1',
            auto_config: false
      # link for swp2 --> server01:eth0
      device.vm.network "private_network",
            :mac => "44383900004b",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9042 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8042 + offset }",
            :libvirt__iface_name => 'swp2',
            auto_config: false
      # link for swp3 --> server02:eth0
      device.vm.network "private_network",
            :mac => "443839000054",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9047 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8047 + offset }",
            :libvirt__iface_name => 'swp3',
            auto_config: false
      # link for swp4 --> server03:eth0
      device.vm.network "private_network",
            :mac => "443839000005",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9003 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8003 + offset }",
            :libvirt__iface_name => 'swp4',
            auto_config: false
      # link for swp5 --> server04:eth0
      device.vm.network "private_network",
            :mac => "443839000056",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9049 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8049 + offset }",
            :libvirt__iface_name => 'swp5',
            auto_config: false
      # link for swp6 --> leaf01:eth0
      device.vm.network "private_network",
            :mac => "443839000025",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9020 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8020 + offset }",
            :libvirt__iface_name => 'swp6',
            auto_config: false
      # link for swp7 --> leaf02:eth0
      device.vm.network "private_network",
            :mac => "443839000045",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9038 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8038 + offset }",
            :libvirt__iface_name => 'swp7',
            auto_config: false
      # link for swp8 --> leaf03:eth0
      device.vm.network "private_network",
            :mac => "443839000034",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9028 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8028 + offset }",
            :libvirt__iface_name => 'swp8',
            auto_config: false
      # link for swp9 --> leaf04:eth0
      device.vm.network "private_network",
            :mac => "44383900003e",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9034 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8034 + offset }",
            :libvirt__iface_name => 'swp9',
            auto_config: false
      # link for swp10 --> spine01:eth0
      device.vm.network "private_network",
            :mac => "443839000039",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9031 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8031 + offset }",
            :libvirt__iface_name => 'swp10',
            auto_config: false
      # link for swp11 --> spine02:eth0
      device.vm.network "private_network",
            :mac => "443839000069",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9059 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8059 + offset }",
            :libvirt__iface_name => 'swp11',
            auto_config: false
      # link for swp12 --> exit01:eth0
      device.vm.network "private_network",
            :mac => "443839000010",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9009 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8009 + offset }",
            :libvirt__iface_name => 'swp12',
            auto_config: false
      # link for swp13 --> exit02:eth0
      device.vm.network "private_network",
            :mac => "443839000055",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9048 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8048 + offset }",
            :libvirt__iface_name => 'swp13',
            auto_config: false
      # link for swp14 --> edge01:eth0
      device.vm.network "private_network",
            :mac => "443839000048",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9040 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8040 + offset }",
            :libvirt__iface_name => 'swp14',
            auto_config: false
      # link for swp15 --> internet:eth0
      device.vm.network "private_network",
            :mac => "443839000040",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9035 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8035 + offset }",
            :libvirt__iface_name => 'swp15',
            auto_config: false



      # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
      device.vm.provision :shell , inline: "(grep -q 'mesg n' /root/.profile 2>/dev/null && sed -i '/mesg n/d' /root/.profile  2>/dev/null && echo 'Ignore the previous error, fixing this now...') || true;"

      

      # Run Any Extra Config
      device.vm.provision :shell , path: "./helper_scripts/config_oob_switch.sh"



      # Apply the interface re-map
      device.vm.provision "file", source: "./helper_scripts/apply_udev.py", destination: "/home/vagrant/apply_udev.py"
      device.vm.provision :shell , inline: "chmod 755 /home/vagrant/apply_udev.py"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:60 swp1"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:4b swp2"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:54 swp3"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:05 swp4"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:56 swp5"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:25 swp6"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:45 swp7"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:34 swp8"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:3e swp9"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:39 swp10"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:69 swp11"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:10 swp12"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:55 swp13"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:48 swp14"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:40 swp15"


      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -vm -nv"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -s"
      device.vm.provision :shell , :inline => $script



  end

  ##### DEFINE VM for exit02 #####
  config.vm.define "exit02" do |device|
    device.vm.hostname = "exit02"
    device.vm.box = "CumulusCommunity/cumulus-vx"
    device.vm.box_version = ">=3.3.0"

    # disabling sync folder support on all VMs
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder '.', '/vagrant', :disabled => true
    device.vm.provider :libvirt do |v|
      v.memory = 512
    end
    device.vm.synced_folder ".", "/vagrant", disabled: true

      # NETWORK INTERFACES
      # link for eth0 --> oob-mgmt-switch:swp13
      device.vm.network "private_network",
            :mac => "a00000000042",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8048 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9048 + offset }",
            :libvirt__iface_name => 'eth0',
            auto_config: false
      # link for swp1 --> edge01:eth2
      device.vm.network "private_network",
            :mac => "44383900000d",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9007 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8007 + offset }",
            :libvirt__iface_name => 'swp1',
            auto_config: false
      # link for swp44 --> internet:swp2
      device.vm.network "private_network",
            :mac => "443839000047",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9039 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8039 + offset }",
            :libvirt__iface_name => 'swp44',
            auto_config: false
      # link for swp45 --> exit02:swp46
      device.vm.network "private_network",
            :mac => "443839000037",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8030 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9030 + offset }",
            :libvirt__iface_name => 'swp45',
            auto_config: false
      # link for swp46 --> exit02:swp45
      device.vm.network "private_network",
            :mac => "443839000038",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9030 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8030 + offset }",
            :libvirt__iface_name => 'swp46',
            auto_config: false
      # link for swp47 --> exit02:swp48
      device.vm.network "private_network",
            :mac => "44383900003c",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8033 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9033 + offset }",
            :libvirt__iface_name => 'swp47',
            auto_config: false
      # link for swp48 --> exit02:swp47
      device.vm.network "private_network",
            :mac => "44383900003d",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9033 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8033 + offset }",
            :libvirt__iface_name => 'swp48',
            auto_config: false
      # link for swp49 --> exit01:swp49
      device.vm.network "private_network",
            :mac => "44383900002d",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9024 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8024 + offset }",
            :libvirt__iface_name => 'swp49',
            auto_config: false
      # link for swp50 --> exit01:swp50
      device.vm.network "private_network",
            :mac => "44383900001a",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9014 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8014 + offset }",
            :libvirt__iface_name => 'swp50',
            auto_config: false
      # link for swp51 --> spine01:swp29
      device.vm.network "private_network",
            :mac => "443839000026",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8021 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9021 + offset }",
            :libvirt__iface_name => 'swp51',
            auto_config: false
      # link for swp52 --> spine02:swp29
      device.vm.network "private_network",
            :mac => "44383900005d",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8053 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9053 + offset }",
            :libvirt__iface_name => 'swp52',
            auto_config: false



      # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
      device.vm.provision :shell , inline: "(grep -q 'mesg n' /root/.profile 2>/dev/null && sed -i '/mesg n/d' /root/.profile  2>/dev/null && echo 'Ignore the previous error, fixing this now...') || true;"

      

      # Run Any Extra Config
      device.vm.provision :shell , path: "./helper_scripts/config_switch.sh"



      # Apply the interface re-map
      device.vm.provision "file", source: "./helper_scripts/apply_udev.py", destination: "/home/vagrant/apply_udev.py"
      device.vm.provision :shell , inline: "chmod 755 /home/vagrant/apply_udev.py"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a a0:00:00:00:00:42 eth0"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:0d swp1"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:47 swp44"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:37 swp45"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:38 swp46"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:3c swp47"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:3d swp48"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:2d swp49"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:1a swp50"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:26 swp51"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:5d swp52"


      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -vm "
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -s"
      device.vm.provision :shell , :inline => $script



  end

  ##### DEFINE VM for exit01 #####
  config.vm.define "exit01" do |device|
    device.vm.hostname = "exit01"
    device.vm.box = "CumulusCommunity/cumulus-vx"
    device.vm.box_version = ">=3.3.0"

    # disabling sync folder support on all VMs
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder '.', '/vagrant', :disabled => true
    device.vm.provider :libvirt do |v|
      v.memory = 512
    end
    device.vm.synced_folder ".", "/vagrant", disabled: true

      # NETWORK INTERFACES
      # link for eth0 --> oob-mgmt-switch:swp12
      device.vm.network "private_network",
            :mac => "a00000000041",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8009 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9009 + offset }",
            :libvirt__iface_name => 'eth0',
            auto_config: false
      # link for swp1 --> edge01:eth1
      device.vm.network "private_network",
            :mac => "443839000053",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9046 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8046 + offset }",
            :libvirt__iface_name => 'swp1',
            auto_config: false
      # link for swp44 --> internet:swp1
      device.vm.network "private_network",
            :mac => "443839000009",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9005 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8005 + offset }",
            :libvirt__iface_name => 'swp44',
            auto_config: false
      # link for swp45 --> exit01:swp46
      device.vm.network "private_network",
            :mac => "44383900004c",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8043 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9043 + offset }",
            :libvirt__iface_name => 'swp45',
            auto_config: false
      # link for swp46 --> exit01:swp45
      device.vm.network "private_network",
            :mac => "44383900004d",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9043 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8043 + offset }",
            :libvirt__iface_name => 'swp46',
            auto_config: false
      # link for swp47 --> exit01:swp48
      device.vm.network "private_network",
            :mac => "443839000013",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8011 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9011 + offset }",
            :libvirt__iface_name => 'swp47',
            auto_config: false
      # link for swp48 --> exit01:swp47
      device.vm.network "private_network",
            :mac => "443839000014",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9011 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8011 + offset }",
            :libvirt__iface_name => 'swp48',
            auto_config: false
      # link for swp49 --> exit02:swp49
      device.vm.network "private_network",
            :mac => "44383900002c",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8024 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9024 + offset }",
            :libvirt__iface_name => 'swp49',
            auto_config: false
      # link for swp50 --> exit02:swp50
      device.vm.network "private_network",
            :mac => "443839000019",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8014 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9014 + offset }",
            :libvirt__iface_name => 'swp50',
            auto_config: false
      # link for swp51 --> spine01:swp30
      device.vm.network "private_network",
            :mac => "44383900000a",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8006 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9006 + offset }",
            :libvirt__iface_name => 'swp51',
            auto_config: false
      # link for swp52 --> spine02:swp30
      device.vm.network "private_network",
            :mac => "443839000063",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8056 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9056 + offset }",
            :libvirt__iface_name => 'swp52',
            auto_config: false



      # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
      device.vm.provision :shell , inline: "(grep -q 'mesg n' /root/.profile 2>/dev/null && sed -i '/mesg n/d' /root/.profile  2>/dev/null && echo 'Ignore the previous error, fixing this now...') || true;"

      

      # Run Any Extra Config
      device.vm.provision :shell , path: "./helper_scripts/config_switch.sh"



      # Apply the interface re-map
      device.vm.provision "file", source: "./helper_scripts/apply_udev.py", destination: "/home/vagrant/apply_udev.py"
      device.vm.provision :shell , inline: "chmod 755 /home/vagrant/apply_udev.py"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a a0:00:00:00:00:41 eth0"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:53 swp1"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:09 swp44"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:4c swp45"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:4d swp46"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:13 swp47"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:14 swp48"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:2c swp49"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:19 swp50"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:0a swp51"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:63 swp52"


      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -vm "
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -s"
      device.vm.provision :shell , :inline => $script



  end

  ##### DEFINE VM for spine02 #####
  config.vm.define "spine02" do |device|
    device.vm.hostname = "spine02"
    device.vm.box = "CumulusCommunity/cumulus-vx"
    device.vm.box_version = ">=3.3.0"

    # disabling sync folder support on all VMs
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder '.', '/vagrant', :disabled => true
    device.vm.provider :libvirt do |v|
      v.memory = 512
    end
    device.vm.synced_folder ".", "/vagrant", disabled: true

      # NETWORK INTERFACES
      # link for eth0 --> oob-mgmt-switch:swp11
      device.vm.network "private_network",
            :mac => "a00000000022",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8059 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9059 + offset }",
            :libvirt__iface_name => 'eth0',
            auto_config: false
      # link for swp1 --> leaf01:swp52
      device.vm.network "private_network",
            :mac => "44383900002b",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9023 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8023 + offset }",
            :libvirt__iface_name => 'swp1',
            auto_config: false
      # link for swp2 --> leaf02:swp52
      device.vm.network "private_network",
            :mac => "443839000068",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9058 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8058 + offset }",
            :libvirt__iface_name => 'swp2',
            auto_config: false
      # link for swp3 --> leaf03:swp52
      device.vm.network "private_network",
            :mac => "443839000020",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9017 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8017 + offset }",
            :libvirt__iface_name => 'swp3',
            auto_config: false
      # link for swp4 --> leaf04:swp52
      device.vm.network "private_network",
            :mac => "44383900004f",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9044 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8044 + offset }",
            :libvirt__iface_name => 'swp4',
            auto_config: false
      # link for swp29 --> exit02:swp52
      device.vm.network "private_network",
            :mac => "44383900005e",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9053 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8053 + offset }",
            :libvirt__iface_name => 'swp29',
            auto_config: false
      # link for swp30 --> exit01:swp52
      device.vm.network "private_network",
            :mac => "443839000064",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9056 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8056 + offset }",
            :libvirt__iface_name => 'swp30',
            auto_config: false
      # link for swp31 --> spine01:swp31
      device.vm.network "private_network",
            :mac => "443839000051",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9045 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8045 + offset }",
            :libvirt__iface_name => 'swp31',
            auto_config: false
      # link for swp32 --> spine01:swp32
      device.vm.network "private_network",
            :mac => "443839000042",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9036 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8036 + offset }",
            :libvirt__iface_name => 'swp32',
            auto_config: false



      # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
      device.vm.provision :shell , inline: "(grep -q 'mesg n' /root/.profile 2>/dev/null && sed -i '/mesg n/d' /root/.profile  2>/dev/null && echo 'Ignore the previous error, fixing this now...') || true;"

      

      # Run Any Extra Config
      device.vm.provision :shell , path: "./helper_scripts/config_switch.sh"



      # Apply the interface re-map
      device.vm.provision "file", source: "./helper_scripts/apply_udev.py", destination: "/home/vagrant/apply_udev.py"
      device.vm.provision :shell , inline: "chmod 755 /home/vagrant/apply_udev.py"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a a0:00:00:00:00:22 eth0"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:2b swp1"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:68 swp2"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:20 swp3"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:4f swp4"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:5e swp29"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:64 swp30"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:51 swp31"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:42 swp32"


      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -vm "
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -s"
      device.vm.provision :shell , :inline => $script



  end

  ##### DEFINE VM for spine01 #####
  config.vm.define "spine01" do |device|
    device.vm.hostname = "spine01"
    device.vm.box = "CumulusCommunity/cumulus-vx"
    device.vm.box_version = ">=3.3.0"

    # disabling sync folder support on all VMs
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder '.', '/vagrant', :disabled => true
    device.vm.provider :libvirt do |v|
      v.memory = 512
    end
    device.vm.synced_folder ".", "/vagrant", disabled: true

      # NETWORK INTERFACES
      # link for eth0 --> oob-mgmt-switch:swp10
      device.vm.network "private_network",
            :mac => "a00000000021",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8031 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9031 + offset }",
            :libvirt__iface_name => 'eth0',
            auto_config: false
      # link for swp1 --> leaf01:swp51
      device.vm.network "private_network",
            :mac => "44383900005c",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9052 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8052 + offset }",
            :libvirt__iface_name => 'swp1',
            auto_config: false
      # link for swp2 --> leaf02:swp51
      device.vm.network "private_network",
            :mac => "44383900002f",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9025 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8025 + offset }",
            :libvirt__iface_name => 'swp2',
            auto_config: false
      # link for swp3 --> leaf03:swp51
      device.vm.network "private_network",
            :mac => "443839000058",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9050 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8050 + offset }",
            :libvirt__iface_name => 'swp3',
            auto_config: false
      # link for swp4 --> leaf04:swp51
      device.vm.network "private_network",
            :mac => "443839000044",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9037 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8037 + offset }",
            :libvirt__iface_name => 'swp4',
            auto_config: false
      # link for swp29 --> exit02:swp51
      device.vm.network "private_network",
            :mac => "443839000027",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9021 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8021 + offset }",
            :libvirt__iface_name => 'swp29',
            auto_config: false
      # link for swp30 --> exit01:swp51
      device.vm.network "private_network",
            :mac => "44383900000b",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9006 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8006 + offset }",
            :libvirt__iface_name => 'swp30',
            auto_config: false
      # link for swp31 --> spine02:swp31
      device.vm.network "private_network",
            :mac => "443839000050",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8045 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9045 + offset }",
            :libvirt__iface_name => 'swp31',
            auto_config: false
      # link for swp32 --> spine02:swp32
      device.vm.network "private_network",
            :mac => "443839000041",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8036 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9036 + offset }",
            :libvirt__iface_name => 'swp32',
            auto_config: false



      # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
      device.vm.provision :shell , inline: "(grep -q 'mesg n' /root/.profile 2>/dev/null && sed -i '/mesg n/d' /root/.profile  2>/dev/null && echo 'Ignore the previous error, fixing this now...') || true;"

      

      # Run Any Extra Config
      device.vm.provision :shell , path: "./helper_scripts/config_switch.sh"



      # Apply the interface re-map
      device.vm.provision "file", source: "./helper_scripts/apply_udev.py", destination: "/home/vagrant/apply_udev.py"
      device.vm.provision :shell , inline: "chmod 755 /home/vagrant/apply_udev.py"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a a0:00:00:00:00:21 eth0"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:5c swp1"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:2f swp2"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:58 swp3"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:44 swp4"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:27 swp29"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:0b swp30"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:50 swp31"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:41 swp32"


      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -vm "
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -s"
      device.vm.provision :shell , :inline => $script



  end

  ##### DEFINE VM for leaf04 #####
  config.vm.define "leaf04" do |device|
    device.vm.hostname = "leaf04"
    device.vm.box = "CumulusCommunity/cumulus-vx"
    device.vm.box_version = ">=3.3.0"

    # disabling sync folder support on all VMs
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder '.', '/vagrant', :disabled => true
    device.vm.provider :libvirt do |v|
      v.memory = 512
    end
    device.vm.synced_folder ".", "/vagrant", disabled: true

      # NETWORK INTERFACES
      # link for eth0 --> oob-mgmt-switch:swp9
      device.vm.network "private_network",
            :mac => "a00000000014",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8034 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9034 + offset }",
            :libvirt__iface_name => 'eth0',
            auto_config: false
      # link for swp1 --> server03:eth2
      device.vm.network "private_network",
            :mac => "443839000066",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9057 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8057 + offset }",
            :libvirt__iface_name => 'swp1',
            auto_config: false
      # link for swp2 --> server04:eth2
      device.vm.network "private_network",
            :mac => "443839000033",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9027 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8027 + offset }",
            :libvirt__iface_name => 'swp2',
            auto_config: false
      # link for swp45 --> leaf04:swp46
      device.vm.network "private_network",
            :mac => "44383900001d",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8016 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9016 + offset }",
            :libvirt__iface_name => 'swp45',
            auto_config: false
      # link for swp46 --> leaf04:swp45
      device.vm.network "private_network",
            :mac => "44383900001e",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9016 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8016 + offset }",
            :libvirt__iface_name => 'swp46',
            auto_config: false
      # link for swp47 --> leaf04:swp48
      device.vm.network "private_network",
            :mac => "44383900003a",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8032 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9032 + offset }",
            :libvirt__iface_name => 'swp47',
            auto_config: false
      # link for swp48 --> leaf04:swp47
      device.vm.network "private_network",
            :mac => "44383900003b",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9032 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8032 + offset }",
            :libvirt__iface_name => 'swp48',
            auto_config: false
      # link for swp49 --> leaf03:swp49
      device.vm.network "private_network",
            :mac => "443839000036",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9029 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8029 + offset }",
            :libvirt__iface_name => 'swp49',
            auto_config: false
      # link for swp50 --> leaf03:swp50
      device.vm.network "private_network",
            :mac => "443839000007",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9004 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8004 + offset }",
            :libvirt__iface_name => 'swp50',
            auto_config: false
      # link for swp51 --> spine01:swp4
      device.vm.network "private_network",
            :mac => "443839000043",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8037 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9037 + offset }",
            :libvirt__iface_name => 'swp51',
            auto_config: false
      # link for swp52 --> spine02:swp4
      device.vm.network "private_network",
            :mac => "44383900004e",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8044 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9044 + offset }",
            :libvirt__iface_name => 'swp52',
            auto_config: false



      # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
      device.vm.provision :shell , inline: "(grep -q 'mesg n' /root/.profile 2>/dev/null && sed -i '/mesg n/d' /root/.profile  2>/dev/null && echo 'Ignore the previous error, fixing this now...') || true;"

      

      # Run Any Extra Config
      device.vm.provision :shell , path: "./helper_scripts/config_switch.sh"



      # Apply the interface re-map
      device.vm.provision "file", source: "./helper_scripts/apply_udev.py", destination: "/home/vagrant/apply_udev.py"
      device.vm.provision :shell , inline: "chmod 755 /home/vagrant/apply_udev.py"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a a0:00:00:00:00:14 eth0"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:66 swp1"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:33 swp2"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:1d swp45"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:1e swp46"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:3a swp47"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:3b swp48"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:36 swp49"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:07 swp50"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:43 swp51"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:4e swp52"


      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -vm "
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -s"
      device.vm.provision :shell , :inline => $script



  end

  ##### DEFINE VM for leaf02 #####
  config.vm.define "leaf02" do |device|
    device.vm.hostname = "leaf02"
    device.vm.box = "CumulusCommunity/cumulus-vx"
    device.vm.box_version = ">=3.3.0"

    # disabling sync folder support on all VMs
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder '.', '/vagrant', :disabled => true
    device.vm.provider :libvirt do |v|
      v.memory = 512
    end
    device.vm.synced_folder ".", "/vagrant", disabled: true

      # NETWORK INTERFACES
      # link for eth0 --> oob-mgmt-switch:swp7
      device.vm.network "private_network",
            :mac => "a00000000012",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8038 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9038 + offset }",
            :libvirt__iface_name => 'eth0',
            auto_config: false
      # link for swp1 --> server01:eth2
      device.vm.network "private_network",
            :mac => "443839000018",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9013 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8013 + offset }",
            :libvirt__iface_name => 'swp1',
            auto_config: false
      # link for swp2 --> server02:eth2
      device.vm.network "private_network",
            :mac => "44383900001c",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9015 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8015 + offset }",
            :libvirt__iface_name => 'swp2',
            auto_config: false
      # link for swp45 --> leaf02:swp46
      device.vm.network "private_network",
            :mac => "44383900000e",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8008 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9008 + offset }",
            :libvirt__iface_name => 'swp45',
            auto_config: false
      # link for swp46 --> leaf02:swp45
      device.vm.network "private_network",
            :mac => "44383900000f",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9008 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8008 + offset }",
            :libvirt__iface_name => 'swp46',
            auto_config: false
      # link for swp47 --> leaf02:swp48
      device.vm.network "private_network",
            :mac => "443839000061",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8055 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9055 + offset }",
            :libvirt__iface_name => 'swp47',
            auto_config: false
      # link for swp48 --> leaf02:swp47
      device.vm.network "private_network",
            :mac => "443839000062",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9055 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8055 + offset }",
            :libvirt__iface_name => 'swp48',
            auto_config: false
      # link for swp49 --> leaf01:swp49
      device.vm.network "private_network",
            :mac => "443839000012",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9010 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8010 + offset }",
            :libvirt__iface_name => 'swp49',
            auto_config: false
      # link for swp50 --> leaf01:swp50
      device.vm.network "private_network",
            :mac => "443839000002",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9001 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8001 + offset }",
            :libvirt__iface_name => 'swp50',
            auto_config: false
      # link for swp51 --> spine01:swp2
      device.vm.network "private_network",
            :mac => "44383900002e",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8025 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9025 + offset }",
            :libvirt__iface_name => 'swp51',
            auto_config: false
      # link for swp52 --> spine02:swp2
      device.vm.network "private_network",
            :mac => "443839000067",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8058 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9058 + offset }",
            :libvirt__iface_name => 'swp52',
            auto_config: false



      # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
      device.vm.provision :shell , inline: "(grep -q 'mesg n' /root/.profile 2>/dev/null && sed -i '/mesg n/d' /root/.profile  2>/dev/null && echo 'Ignore the previous error, fixing this now...') || true;"

      

      # Run Any Extra Config
      device.vm.provision :shell , path: "./helper_scripts/config_switch.sh"



      # Apply the interface re-map
      device.vm.provision "file", source: "./helper_scripts/apply_udev.py", destination: "/home/vagrant/apply_udev.py"
      device.vm.provision :shell , inline: "chmod 755 /home/vagrant/apply_udev.py"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a a0:00:00:00:00:12 eth0"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:18 swp1"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:1c swp2"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:0e swp45"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:0f swp46"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:61 swp47"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:62 swp48"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:12 swp49"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:02 swp50"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:2e swp51"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:67 swp52"


      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -vm "
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -s"
      device.vm.provision :shell , :inline => $script



  end

  ##### DEFINE VM for leaf03 #####
  config.vm.define "leaf03" do |device|
    device.vm.hostname = "leaf03"
    device.vm.box = "CumulusCommunity/cumulus-vx"
    device.vm.box_version = ">=3.3.0"

    # disabling sync folder support on all VMs
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder '.', '/vagrant', :disabled => true
    device.vm.provider :libvirt do |v|
      v.memory = 512
    end
    device.vm.synced_folder ".", "/vagrant", disabled: true

      # NETWORK INTERFACES
      # link for eth0 --> oob-mgmt-switch:swp8
      device.vm.network "private_network",
            :mac => "a00000000013",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8028 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9028 + offset }",
            :libvirt__iface_name => 'eth0',
            auto_config: false
      # link for swp1 --> server03:eth1
      device.vm.network "private_network",
            :mac => "443839000029",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9022 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8022 + offset }",
            :libvirt__iface_name => 'swp1',
            auto_config: false
      # link for swp2 --> server04:eth1
      device.vm.network "private_network",
            :mac => "443839000024",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9019 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8019 + offset }",
            :libvirt__iface_name => 'swp2',
            auto_config: false
      # link for swp45 --> leaf03:swp46
      device.vm.network "private_network",
            :mac => "443839000030",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8026 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9026 + offset }",
            :libvirt__iface_name => 'swp45',
            auto_config: false
      # link for swp46 --> leaf03:swp45
      device.vm.network "private_network",
            :mac => "443839000031",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9026 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8026 + offset }",
            :libvirt__iface_name => 'swp46',
            auto_config: false
      # link for swp47 --> leaf03:swp48
      device.vm.network "private_network",
            :mac => "443839000059",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8051 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9051 + offset }",
            :libvirt__iface_name => 'swp47',
            auto_config: false
      # link for swp48 --> leaf03:swp47
      device.vm.network "private_network",
            :mac => "44383900005a",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9051 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8051 + offset }",
            :libvirt__iface_name => 'swp48',
            auto_config: false
      # link for swp49 --> leaf04:swp49
      device.vm.network "private_network",
            :mac => "443839000035",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8029 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9029 + offset }",
            :libvirt__iface_name => 'swp49',
            auto_config: false
      # link for swp50 --> leaf04:swp50
      device.vm.network "private_network",
            :mac => "443839000006",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8004 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9004 + offset }",
            :libvirt__iface_name => 'swp50',
            auto_config: false
      # link for swp51 --> spine01:swp3
      device.vm.network "private_network",
            :mac => "443839000057",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8050 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9050 + offset }",
            :libvirt__iface_name => 'swp51',
            auto_config: false
      # link for swp52 --> spine02:swp3
      device.vm.network "private_network",
            :mac => "44383900001f",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8017 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9017 + offset }",
            :libvirt__iface_name => 'swp52',
            auto_config: false



      # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
      device.vm.provision :shell , inline: "(grep -q 'mesg n' /root/.profile 2>/dev/null && sed -i '/mesg n/d' /root/.profile  2>/dev/null && echo 'Ignore the previous error, fixing this now...') || true;"

      

      # Run Any Extra Config
      device.vm.provision :shell , path: "./helper_scripts/config_switch.sh"



      # Apply the interface re-map
      device.vm.provision "file", source: "./helper_scripts/apply_udev.py", destination: "/home/vagrant/apply_udev.py"
      device.vm.provision :shell , inline: "chmod 755 /home/vagrant/apply_udev.py"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a a0:00:00:00:00:13 eth0"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:29 swp1"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:24 swp2"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:30 swp45"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:31 swp46"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:59 swp47"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:5a swp48"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:35 swp49"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:06 swp50"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:57 swp51"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:1f swp52"


      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -vm "
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -s"
      device.vm.provision :shell , :inline => $script



  end

  ##### DEFINE VM for leaf01 #####
  config.vm.define "leaf01" do |device|
    device.vm.hostname = "leaf01"
    device.vm.box = "CumulusCommunity/cumulus-vx"
    device.vm.box_version = ">=3.3.0"

    # disabling sync folder support on all VMs
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder '.', '/vagrant', :disabled => true
    device.vm.provider :libvirt do |v|
      v.memory = 512
    end
    device.vm.synced_folder ".", "/vagrant", disabled: true

      # NETWORK INTERFACES
      # link for eth0 --> oob-mgmt-switch:swp6
      device.vm.network "private_network",
            :mac => "a00000000011",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8020 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9020 + offset }",
            :libvirt__iface_name => 'eth0',
            auto_config: false
      # link for swp1 --> server01:eth1
      device.vm.network "private_network",
            :mac => "443839000004",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9002 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8002 + offset }",
            :libvirt__iface_name => 'swp1',
            auto_config: false
      # link for swp2 --> server02:eth1
      device.vm.network "private_network",
            :mac => "443839000016",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9012 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8012 + offset }",
            :libvirt__iface_name => 'swp2',
            auto_config: false
      # link for swp45 --> leaf01:swp46
      device.vm.network "private_network",
            :mac => "443839000021",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8018 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9018 + offset }",
            :libvirt__iface_name => 'swp45',
            auto_config: false
      # link for swp46 --> leaf01:swp45
      device.vm.network "private_network",
            :mac => "443839000022",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9018 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8018 + offset }",
            :libvirt__iface_name => 'swp46',
            auto_config: false
      # link for swp47 --> leaf01:swp48
      device.vm.network "private_network",
            :mac => "443839000049",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8041 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9041 + offset }",
            :libvirt__iface_name => 'swp47',
            auto_config: false
      # link for swp48 --> leaf01:swp47
      device.vm.network "private_network",
            :mac => "44383900004a",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 9041 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 8041 + offset }",
            :libvirt__iface_name => 'swp48',
            auto_config: false
      # link for swp49 --> leaf02:swp49
      device.vm.network "private_network",
            :mac => "443839000011",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8010 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9010 + offset }",
            :libvirt__iface_name => 'swp49',
            auto_config: false
      # link for swp50 --> leaf02:swp50
      device.vm.network "private_network",
            :mac => "443839000001",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8001 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9001 + offset }",
            :libvirt__iface_name => 'swp50',
            auto_config: false
      # link for swp51 --> spine01:swp1
      device.vm.network "private_network",
            :mac => "44383900005b",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8052 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9052 + offset }",
            :libvirt__iface_name => 'swp51',
            auto_config: false
      # link for swp52 --> spine02:swp1
      device.vm.network "private_network",
            :mac => "44383900002a",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8023 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9023 + offset }",
            :libvirt__iface_name => 'swp52',
            auto_config: false



      # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
      device.vm.provision :shell , inline: "(grep -q 'mesg n' /root/.profile 2>/dev/null && sed -i '/mesg n/d' /root/.profile  2>/dev/null && echo 'Ignore the previous error, fixing this now...') || true;"

      

      # Run Any Extra Config
      device.vm.provision :shell , path: "./helper_scripts/config_switch.sh"



      # Apply the interface re-map
      device.vm.provision "file", source: "./helper_scripts/apply_udev.py", destination: "/home/vagrant/apply_udev.py"
      device.vm.provision :shell , inline: "chmod 755 /home/vagrant/apply_udev.py"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a a0:00:00:00:00:11 eth0"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:04 swp1"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:16 swp2"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:21 swp45"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:22 swp46"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:49 swp47"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:4a swp48"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:11 swp49"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:01 swp50"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:5b swp51"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:2a swp52"


      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -vm "
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -s"
      device.vm.provision :shell , :inline => $script



  end

  ##### DEFINE VM for edge01 #####
  config.vm.define "edge01" do |device|
    device.vm.hostname = "edge01"
    device.vm.box = "yk0/ubuntu-xenial"
    

    # disabling sync folder support on all VMs
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder '.', '/vagrant', :disabled => true
    device.vm.provider :libvirt do |v|
      v.memory = 512
      v.nic_model_type = 'e1000' 
    end
    device.vm.synced_folder ".", "/vagrant", disabled: true

      # NETWORK INTERFACES
      # link for eth0 --> oob-mgmt-switch:swp14
      device.vm.network "private_network",
            :mac => "a00000000051",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8040 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9040 + offset }",
            :libvirt__iface_name => 'eth0',
            auto_config: false
      # link for eth1 --> exit01:swp1
      device.vm.network "private_network",
            :mac => "443839000052",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8046 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9046 + offset }",
            :libvirt__iface_name => 'eth1',
            auto_config: false
      # link for eth2 --> exit02:swp1
      device.vm.network "private_network",
            :mac => "44383900000c",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8007 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9007 + offset }",
            :libvirt__iface_name => 'eth2',
            auto_config: false



      # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
      device.vm.provision :shell , inline: "(grep -q 'mesg n' /root/.profile 2>/dev/null && sed -i '/mesg n/d' /root/.profile  2>/dev/null && echo 'Ignore the previous error, fixing this now...') || true;"

      # Shorten Boot Process - Applies to Ubuntu Only - remove \"Wait for Network\"
      device.vm.provision :shell , inline: "sed -i 's/sleep [0-9]*/sleep 1/' /etc/init/failsafe.conf || true"

      # Run Any Extra Config
      device.vm.provision :shell , path: "./helper_scripts/config_server.sh"



      # Apply the interface re-map
      device.vm.provision "file", source: "./helper_scripts/apply_udev.py", destination: "/home/vagrant/apply_udev.py"
      device.vm.provision :shell , inline: "chmod 755 /home/vagrant/apply_udev.py"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a a0:00:00:00:00:51 eth0"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:52 eth1"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:0c eth2"


      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -vm "
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -s"
      device.vm.provision :shell , :inline => $script



  end

  ##### DEFINE VM for server01 #####
  config.vm.define "server01" do |device|
    device.vm.hostname = "server01"
    device.vm.box = "yk0/ubuntu-xenial"
    

    # disabling sync folder support on all VMs
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder '.', '/vagrant', :disabled => true
    device.vm.provider :libvirt do |v|
      v.memory = 512
      v.nic_model_type = 'e1000' 
    end
    device.vm.synced_folder ".", "/vagrant", disabled: true

      # NETWORK INTERFACES
      # link for eth0 --> oob-mgmt-switch:swp2
      device.vm.network "private_network",
            :mac => "a00000000031",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8042 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9042 + offset }",
            :libvirt__iface_name => 'eth0',
            auto_config: false
      # link for eth1 --> leaf01:swp1
      device.vm.network "private_network",
            :mac => "443839000003",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8002 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9002 + offset }",
            :libvirt__iface_name => 'eth1',
            auto_config: false
      # link for eth2 --> leaf02:swp1
      device.vm.network "private_network",
            :mac => "443839000017",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8013 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9013 + offset }",
            :libvirt__iface_name => 'eth2',
            auto_config: false



      # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
      device.vm.provision :shell , inline: "(grep -q 'mesg n' /root/.profile 2>/dev/null && sed -i '/mesg n/d' /root/.profile  2>/dev/null && echo 'Ignore the previous error, fixing this now...') || true;"

      # Shorten Boot Process - Applies to Ubuntu Only - remove \"Wait for Network\"
      device.vm.provision :shell , inline: "sed -i 's/sleep [0-9]*/sleep 1/' /etc/init/failsafe.conf || true"

      # Run Any Extra Config
      device.vm.provision :shell , path: "./helper_scripts/config_server.sh"



      # Apply the interface re-map
      device.vm.provision "file", source: "./helper_scripts/apply_udev.py", destination: "/home/vagrant/apply_udev.py"
      device.vm.provision :shell , inline: "chmod 755 /home/vagrant/apply_udev.py"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a a0:00:00:00:00:31 eth0"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:03 eth1"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:17 eth2"


      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -vm "
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -s"
      device.vm.provision :shell , :inline => $script



  end

  ##### DEFINE VM for server03 #####
  config.vm.define "server03" do |device|
    device.vm.hostname = "server03"
    device.vm.box = "yk0/ubuntu-xenial"
    

    # disabling sync folder support on all VMs
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder '.', '/vagrant', :disabled => true
    device.vm.provider :libvirt do |v|
      v.memory = 512
      v.nic_model_type = 'e1000' 
    end
    device.vm.synced_folder ".", "/vagrant", disabled: true

      # NETWORK INTERFACES
      # link for eth0 --> oob-mgmt-switch:swp4
      device.vm.network "private_network",
            :mac => "a00000000033",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8003 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9003 + offset }",
            :libvirt__iface_name => 'eth0',
            auto_config: false
      # link for eth1 --> leaf03:swp1
      device.vm.network "private_network",
            :mac => "443839000028",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8022 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9022 + offset }",
            :libvirt__iface_name => 'eth1',
            auto_config: false
      # link for eth2 --> leaf04:swp1
      device.vm.network "private_network",
            :mac => "443839000065",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8057 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9057 + offset }",
            :libvirt__iface_name => 'eth2',
            auto_config: false



      # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
      device.vm.provision :shell , inline: "(grep -q 'mesg n' /root/.profile 2>/dev/null && sed -i '/mesg n/d' /root/.profile  2>/dev/null && echo 'Ignore the previous error, fixing this now...') || true;"

      # Shorten Boot Process - Applies to Ubuntu Only - remove \"Wait for Network\"
      device.vm.provision :shell , inline: "sed -i 's/sleep [0-9]*/sleep 1/' /etc/init/failsafe.conf || true"

      # Run Any Extra Config
      device.vm.provision :shell , path: "./helper_scripts/config_server.sh"



      # Apply the interface re-map
      device.vm.provision "file", source: "./helper_scripts/apply_udev.py", destination: "/home/vagrant/apply_udev.py"
      device.vm.provision :shell , inline: "chmod 755 /home/vagrant/apply_udev.py"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a a0:00:00:00:00:33 eth0"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:28 eth1"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:65 eth2"


      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -vm "
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -s"
      device.vm.provision :shell , :inline => $script



  end

  ##### DEFINE VM for server02 #####
  config.vm.define "server02" do |device|
    device.vm.hostname = "server02"
    device.vm.box = "yk0/ubuntu-xenial"
    

    # disabling sync folder support on all VMs
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder '.', '/vagrant', :disabled => true
    device.vm.provider :libvirt do |v|
      v.memory = 512
      v.nic_model_type = 'e1000' 
    end
    device.vm.synced_folder ".", "/vagrant", disabled: true

      # NETWORK INTERFACES
      # link for eth0 --> oob-mgmt-switch:swp3
      device.vm.network "private_network",
            :mac => "a00000000032",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8047 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9047 + offset }",
            :libvirt__iface_name => 'eth0',
            auto_config: false
      # link for eth1 --> leaf01:swp2
      device.vm.network "private_network",
            :mac => "443839000015",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8012 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9012 + offset }",
            :libvirt__iface_name => 'eth1',
            auto_config: false
      # link for eth2 --> leaf02:swp2
      device.vm.network "private_network",
            :mac => "44383900001b",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8015 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9015 + offset }",
            :libvirt__iface_name => 'eth2',
            auto_config: false



      # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
      device.vm.provision :shell , inline: "(grep -q 'mesg n' /root/.profile 2>/dev/null && sed -i '/mesg n/d' /root/.profile  2>/dev/null && echo 'Ignore the previous error, fixing this now...') || true;"

      # Shorten Boot Process - Applies to Ubuntu Only - remove \"Wait for Network\"
      device.vm.provision :shell , inline: "sed -i 's/sleep [0-9]*/sleep 1/' /etc/init/failsafe.conf || true"

      # Run Any Extra Config
      device.vm.provision :shell , path: "./helper_scripts/config_server.sh"



      # Apply the interface re-map
      device.vm.provision "file", source: "./helper_scripts/apply_udev.py", destination: "/home/vagrant/apply_udev.py"
      device.vm.provision :shell , inline: "chmod 755 /home/vagrant/apply_udev.py"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a a0:00:00:00:00:32 eth0"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:15 eth1"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:1b eth2"


      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -vm "
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -s"
      device.vm.provision :shell , :inline => $script



  end

  ##### DEFINE VM for server04 #####
  config.vm.define "server04" do |device|
    device.vm.hostname = "server04"
    device.vm.box = "yk0/ubuntu-xenial"
    

    # disabling sync folder support on all VMs
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder '.', '/vagrant', :disabled => true
    device.vm.provider :libvirt do |v|
      v.memory = 512
      v.nic_model_type = 'e1000' 
    end
    device.vm.synced_folder ".", "/vagrant", disabled: true

      # NETWORK INTERFACES
      # link for eth0 --> oob-mgmt-switch:swp5
      device.vm.network "private_network",
            :mac => "a00000000034",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8049 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9049 + offset }",
            :libvirt__iface_name => 'eth0',
            auto_config: false
      # link for eth1 --> leaf03:swp2
      device.vm.network "private_network",
            :mac => "443839000023",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8019 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9019 + offset }",
            :libvirt__iface_name => 'eth1',
            auto_config: false
      # link for eth2 --> leaf04:swp2
      device.vm.network "private_network",
            :mac => "443839000032",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8027 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9027 + offset }",
            :libvirt__iface_name => 'eth2',
            auto_config: false



      # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
      device.vm.provision :shell , inline: "(grep -q 'mesg n' /root/.profile 2>/dev/null && sed -i '/mesg n/d' /root/.profile  2>/dev/null && echo 'Ignore the previous error, fixing this now...') || true;"

      # Shorten Boot Process - Applies to Ubuntu Only - remove \"Wait for Network\"
      device.vm.provision :shell , inline: "sed -i 's/sleep [0-9]*/sleep 1/' /etc/init/failsafe.conf || true"

      # Run Any Extra Config
      device.vm.provision :shell , path: "./helper_scripts/config_server.sh"



      # Apply the interface re-map
      device.vm.provision "file", source: "./helper_scripts/apply_udev.py", destination: "/home/vagrant/apply_udev.py"
      device.vm.provision :shell , inline: "chmod 755 /home/vagrant/apply_udev.py"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a a0:00:00:00:00:34 eth0"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:23 eth1"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:32 eth2"


      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -vm "
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -s"
      device.vm.provision :shell , :inline => $script



  end

  ##### DEFINE VM for internet #####
  config.vm.define "internet" do |device|
    device.vm.hostname = "internet"
    device.vm.box = "CumulusCommunity/cumulus-vx"
    device.vm.box_version = ">=3.3.0"

    # disabling sync folder support on all VMs
    #   see note here: https://github.com/pradels/vagrant-libvirt#synced-folders
    device.vm.synced_folder '.', '/vagrant', :disabled => true
    device.vm.provider :libvirt do |v|
      v.memory = 256
    end
    device.vm.synced_folder ".", "/vagrant", disabled: true

      # NETWORK INTERFACES
      # link for eth0 --> oob-mgmt-switch:swp15
      device.vm.network "private_network",
            :mac => "44383900003f",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8035 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9035 + offset }",
            :libvirt__iface_name => 'eth0',
            auto_config: false
      # link for swp1 --> exit01:swp44
      device.vm.network "private_network",
            :mac => "443839000008",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8005 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9005 + offset }",
            :libvirt__iface_name => 'swp1',
            auto_config: false
      # link for swp2 --> exit02:swp44
      device.vm.network "private_network",
            :mac => "443839000046",
            :libvirt__tunnel_type => 'udp',
            :libvirt__tunnel_local_ip => '127.0.0.1',
            :libvirt__tunnel_local_port => "#{ 8039 + offset }",
            :libvirt__tunnel_ip => '127.0.0.1',
            :libvirt__tunnel_port => "#{ 9039 + offset }",
            :libvirt__iface_name => 'swp2',
            auto_config: false



      # Fixes "stdin: is not a tty" and "mesg: ttyname failed : Inappropriate ioctl for device"  messages --> https://github.com/mitchellh/vagrant/issues/1673
      device.vm.provision :shell , inline: "(grep -q 'mesg n' /root/.profile 2>/dev/null && sed -i '/mesg n/d' /root/.profile  2>/dev/null && echo 'Ignore the previous error, fixing this now...') || true;"

      

      # Run Any Extra Config
      device.vm.provision :shell , path: "./helper_scripts/config_internet.sh"



      # Apply the interface re-map
      device.vm.provision "file", source: "./helper_scripts/apply_udev.py", destination: "/home/vagrant/apply_udev.py"
      device.vm.provision :shell , inline: "chmod 755 /home/vagrant/apply_udev.py"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:3f eth0"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:08 swp1"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -a 44:38:39:00:00:46 swp2"


      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -vm --vagrant-name=swp48"
      device.vm.provision :shell , inline: "/home/vagrant/apply_udev.py -s"
      device.vm.provision :shell , :inline => $script



  end



end
