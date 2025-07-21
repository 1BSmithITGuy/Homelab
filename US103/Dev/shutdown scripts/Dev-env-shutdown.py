import subprocess
import time
import json
import shutil
import os
from datetime import datetime
import sys

# ===================== CONFIGURATION =====================
XO_CLI = os.path.expandvars(r"%APPDATA%\\npm\\xo-cli.cmd")
PLINK_PATH = shutil.which("plink") or "plink"

# Hardcoded root credentials for SSH
ROOT_USER = "root"
ROOT_PASS = "x$dN@r0n"  # Replace this with your actual password

# Dev and Prod host IPs
DEV_HOSTS = ["10.0.0.52", "10.0.0.53"]
PROD_HOST = "10.0.0.51"
XO_VM_NAME = "BSUS103XO01"
XO_VM_IP = "10.0.0.50"

# Log setup
LOG_DIR = "log"
os.makedirs(LOG_DIR, exist_ok=True)
LOG_FILE = os.path.join(LOG_DIR, f"shutdown_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log")

# Emoji/Text fallback
def log(msg, file_fallback=""):
    print(msg)
    with open(LOG_FILE, "a", encoding="utf-8") as f:
        safe = file_fallback if file_fallback else msg.encode('ascii', errors='ignore').decode()
        f.write(safe + "\n")

# ========== VM LISTS ==========
K8S_VMS = [
    {"name": "bsus103k-8w02", "pause": 3},
    {"name": "bsus103k-8w01", "pause": 3},
    {"name": "bsus103k-8m01", "pause": 5},
]

ADDS_VMS = [
    {"name": "INFUS103TS01", "pause": 2},
    {"name": "INFUS103DC02", "pause": 5},
    {"name": "INFUS103DC01", "pause": 0},
]

# ========== XO-CLI INTERFACE ==========
def get_vm_list():
    command = f'"{XO_CLI}" list-objects type=VM'
    result = subprocess.run(command, capture_output=True, text=True, shell=True)
    if result.returncode != 0:
        log("❌ Error fetching VM list", "[ERROR] Error fetching VM list")
        log(result.stderr)
        sys.exit(1)
    return json.loads(result.stdout)

def get_vm_uuid(name, all_vms):
    for vm in all_vms:
        if vm.get("name_label") == name:
            return vm.get("id"), vm.get("resident_on")
    return None, None

def shutdown_vm(uuid, name):
    log(f"🚀 Initiating shutdown of {name}...", f"[START] Shutting down {name}...")
    try:
        command = f'"{XO_CLI}" rest post vms/{uuid}/actions/acpiShutdown'
        result = subprocess.run(command, capture_output=True, text=True, shell=True)
        if result.returncode != 0:
            log(f"❌ Failed to shutdown {name}:", f"[ERROR] Failed to shutdown {name}")
            log(result.stderr)
        else:
            log(f"✅ {name} shutdown initiated.", f"[OK] Shutdown initiated for {name}")
    except Exception as e:
        log(f"❌ Exception during shutdown of {name}: {e}", f"[ERROR] {name} exception: {e}")

# ========== HOST CHECKING ==========
def get_vm_host(uuid, all_vms):
    for vm in all_vms:
        if vm.get("id") == uuid:
            return vm.get("resident_on")
    return None

def filter_running_vms(vms, excluded_names):
    return [vm for vm in vms if vm.get("type") == "VM" and vm.get("power_state") == "Running"
            and vm.get("name_label") not in excluded_names and vm.get("resident_on") in DEV_HOSTS]

def confirm_all_vms_shutdown(host_ips, excluded=[]):
    timeout = time.time() + 300
    while time.time() < timeout:
        current = get_vm_list()
        running = filter_running_vms(current, excluded)
        if not running:
            return True
        time.sleep(2)
    return False

def shutdown_host(ip):
    log(f"⚙️ Initiating shutdown of host {ip}...", f"[HOST] Shutting down {ip}")
    try:
        command = [PLINK_PATH, "-ssh", f"{ROOT_USER}@{ip}", "-pw", ROOT_PASS, "poweroff"]
        result = subprocess.run(command, capture_output=True, text=True)
        if result.returncode != 0:
            log(f"❌ Host shutdown failed: {ip}", f"[ERROR] Host {ip} failed shutdown")
            log(result.stderr)
        else:
            log(f"✅ Host {ip} shutdown initiated.", f"[OK] Host {ip} shutdown")
    except Exception as e:
        log(f"❌ Host {ip} shutdown exception: {e}", f"[ERROR] Exception on host {ip}: {e}")

def wait_for_host_shutdown(ip):
    timeout = time.time() + 300
    while time.time() < timeout:
        ping = subprocess.run(["ping", "-n", "1", "-w", "1000", ip], stdout=subprocess.DEVNULL)
        if ping.returncode != 0:
            log(f"✅ Host {ip} is offline.", f"[OFFLINE] Host {ip}")
            return True
        time.sleep(2)
    log(f"❌ Timeout waiting for host {ip} to shutdown.", f"[ERROR] Host {ip} still online")
    return False

# ===================== MAIN =====================
def main():
    log("========== SHUTDOWN SCRIPT START ==========\n")

    all_vms = get_vm_list()

    # Shut down K8s VMs (in reverse)
    for entry in K8S_VMS:
        uuid, host = get_vm_uuid(entry["name"], all_vms)
        if uuid:
            shutdown_vm(uuid, entry["name"])
            time.sleep(entry["pause"])

    # Shut down ADDS VMs (in reverse)
    for entry in ADDS_VMS:
        uuid, host = get_vm_uuid(entry["name"], all_vms)
        if uuid:
            shutdown_vm(uuid, entry["name"])
            time.sleep(entry["pause"])

    # Confirm shutdown of additional VMs
    excluded = [vm["name"] for vm in K8S_VMS + ADDS_VMS] + [XO_VM_NAME]
    remaining = filter_running_vms(all_vms, excluded)
    if remaining:
        print(f"❓ {len(remaining)} additional dev VMs are running:")
        for vm in remaining:
            print(f" - {vm['name_label']}")
        confirm = input("Shutdown these VMs too? (y/N): ").strip().lower()
        if confirm == 'y':
            for vm in remaining:
                shutdown_vm(vm['id'], vm['name_label'])

    # Wait for all VMs (except XO) to shutdown
    if confirm_all_vms_shutdown(DEV_HOSTS, excluded):
        # Shutdown XO VM
        xo_uuid, _ = get_vm_uuid(XO_VM_NAME, all_vms)
        if xo_uuid:
            shutdown_vm(xo_uuid, XO_VM_NAME)
            time.sleep(30)  # Graceful wait before shutting down hosts

        # Shutdown hosts in sequence
        for host_ip in reversed(DEV_HOSTS):
            shutdown_host(host_ip)
            wait_for_host_shutdown(host_ip)
    else:
        log("❌ VMs failed to shut down in time. Aborting host shutdown.", "[ABORT] VMs still running")

    log("\n========== SHUTDOWN COMPLETE ==========")
    print(f"📄 Log written to: {LOG_FILE}")

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        log("🛑 Script interrupted by user. Aborting.", "[INTERRUPT] Script aborted by user")
