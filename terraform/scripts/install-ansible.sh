#!/bin/bash
# Activer le mode strict pour arrêter le script dès qu'une erreur est détectée
set -euo pipefail

# Passlib est utilisé par Ansible sur le contrôleur pour les mots de passe.
dnf install -y epel-release
dnf install -y ansible-core python3 python3-passlib openssh-clients

ansible --version
