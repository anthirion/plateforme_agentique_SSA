# Guide du dépôt

## Structure du projet et organisation des modules

- Objectif : réaliser un PoC GCP d’une plateforme de vibe-coding agentique. Cette plateforme sera hébergée sur des VM.
- Les VM seront régulièrement détruites et reconstruites dans le cadre du PoC. Automatiser au maximum leur initialisation et leur configuration afin qu’une reconstruction permette de retrouver rapidement un environnement opérationnel, sans étapes manuelles récurrentes.
- `terraform/` contient l’infrastructure GCP ; `ansible/` contient la configuration Linux et ses rôles locaux.
- `ansible/main.yml` est le playbook principal.
- Les scripts de démarrage, dans `terraform/scripts/`, sont réservés à la préparation d’AD et à l’installation d’Ansible sur le contrôleur.
- Écrire du code simple, adapté à un PoC, et documenter en français à l’essentiel.

## Style de code et conventions de nommage

- Terraform :
  - Indentation de deux espaces.
  - Noms `snake_case` pour les variables et ressources.
  - Garder une configuration simple : ne pas surutiliser les variables (ex: définir les tailles des VM en dur).
- Ansible :
  - Éviter au maximum les rôles externes ; privilégier les rôles locaux et les modules `ansible.builtin`, en particulier `ansible.builtin.command` ou `ansible.builtin.shell` lorsque des commandes système sont nécessaires. Ne pas ajouter de rôle Galaxy ni de collection externe.
- Configurer Guacamole/guacd, Tomcat, PostgreSQL et Nginx comme services natifs, sans conteneurs. Configurer les autres services Linux avec des rôles Ansible, pas avec des scripts de démarrage.
- Configurer firewalld avec ses commandes natives, vérifier l’état avant modification et déclencher son rechargement avec un handler. Ne pas utiliser de module firewalld non builtin.

## Sécurité et configuration

- Ne pas activer d’API GCP ni créer de comptes de service dédiés pour ce PoC.
- Les règles d’administration autorisent SSH vers les trois VM Linux et RDP vers AD ; ne pas utiliser de relais IAP. Garder SSH privé du contrôleur Ansible vers la gateway et la VM dev, ainsi que RDP privé de la gateway vers la VM dev.
- Ajouter `no_log: true` aux tâches Ansible qui manipulent des secrets.

## Vérifications et opérations

- Depuis `terraform/`, vérifier la configuration avec `terraform fmt -check -recursive`, `terraform validate` et `terraform test`.
- Ne pas appliquer les rôles Ansible sans accord explicite.
- Ne pas exécuter `terraform apply` ni `terraform destroy` sans accord explicite.
- Ne pas exécuter de commandes git.
