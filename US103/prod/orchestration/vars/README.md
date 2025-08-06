# Variable Files for Orchestration

This directory defines the sets of VMs used during orchestration tasks such as startup and shutdown. These files are loaded by scripts in the `/bin` directory to determine what infrastructure to act on.

---

## 📁 global/

This subdirectory contains **required** variables that define the core infrastructure for a site or service. These files are sourced as shell scripts (`.vars`) and typically define structured variables like Kubernetes context or a list of domain controllers.

Examples:
- `US103-AD-DCs.vars` – Lists AD domain controller VM names.
- `US103-k8s-servers.vars` – Defines the Kubernetes context and worker nodes for the US103 cluster.
- `US103-Xen-Infra.vars` – Defines the Xen Infrastructure components.

Example structure:
```bash
context="k3s-us103"
workers=("bsus103k-8w01" "bsus103k-8w02")
```

---

## 📁 optional/

This subdirectory contains **optional** VM lists for extended or stack-specific components. These are only used by orchestration scripts if the file exists.

Files in this directory are simple, line-separated VM name lists:
```
bsus103jump01
bsus103grafana01
```

Scripts like `us103-shutdown-k8s.sh` or `us103-start-adds.sh` will check for these files and shut down or start the listed VMs accordingly.

---

## Usage in Scripts

Orchestration scripts use both global and optional files like this:

- `source vars/global/US103-k8s-servers.vars`
- `if [[ -f vars/optional/us103-start-k8s.vars ]]; then ... fi`

This structure keeps your orchestration logic clean, modular, and site-aware.
