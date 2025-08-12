#  deploying argocd in kubernetes

kubectl create namespace argocd

kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

#  started following https://www.youtube.com/watch?v=8AJlVQy6Cx0

k -n argocd edit svc argocd-server
#  changed "type:" to "NodePort" from "clusterIP"
#  "k get svc" now shows NodePort for "type"
#  I can now access from either the master IP or the IP of the node the argo-cdserver pod is on

k get secret -n argocd
k get secrets -n argocd argocd-initial-admin-secret -o json
#  you will see the admin password in here, but it is encoded.  

#  to decode the password:
k get secrets -n argocd argocd-initial-admin-secret -o json | jq .data.password -r | base64 -d

brew install argocd
#  installed on local jump workstation, not in the cluster.  

argocd login 10.0.2.20:32533
#  same IP and port that the web UI is on

#  when deploying from repo, ./ is the root
./Dev/argoCD/Demos/Solar System

# To uninstall the above:
kubectl delete -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

kubectl delete ns argocd --ignore-not-found

kubectl get validatingwebhookconfigurations,mutatingwebhookconfigurations -o name | grep -i argocd | xargs -r kubectl delete

