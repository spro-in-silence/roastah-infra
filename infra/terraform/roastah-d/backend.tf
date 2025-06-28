# Roastah Infrastructure - Backend Configuration
# This file contains the Terraform backend configuration for the roastah product

# TODO: Configure backend for roastah infrastructure 

terraform {
  backend "gcs" {
    bucket = "roastah-d-tf"
    prefix = "roastah-d/terraform/state"
  }
} 