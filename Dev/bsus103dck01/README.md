# for udemy k8s course
# ubuntudev - hostname
# note:  these steps need to be modified, I removed the newest minicube to be able to work with rancher.  See note below, I have not updated the whole process to include this.
        #  note:  had to remove another version


installed from iso, not template

sudo apt update && sudo apt upgrade -y

sudo apt install xe-guest-utilities

sudo apt install -y curl wget htop unzip bash-completion net-tools dnsutils traceroute iputils-ping telnet

I added custom .bashrc to /etc/skel and /root - both are different from each other.  

sudo apt update
sudo apt install -y ca-certificates curl gnupg lsb-release

sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Add your user to the docker group (then log out and back in)
sudo usermod -aG docker $USER

curl -LO "https://dl.k8s.io/release/$(curl -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

chmod +x kubectl
sudo mv kubectl /usr/local/bin/

curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube

# Start Minikube with Docker as the driver
minikube start --driver=docker

docker run -d -p 5000:5000 --name registry registry:2

nano Dockerfile
    *  note:  put this in the file:
        FROM nginx:alpine
        COPY index.html /usr/share/nginx/html/index.html

  echo "Hello from my custom NGINX container!" > index.html
  docker build -t localhost:5000/myapp:v1 .
  docker push localhost:5000/myapp:v1
image: localhost:5000/myapp:v1

curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

#  install Rancher:
helm repo add rancher-latest https://releases.rancher.com/server-charts/latest
helm repo update

kubectl create namespace cattle-system

#  had to delete minicube newest version because of rancher
minikube delete
minikube start --kubernetes-version=v1.32.4
kubectl create namespace cattle-system
helm repo add jetstack https://charts.jetstack.io
helm repo update

kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.2/cert-manager.crds.yaml

helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.13.2

#  wrong version, again!!  installing another version.
        minikube delete
        minikube start --kubernetes-version=v1.27.9

        kubectl create namespace cattle-system
        helm repo add jetstack https://charts.jetstack.io
        helm repo update

        kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.2/cert-manager.crds.yaml

        helm install cert-manager jetstack/cert-manager \
        --namespace cert-manager \
        --create-namespace \
        --version v1.13.2

        helm install rancher rancher-latest/rancher \
  --namespace cattle-system \
  --create-namespace \
  --set replicas=1 \
  --set hostname=rancher.localhost \
  --set bootstrapPassword=admin \
  --version 2.8.2

  $kubectl patch svc rancher -n cattle-system -p '{"spec": {"type": "NodePort"}}'


kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.9.0/deploy/static/provider/cloud/deploy.yaml