# Orchestration Bin Scripts

This directory contains high-level orchestration scripts to start and stop core infrastructure services in the US103 lab environment.

### Scripts

- `us103-shutdown-the-world.sh`  
  Shuts down Kubernetes, AD, and all eligible lab VMs and hosts.

- `us103-shutdown-k8s.sh`  
  Gracefully cordones and shuts down Kubernetes nodes.

- `us103-shutdown-adds.sh`  
  Shuts down Active Directory domain controllers and optional stack VMs.

- `us103-start-k8s.sh`  
  Starts Kubernetes VMs and uncordons nodes.

- `us103-start-adds.sh`  
  Starts AD domain controllers and optional infrastructure.

- `us103-update-orcserver-hostsfile.sh`  
  Updates /etc/hosts file with local DNS entries on orchestration server.
