# Migration Guide: Script-First to Terraform-First

This guide explains the migration from the previous script-heavy approach to the new **Terraform-first approach** for managing Roastah infrastructure.

## 🎯 What Changed

### Before: Script-Heavy Approach
- **Primary**: Python/Shell scripts managed infrastructure
- **Secondary**: Terraform only for basic resources
- **Issues**: 
  - Hardcoded service account emails
  - Manual IAM management
  - Inconsistent resource naming
  - Difficult to track changes
  - No state management

### After: Terraform-First Approach
- **Primary**: Terraform manages all infrastructure declaratively
- **Secondary**: Scripts handle operational tasks only
- **Benefits**:
  - Single source of truth
  - Declarative configuration
  - State management
  - Consistent resource naming
  - Version-controlled infrastructure

## 🔄 Migration Steps

### Step 1: Backup Current State
```bash
# Export current infrastructure (if needed for reference)
./bootstrap-export.sh
```

### Step 2: Deploy New Infrastructure
```bash
# Deploy to dev environment first
./deploy.sh roastah-d dev plan
./deploy.sh roastah-d dev apply

# Deploy to production
./deploy.sh roastah prod plan
./deploy.sh roastah prod apply
```

### Step 3: Update Secrets
```bash
# Create environment files with your secrets
cat > .env.dev << EOF
DATABASE_URL=your_dev_database_url
OPENAI_API_KEY=your_dev_openai_key
SESSION_SECRET=your_dev_session_secret
GCP_SERVICE_ACCOUNT_KEY=your_dev_service_account_key
EOF

cat > .env.prod << EOF
DATABASE_URL=your_prod_database_url
OPENAI_API_KEY=your_prod_openai_key
SESSION_SECRET=your_prod_session_secret
GCP_SERVICE_ACCOUNT_KEY=your_prod_service_account_key
EOF

# Update secrets
./deploy.sh roastah-d dev secrets
./deploy.sh roastah prod secrets
```

### Step 4: Validate Migration
```bash
# Validate both environments
./deploy.sh roastah-d dev validate
./deploy.sh roastah prod validate
```

## 📊 Resource Mapping

### What Terraform Now Manages

| Resource Type | Old Approach | New Approach |
|---------------|--------------|--------------|
| **Artifact Registry** | Scripts | ✅ Terraform |
| **Service Accounts** | Scripts | ✅ Terraform |
| **IAM Permissions** | Scripts | ✅ Terraform |
| **Secret Structures** | Scripts | ✅ Terraform |
| **Cloud Run Services** | Cloud Build | ✅ Terraform |
| **Cloud Build Triggers** | Scripts | ✅ Terraform |
| **Pub/Sub Topics** | Manual | ✅ Terraform |

### What Scripts Still Handle

| Task | Old Approach | New Approach |
|------|--------------|--------------|
| **Secret Values** | Scripts | ✅ Scripts (operational) |
| **Infrastructure Export** | Scripts | ✅ Scripts (disaster recovery) |
| **Validation** | Manual | ✅ Scripts (automated) |
| **One-off Operations** | Manual | ✅ Scripts (specialized) |

## 🔧 Key Changes in Configuration

### Cloud Build Changes
**Before:**
```yaml
# Hardcoded service account
--service-account=256468121098-compute@developer.gserviceaccount.com
```

**After:**
```yaml
# Uses Terraform-managed service account
# Service account is automatically configured by Terraform
```

### Service Account Management
**Before:**
```bash
# Manual IAM role assignment
gcloud projects add-iam-policy-binding roastah-d \
  --member="serviceAccount:roastah-d-sa@roastah-d.iam.gserviceaccount.com" \
  --role="roles/run.admin"
```

**After:**
```hcl
# Declarative IAM management
resource "google_project_iam_member" "run_admin" {
  project = var.project_id
  role    = "roles/run.admin"
  member  = "serviceAccount:${google_service_account.run_sa.email}"
}
```

### Cloud Run Configuration
**Before:**
```yaml
# Cloud Build managed deployment
gcloud run deploy roastah-d \
  --image=us-central1-docker.pkg.dev/$PROJECT_ID/roastah-d/roastah-d:$SHORT_SHA
```

**After:**
```hcl
# Terraform manages the service
resource "google_cloud_run_service" "roastah_d" {
  name     = "roastah-d"
  location = var.region
  
  template {
    spec {
      containers {
        image = "us-central1-docker.pkg.dev/${var.project_id}/roastah-d/roastah-d:latest"
        # ... full configuration
      }
    }
  }
}
```

## 🚀 New Workflow

### Development Workflow
```bash
# 1. Plan changes
./deploy.sh roastah-d dev plan

# 2. Apply infrastructure changes
./deploy.sh roastah-d dev apply

# 3. Update secrets if needed
./deploy.sh roastah-d dev secrets

# 4. Validate everything
./deploy.sh roastah-d dev validate
```

### Production Workflow
```bash
# 1. Plan production changes
./deploy.sh roastah prod plan

# 2. Apply to production
./deploy.sh roastah prod apply

# 3. Update production secrets
./deploy.sh roastah prod secrets

# 4. Validate production
./deploy.sh roastah prod validate
```

### Operational Tasks
```bash
# List all secrets
python3 apply_config.py --project-id roastah-d --action list-secrets

# Update a specific secret
python3 apply_config.py --project-id roastah-d --action update-secret \
  --secret-id DATABASE_URL --secret-value "new-value"

# Validate infrastructure
python3 apply_config.py --project-id roastah-d --action validate
```

## 🔍 Verification Checklist

### Infrastructure Verification
- [ ] Terraform plan shows no unexpected changes
- [ ] All resources are created in the correct projects
- [ ] Service accounts have correct permissions
- [ ] Cloud Run services are accessible
- [ ] Cloud Build triggers are working
- [ ] Secrets are properly configured

### Application Verification
- [ ] Development environment is accessible
- [ ] Production environment is accessible
- [ ] Database connections work
- [ ] External API calls work (OpenAI)
- [ ] CI/CD pipeline is functional

### Security Verification
- [ ] Service accounts have minimal required permissions
- [ ] Secrets are not exposed in logs or state files
- [ ] IAM policies follow principle of least privilege
- [ ] Public access is properly configured

## 🚨 Rollback Plan

If issues arise during migration:

### Quick Rollback
```bash
# Destroy new infrastructure
./deploy.sh roastah-d dev destroy
./deploy.sh roastah prod destroy

# Recreate old infrastructure using bootstrap script
./bootstrap-export.sh
python3 apply_config.py --project-id roastah-d --action update-from-env --env-file .env.dev
```

### Partial Rollback
```bash
# Import existing resources into Terraform state
terraform import google_cloud_run_service.roastah_d \
  projects/roastah-d/locations/us-central1/services/roastah-d

# Then apply Terraform to manage them
./deploy.sh roastah-d dev apply
```

## 📈 Benefits Realized

### Immediate Benefits
- ✅ **Consistency**: All environments use identical configuration
- ✅ **Visibility**: Infrastructure changes are tracked in Git
- ✅ **Reliability**: State management prevents drift
- ✅ **Security**: IAM permissions are declarative and auditable

### Long-term Benefits
- ✅ **Scalability**: Easy to add new environments
- ✅ **Maintainability**: Single source of truth for all infrastructure
- ✅ **Compliance**: Infrastructure as code enables better governance
- ✅ **Disaster Recovery**: Infrastructure can be recreated from code

## 🎉 Migration Complete!

After following this guide, you'll have:

1. **Terraform-managed infrastructure** for all resources
2. **Operational scripts** for tasks that don't fit the declarative model
3. **Consistent deployment process** across all environments
4. **Better security and compliance** through declarative IAM
5. **Improved disaster recovery** capabilities

The new Terraform-first approach provides a solid foundation for scaling your infrastructure while maintaining security, consistency, and operational efficiency. 