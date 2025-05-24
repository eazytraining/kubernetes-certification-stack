#!/bin/bash
set -e

sudo apt update
sudo apt install -y software-properties-common

# Ajouter le PPA d'Ansible
echo "Ajout du PPA d'Ansible..."
sudo add-apt-repository -y ppa:ansible/ansible

sudo apt update
# Installer Ansible
sudo apt install -y ansible

# Optionally, remove previous directory and retrieve project
rm -Rf kubernetes-certification-stack || echo "previous folder removed"
git clone -b v1.32 https://github.com/eazytraining/kubernetes-certification-stack.git
cd kubernetes-certification-stack/ubuntu

KUBERNETES_VERSION=1.32.1

ansible-galaxy install -r roles/requirements.yml
ansible-galaxy collection install -r roles/requirements.yml

# Detect network interface (adapt if needed)
IFACE="enp0s8"
IP_ADDR=$(ip -f inet addr show $IFACE | sed -En -e 's/.*inet ([0-9.]+).*/\1/p')

if [ "$1" == "master" ]
then
    ansible-playbook install_kubernetes.yml --extra-vars "kubernetes_role=control_plane kubernetes_apiserver_advertise_address=$2 kubernetes_version=$KUBERNETES_VERSION installation_method=vagrant"
    sudo apt -y install bash-completion
    kubectl completion bash | sudo tee /etc/bash_completion.d/kubectl > /dev/null
    echo "###################################################"
    echo "For this Stack, you will use $IP_ADDR IP Address"
    echo "You need to be root to use kubectl in $IP_ADDR VM (run 'sudo su -' to become root and then use kubectl as you want)"
    echo "###################################################"
else
    ansible-playbook install_kubernetes.yml --extra-vars "kubernetes_role=$1 kubernetes_apiserver_advertise_address=$2 kubernetes_version=$KUBERNETES_VERSION kubernetes_join_command='kubeadm join $2:6443 --ignore-preflight-errors=all --token={{ token }} --discovery-token-unsafe-skip-ca-verification'"
    echo "For this Stack, you will use $IP_ADDR IP Address"
fi
