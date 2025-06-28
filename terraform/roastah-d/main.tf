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

# Roastah Dev Infrastructure - Main Configuration
# This file contains the main Terraform resources for the roastah-d product

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
    environment = "development"
    project     = "roastah-d"
    managed_by  = "terraform"
    team        = "infrastructure"
  }
}

resource "google_artifact_registry_repository" "roastah_d_repo" {
  location      = var.region
  repository_id = "roastah-d"
  description   = "Artifact Registry for Roastah Dev"
  format        = "DOCKER"
  
  labels = local.common_labels
}

resource "google_service_account" "run_sa" {
  account_id   = "roastah-d-sa"
  display_name = "Roastah Dev Cloud Run Service Account"
  
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

resource "google_secret_manager_secret" "session_secret" {
  secret_id = "SESSION_SECRET"
  replication {
    automatic = true
  }
  
  labels = local.common_labels
}

resource "google_secret_manager_secret" "gcp_service_account_key" {
  secret_id = "GCP_SERVICE_ACCOUNT_KEY"
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

resource "google_secret_manager_secret_iam_member" "session_secret_accessor" {
  secret_id = google_secret_manager_secret.session_secret.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.run_sa.email}"
}

resource "google_secret_manager_secret_iam_member" "gcp_service_account_key_accessor" {
  secret_id = google_secret_manager_secret.gcp_service_account_key.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.run_sa.email}"
}

resource "google_cloud_run_service" "roastah_d" {
  name     = "roastah-d"
  location = var.region

  template {
    metadata {
      annotations = {
        "autoscaling.knative.dev/maxScale" = "40"
        "run.googleapis.com/startup-cpu-boost" = "true"
      }
    }
    spec {
      service_account_name = google_service_account.run_sa.email
      container_concurrency = 80
      timeout_seconds = 600
      
      containers {
        image = "us-central1-docker.pkg.dev/${var.project_id}/roastah-d/roastah-d:latest"
        ports {
          container_port = 8080
        }
        
        env {
          name  = "NODE_ENV"
          value = "development"
        }
        env {
          name  = "APP_ENV"
          value = "development"
        }
        env {
          name  = "GCP_PROJECT_ID"
          value = var.project_id
        }
        env {
          name = "DATABASE_URL"
          value = "sm://${google_secret_manager_secret.db_url.secret_id}"
        }
        env {
          name = "OPENAI_API_KEY"
          value = "sm://${google_secret_manager_secret.openai_key.secret_id}"
        }
        env {
          name = "SESSION_SECRET"
          value = "sm://${google_secret_manager_secret.session_secret.secret_id}"
        }
        env {
          name = "GCP_SERVICE_ACCOUNT_KEY"
          value = "sm://${google_secret_manager_secret.gcp_service_account_key.secret_id}"
        }
        env {
          name  = "SSL_ENABLED"
          value = "true"
        }
        
        resources {
          limits = {
            cpu    = "1000m"
            memory = "512Mi"
          }
        }
        
        startup_probe {
          tcp_socket {
            port = 8080
          }
          failure_threshold = 1
          period_seconds    = 240
          timeout_seconds   = 240
        }
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }

  labels = local.common_labels
}

resource "google_cloud_run_service_iam_member" "public_access" {
  location = google_cloud_run_service.roastah_d.location
  service  = google_cloud_run_service.roastah_d.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

resource "google_cloudbuild_trigger" "roastah_d_trigger" {
  name        = "roastah-d"
  location    = "global"
  description = "Build and deploy roastah-d on push to dev"
  
  github {
    owner = "roastah"
    name  = "roastah"
    push {
      branch = "^dev$"
    }
  }
  
  filename = "cloudbuild.dev.yaml"
  
  substitutions = {
    _SERVICE_NAME = "roastah-d"
    _REGION       = var.region
  }
  
  service_account = google_service_account.run_sa.id
  
  labels = local.common_labels
}

resource "google_pubsub_topic" "ci_notify" {
  name = "ci-notify"
  
  labels = local.common_labels
}

resource "google_project_iam_member" "cloudbuild_run_admin" {
  project = var.project_id
  role    = "roles/run.admin"
  member  = "serviceAccount:${data.google_project.current.number}@cloudbuild.gserviceaccount.com"
}

resource "google_project_iam_member" "cloudbuild_storage_admin" {
  project = var.project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${data.google_project.current.number}@cloudbuild.gserviceaccount.com"
}

resource "google_project_iam_member" "cloudbuild_pubsub_publisher" {
  project = var.project_id
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${data.google_project.current.number}@cloudbuild.gserviceaccount.com"
}

resource "google_project_iam_member" "cloudbuild_service_account_user" {
  project = var.project_id
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${data.google_project.current.number}@cloudbuild.gserviceaccount.com"
}

resource "google_project_iam_member" "cloudbuild_secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${data.google_project.current.number}@cloudbuild.gserviceaccount.com"
} 