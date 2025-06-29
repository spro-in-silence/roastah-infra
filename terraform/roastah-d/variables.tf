# Roastah Infrastructure - Variables
# This file contains variable definitions for the roastah product

# TODO: Add variable definitions for roastah infrastructure 

variable "project_id" {
  type        = string
  description = "The GCP project ID"
  
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "Project ID must be between 6 and 30 characters, start with a letter, and contain only lowercase letters, numbers, and hyphens."
  }
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "us-central1"
  
  validation {
    condition     = can(regex("^[a-z]+-[a-z]+[0-9]*$", var.region))
    error_message = "Region must be in the format 'region-zone' (e.g., us-central1, europe-west1)."
  }
} 