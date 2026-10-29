variable "project_id" {
  description = "Projet GCP existant, avec facturation active."
  type        = string
}

variable "project_prefix" {
  description = "Préfixe des noms et tags des ressources, tiret final non-inclus."
  type        = string
}

variable "region" {
  type = string
}

variable "zone" {
  type = string
}
