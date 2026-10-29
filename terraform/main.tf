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

  depends_on = [google_compute_router_nat.poc, google_compute_firewall.admin_rdp]
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

  depends_on = [google_compute_firewall.admin_ssh]
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
    access_config {} # IP publique
  }

  metadata = {
    "enable-oslogin"         = "TRUE"
    "block-project-ssh-keys" = "TRUE"
  }

  depends_on = [google_compute_router_nat.poc, google_compute_firewall.admin_ssh]
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

  metadata = {
    "enable-oslogin"         = "TRUE"
    "block-project-ssh-keys" = "TRUE"
  }

  depends_on = [google_compute_router_nat.poc, google_compute_firewall.admin_ssh]
}
