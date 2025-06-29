terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
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

# Service Account for Cloud Run
resource "google_service_account" "run_sa" {
  account_id   = "${var.project_id}-sa"
  display_name = "Service Account for ${var.project_id} Cloud Run"
  project      = var.project_id
}

# IAM roles for the service account
resource "google_project_iam_member" "run_admin" {
  project = var.project_id
  role    = "roles/run.admin"
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

resource "google_project_iam_member" "storage_admin" {
  project = var.project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.run_sa.email}"
}

# Artifact Registry Repository
resource "google_artifact_registry_repository" "roastah_d_repo" {
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

# Secret Manager Secrets
resource "google_secret_manager_secret" "db_url" {
  secret_id = "DATABASE_URL"
  project   = var.project_id

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret" "openai_key" {
  secret_id = "OPENAI_API_KEY"
  project   = var.project_id

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret" "session_secret" {
  secret_id = "SESSION_SECRET"
  project   = var.project_id

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret" "gcp_service_account_key" {
  secret_id = "GCP_SERVICE_ACCOUNT_KEY"
  project   = var.project_id

  replication {
    auto {}
  }
}

# IAM access for secrets
resource "google_secret_manager_secret_iam_member" "db_url_accessor" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.db_url.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.run_sa.email}"
}

resource "google_secret_manager_secret_iam_member" "openai_key_accessor" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.openai_key.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.run_sa.email}"
}

resource "google_secret_manager_secret_iam_member" "session_secret_accessor" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.session_secret.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.run_sa.email}"
}

resource "google_secret_manager_secret_iam_member" "gcp_service_account_key_accessor" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.gcp_service_account_key.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.run_sa.email}"
}

# Pub/Sub Topic for CI notifications
resource "google_pubsub_topic" "ci_notify" {
  name    = "ci-notify"
  project = var.project_id
}

# Cloud Run Service (Infrastructure only - deployments handled by Cloud Build)
resource "google_cloud_run_service" "roastah_d" {
  name     = var.project_id
  location = "us-central1"
  project  = var.project_id

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
        # Placeholder image - Cloud Build will deploy the actual application image
        image = "gcr.io/cloudrun/hello"
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
          value = "projects/${var.project_id}/secrets/DATABASE_URL/versions/latest"
        }
        env {
          name = "OPENAI_API_KEY"
          value = "projects/${var.project_id}/secrets/OPENAI_API_KEY/versions/latest"
        }
        env {
          name = "SESSION_SECRET"
          value = "projects/${var.project_id}/secrets/SESSION_SECRET/versions/latest"
        }
        env {
          name = "GCP_SERVICE_ACCOUNT_KEY"
          value = "projects/${var.project_id}/secrets/GCP_SERVICE_ACCOUNT_KEY/versions/latest"
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

  # Traffic configuration - Cloud Build will manage this during deployments
  traffic {
    percent         = 100
    latest_revision = true
  }
}

# Public access to Cloud Run service
resource "google_cloud_run_service_iam_member" "public_access" {
  location = "us-central1"
  project  = var.project_id
  service  = google_cloud_run_service.roastah_d.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# Cloud Build IAM permissions (for building, pushing, and deploying)
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

# Cloud Build Trigger
resource "google_cloudbuild_trigger" "roastah_d_trigger" {
  name        = "roastah-d"
  description = "Build and deploy roastah-d on push to dev"
  location    = "us-central1"
  project     = var.project_id

  github {
    owner = "spro-in-silence"
    name  = "roastah"
    push {
      branch = "^dev$"
    }
  }

  filename        = "cloudbuild.dev.yaml"
  service_account = google_service_account.run_sa.id

  substitutions = {
    _SERVICE_NAME = "roastah-d"
    _REGION       = "us-central1"
  }
} 