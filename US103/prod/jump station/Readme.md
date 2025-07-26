#  I had made changes to VIM from the k8s fundementals class, installed kubectl and a lot of other stuff for the class, and also installed vscode.
#  This was using the non-lts ubuntu release because of the RDP support

#  setup xo-cli so I could execute scripts on Xen Orchestra
sudo apt install -y nodejs npm
sudo npm install -g xo-cli

# -------------------------------------------------------------------
#  to get xo-cli to work, create a token under the automation user.
#  then do the following:
mkdir -p ~/.config/xo-cli
nano ~/.config/xo-cli/config.json
#  {
#  "allowUnauthorized": true,
#  "clientId": "4kai9zm7vmi",
#  "server": "https://10.0.0.50",
#  "token": "paste new token here"
# }
# -------------------------------------------------------------------

# ----------------------------------------------
#  this is to run scripts off the jump station onto k8s nodes
 ssh-keygen -t ed25519 -C "k8s-automation"
#      #  accept defaults on all prompts
  
ssh-copy-id your-username@<node-ip>
#     #  use the username to login to the node
#     #  do this for each node/master
# ----------------------------------------------

# ----------------------------------------------
#  this is to run scripts directly into the xcp-ng hosts, xo-cli doesn't work for shutdown of a VM
ssh-copy-id root@10.0.0.51
ssh-copy-id root@10.0.0.52
ssh-copy-id root@10.0.0.53
# ----------------------------------------------

#  had to install tools from iso to get IP reporting