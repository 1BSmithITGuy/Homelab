terraform {
  required_providers {
    xenorchestra = {
      source = "vatesfr/xenorchestra"
    }
  }
}


provider "xenorchestra" {
  url      = "https://10.0.0.50"
  username = "admin@admin.net"
  password = "admin"
}

# Get the pool
data "xenorchestra_pool" "main" {
  name_label = "BSUS103POOL01"
}

# Optional: pin to a specific host
data "xenorchestra_host" "preferred" {
  name_label = "BSUS103VM02"
}

# Get storage repository for VM disk
data "xenorchestra_sr" "vm_storage" {
  name_label = "BSUS103VM02-VM-Storage"
}

# Get storage repository for ISOs
data "xenorchestra_sr" "iso_storage" {
  name_label = "US103VM02-ISO-Storage"
}

# Get the network (VLAN10)
data "xenorchestra_network" "vlan10" {
  name_label = "VLAN10"
}

# Define the VM
resource "xenorchestra_vm" "ad_dc1" {
  name_label        = "AD1-Root-DC"
  cpus              = 1
  memory_max        = 2147483648
  memory_static_max = 2147483648
  pool_id           = data.xenorchestra_pool.main.id
  affinity_host     = data.xenorchestra_host.preferred.id
  boot_order        = ["cd", "disk"]

  # Virtual Disk
  disks {
    sr_id      = data.xenorchestra_sr.vm_storage.id
    name_label = "AD1-Root-DC"
    size       = 32212254720  # 30 GB
  }

  # Network Interface
  network {
    network_id = data.xenorchestra_network.vlan10.id
  }

  # Attach Windows Server ISO
  cdrom {
    sr_id      = data.xenorchestra_sr.iso_storage.id
    name_label = "Windows_Server_Core_2022.iso"
  }

  # Attach Unattend ISO
  cdrom {
    sr_id      = data.xenorchestra_sr.iso_storage.id
    name_label = "AD-1-UnattendRootDC.iso"
  }
}