# Rôle `common`

Ce rôle prépare uniquement les VM AlmaLinux 9 en installant les outils communs, SSH et un bureau XFCE accessible en RDP.

## Prérequis

- La VM cible doit utiliser AlmaLinux 9 (`Vérifier la distribution cible`).

## Tâches

- Installation des outils communs (`dnf-plugins-core`, `firewalld`, `openssh-server`, `openssl`, `policycoreutils-python-utils`, `tar`, `gzip`).
- Activation des dépôts CRB et EPEL.
- Activation de SSH et ajout de la règle firewalld si nécessaire.
- Installation de XFCE, Xorg, xrdp et de ses composants Xorg.
- Configuration de xrdp pour lancer les sessions sous XFCE.
