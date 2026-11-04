# Configuration Linux avec Ansible

Rôles **locaux**, uniquement `ansible.builtin` : aucun rôle Galaxy ni collection externe. Cibles : AlmaLinux 9. OS Login authentifie SSH ; le contrôleur joint les cibles en SSH privé. Le dossier est copié automatiquement par Terraform, sans lancer les rôles.

## Copie automatique lors du déploiement

`terraform_data.ansible_files` copie le contenu local de `ansible/` dans `~/ansible` sur le contrôleur, après sa création. La copie est relancée lorsque la VM est remplacée ou que les fichiers changent, sans recréer la VM pour une simple mise à jour de fichiers. Les caches de collections et `__pycache__` sont exclus.

Prérequis **sur le poste exécutant Terraform** : PowerShell 7 (`pwsh`), `tar`, client SSH, `gcloud auth login` et droits de lecture Compute/OS Admin Login. Le compte actif de `gcloud` doit pouvoir accéder à la VM ; si sa clé SSH est protégée par une phrase secrète, la charger dans un agent avant `apply` (copie non interactive).

Le Terraform actuel attribue une IP publique au contrôleur et autorise SSH depuis le `/24` détecté : la copie utilise SSH direct, pas IAP. Si la VM devient privée, il faudra un accès réseau adapté (VPN ou IAP avec les règles correspondantes) ; le script ne modifie pas les pare-feu. Aucune configuration réseau n'est changée par cette fonctionnalité.

La copie attend SSH, prépare un dossier privé, installe `tar`/`gzip` sur le contrôleur seulement s'ils manquent, puis transfère et extrait une archive via SSH. **Aucun playbook n'est exécuté.** Les fichiers portant le même nom sont actualisés ; les autres fichiers du contrôleur ne sont pas supprimés.

`.vault_password` est copiée si elle existe, protégée en `0600` sur la VM, mais n'est jamais lue ni hachée par Terraform. L'archive temporaire est protégée et nettoyée. Si la clé est absente localement, fournir/restaurer cette clé séparément sur le contrôleur : aucune nouvelle clé n'est générée.

L'inventaire local `inventory.ini` est copié tel quel. Après avoir régénéré cet inventaire depuis les outputs, relancer `terraform apply` pour recopier sa mise à jour. Pour forcer une copie (par exemple après restauration de la clé sans changement du Vault), depuis `terraform/` :

```powershell
terraform apply -replace=terraform_data.ansible_files
```

Un déploiement ciblant uniquement `google_compute_instance.ansible` ignore cette ressource de copie dépendante : utiliser un plan complet, ou cibler explicitement `terraform_data.ansible_files`.

## 1. Préparer le contrôleur (une fois)

Après `terraform apply`, **depuis `terraform/` sur le poste** disposant de `gcloud`, de lecture Compute et OS Admin Login :

```powershell
$project = "MON_PROJET"
$zone = "europe-west1-b"
$controller = (terraform output -json vm_names | ConvertFrom-Json).ansible
[System.IO.File]::WriteAllText("$PWD/../ansible/inventory.ini", ((terraform output -raw ansible_inventory) -join "`n"))
gcloud compute ssh $controller --project=$project --zone=$zone
```

Le contrôleur conserve une IP publique pour SSH direct, filtré par le `/24` de sortie détecté par AWS. Sur une image neuve, il utilise le serveur SSH de l'image AlmaLinux. En cas d'échec, ajouter `--troubleshoot` à la commande pour vérifier IAM et le réseau ; vérifier sshd/firewalld via la console série si nécessaire.

Ansible Core, Python et `passlib` sont installés automatiquement au premier démarrage par `terraform/scripts/install-ansible.sh`. Le script ne lance aucun playbook. Sur un contrôleur existant, installer `epel-release` puis `python3-passlib` avec `dnf`. Vérifier son exécution avec `ansible --version` après connexion. Puis générer une clé SSH pour les connexions privées du contrôleur :

```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519
```

Une phrase secrète est recommandée ; dans ce cas charger la clé avec `ssh-agent` / `ssh-add` avant Ansible. OpenSSL est disponible dans l'image AlmaLinux ; il est utilisé par les rôles.

Depuis le poste, **dans `terraform/`**, enregistrer la clé publique du contrôleur dans OS Login pour votre identité (validité 1 jour). Le dossier Ansible a déjà été transféré par Terraform :

```powershell
$publicKey = Join-Path $env:TEMP "vibe-ansible.pub"
gcloud compute scp "${controller}:~/.ssh/id_ed25519.pub" $publicKey --project=$project --zone=$zone
gcloud compute os-login ssh-keys add --key-file=$publicKey --ttl=1d --project=$project
```

La clé privée reste sur le contrôleur. Les VM utilisent le même compte OS Login ; le contrôleur peut joindre leurs IP privées en SSH grâce à la règle Terraform dédiée. Renouveler l'enregistrement de la clé après expiration. Aucun compte de service puissant ni secret SSH n'est créé par Terraform.

## 2. Mot de passe desktop avec Vault

Les deux fichiers sont déjà préparés pour le PoC et doivent être conservés :
- `vault/desktop_user.yml` : mot de passe et hash SHA-512 **chiffrés**, versionnables ;
- `.vault_password` : clé de déchiffrement **en clair**, ignorée par Git. La conserver et la sauvegarder séparément, avec permissions `0600` sur Linux ou ACL restrictives sur Windows.

Sur WSL, privilégier un dépôt dans le système de fichiers Linux. Sous `/mnt/c`, `chmod` peut être sans effet : restreindre les ACL de `.vault_password` sous Windows et retirer les droits d'exécution. Une clé exécutable est interprétée par Ansible comme un programme de fourniture de secret.

`ansible.cfg` lit la clé automatiquement : pas besoin de `--ask-vault-pass`. Le transfert de tout `ansible/` par SCP inclut aussi `.vault_password` ; ne la transférer que vers le contrôleur de confiance et appliquer `chmod 600 .vault_password`. Un clone Git seul n'inclut pas la clé.

```bash
ansible-vault view vault/desktop_user.yml  # Pour récupérer le mot de passe RDP.
```

Aucun outil de génération ou de rotation n'est nécessaire pour ce PoC. Si la clé est absente, la restaurer depuis sa sauvegarde : une nouvelle clé ne déchiffrera pas le Vault existant. Les secrets ne passent pas par Terraform, les arguments CLI ni les logs Ansible.

## 3. Exécuter les rôles

Sur le contrôleur, vérifier une première fois les clés d'hôte SSH via une connexion directe à chaque VM (ne pas désactiver leur vérification) :

```bash
chmod 700 ~/ansible
ssh "$(whoami)@10.20.0.11" hostname
ssh "$(whoami)@10.20.0.12" hostname
cd ~/ansible
chmod 600 .vault_password
ansible-playbook --syntax-check -i inventory.ini access.yml
ansible all -m ansible.builtin.ping -e "ansible_user=$(whoami)"
# Après vérification et accord explicite :
ansible-playbook access.yml -e "ansible_user=$(whoami)"
```

Si le nom POSIX OS Login diffère entre projets/comptes, fournir le nom correct dans `ansible_user`. L'inventaire réel est généré par Terraform ; `inventory.ini.example` sert uniquement à la validation syntaxique.

Les règles firewalld sont vérifiées puis ajoutées avec `firewall-cmd` via `ansible.builtin.command`. `common` active sshd et autorise SSH sur gateway/dev ; son handler recharge les règles permanentes lorsqu'elles ont changé. Aucune installation de collection n'est requise sur le contrôleur.

Après un changement d'IP publique de la passerelle, actualiser le state Terraform et régénérer/transférer l'inventaire. Un changement de votre réseau utilisateur `/24` nécessite `terraform plan` / `apply` pour actualiser HTTPS, SSH public gateway/Ansible et RDP public gateway via `local.cidr_24`. `terraform output vm_public_ips` contient gateway et Ansible ; aucun accès IAP n'est autorisé.

## 4. Se connecter en SSH et RDP

Depuis `terraform/`, obtenir les IP et le nom POSIX OS Login :

```powershell
$ips = terraform output -json vm_public_ips | ConvertFrom-Json
$loginName = gcloud compute os-login describe-profile --project=$project --format="value(posixAccounts[0].username)"
# Cette connexion prépare/enregistre normalement la clé gcloud du poste.
gcloud compute ssh $controller --project=$project --zone=$zone
```

Ajouter les blocs suivants dans `~/.ssh/config` du **poste**, sans écraser sa configuration existante. Remplacer les trois valeurs entre chevrons par les résultats ci-dessus. Si gcloud utilise une autre clé, adapter `IdentityFile` :

```sshconfig
Host vibe-gateway
    HostName <IP_GATEWAY>
    User <NOM_OS_LOGIN>
    IdentityFile ~/.ssh/google_compute_engine
    IdentitiesOnly yes

Host vibe-ansible
    HostName <IP_ANSIBLE>
    User <NOM_OS_LOGIN>
    IdentityFile ~/.ssh/google_compute_engine
    IdentitiesOnly yes

Host vibe-dev
    HostName 10.20.0.12
    User <NOM_OS_LOGIN>
    IdentityFile ~/.ssh/google_compute_engine
    IdentitiesOnly yes
```

```powershell
ssh vibe-ansible
ssh -J vibe-gateway vibe-dev
mstsc /v:$($ips.gateway):3389
```

Les clés privées restent sur le poste, sans `ssh -A`. Vérifier les clés d'hôte lors du premier accès. Le forwarding de la gateway est limité à `10.20.0.12:22` et `:3389` par `ssh_gateway`.

Pour RDP, choisir **Xorg**, utilisateur `developer`, mot de passe existant du Vault (consultable sur le contrôleur avec `ansible-vault view vault/desktop_user.yml`). Accepter le certificat auto-signé seulement après vérification pour ce PoC. Depuis un terminal XFCE sur la gateway :

```bash
xfreerdp /v:10.20.0.12 /u:developer /cert:tofu
```

Le mot de passe est saisi à l'invite, jamais dans la ligne de commande. Le même compte et mot de passe Vault sont utilisés sur gateway/dev pour ce PoC. Le RDP dev passe exclusivement par l'IP privée.

Alternative sans bureau intermédiaire : depuis le poste, `ssh -N -L 127.0.0.1:13389:10.20.0.12:3389 vibe-gateway`, puis `mstsc /v:127.0.0.1:13389` dans un autre terminal.

Vérifier sur les VM `sudo systemctl status xrdp xrdp-sesman` et, sur la gateway, `sudo sshd -T | grep -E 'allowtcpforwarding|permitopen|allowagentforwarding'`. Les règles Terraform et les vérifications syntaxiques ne prouvent pas le fonctionnement réel des services.

## Contenu et limites

| Rôle | Fonction | Tâches déclarées |
|---|---|---:|
| `common` | Dépôts CRB/EPEL, outils, SSH/firewalld, XFCE/Xorg et xrdp | 17 |
| `dev_desktop` | Compte Vault, client RDP gateway, TLS et pare-feu | 6 |
| `ssh_gateway` | Forwarding SSH limité à SSH/RDP dev | 1 |

`access.yml` est autonome et utilise uniquement ces trois rôles présents. `site.yml` importe aussi `access.yml`, mais ses rôles `guacamole` et `web_proxy` (ainsi que `postgresql` cité historiquement) sont absents du dépôt : sa validation/exécution complète reste bloquée jusqu'à leur restauration séparée. `common` est chargé comme dépendance locale. Les boucles/handlers et conditions font varier le nombre d'opérations réellement exécutées.

Le choix sans rôle préfait est **raisonnable pour ce PoC**, mais plus long à maintenir qu'un rôle existant. Le surcoût est concentré sur PostgreSQL (SQL via `psql`) et les services Guacamole/SELinux/HTTPS. Les téléchargements Apache sont vérifiés par SHA-256 ; modifier version et sommes ensemble. Les paquets AlmaLinux/EPEL restent gérés par DNF.

- Aucun conteneur, ni Docker ni Podman installés par ces rôles.
- Guacamole : `/etc/guacamole/`, Tomcat : `/etc/tomcat/`, données PostgreSQL : `/var/lib/pgsql/data/`.
- Le secret PostgreSQL est généré **sur la gateway**, conservé dans `/etc/guacamole/postgresql.password` (root, `0600`) et masqué avec `no_log` ; ne pas le committer.
- Compte initial web : `guacadmin` / `guacadmin`, à changer immédiatement. Mot de passe RDP local : défini par le rôle depuis Vault.
- Certificat auto-signé valable 90 jours : relancer les rôles avant expiration pour le renouveler ; aucune tâche planifiée de renouvellement n'est ajoutée.
- L'intégration LDAP/AD reste une étape séparée ; le réseau autorise TCP 389 (non chiffré sans StartTLS).
- Pas de migration automatique d'une installation en conteneurs ni de mise à niveau majeure PostgreSQL. Les rôles refusent les cas détectés plutôt que d'effacer des données. Pour le PoC, privilégier des VM neuves après sauvegarde des anciennes.
- Examiner le plan Terraform avant application : retirer les anciens scripts Linux peut entraîner un remplacement de VM selon le state/provider. Sauvegarder les données avant tout remplacement.
- `--syntax-check` ne valide pas l'installation réelle. Un premier `--check` sur une VM vierge peut être incomplet : certaines commandes dépendent de paquets/secret qui ne sont pas créés en mode simulation. Tester un déploiement puis une seconde exécution sur GCP pour confirmer le fonctionnement et l'idempotence.
