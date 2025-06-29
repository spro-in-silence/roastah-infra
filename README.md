# Roastah Infrastructure

This repository contains the infrastructure as code (IaC) for the Roastah application using Terraform.

## Architecture

The infrastructure is designed with a **clear separation of concerns**:
- **Terraform** manages infrastructure configuration (Cloud Run service, IAM, secrets, etc.)
- **Cloud Build** handles application deployments (building, pushing, deploying to Cloud Run)
- **GitOps workflow** triggers complete deployments automatically

## Environments

- **roastah-d** (Development): `roastah-d` project
- **roastah** (Production): `roastah` project

## Workflow

### 1. Development Workflow

1. **Make code changes** in your application repository
2. **Push to `dev` branch** - this triggers Cloud Build
3. **Cloud Build automatically**:
   - Builds Docker image with correct architecture (linux/amd64)
   - Pushes to Artifact Registry with `:latest` tag
   - Deploys to Cloud Run with zero-downtime rollout
   - Cleans up old revisions and images
   - Sends deployment notifications

### 2. Production Workflow

1. **Merge to `main` branch** - this triggers Cloud Build
2. **Cloud Build automatically**:
   - Builds Docker image
   - Pushes to Artifact Registry
   - Deploys to Cloud Run with zero-downtime rollout
   - Cleans up old revisions and images
   - Sends deployment notifications

## Infrastructure Components

### Managed by Terraform (Infrastructure Configuration)

- **Artifact Registry**: Docker image storage with retention policies
- **Cloud Run Service**: Infrastructure configuration (not deployments)
- **Secret Manager**: Environment variables and secrets
- **IAM**: Service accounts and permissions
- **Cloud Build Triggers**: Automated deployment triggers
- **Pub/Sub**: Build notifications

### Managed by Cloud Build (Application Deployments)

- **Docker image building** and pushing
- **Cloud Run deployments** with zero-downtime rollouts
- **Traffic management** (100% to latest revision)
- **Revision cleanup** (keeps last 5 revisions)
- **Image cleanup** (keeps last 2 images)

### Retention Policies

- **Artifact Registry**: Keeps last 2 images, deletes older than 30 days
- **Cloud Run**: Keeps last 5 revisions, Cloud Build manages cleanup

## Usage

### Initial Setup

1. **Set up GCP projects** (`roastah-d`, `roastah`)
2. **Enable required APIs**:
   ```bash
   gcloud services enable cloudbuild.googleapis.com
   gcloud services enable run.googleapis.com
   gcloud services enable artifactregistry.googleapis.com
   gcloud services enable secretmanager.googleapis.com
   ```

3. **Deploy infrastructure**:
   ```bash
   # Development
   cd terraform/roastah-d
   terraform init
   terraform apply -var="project_id=roastah-d"
   
   # Production
   cd terraform/roastah
   terraform init
   terraform apply -var="project_id=roastah"
   ```

### Daily Development

1. **Make code changes** in your app repository
2. **Push to `dev` branch** - triggers automatic build and deployment
3. **Monitor deployment** via Cloud Build logs or Pub/Sub notifications

### Production Deployment

1. **Merge to `main` branch** - triggers automatic build and deployment
2. **Monitor deployment** via Cloud Build logs or Pub/Sub notifications

## Cloud Build Configuration

Cloud Build is configured to:
- Build images for `linux/amd64` architecture (Cloud Run compatible)
- Use Artifact Registry (not legacy Container Registry)
- Tag images with both commit SHA and `:latest`
- Deploy to Cloud Run with zero-downtime rollout
- Clean up old revisions and images automatically
- Send notifications via Pub/Sub

## Deployment Process

Each Cloud Build deployment includes:

1. **Image Building**: Docker build with proper architecture
2. **Image Pushing**: Push to Artifact Registry with SHA and latest tags
3. **Service Deployment**: Deploy to Cloud Run with `--no-traffic` flag
4. **Health Check**: Wait for new revision to be ready
5. **Traffic Switch**: Switch 100% traffic to new revision
6. **Cleanup**: Remove old revisions and images
7. **Notification**: Send deployment status via Pub/Sub

## Troubleshooting

### Common Issues

1. **Container startup failures**:
   - Check if image was built for correct architecture (`linux/amd64`)
   - Verify container listens on port 8080
   - Check Cloud Run logs for startup errors

2. **Deployment failures**:
   - Check Cloud Build logs for deployment errors
   - Verify IAM permissions for Cloud Build service account
   - Check if Cloud Run service exists and is accessible

3. **Permission errors**:
   - Check IAM roles are properly assigned
   - Verify service account permissions

### Useful Commands

```bash
# Check Cloud Run logs
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=roastah-d" --limit=20

# List Artifact Registry images
gcloud artifacts docker images list us-central1-docker.pkg.dev/roastah-d/roastah-d

# Check Cloud Build status
gcloud builds list --limit=5

# Check Cloud Run revisions
gcloud run revisions list --service=roastah-d --region=us-central1
```

## Security

- All secrets are managed via Secret Manager
- Service accounts have minimal required permissions
- Cloud Run services are publicly accessible (can be restricted if needed)
- Artifact Registry has retention policies to prevent storage bloat

## Cost Optimization

- Cloud Run scales to zero when not in use
- Artifact Registry retention policies limit storage costs
- Minimal IAM permissions reduce security overhead
- Automatic cleanup of old revisions and images

## Benefits of This Approach

1. **Clear Separation**: Infrastructure (Terraform) vs Deployments (Cloud Build)
2. **Zero-Downtime**: Cloud Build handles safe rollouts
3. **Automated**: No manual deployment steps required
4. **Consistent**: Same deployment process for all environments
5. **Observable**: Built-in notifications and logging
6. **Maintainable**: Infrastructure changes don't affect deployments
