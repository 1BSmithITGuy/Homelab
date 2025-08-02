# Orchestration Helper Scripts

This directory includes internal helper scripts used by orchestration logic in `/bin`.

### Scripts

- `us103-shutdown-xo-vm.sh`  
  SSH-based shutdown of running VMs using XCP-ng `xe` CLI.

- `us103-start-xo-vm.sh`  
  Starts VMs by name via `xo-cli`.

- `us103-get-xo-vm-ip.sh`  
  Retrieves VM IP addresses from Xen Orchestra metadata.
