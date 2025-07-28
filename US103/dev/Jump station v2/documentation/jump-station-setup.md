# Jump Station Setup Notes

> Notes on how this jump station was installed, configured, and integrated with the homelab. This is not intended to be polished documentation—just a technical log for internal reference.

---

## 🖥️ Base Installation

        **Ubuntu Version:**  
        Ubuntu 25.04 Desktop

        **Install Method:**  
        XCP-ng VM → Ubuntu ISO mounted → Manual install via GUI

        **Disk Layout:**  
        - Disk 1 (xvda):  40 GiB
            -   xvda1 - /boot/efi (fast32)
            -   xvda2 - /   (ext4)

        - Disk 2 (xvdb):  20 GiB
            -   xvdb1 - /srv    (ext4)

        - Disk 3 (xvdc):  10 GiB
            -   xvdc1 - /home   (ext4)

        **Hostname:**  
        `bsus103jump01`

        ---

        ## 🔑 SSH Setup

        - SSH key generated via:  
        ```bash
        ssh-keygen -t ed25519 -C "jump station key"

## 🖥️ Post Installation


also add in tree to t he install

I ran:

# for xcp-ng tools:
        sudo mkdir /mnt/xcp
        sudo mount /dev/cdrom /mnt/xcp
        sudo bash /mnt/xcp/Linux/install.sh
        sudo umount /mnt/xcp
        sudo reboot

# for network:
    sudo nano /etc/netplan/99-custom.yaml
#  Here is the yaml for /etc/netplan/99-custom.yaml:
            network:
            version: 2
            renderer: NetworkManager
            ethernets:
                enX0:
                dhcp4: false
                addresses:
                    - 10.0.2.14/27
                routes: 
                    - to: default
                    via: 10.0.2.1
                nameservers:
                    search: [ad.infutable.com]
                    addresses:
                    - 10.0.1.2
                    - 10.0.1.3
                    - 10.0.2.1

#  vim setup
sudo apt install -y vim

#  the ~/.vimrc file:
        " General settings
        syntax on
        filetype plugin indent on
        set tabstop=2
        set shiftwidth=2
        set expandtab
        set autoindent
        set number
        set cursorline
        set showmatch

        " YAML-specific improvements
        autocmd FileType yaml,yml setlocal ts=2 sts=2 sw=2 expandtab
        autocmd FileType yaml,yml setlocal foldmethod=indent

        " Highlight trailing whitespace and reapply as needed
        highlight ExtraWhitespace ctermbg=red guibg=red
        autocmd BufWinEnter * match ExtraWhitespace /\s\+$/
        autocmd InsertEnter * match ExtraWhitespace /\s\+\%#\@<!$/
        autocmd InsertLeave * match ExtraWhitespace /\s\+$/

#  remove apps
        sudo apt purge -y evolution thunderbird libreoffice* aisleriot gnome-mahjongg gnome-mines gnome-sudoku
        sudo apt autoremove -y

gsettings set org.gnome.desktop.interface enable-animations false

wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
sudo install -o root -g root -m 644 packages.microsoft.gpg /etc/apt/trusted.gpg.d/
echo "deb [arch=amd64] https://packages.microsoft.com/repos/code stable main" | sudo tee /etc/apt/sources.list.d/vscode.list
sudo apt update
sudo apt install -y code

#  kubernetes 
curl -LO "https://dl.k8s.io/release/$(curl -Ls https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

chmod +x kubectl

sudo mv kubectl /usr/local/bin/

curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

#  xo-cli
sudo apt install -y nodejs npm
sudo npm install -g xo-cli

#  Make the config file for xo-cli access
#  for automation/scripting, need to create a file where you can put the <inserttokenhere> value, and put instructions at top of script to do that.

nano ~/.config/xo-cli/config.json
{
   "allowUnauthorized": true,
   "clientId": "4kai9zm7vmi",
   "server": "https://10.0.0.50",
   "token": "<inserttokenhere>"
 }

#  kubernetes and xcp-ng automation - add keys to hosts
ssh-keygen -t ed25519 -C "k8s-automation"
#       accepted default values
#  for automation, need to automate asking for a password with anything ssh-copy-id below:
ssh-copy-id bssadm@10.0.2.21
ssh-copy-id bssadm@10.0.2.22
ssh-copy-id bssadm@10.0.2.23

ssh-copy-id root@10.0.0.51
ssh-copy-id root@10.0.0.52
#  this host is off, will run this when needed later, for scripting just report and keep going:
ssh-copy-id root@10.0.0.53

Left off:  need to setup argocd cli, kubectl context, git repos, 