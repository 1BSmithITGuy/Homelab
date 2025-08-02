# US103 Homelab Orchestration Scripts

This repository contains infrastructure automation scripts used to manage the startup and shutdown lifecycle of the US103 lab environment (US103 is the sitecode for my basement datacenter). These scripts coordinate VM orchestration, Active Directory services, Kubernetes nodes, and low-level host control using Xen Orchestra and XCP-ng.

---

## 🔧 Directory Structure

### `/bin`
High-level orchestration commands. These scripts handle full environment startup and shutdown, coordinate subsystems like AD and Kubernetes, and sequence tasks using tags defined in Xen Orchestra.

Scripts:
- `us103-shutdown-the-world.sh` – Cleanly shuts down the entire lab environment (AD, K8s, VMs, and hosts).
- `us103-shutdown-k8s.sh` – Drains, cordons, and shuts down Kubernetes nodes and stack services.
- `us103-shutdown-adds.sh` – Shuts down domain controllers and optional stack VMs.
- `us103-start-k8s.sh` – Starts Kubernetes VMs and uncordons nodes for service availability.
- `us103-start-adds.sh` – Starts AD domain controllers and optional infrastructure VMs.
- `us103-update-orcserver-hostsfile.sh` – Updates the `/etc/hosts` file on orchestration nodes.

---

### `/libexec`
Internal helper scripts used by the orchestration layer in `/bin`. These scripts are not run directly but are used for tasks like starting or stopping specific VMs or querying metadata.

Scripts:
- `us103-shutdown-xo-vm.sh` – Gracefully shuts down VMs via SSH and the `xe` command.
- `us103-start-xo-vm.sh` – Starts VMs using `xo-cli`.
- `us103-get-xo-vm-ip.sh` – Retrieves the current IP address of a VM via `xo-cli`.

---

### `/vars/global` and `/vars/optional`
- `global/` contains environment-wide configuration files, such as lists of AD domain controllers or Kubernetes servers.
- `optional/` contains supplemental or stack-specific VMs to be optionally started or stopped along with core services.

---

## ✅ Tagging Conventions (Used in XO)

The orchestration relies on VM and host tags in Xen Orchestra:

| Tag             | Purpose                                                   |
|------------------|-----------------------------------------------------------|
| `Env=Lab`        | Identifies lab infrastructure eligible for orchestration |
| `Shutdown=Auto`  | VMs that should be shut down automatically                |
| `Shutdown=Host`  | Running VM permitted to keep host powered on              |

---

## 🔁 Dependencies

- `xo-cli` must be configured and authenticated
- SSH access is required for host shutdown
- Scripts assume Xen Orchestra tags are correctly applied

---

## 📘 Documentation

Each script includes a detailed header with description, last modified date, and prerequisites. See the top of each `.sh` file for details.

