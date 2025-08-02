Had to do the following to get this to work:

kubectl create secret generic db-secret --from-literal=db-encryption-key=<SECRET_ENCRYPTION_KEY_SECRET_TO_CHANGE> --namespace homar

helm install homarr homarr-labs/homarr -f values.yaml -n homarr

