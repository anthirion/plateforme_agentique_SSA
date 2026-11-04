# Rôle `common`

Prépare les VM AlmaLinux 9 pour leur administration et, lorsqu'un bureau est installé, leur accès graphique XFCE par RDP. Le rôle configure les outils de base, SSH, le pare-feu, le compte desktop et xrdp.

## Prérequis

- Les hôtes gérés utilisent AlmaLinux 9.
- Le contrôleur dispose d'Ansible Core et de `passlib`. Ces dépendances sont installées lors de sa préparation par `terraform/scripts/install-ansible.sh`.
- Le fichier de secrets Ansible Vault et sa clé locale doivent être disponibles pour déchiffrer les identifiants desktop.

## Architecture et sécurité

Le nom du compte et son mot de passe sont définis dans `default/desktop_user.yml`. Le mot de passe y est chiffré avec Ansible Vault ; le compte système reçoit un hash SHA-512 à sel stable, ce qui rend les exécutions répétées idempotentes. Le compte sert aux sessions XFCE via xrdp.

## Structure du rôle

```text
common/
├── default/
│   └── desktop_user.yml  # Identifiants desktop protégés par Vault
├── handlers/
│   └── main.yml          # Actions de redémarrage des services
├── meta/
│   └── main.yml          # Métadonnées du rôle
└── tasks/
    ├── main.yml          # Préparation commune des VM AlmaLinux
    └── desktop.yml       # Compte desktop, XFCE et accès xrdp
```
