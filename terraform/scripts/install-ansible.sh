#!/bin/bash
# Activer le mode strict pour arrêter le script dès qu'une erreur est détectée
set -euo pipefail

# Les rôles utilisent uniquement ansible.builtin : ansible-core suffit.
dnf install -y ansible-core python3 openssh-clients

ansible --version