# Changelog

## Fiabilisation du provisioning Vagrant/Ansible

Le `vagrant up` initial échouait systématiquement avant d'atteindre un cluster
fonctionnel. Détail des correctifs apportés dans `install_kubernetes.sh` et
`roles/requirements.yml` :

- **Fichiers de configuration introuvables** : `install_kubernetes.sh`
  référençait `roles/requirements.yaml` et `install_kubernetes.yaml`, alors
  que les fichiers présents dans le repo sont nommés `requirements.yml` et
  `install_kubernetes.yml` (extension `.yml`, sans le `a`). Le script
  échouait dès la première étape faute de trouver ces fichiers.

- **Rôle Ansible introuvable au moment de l'exécution** :
  `roles/requirements.yml` installait le rôle Galaxy sous le nom
  `ulrich-sun.kubernetes`, alors que `install_kubernetes.yml` référence un
  rôle nommé `kubernetes` (et `install_kubernetes.sh` fait
  `ansible-galaxy remove kubernetes`). Le rôle est désormais installé
  localement sous le nom `kubernetes` (`src: ulrich-sun.kubernetes` /
  `name: kubernetes`), pour correspondre à ce que le reste de la
  configuration attend.

- **Dépendance à un dépôt externe non maîtrisé** : le rôle Galaxy provenait
  du dépôt personnel `ulrich-sun/ansible-roles-kubernetes`. Il est
  maintenant récupéré depuis le fork `eazytraining/ansible-roles-kubernetes`,
  pour ne plus dépendre d'un dépôt tiers qui pourrait être supprimé, renommé
  ou modifié sans préavis.

- **Blocage sur le verrou dpkg au premier démarrage** : sur une VM tout juste
  créée, `unattended-upgrades` tourne en tâche de fond et détient le verrou
  `apt` pendant plusieurs minutes. `install_kubernetes.sh` échouait
  immédiatement au lieu d'attendre. Un délai d'attente
  (`DPkg::Lock::Timeout`) a été ajouté pour qu'`apt` patiente jusqu'à la
  libération du verrou avant d'abandonner.

Ces correctifs ont été validés par un `vagrant up` complet : les deux
machines (master et worker) se créent, Kubernetes s'installe sur le master,
et le worker rejoint automatiquement le cluster.
