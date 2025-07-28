# 🖥️ Jump Station Setup

> Setup and configuration notes for `bsus103jump01`, the Ubuntu jump station used to manage the homelab infrastructure.  
> Built on XCP-ng and configured for daily administrative tasks, Kubernetes management, and automation workflows.

---

## 📦 Base Installation

- **Ubuntu Version:** Ubuntu 25.04 Desktop  
- **Install Method:** XCP-ng VM → Manual install via ISO  
- **Hostname:** `bsus103jump01`  
- **Username:** `bryan`  

### 💾 Disk Layout

| Disk   | Mount Point | Size  | FS   | Notes             |
|--------|-------------|-------|------|-------------------|
| xvda   | `/`, `/boot`| 40 GB | ext4 | OS root + boot    |
| xvdb   | `/srv`      | 20 GB | ext4 | For Git repositories and data |
| xvdc   | `/home`     | 10 GB | ext4 | Separate user home directory  |

---

## ⚙️ Post-Installation Configuration

<details>
<summary><strong>XCP-ng Tools</strong></summary>

```bash
sudo mkdir /mnt/xcp
sudo mount /dev/cdrom /mnt/xcp
sudo bash /mnt/xcp/Linux/install.sh
sudo umount /mnt/xcp
sudo reboot
```
</details>

<details>
<summary><strong>Network Configuration (/etc/netplan/99-custom.yaml)</strong></summary>

```yaml
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
```
</details>

<details>
<summary><strong>Desktop Tweaks</strong></summary>

```bash
gsettings set org.gnome.desktop.interface enable-animations false
gsettings set org.gnome.desktop.session idle-delay 600  # 10 minutes
gsettings set org.gnome.desktop.screensaver lock-delay 0
```

Uninstalled unnecessary apps:

```bash
sudo apt purge -y evolution thunderbird libreoffice* aisleriot gnome-mahjongg gnome-mines gnome-sudoku
sudo apt autoremove -y
```

Installed `vim` and `.vimrc` with YAML enhancements:

```bash
sudo apt install -y vim
```

`~/.vimrc`:
```vim
syntax on
filetype plugin indent on
set tabstop=2 shiftwidth=2 expandtab autoindent
set number cursorline showmatch

autocmd FileType yaml,yml setlocal ts=2 sts=2 sw=2 expandtab
autocmd FileType yaml,yml setlocal foldmethod=indent

highlight ExtraWhitespace ctermbg=red guibg=red
autocmd BufWinEnter * match ExtraWhitespace /\s\+$/
autocmd InsertEnter * match ExtraWhitespace /\s\+\%#\@<!$/
autocmd InsertLeave * match ExtraWhitespace /\s\+$/
```
</details>

---

## 🔧 Essential Software Setup

```bash
sudo apt install -y tree git curl jq htop unzip build-essential   nodejs npm vim code remmina
```

**Visual Studio Code (manual install steps):**

```bash
wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
sudo install -o root -g root -m 644 packages.microsoft.gpg /etc/apt/trusted.gpg.d/
echo "deb [arch=amd64] https://packages.microsoft.com/repos/code stable main" | sudo tee /etc/apt/sources.list.d/vscode.list
sudo apt update
sudo apt install -y code
```

---

## 🔑 SSH Keys for Automation

```bash
ssh-keygen -t ed25519 -C "k8s-automation"
```

Deploy keys:

```bash
ssh-copy-id bssadm@10.0.2.20
ssh-copy-id bssadm@10.0.2.21
ssh-copy-id bssadm@10.0.2.22
ssh-copy-id root@10.0.0.51
ssh-copy-id root@10.0.0.52
ssh-copy-id root@10.0.0.53  # Offline — script handles gracefully
```

---

## ☸️ Kubernetes Tools

### kubectl

```bash
curl -LO "https://dl.k8s.io/release/$(curl -Ls https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
```

### Helm

```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

### ArgoCD CLI

```bash
ARGO_VERSION=$(curl -s https://api.github.com/repos/argoproj/argo-cd/releases/latest | grep tag_name | cut -d '"' -f 4)
curl -sSL -o argocd "https://github.com/argoproj/argo-cd/releases/download/${ARGO_VERSION}/argocd-linux-amd64"
sudo install -m 555 argocd /usr/local/bin/argocd
rm argocd
```

---

## 💾 Git Repo and Group Access Setup

```bash
sudo groupadd gitadmins
sudo usermod -aG gitadmins bryan
sudo mkdir -p /srv/repos
sudo chown root:gitadmins /srv/repos
sudo chmod 2770 /srv/repos
```

Clone repo:

```bash
git clone git@github.com:1BSmithITGuy/Homelab.git /srv/repos/Homelab
git config --global user.email "you@example.com"
```

---

## 🔁 Kubernetes Context Merge

Copied files:
- From kubeadm master: `/etc/kubernetes/admin.conf`
- From k3s node: `/etc/rancher/k3s/k3s.yaml → config-k3sonly.bak`

Merge contexts:
```bash
KUBECONFIG=~/.kube/config:~/.kube/config-k3sonly.bak kubectl config view --flatten > ~/.kube/config.merged
cp ~/.kube/config.merged ~/.kube/config
export KUBECONFIG=~/.kube/config
```

Manually updated names in merged config:

```yaml
contexts:
- name: us103-kubeadm01
  context:
    cluster: us103-kubeadm01_cluster
    user: us103kubeadm01-admin
- name: us103-k3s01
  context:
    cluster: us103-k3s01_cluster
    user: us103k3s01-admin
current-context: us103-k3s01
```

---

## 🧪 TODO

- [ ] Add `.bashrc` templates to `/etc/skel` and `/root`
- [ ] Finalize ArgoCD CLI and kubectl context helper scripts
- [ ] Add automated backup routine for `/srv/repos`
- [ ] Create template from this VM (remove keys, history, temp files)

---

## 🗓️ Setup Timeline

| Date       | Event                                    |
|------------|------------------------------------------|
| 2025-07-27 | Ubuntu installed, disk layout finalized  |
| 2025-07-28 | XO CLI, ArgoCD, SSH, and Git configured  |
| TBD        | Create Git-backed template for reuse     |
