#----------------------------------------------------------------------------------------------------------------
#  Bryan Smith
#  BSmithITGuy@gmail.com
#  Last Update:  08/01/2025

#  DESCRIPTION:
    # This script updates the Orchestration server's hosts file to ensure DNS resolution to key infrastructure services.  
    # Backs up /etc/hosts, then updates it.  it will check for duplicate entries.
#----------------------------------------------------------------------------------------------------------------

#!/bin/bash
set -euo pipefail

echo "🔧 Starting /etc/hosts update process..."

TMPFILE=$(mktemp)
ANY_CHANGES=false

# Write the desired entries into a second temp file to loop over
HOSTS_LIST=$(mktemp)
cat << 'EOF' > "$HOSTS_LIST"
# Xen/XCP-NG
10.0.0.50	BSUS103XO01
10.0.0.51	BSUS103VM01
10.0.0.52	BSUS103VM02
10.0.0.53	BSUS103VM03

# AD DCs
10.0.1.2	INFUS103DC01	INFUS103DC01.ad.infutable.com
10.0.1.3	INFUS103DC02	INFUS103DC02.ad.infutable.com

# Kubeadm
10.0.2.20	bsus103k-8m01	bsus103k-8m01.ad.infutable.com
10.0.2.22	bsus103k-8w01	bsus103k-8w01.ad.infutable.com
10.0.2.23	bsus103k-8w02	bsus103k-8w02.ad.infutable.com

# k3s
10.0.0.202	BSUS103KM01
EOF

while IFS= read -r line; do
    [[ -z "$line" ]] && continue

    if [[ "$line" =~ ^# ]]; then
        echo "$line" >> "$TMPFILE"
        continue
    fi

    IP=$(echo "$line" | awk '{print $1}')
    HOSTNAMES=$(echo "$line" | cut -d' ' -f2-)
    FOUND=false

    for NAME in $HOSTNAMES; do
        if grep -qE "\b$NAME\b" /etc/hosts; then
            FOUND=true
            break
        fi
    done

    if [ "$FOUND" = false ]; then
        echo "➕ Will add: $line"
        echo "$line" >> "$TMPFILE"
        ANY_CHANGES=true
    else
        echo "✔️  Already present: $line"
    fi
done < "$HOSTS_LIST"

if [ "$ANY_CHANGES" = true ]; then
    TIMESTAMP=$(date +%Y%m%d%H%M%S)
    BACKUP_FILE="/etc/hosts.bak.$TIMESTAMP"
    echo "📦 Backing up /etc/hosts to $BACKUP_FILE"
    sudo cp /etc/hosts "$BACKUP_FILE"

    echo "✍️ Appending new entries..."
    sudo tee -a /etc/hosts < "$TMPFILE" > /dev/null
    echo "✅ Update complete."
else
    echo "ℹ️  No new entries to add. Everything is up to date."
fi

rm -f "$TMPFILE" "$HOSTS_LIST"

