# Consignes du projet

- Objectif : PoC GCP d'une plateforme de vibe-coding, puis cible self-hostée sur VM et services natifs.
- Répondre et documenter en français, à l'essentiel.
- Infrastructure dans `terraform/`, configuration Linux dans `ansible/`. Seul AD conserve un script de démarrage.
- Aucun conteneur : Guacamole/guacd, Tomcat, PostgreSQL et Nginx natifs. Rôles Ansible locaux, uniquement modules `ansible.builtin`, aucun rôle Galaxy ni collection externe. Configurer firewalld via les commandes natives avec vérification préalable et handler de rechargement.
- Ne pas supprimer ni réinitialiser les données d'une ancienne installation ; migration séparée, privilégier des VM neuves.
- Garder le PoC simple : quatre ressources VM explicites, dont un contrôleur Ansible AlmaLinux sans GUI ; tailles en dur dans `main.tf`, pas d'activation d'API ni de comptes de service dédiés. Détecter l'IP utilisateur via AWS checkip à chaque plan.
- Seule la gateway a une IP publique, avec HTTPS limité à `${local.my_ip}/24`, réseau /24 de l'IPv4 détectée par AWS. AD, dev et le contrôleur Ansible restent privés. Les règles admin actuelles autorisent SSH des trois VM Linux et RDP AD depuis `${local.my_ip}/24`, pas les relais IAP. Conserver SSH privé du contrôleur vers gateway/dev et RDP dev privé depuis la passerelle.
- Aucun secret en clair dans Git, les variables Terraform ou les scripts de démarrage. Les fichiers Vault chiffrés sont versionnables ; `ansible/.vault_password` doit rester local, protégé et ignoré par Git. Ne pas versionner le state ; conserver le fichier de verrouillage des providers.
- Conserver SELinux actif, les versions Guacamole explicites et les rôles relançables ; protéger les tâches contenant des secrets avec `no_log`.
- Vérifier avec `terraform fmt -check -recursive`, `terraform validate` et `terraform test` depuis `terraform/`.
- Vérifier Ansible avec `ansible-playbook --syntax-check -i inventory.ini.example site.yml` depuis `ansible/`. Ne pas appliquer les rôles sans accord explicite.
- Ne pas exécuter `terraform apply` ou `destroy` sans accord explicite. Un plan ne valide pas le fonctionnement des services dans les VM.
