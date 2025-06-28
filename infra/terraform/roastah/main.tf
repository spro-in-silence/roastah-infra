# Roastah Infrastructure - Main Configuration
# This file contains the main Terraform resources for the roastah product

# TODO: Add resource blocks for roastah infrastructure 

terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 4.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# Data sources
data "google_project" "current" {
  project_id = var.project_id
}

# Common labels for all resources
locals {
  common_labels = {
    environment = "production"
    project     = "roastah"
    managed_by  = "terraform"
    team        = "infrastructure"
  }
}

resource "google_artifact_registry_repository" "roastah_repo" {
  location      = var.region
  repository_id = "roastah"
  description   = "Artifact Registry for Roastah"
  format        = "DOCKER"
  
  labels = local.common_labels
}

resource "google_service_account" "run_sa" {
  account_id   = "roastah-sa"
  display_name = "Roastah Cloud Run Service Account"
  
  labels = local.common_labels
}

resource "google_secret_manager_secret" "db_url" {
  secret_id = "DATABASE_URL"
  replication {
    automatic = true
  }
  
  labels = local.common_labels
}

resource "google_secret_manager_secret" "openai_key" {
  secret_id = "OPENAI_API_KEY"
  replication {
    automatic = true
  }
  
  labels = local.common_labels
}

resource "google_project_iam_member" "run_admin" {
  project = var.project_id
  role    = "roles/run.admin"
  member  = "serviceAccount:${google_service_account.run_sa.email}"
}

resource "google_project_iam_member" "storage_admin" {
  project = var.project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.run_sa.email}"
}

resource "google_project_iam_member" "secretmanager_admin" {
  project = var.project_id
  role    = "roles/secretmanager.admin"
  member  = "serviceAccount:${google_service_account.run_sa.email}"
}

resource "google_project_iam_member" "service_account_user" {
  project = var.project_id
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${google_service_account.run_sa.email}"
}

resource "google_secret_manager_secret_iam_member" "db_url_accessor" {
  secret_id = google_secret_manager_secret.db_url.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.run_sa.email}"
}

resource "google_secret_manager_secret_iam_member" "openai_key_accessor" {
  secret_id = google_secret_manager_secret.openai_key.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.run_sa.email}"
} 