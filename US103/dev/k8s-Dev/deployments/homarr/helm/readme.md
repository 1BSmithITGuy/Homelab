#  Had to do the following to get this to work:

kubectl create secret generic db-secret --from-literal=db-encryption-key=<SECRET_ENCRYPTION_KEY_SECRET_TO_CHANGE> --namespace homar
#  you do not need to keep doing this unless you delete the secret or maybe namespace.

#  to install
helm install homarr homarr-labs/homarr -f values.yaml -n homarr

#  to update/upgrade
helm upgrade -n homarr homarr homarr-labs/homarr --values=values.yaml


