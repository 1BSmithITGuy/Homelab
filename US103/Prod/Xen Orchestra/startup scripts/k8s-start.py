import subprocess
import time
import shutil
import sys
import json

ADDS_SCRIPT = "ADDS-Start.py"
XO_CLI = shutil.which("xo-cli") or shutil.which("xo-cli.cmd")

if not XO_CLI:
    print("❌ xo-cli not found in PATH.")
    sys.exit(1)

# Domain Controller IPs
dc_ips = ["10.0.1.2", "10.0.1.3"]

def is_host_reachable(ip):
    try:
        result = subprocess.run(
            ["ping", "-n", "1", ip],
            capture_output=True,
            text=True
        )
        return result.returncode == 0
    except Exception as e:
        print(f"Ping error for {ip}: {e}")
        return False

def get_vm_list():
    command = f'"{XO_CLI}" list-objects type=VM'
    result = subprocess.run(command, capture_output=True, text=True, shell=True)
    if result.returncode != 0:
        print("❌ Failed to fetch VM list:")
        print(result.stderr)
        sys.exit(1)
    return json.loads(result.stdout)

def get_vm_uuid_by_name(vms_data, name):
    for vm in vms_data:
        if vm.get("name_label") == name:
            return vm.get("id")
    return None

def start_vm(uuid, name):
    print(f"🚀 Starting {name}...")
    command = f'"{XO_CLI}" rest post vms/{uuid}/actions/start'
    result = subprocess.run(command, capture_output=True, text=True, shell=True)
    if result.returncode != 0:
        print(f"❌ Failed to start {name}:")
        print(result.stderr)
    else:
        print(f"✅ {name} started successfully.")

def ensure_dc_online():
    print("🔍 Checking if any domain controller IP is reachable...")
    for ip in dc_ips:
        if is_host_reachable(ip):
            print(f"✅ DC at {ip} is reachable.")
            return True
    print("⚠️ No DCs reachable by IP. Starting ADDS script...")
    result = subprocess.run(["py", ADDS_SCRIPT])
    if result.returncode != 0:
        print("❌ Failed to start ADDS script.")
        sys.exit(1)
    return True

def main():
    ensure_dc_online()

    # K3s VM boot sequence
    k3s_vms = [
        {"name": "bsus103k-8m01", "pause": 0},
        {"name": "bsus103k-8w01", "pause": 5},
        {"name": "bsus103k-8w02", "pause": 5}
    ]

    all_vms = get_vm_list()

    for vm in k3s_vms:
        uuid = get_vm_uuid_by_name(all_vms, vm["name"])
        if uuid:
            start_vm(uuid, vm["name"])
            time.sleep(vm["pause"])
        else:
            print(f"⚠️ VM '{vm['name']}' not found.")

if __name__ == "__main__":
    main()