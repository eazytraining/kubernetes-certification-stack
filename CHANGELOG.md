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

## Réseau inter-nœuds (rôle `kubernetes` v1.0.7 et v1.0.8)

Chaque VM Vagrant a deux interfaces : `enp0s3` (NAT, IP `10.0.2.15`
**identique sur chaque VM**, injoignable entre nœuds) et `enp0s8` (réseau
privé `192.168.99.x`, unique par VM). Par défaut, Kubernetes et Flannel
choisissent l'interface de la route par défaut, donc le NAT.

- **`kubectl logs` / `kubectl exec` en `NotFound` sur les pods du worker**
  (v1.0.7) : kubelet annonçait `10.0.2.15` comme IP du nœud sur le master
  et sur le worker. L'apiserver, pour joindre le kubelet du worker,
  retombait sur son propre kubelet. Le rôle écrit désormais
  `/etc/default/kubelet` avec `--node-ip=<IP de k8s_interface>` avant le
  démarrage de kubelet.

- **Échecs DNS depuis les pods du worker** (v1.0.8) : les deux nœuds
  annonçaient la même extrémité de tunnel VXLAN (`10.0.2.15`), les pods du
  worker ne joignaient donc pas CoreDNS (sur le master). Le rôle injecte
  désormais `--iface={{ k8s_interface }}` dans les arguments du DaemonSet
  `kube-flannel` avant de l'appliquer.

Dans les deux cas, la variable `k8s_interface` (`enp0s8` par défaut) du rôle
était définie mais jamais utilisée.

- **Trafic vers les IP de Service bloqué entre nœuds** (v1.0.9) : même après
  les correctifs ci-dessus, une connexion locale vers une IP de Service
  (ex. `10.96.0.1`, utilisée par Flannel et CoreDNS pour joindre l'API)
  pouvait repartir avec l'IP de l'interface NAT comme source — le noyau
  choisit la source avant que le DNAT d'iptables ne s'applique, et la
  destination d'origine (une IP virtuelle) ne correspond à aucune route
  spécifique, donc tombe sur la route par défaut (NAT). Le nœud distant
  recevait alors un paquet à la source incohérente avec sa table de
  routage et le rejetait silencieusement, bloquant tout trafic vers les
  IP de Service depuis un nœud non-master (`CrashLoopBackOff` en boucle
  sur Flannel et CoreDNS). Le rôle active désormais `masqueradeAll: true`
  sur le ConfigMap `kube-proxy` juste après l'initialisation du master,
  pour forcer la réécriture systématique de l'adresse source.

Ce dernier bug a été découvert après une corruption du datastore etcd
(suite à un arrêt brutal du PC hôte pendant que les VM tournaient) ayant
nécessité une réinitialisation complète du control-plane — voir la section
Prérequis du README pour la bonne procédure d'arrêt (`vagrant halt`).
