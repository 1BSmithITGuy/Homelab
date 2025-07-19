#  I had made changes to VIM from the k8s fundementals class, installed kubectl and a lot of other stuff for the class, and also installed vscode.
#  This was using the non-lts ubuntu release because of the RDP support

#  setup xo-cli so I could execute scripts on Xen Orchestra
sudo apt install -y nodejs npm
sudo npm install -g xo-cli
xo-cli --url https://your-xo-server --token your-token vm.list

