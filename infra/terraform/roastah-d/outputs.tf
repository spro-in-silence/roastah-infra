# Roastah Infrastructure - Outputs
# This file contains output definitions for the roastah product

# TODO: Add output definitions for roastah infrastructure 

output "run_service_account_email" {
  value = google_service_account.run_sa.email
}

output "artifact_registry_repository_url" {
  value = google_artifact_registry_repository.roastah_d_repo.repository_id
}

output "database_url_secret_id" {
  value = google_secret_manager_secret.db_url.secret_id
}

output "openai_api_key_secret_id" {
  value = google_secret_manager_secret.openai_key.secret_id
}

output "project_id" {
  value = data.google_project.current.project_id
}

output "project_number" {
  value = data.google_project.current.number
} 