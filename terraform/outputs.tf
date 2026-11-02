output "guacamole_url" {
  description = "HTTPS avec certificat auto-signé pour le PoC."
  value       = "https://${google_compute_instance.gateway.network_interface[0].access_config[0].nat_ip}/guacamole/"
}

output "vm_private_ips" {
  value = {
    ad      = google_compute_instance.ad.network_interface[0].network_ip
    gateway = google_compute_instance.gateway.network_interface[0].network_ip
    dev     = google_compute_instance.dev.network_interface[0].network_ip
    ansible = google_compute_instance.ansible.network_interface[0].network_ip
  }
}

output "vm_names" {
  value = {
    ad      = google_compute_instance.ad.name
    gateway = google_compute_instance.gateway.name
    dev     = google_compute_instance.dev.name
    ansible = google_compute_instance.ansible.name
  }
}

output "authorized_web_ip" {
  value = local.my_ip
}

output "my_ip" {
  description = "IP de sortie détectée, dont le réseau /24 est autorisé pour HTTPS sur la gateway."
  value       = local.my_ip
}

output "vm_public_ips" {
  description = "Seules la gateway et le contrôleur Ansible possèdent une IP publique."
  value = {
    gateway = google_compute_instance.gateway.network_interface[0].access_config[0].nat_ip
    ansible = google_compute_instance.ansible.network_interface[0].access_config[0].nat_ip
  }
}

output "ansible_inventory" {
  description = "Inventaire à enregistrer dans ansible/inventory.ini après apply."
  value       = <<-INI
    [gateways]
    gateway ansible_host=${google_compute_instance.gateway.network_interface[0].network_ip} gateway_public_ip=${google_compute_instance.gateway.network_interface[0].access_config[0].nat_ip}

    [development]
    dev ansible_host=${google_compute_instance.dev.network_interface[0].network_ip}

    [all:vars]
    ansible_python_interpreter=/usr/bin/python3
    ansible_ssh_private_key_file=~/.ssh/id_ed25519
  INI
}

output "connectivity_summary" {
  description = "Résumé de la connectivité configurée"
  value       = <<-EOT
  ========================================
  CONNECTIVITÉ RÉSEAU CONFIGURÉE
  ========================================
  
  VOTRE IP: ${local.my_ip}
  RÉSEAU AUTORISÉ: ${local.cidr_24}
  
  🔒 ACCÈS DEPUIS VOTRE RÉSEAU:
     SSH  → Ansible: ${google_compute_instance.ansible.network_interface[0].access_config[0].nat_ip}:22
     RDP  → Gateway: ${google_compute_instance.gateway.network_interface[0].access_config[0].nat_ip}:3389
     HTTPS → Gateway: ${google_compute_instance.gateway.network_interface[0].access_config[0].nat_ip}:443
  
  🔄 ACCÈS DEPUIS ANSIBLE:
     SSH → Gateway: 10.20.0.11:22
     SSH → Dev via bastion: ssh -J utilisateur@10.20.0.11 utilisateur@10.20.0.12
  
  🚪 ACCÈS DEPUIS GATEWAY:
     RDP → AD: 10.20.0.10:3389
     RDP → Dev: 10.20.0.12:3389
     LDAP → AD: 10.20.0.10:389
  
  ⛔ ACCÈS INTERDITS DEPUIS VOTRE RÉSEAU:
     ❌ SSH direct vers Gateway ou Dev
     ❌ RDP direct vers AD ou Dev
  
  ========================================
  COMMANDES UTILES:
  
  1. Connexion à Ansible:
     ssh utilisateur@${google_compute_instance.ansible.network_interface[0].access_config[0].nat_ip}
  
  2. Connexion RDP à Gateway:
     xfreerdp /v:${google_compute_instance.gateway.network_interface[0].access_config[0].nat_ip} /u:utilisateur
  
  3. Connexion à Dev via bastion (depuis Ansible):
     ssh -J utilisateur@10.20.0.11 utilisateur@10.20.0.12
  
  4. Vérification de connectivité:
     Consultez terraform/test_connectivite.md
  
  ========================================
  EOT
}
