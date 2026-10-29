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
  description = "Seule la gateway possède une IP publique pour HTTPS."
  value = {
    gateway = google_compute_instance.gateway.network_interface[0].access_config[0].nat_ip
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
