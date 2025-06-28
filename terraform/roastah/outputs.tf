# Roastah Infrastructure - Outputs
# This file contains output definitions for the roastah product

# TODO: Add output definitions for roastah infrastructure 

output "run_service_account_email" {
  value = google_service_account.run_sa.email
}

output "artifact_registry_repository_url" {
  value = google_artifact_registry_repository.roastah_repo.repository_id
}

output "database_url_secret_id" {
  value = google_secret_manager_secret.db_url.secret_id
}

output "openai_api_key_secret_id" {
  value = google_secret_manager_secret.openai_key.secret_id
}

output "session_secret_id" {
  value = google_secret_manager_secret.session_secret.secret_id
}

output "gcp_service_account_key_secret_id" {
  value = google_secret_manager_secret.gcp_service_account_key.secret_id
}

output "cloud_run_service_url" {
  value = google_cloud_run_service.roastah.status[0].url
}

output "cloud_run_service_name" {
  value = google_cloud_run_service.roastah.name
}

output "cloud_build_trigger_id" {
  value = google_cloudbuild_trigger.roastah_trigger.id
}

output "cloud_build_trigger_name" {
  value = google_cloudbuild_trigger.roastah_trigger.name
}

output "pubsub_topic_name" {
  value = google_pubsub_topic.ci_notify.name
}

output "project_id" {
  value = data.google_project.current.project_id
}

output "project_number" {
  value = data.google_project.current.number
} 