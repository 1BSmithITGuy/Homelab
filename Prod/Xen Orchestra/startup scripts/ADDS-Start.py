import subprocess
import time
import json
import shutil
import sys

# List of VMs and their startup delays
vms = [
    {"name": "INFUS103DC01", "pause": 0},
    {"name": "INFUS103DC02", "pause": 5},
    {"name": "INFUS103TS01", "pause": 2}
]

# Locate xo-cli in PATH
XO_CLI = shutil.which("xo-cli") or shutil.which("xo-cli.cmd")

if not XO_CLI:
    print("❌ Error: xo-cli not found in PATH.")
    sys.exit(1)

# Fetch VM list
def get_vm_list():
    command = f'"{XO_CLI}" list-objects type=VM'
    result = subprocess.run(command, capture_output=True, text=True, shell=True)
    if result.returncode != 0:
        print("❌ Error fetching VM list:")
        print(result.stderr)
        sys.exit(1)
    return json.loads(result.stdout)

# Find VM UUID by name
def get_vm_uuid_by_name(vms_data, name):
    for vm in vms_data:
        if vm.get("name_label") == name:
            return vm.get("id")
    return None

# Power on VM by UUID
def start_vm(uuid, name):
    print(f"🚀 Starting {name}...")
    command = f'"{XO_CLI}" rest post vms/{uuid}/actions/start'
    result = subprocess.run(command, capture_output=True, text=True, shell=True)
    if result.returncode != 0:
        print(f"❌ Failed to start {name}:")
        print(result.stderr)
    else:
        print(f"✅ {name} started successfully.")

# Run power-on sequence
def main():
    all_vms = get_vm_list()
    for entry in vms:
        uuid = get_vm_uuid_by_name(all_vms, entry["name"])
        if uuid:
            start_vm(uuid, entry["name"])
            time.sleep(entry["pause"])
        else:
            print(f"⚠️ VM '{entry['name']}' not found.")

if __name__ == "__main__":
    main()