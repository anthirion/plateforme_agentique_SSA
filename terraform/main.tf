locals {
  vm_user = "antoine_thirion_wavestone_com"
}

resource "google_compute_instance" "ad" {
  name         = "${var.project_prefix}-ad"
  machine_type = "e2-standard-2" # 2 vCPU, 8 Go RAM
  tags         = ["${var.project_prefix}-ad"]

  labels = {
    environnement = "dev"
    project       = "vibe-coding-ssa"
  }

  boot_disk {
    initialize_params {
      image = "projects/windows-cloud/global/images/family/windows-2022"
      size  = 60
      type  = "pd-balanced"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.poc.id
    network_ip = "10.20.0.10"
  }

  metadata = {
    "windows-startup-script-ps1" = file("${path.module}/scripts/ad.ps1")
    "block-project-ssh-keys"     = "TRUE"
  }

  depends_on = [google_compute_router_nat.poc, google_compute_firewall.gateway_ad_rdp]
}

resource "google_compute_instance" "gateway" {
  name         = "${var.project_prefix}-gateway"
  machine_type = "e2-medium" # 2 vCPU, 4 Go RAM
  tags         = ["${var.project_prefix}-gateway"]

  labels = {
    environnement = "dev"
    project       = "vibe-coding-ssa"
  }

  boot_disk {
    initialize_params {
      image = "projects/almalinux-cloud/global/images/family/almalinux-9"
      size  = 30
      type  = "pd-balanced"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.poc.id
    network_ip = "10.20.0.11"
    access_config {} # IP publique
  }

  metadata = {
    "enable-oslogin"         = "TRUE"
    "block-project-ssh-keys" = "TRUE"
  }

  depends_on = [google_compute_firewall.admin_rdp_gateway, google_compute_firewall.https]
}

resource "google_compute_instance" "dev" {
  name         = "${var.project_prefix}-dev"
  machine_type = "e2-standard-2" # 2 vCPU, 8 Go RAM
  tags         = ["${var.project_prefix}-dev"]

  labels = {
    environnement = "dev"
    project       = "vibe-coding-ssa"
  }

  boot_disk {
    initialize_params {
      image = "projects/almalinux-cloud/global/images/family/almalinux-9"
      size  = 30
      type  = "pd-balanced"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.poc.id
    network_ip = "10.20.0.12"
  }

  metadata = {
    "enable-oslogin"         = "TRUE"
    "block-project-ssh-keys" = "TRUE"
  }

  depends_on = [
    google_compute_router_nat.poc, google_compute_firewall.dev_rdp,
    google_compute_firewall.ansible_ssh,
  ]
}

resource "google_compute_instance" "ansible" {
  name         = "${var.project_prefix}-ansible"
  machine_type = "e2-small" # 2 vCPU partagés, 2 Go RAM
  tags         = ["${var.project_prefix}-ansible"]

  labels = {
    environnement = "dev"
    project       = "vibe-coding-ssa"
  }

  boot_disk {
    initialize_params {
      image = "projects/almalinux-cloud/global/images/family/almalinux-9"
      size  = 20
      type  = "pd-balanced"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.poc.id
    network_ip = "10.20.0.13"
    access_config {} # IP publique
  }

  # Copy files of the ansible/ directory to the remote dev VM in the /opt/ directory
  provisioner "file" {
    source      = "${path.root}/../ansible"
    destination = "/home/${local.vm_user}"

    connection {
      type        = "ssh"
      host        = self.network_interface[0].access_config[0].nat_ip
      user        = local.vm_user
      private_key = file("//wsl.localhost/Ubuntu-22.04/home/anthirion/.ssh/id_rsa")
      timeout     = "3m"
    }

    when       = create
    on_failure = fail
  }

  metadata = {
    "enable-oslogin"         = "TRUE"
    "block-project-ssh-keys" = "TRUE"
  }

  depends_on = [google_compute_router_nat.poc, google_compute_firewall.admin_ssh]
}
