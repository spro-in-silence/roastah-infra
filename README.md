# Roastah Infrastructure

This repository contains the infrastructure configuration for the Roastah application using Terraform and Google Cloud Platform.

## Overview

This infrastructure setup provides:
- **Terraform-first approach**: All infrastructure is managed declaratively through Terraform
- **Environment parity**: Consistent configurations across development and production
- **Security**: Proper IAM roles, service accounts, and secret management
- **Scalability**: Cloud Run services with auto-scaling capabilities
- **CI/CD**: Cloud Build triggers for automated deployments

## Repository Structure

```
roastah-infra/
├── terraform/
│   ├── roastah/            # Production environment
│   └── roastah-d/          # Development environment
├── infra-config/
│   ├── cloudbuild/         # Cloud Build configurations
│   ├── cloudrun/           # Cloud Run service configurations
│   ├── iam/               # IAM policy configurations
│   ├── secrets/           # Secret Manager configurations
│   └── triggers/          # Cloud Build trigger configurations
├── apply_config.py        # Operational script for secret management
├── deploy.sh              # Deployment orchestrator
└── bootstrap-export.sh    # Bootstrap script for initial setup
```

## Prerequisites

- Google Cloud SDK (`gcloud`)
- Terraform (v1.0+)
- Python 3.7+
- Git

## Quick Start

### 1. Initial Setup

```bash
# Clone the repository
git clone <repository-url>
cd roastah-infra

# Set up GCP authentication
gcloud auth application-default login

# Bootstrap the infrastructure (first time only)
./bootstrap-export.sh
```

### 2. Deploy Infrastructure

```bash
# Deploy all environments
./deploy.sh

# Deploy specific environment
./deploy.sh roastah
./deploy.sh roastah-d
```

### 3. Update Secrets

```bash
# Update secret values using the operational script
python3 apply_config.py update-secret DATABASE_URL "new-connection-string"
python3 apply_config.py update-secret OPENAI_API_KEY "new-api-key"
```

## Infrastructure Components

### Terraform Resources

Each environment (`roastah` and `roastah-d`) includes:

- **Artifact Registry**: Container image storage
- **Service Accounts**: Application and deployment identities
- **Secret Manager**: Secure secret storage
- **IAM Roles**: Proper access controls
- **Cloud Run Services**: Application deployment
- **Cloud Build Triggers**: Automated CI/CD
- **Backend State**: GCS bucket for Terraform state

### Cloud Build Pipeline

The CI/CD pipeline includes:

1. **Build**: Containerize application
2. **Test**: Run automated tests
3. **Deploy**: Deploy to Cloud Run
4. **Validate**: Health checks and monitoring

### Security Features

- **Least Privilege**: Service accounts with minimal required permissions
- **Secret Management**: All secrets stored in Secret Manager
- **Network Security**: Private networking where applicable
- **Audit Logging**: Comprehensive logging and monitoring

## Environment Management

### Development Environment (`roastah-d`)

- Project: `roastah-d`
- Purpose: Development and testing
- Features: Auto-scaling, development-specific configurations

### Production Environment (`roastah`)

- Project: `roastah`
- Purpose: Production workloads
- Features: High availability, production-grade configurations

## Operational Scripts

### `apply_config.py`

Operational script for managing infrastructure configurations:

```bash
# Update secret values
python3 apply_config.py update-secret <secret-name> <new-value>

# Validate configurations
python3 apply_config.py validate

# List all secrets
python3 apply_config.py list-secrets
```

### `deploy.sh`

Deployment orchestrator that manages the complete deployment process:

```bash
# Deploy all environments
./deploy.sh

# Deploy specific environment
./deploy.sh roastah
./deploy.sh roastah-d
```

## Monitoring and Logging

- **Cloud Logging**: Centralized logging for all services
- **Cloud Monitoring**: Metrics and alerting
- **Error Reporting**: Application error tracking
- **Audit Logs**: Security and compliance logging

## Troubleshooting

### Common Issues

1. **Terraform State Lock**: If Terraform operations fail due to state locks
   ```bash
   terraform force-unlock <lock-id>
   ```

2. **Permission Errors**: Ensure proper IAM roles are assigned
   ```bash
   gcloud projects get-iam-policy <project-id>
   ```

3. **Secret Access**: Verify service accounts can access secrets
   ```bash
   gcloud secrets list --project=<project-id>
   ```

### Validation Commands

```bash
# Validate Terraform configurations
cd terraform/roastah && terraform validate
cd terraform/roastah-d && terraform validate

# Validate Python scripts
python3 -m py_compile apply_config.py

# Validate shell scripts
bash -n deploy.sh
```

## Contributing

1. Make changes to Terraform configurations
2. Test deployment: `./deploy.sh`
3. Update secrets if needed: `python3 apply_config.py update-secret <name> <value>`
4. Commit and push changes using your preferred method

## Migration Guide

For detailed migration instructions from the previous infrastructure approach, see [MIGRATION_GUIDE.md](MIGRATION_GUIDE.md).

## Support

For infrastructure issues or questions:
1. Check the troubleshooting section
2. Review Cloud Logging for error details
3. Validate configurations using the provided scripts
4. Consult the migration guide for recent changes
