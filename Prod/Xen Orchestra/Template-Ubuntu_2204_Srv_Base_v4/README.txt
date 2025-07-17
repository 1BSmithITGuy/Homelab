#  Prod ready 06/29/2025
This is for Template-Ubuntu_2204_Srv_Base_v4 template in xcp-ng.  


I followed the documentation titled: Create and use custom XCP-NG templates: a guide for Ubuntu
At the following link:
https://docs.xcp-ng.org/guides/create-use-custom-xcpng-ubuntu-templates/ 

These were run on this template from the website above:

        sudo apt update && sudo apt upgrade
        sudo apt install xe-guest-utilities
        sudo apt install cloud-init
        sudo apt install cloud-initramfs-growroot
        sudo dpkg-reconfigure cloud-init
             # NOTE: here you want to select NoCloud, ConfigDrive, and OpenStack

        sudo rm -f /etc/cloud/cloud.cfg.d/99-installer.cfg
        sudo rm -f /etc/cloud/cloud.cfg.d/subiquity-disable-cloudinit-networking.cfg
        sudo rm -rf /var/lib/cloud/instance
        sudo rm -f /etc/netplan/00-installer-config.yaml

I also installed:
sudo apt install -y curl wget htop unzip bash-completion net-tools dnsutils traceroute iputils-ping telnet

I added custom .bashrc to /etc/skel and /root - both are different from each other.  

The following was run on the current template in prod, which has not been run on this VM yet:

        sudo rm -rf /var/lib/cloud/instances /var/lib/cloud/instance
        sudo rm -rf /var/log/cloud-init.log /var/log/cloud-init*
        sudo rm -f /etc/netplan/50-cloud-init.yaml
        sudo rm -f /etc/cloud/cloud.cfg.d/90-installer-network.cfg
        sudo truncate -s 0 /etc/machine-id
        Then you will shutdown and create the template.

You want to use this format for the "Network Config" YAML:

      #cloud-config
      network:
        version: 2
        ethernets:
          eth0:
            dhcp4: false
            addresses:
              - 10.0.2.6/27
            gateway4: 10.0.2.1
            nameservers:
              addresses:
                - 10.0.2.1
                - 1.1.1.1
Make sure your IP is in CIDR notation.

If you have any trouble, in /var/log you want to look through the cloud-init.log to start, and there is another cloud-init log in there.

#  add later:

netcat
