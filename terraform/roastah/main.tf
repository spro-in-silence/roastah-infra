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
  location      = "us-central1"
  repository_id = var.project_id
  description   = "Docker repository for ${var.project_id}"
  format        = "DOCKER"
  project       = var.project_id

  cleanup_policy_dry_run = false

  cleanup_policies {
    id     = "keep-minimum-2"
    action = "KEEP"
    most_recent_versions {
      keep_count = 2
    }
  }

  cleanup_policies {
    id     = "delete-older-than-30-days"
    action = "DELETE"
    condition {
      older_than = "2592000s"  # 30 days in seconds
    }
  }
}

resource "google_service_account" "run_sa" {
  account_id   = "roastah-sa"
  display_name = "Roastah Cloud Run Service Account"
  
}

resource "google_secret_manager_secret" "db_url" {
  secret_id = "DATABASE_URL"
  replication {
    auto {}
  }
  
}

resource "google_secret_manager_secret" "openai_key" {
  secret_id = "OPENAI_API_KEY"
  replication {
    auto {}
  }
  
}

resource "google_secret_manager_secret" "session_secret" {
  secret_id = "SESSION_SECRET"
  replication {
    auto {}
  }
  
}

resource "google_secret_manager_secret" "gcp_service_account_key" {
  secret_id = "GCP_SERVICE_ACCOUNT_KEY"
  replication {
    auto {}
  }
  
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

resource "google_cloud_run_service" "roastah" {
  name     = "roastah"
  location = var.region

  template {
    metadata {
      annotations = {
        "autoscaling.knative.dev/maxScale" = "100"
        "run.googleapis.com/startup-cpu-boost" = "true"
      }
    }
    spec {
      service_account_name = google_service_account.run_sa.email
      container_concurrency = 80
      timeout_seconds = 600
      
      containers {
        image = "us-central1-docker.pkg.dev/${var.project_id}/${var.project_id}/${var.project_id}:latest"
        ports {
          container_port = 8080
        }
        
        env {
          name  = "NODE_ENV"
          value = "production"
        }
        env {
          name  = "APP_ENV"
          value = "production"
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

}

resource "google_cloud_run_service_iam_member" "public_access" {
  location = google_cloud_run_service.roastah.location
  service  = google_cloud_run_service.roastah.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

resource "google_cloudbuild_trigger" "roastah_trigger" {
  name        = "roastah"
  location    = "us-central1"
  description = "Build and deploy roastah on push to main"
  
  github {
    owner = "roastah"
    name  = "roastah"
    push {
      branch = "^main$"
    }
  }
  
  filename = "cloudbuild.yaml"
  
  substitutions = {
    _SERVICE_NAME = "roastah"
    _REGION       = var.region
  }
  
  service_account = google_service_account.run_sa.id
  
}

resource "google_pubsub_topic" "ci_notify" {
  name = "ci-notify"
  
}

# Cloud Build IAM permissions (minimal - only for building/pushing images)
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