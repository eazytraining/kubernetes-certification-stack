# kubernetes-certification-stack

## Prérequis

Environnement testé et validé avec :

- **Vagrant** 2.4.1 ou supérieur
- **VirtualBox** 7.0.x

> Un avertissement `Guest Additions Version ... do not match the installed
> version of VirtualBox` peut s'afficher au démarrage des VM (la box embarque
> des Guest Additions en version 6.0) — sans impact, à ignorer.

## Arrêt des VM

Toujours arrêter les VM proprement avant d'éteindre la machine hôte :

```bash
vagrant halt
```

Éteindre l'hôte pendant que les VM tournent (ou sont suspendues) peut
corrompre le datastore `etcd` du cluster (coupure en plein milieu d'une
écriture), rendant le control-plane inutilisable et nécessitant une
réinitialisation complète (voir `CHANGELOG.md`).
