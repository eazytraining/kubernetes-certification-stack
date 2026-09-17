#!/bin/bash
set -e

ROLE=$1
MASTER_IP=$2

echo "Role: $ROLE"
echo "Master IP: $MASTER_IP"

# Au premier boot d'une VM Ubuntu fraiche, unattended-upgrades peut tenir
# le verrou dpkg pendant tres longtemps (mise a jour noyau/systemd/etc.),
# et un simple stop/disable ne l'empeche pas de redemarrer en cours de
# route (timer/dependance). On le masque : aucun moyen de le (re)lancer
# tant qu'on ne le demasque pas explicitement.
sudo systemctl mask --now unattended-upgrades.service apt-daily.service apt-daily-upgrade.service apt-daily.timer apt-daily-upgrade.timer 2>/dev/null || true
sudo killall -9 unattended-upgrade 2>/dev/null || true
sleep 2
sudo rm -f /var/lib/dpkg/lock-frontend /var/lib/apt/lists/lock /var/cache/apt/archives/lock
sudo dpkg --configure -a

# Garde-fou : si le verrou est malgre tout repris plus tard (tache apt du
# role Ansible), attendre au lieu d'echouer immediatement
echo 'DPkg::Lock::Timeout "600";' | sudo tee /etc/apt/apt.conf.d/99-dpkg-lock-timeout > /dev/null

# Mettre à jour les paquets
sudo apt update -y
# sudo apt upgrade -y

# Installer Ansible + Git
sudo apt -y install software-properties-common
sudo add-apt-repository --yes --update ppa:ansible/ansible
sudo apt -y install ansible git


# Installer le rôle depuis Galaxy
ansible-galaxy remove kubernetes
ansible-galaxy install -r /vagrant/roles/requirements.yml

export K8S_MASTER_IP=$MASTER_IP

# Lancer le playbook
if [ "$1" == "master" ]; then
    ansible-playbook /vagrant/install_kubernetes.yml \
    --extra-vars "kubernetes_role=$ROLE kubernetes_apiserver_advertise_address=$K8S_MASTER_IP installation_method=vagrant"
else
    ansible-playbook /vagrant/install_kubernetes.yml \
      --extra-vars "kubernetes_role=$ROLE kubernetes_apiserver_advertise_address=$K8S_MASTER_IP installation_method=vagrant kubernetes_join_command='kubeadm join $K8S_MASTER_IP:6443 --ignore-preflight-errors=all --token={{ token }} --discovery-token-unsafe-skip-ca-verification'"
fi
