# Ubuntu 22.04 Server Base Template (XCP-ng + Xen Orchestra)

📦 **Template Name**: `Template-Ubuntu_2204_Srv_Base_v4`  
🛠️ **Platform**: XCP-ng (via Xen Orchestra)  
📅 **Production-Ready as of**: June 29, 2025  

This template was created as a clean, cloud-init–enabled base for deploying Ubuntu 22.04 server VMs in a homelab or production-like XCP-ng environment. It automates common configuration tasks, supports cloud-init user data, and includes basic system administration tools out of the box.

---

## 🧠 Purpose

To provide a reusable, preconfigured Ubuntu 22.04 server image for use in Xen Orchestra (XO), following best practices for XCP-ng templates and enabling efficient VM provisioning via cloud-init.

---

## 📚 Reference

Based on the XCP-ng official guide:  
**[Create and use custom XCP-ng templates: a guide for Ubuntu](https://docs.xcp-ng.org/guides/create-use-custom-xcpng-ubuntu-templates/)**

> ⚠️ *Note: The official guide has a few inconsistencies. Steps and corrections are documented below.*

---

## ✅ Template Creation Steps

Run these steps on a freshly installed Ubuntu 22.04 VM before converting it into a template:

### 1. Update & Install Required Packages

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y xe-guest-utilities cloud-init cloud-initramfs-growroot
sudo apt install -y curl wget htop unzip bash-completion net-tools dnsutils traceroute iputils-ping telnet
```

### 2. Configure cloud-init

```bash
sudo dpkg-reconfigure cloud-init
```

**Selection during reconfiguration**:
- ✅ NoCloud  
- ✅ ConfigDrive  
- ✅ OpenStack  

### 3. Clean Up and Prepare for Template

```bash
sudo rm -f /etc/cloud/cloud.cfg.d/99-installer.cfg
sudo rm -f /etc/cloud/cloud.cfg.d/subiquity-disable-cloudinit-networking.cfg
sudo rm -rf /var/lib/cloud/instance /var/lib/cloud/instances
sudo rm -f /etc/netplan/00-installer-config.yaml
sudo rm -f /etc/netplan/50-cloud-init.yaml
sudo rm -f /etc/cloud/cloud.cfg.d/90-installer-network.cfg
sudo truncate -s 0 /etc/machine-id
sudo rm -f /var/log/cloud-init.log /var/log/cloud-init*
```

---

## 🧩 Customizations

- Added custom `.bashrc` files:
  - `/etc/skel/.bashrc` → applies to new users
  - `/root/.bashrc` → tailored for root login
- Future iterations will include:
  - `netcat`, `vim`, and a custom `.vimrc`

---

## 🌐 Network Configuration (YAML Example)

Use the following format when injecting a static IP config via cloud-init:

```yaml
network:
  version: 2
  ethernets:
    eth0:
      dhcp4: false
      addresses:
        - <IP>/<prefix>
      routes:
        - to: default
          via: <gateway>
      nameservers:
        search: [ad.infutable.com]
        addresses:
          - <gateway>
          - 1.1.1.1
```

Replace placeholders (`<IP>`, `<prefix>`, `<gateway>`) with appropriate values.

---

## 🔍 Troubleshooting

Check the following logs on boot if cloud-init does not behave as expected:

- `/var/log/cloud-init.log`
- `/var/log/cloud-init-output.log`

These provide detailed insight into cloud-init stages and any network/user-data issues.

---

## 📝 Future Improvements

- [ ] Preinstall `netcat` and `vim`
- [ ] Include preconfigured `.vimrc`
- [ ] Automate cleanup tasks via script for faster rebuilds

---