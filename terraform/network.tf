data "http" "my_ip" {
  url                = "https://checkip.amazonaws.com"
  request_timeout_ms = 10000

  lifecycle {
    postcondition {
      condition     = self.status_code == 200 && can(cidrnetmask("${trimspace(self.response_body)}/32"))
      error_message = "Le service AWS checkip doit renvoyer une adresse IPv4 valide."
    }
  }
}

locals {
  my_ip   = trimspace(data.http.my_ip.response_body)
  cidr_24 = "${join(".", slice(split(".", local.my_ip), 0, 3))}.0/24"
}

# Les règles normalisent l'IP détectée en réseau /24 (ex. 203.0.113.10 -> 203.0.113.0/24).
# Une réponse invalide reste rejetée par la postcondition du service AWS ci-dessus.

resource "google_compute_network" "poc" {
  name                    = "${var.project_prefix}-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "poc" {
  name                     = "${var.project_prefix}-subnet"
  network                  = google_compute_network.poc.id
  ip_cidr_range            = "10.20.0.0/24"
  private_ip_google_access = true
}

resource "google_compute_router" "poc" {
  name    = "${var.project_prefix}-router"
  network = google_compute_network.poc.id
}

resource "google_compute_router_nat" "poc" {
  name                               = "${var.project_prefix}-nat"
  router                             = google_compute_router.poc.name
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  subnetwork {
    name                    = google_compute_subnetwork.poc.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }
}

resource "google_compute_firewall" "https" {
  name          = "${var.project_prefix}-https"
  network       = google_compute_network.poc.id
  source_ranges = ["${local.cidr_24}"]
  target_tags   = ["${var.project_prefix}-gateway"]
  allow {
    protocol = "tcp"
    ports    = ["443"]
  }
}

resource "google_compute_firewall" "admin_ssh" {
  name          = "${var.project_prefix}-admin-ssh"
  network       = google_compute_network.poc.id
  source_ranges = ["${local.cidr_24}"]
  target_tags = [
    "${var.project_prefix}-gateway",
    "${var.project_prefix}-dev",
    "${var.project_prefix}-ansible",
  ]
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

resource "google_compute_firewall" "admin_rdp" {
  name          = "${var.project_prefix}-admin-rdp-ad"
  network       = google_compute_network.poc.id
  source_ranges = [try(cidrsubnet("${local.my_ip}/24", 0, 0), null)]
  target_tags   = ["${var.project_prefix}-ad"]
  allow {
    protocol = "tcp"
    ports    = ["3389"]
  }
}

resource "google_compute_firewall" "ansible_ssh" {
  name        = "${var.project_prefix}-ansible-ssh"
  network     = google_compute_network.poc.id
  source_tags = ["${var.project_prefix}-ansible"]
  target_tags = [
    "${var.project_prefix}-gateway",
    "${var.project_prefix}-dev",
  ]
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

resource "google_compute_firewall" "dev_rdp" {
  name        = "${var.project_prefix}-gateway-dev-rdp"
  network     = google_compute_network.poc.id
  source_tags = ["${var.project_prefix}-gateway"]
  target_tags = ["${var.project_prefix}-dev"]
  allow {
    protocol = "tcp"
    ports    = ["3389"]
  }
}

resource "google_compute_firewall" "ad_ldap" {
  name        = "${var.project_prefix}-gateway-ad-ldap"
  network     = google_compute_network.poc.id
  source_tags = ["${var.project_prefix}-gateway"]
  target_tags = ["${var.project_prefix}-ad"]
  allow {
    protocol = "tcp"
    ports    = ["389"]
  }
}
