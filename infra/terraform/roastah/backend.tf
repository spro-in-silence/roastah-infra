# Roastah Infrastructure - Backend Configuration
# This file contains the Terraform backend configuration for the roastah product

# TODO: Configure backend for roastah infrastructure 

terraform {
  backend "gcs" {
    bucket = "roastah-tf"
    prefix = "roastah/terraform/state"
  }
} 