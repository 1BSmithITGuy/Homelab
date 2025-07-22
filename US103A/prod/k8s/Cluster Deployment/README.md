used Template-Ubuntu_2204_Srv_Base_v4

On all nodes:

sudo apt-get update
# apt-transport-https may be a dummy package; if so, you can skip that package
sudo apt-get install -y apt-transport-https ca-certificates curl gpg

From <https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/> 

These instructions are for Kubernetes v1.33.
	1. Update the apt package index and install packages needed to use the Kubernetes apt repository:
sudo apt-get update
# apt-transport-https may be a dummy package; if so, you can skip that package
sudo apt-get install -y apt-transport-https ca-certificates curl gpg
	2. Download the public signing key for the Kubernetes package repositories. The same signing key is used for all repositories so you can disregard the version in the URL:
# If the directory `/etc/apt/keyrings` does not exist, it should be created before the curl command, read the note below.
# sudo mkdir -p -m 755 /etc/apt/keyrings
	curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.33/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
	
	From <https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/> 
	
From <https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/> 


echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.33/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

From <https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/> 


sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

From <https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/> 

sudo systemctl enable --now kubelet

From <https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/> 

NOTE:  I installed containerd using a different mthod with chatgpt, which is the below method.  
		sudo apt update
		sudo apt install -y containerd
		
		sudo mkdir -p /etc/containerd
		containerd config default | sudo tee /etc/containerd/config.toml
		
		# Optional but recommended for kubeadm compatibility
		sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
		
		sudo systemctl restart containerd
		sudo systemctl enable containerd
		
	This also was chatgpt, for the cgroup driver:
		sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
		
		
	This also is chatgpt.  Ran on the master node:
			Run this command to enable IP forwarding:
			
			bash
			CopyEdit
			sudo sysctl -w net.ipv4.ip_forward=1
			Then make it persistent across reboots by editing the sysctl config:
			
			bash
			CopyEdit
			sudo nano /etc/sysctl.conf
			Add this line (or uncomment/modify it if it already exists):
			
			conf
			CopyEdit
			net.ipv4.ip_forward=1
			Then apply it:
			
			bash
			CopyEdit
			sudo sysctl -p
			
			✅ Re-run kubeadm:
			Now try again:
			
			bash
			CopyEdit
			sudo kubeadm init --pod-network-cidr=192.168.0.0/16
			
			mkdir -p $HOME/.kube
			  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
			  sudo chown $(id -u):$(id -g) $HOME/.kube/config
			
			kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/calico.yaml
			
	
	Chatgpt:  on the worker nodes:
	
			✅ On Worker Nodes — Required Steps
			1. Enable IP forwarding (YES)
			
			sudo sysctl -w net.ipv4.ip_forward=1
			And make it persistent:
			
			echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
				🔸 This is required so Calico can handle routing correctly on the worker nodes.
	
	
	
				✅ What you SHOULD do on workers:
				2. Run the kubeadm join command
				This connects the worker node to your control plane:
				
				bash
				CopyEdit
				sudo kubeadm join bsus103k-8m01:6443 --token 0l1zqj.7rnp61nfmv1k1euw --discovery-token-ca-cert-hash sha256:12bdec1e5ae7fb207b7997cf3a62fac37ec9bb8cbf736d81b896b8b193da30cd
				
				You get this from the output of kubeadm init.
				If you lost it, run this on the master:
				
				bash
				CopyEdit
				kubeadm token create --print-join-command
				
				✅ Final Check After Joining
				Back on the master node, run:
				
				bash
				CopyEdit
				kubectl get nodes
				You should now see:
				
				pgsql
				CopyEdit
				NAME              STATUS   ROLES           AGE   VERSION
bsus103k-8m01     Ready    control-plane   15m   v1.33.2
worker-node-01    Ready    <none>          2m    v1.33.2
worker-node-02    Ready    <none>          2m    v1.33.2

#  for k8s shutdown script from a jump station, on each node/master:  
  sudo visudo
  # add to bottom of file: bssadm ALL=(ALL) NOPASSWD: /sbin/shutdown
