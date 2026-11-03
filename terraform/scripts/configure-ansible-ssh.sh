#!/bin/bash
# Installer la clé SSH générée par Terraform une fois son transfert terminé.
set -euo pipefail

# Lire le nom du compte depuis les métadonnées de la VM.
metadata_url="http://metadata.google.internal/computeMetadata/v1/instance/attributes"
ansible_user="$(curl -fsS -H "Metadata-Flavor: Google" "$metadata_url/ansible-user")"

# Créer le compte si le démarrage du script précède sa création par l'agent GCE.
if ! id "$ansible_user" >/dev/null 2>&1; then
  useradd --create-home --shell /bin/bash "$ansible_user"
fi

ansible_home="$(getent passwd "$ansible_user" | cut -d: -f6)"
ansible_group="$(id -gn "$ansible_user")"
staged_key="$ansible_home/ansible-ssh-key.pending"
target_key="$ansible_home/.ssh/id_ed25519"

# Le provisioner file transfère la clé après la création de la VM.
# Attendre son arrivée plutôt que de l'exposer dans les métadonnées.
for attempt in {1..150}; do
  if [[ -s "$staged_key" ]]; then
    break
  fi
  sleep 2
done

if [[ ! -s "$staged_key" ]]; then
  echo "La clé SSH transférée par Terraform est introuvable." >&2
  exit 1
fi

# Créer le répertoire SSH et installer la clé avec un accès réservé à son compte.
install -d -m 700 -o "$ansible_user" -g "$ansible_group" "$ansible_home/.ssh"
install -m 600 -o "$ansible_user" -g "$ansible_group" "$staged_key" "$target_key"
rm -f "$staged_key"
