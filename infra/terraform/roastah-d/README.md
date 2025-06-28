# Terraform for Roastah Dev GCP Infrastructure

This directory contains the Terraform configuration for the roastah-d development infrastructure.

## Prerequisites

- Terraform >= 1.0
- Google Cloud SDK (gcloud)
- Access to the roastah-d GCP project

## Authentication

1. **Authenticate with GCP:**
   ```bash
   gcloud auth application-default login
   gcloud config set project roastah-d
   ```

2. **Verify permissions:**
   Ensure your account has the following roles:
   - `roles/resourcemanager.projectIamAdmin`
   - `roles/iam.serviceAccountAdmin`
   - `roles/secretmanager.admin`
   - `roles/artifactregistry.admin`
   - `roles/run.admin`

## Usage

1. **Navigate to this directory:**
   ```bash
   cd infra/terraform/roastah-d
   ```

2. **Initialize Terraform:**
   ```bash
   terraform init
   ```

3. **Plan the deployment:**
   ```bash
   terraform plan -var="project_id=roastah-d" -var="region=us-central1"
   ```

4. **Apply the configuration:**
   ```bash
   terraform apply -var="project_id=roastah-d" -var="region=us-central1"
   ```

5. **Verify deployment:**
   ```bash
   terraform output
   ```

## Resources Created

- **Artifact Registry Repository**: `roastah-d` (Docker format)
- **Service Account**: `roastah-d-sa@roastah-d.iam.gserviceaccount.com`
- **Secret Manager Secrets**: `DATABASE_URL`, `OPENAI_API_KEY`
- **IAM Permissions**: Cloud Run, Storage, Secret Manager, Document AI access

## Outputs

- `run_service_account_email`: Service account email for Cloud Run
- `artifact_registry_repository_url`: Artifact Registry repository ID
- `database_url_secret_id`: DATABASE_URL secret ID
- `openai_api_key_secret_id`: OPENAI_API_KEY secret ID
- `project_id`: Current project ID
- `project_number`: Current project number

## Environment

This configuration manages the **roastah-d development infrastructure**.

## Development Workflow

1. **Make changes to infrastructure:**
   - Edit Terraform files as needed
   - Test changes with `terraform plan`

2. **Deploy changes:**
   ```bash
   terraform apply -var="project_id=roastah-d" -var="region=us-central1"
   ```

3. **Verify changes:**
   - Check GCP Console for new resources
   - Test application functionality

## Troubleshooting

### Common Issues

1. **Permission Denied:**
   - Ensure you have the required IAM roles
   - Verify you're authenticated to the correct project

2. **Backend Configuration Error:**
   - Ensure the GCS bucket `roastah-d-tf` exists
   - Verify bucket permissions

3. **Resource Already Exists:**
   - Use `terraform import` to import existing resources
   - Or delete existing resources manually

### Useful Commands

```bash
# Check Terraform version
terraform version

# Validate configuration
terraform validate

# Show current state
terraform show

# List resources
terraform state list

# Destroy infrastructure (use with caution)
terraform destroy -var="project_id=roastah-d" -var="region=us-central1"
```

## Security Notes

- Service account keys are not stored in Terraform state
- Secrets are created but values must be added manually
- IAM permissions follow principle of least privilege
- All resources are tagged for cost tracking and management
- Development environment has same security standards as production

## Maintenance

- Regularly update Terraform and provider versions
- Review and rotate service account keys periodically
- Monitor resource usage and costs
- Keep secrets updated and secure
- Clean up unused development resources

# Roastah Infrastructure - Terraform

This directory contains the Terraform configuration for the roastah product infrastructure.

## Files

- `main.tf` - Main Terraform resources and data sources
- `variables.tf` - Input variable definitions
- `outputs.tf` - Output value definitions
- `backend.tf` - Terraform backend configuration
- `README.md` - This documentation file

## Usage

1. Navigate to this directory: `cd infra/terraform/roastah`
2. Initialize Terraform: `terraform init`
3. Plan changes: `terraform plan`
4. Apply changes: `terraform apply`

## Environment

This configuration manages the roastah production infrastructure.

## TODO

- Add resource blocks for roastah infrastructure
- Configure backend for state management
- Define variables and outputs
- Add documentation for specific resources 