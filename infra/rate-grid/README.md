# rate-grid-infra
YAML Configurations for GCP

This project provides a Python-based solution to apply YAML configurations to various GCP services including IAM, Cloud Run, and Cloud Build.

## Prerequisites

1. Python 3.7 or higher
2. Google Cloud SDK installed and configured
3. Required Python packages (install using `pip install -r requirements.txt`)

## Setup

1. Create a `.env` file in the project root with your GCP project ID:
   ```
   GCP_PROJECT_ID=your-project-id
   ```

2. Ensure you have the necessary GCP permissions to manage IAM, Cloud Run, and Cloud Build resources.

## Directory Structure

- `iam/`: Contains IAM configuration YAML files
- `cloudrun/`: Contains Cloud Run service configuration YAML files
- `cloudbuild/`: Contains Cloud Build trigger configuration YAML files

## Usage

1. Place your YAML configuration files in the appropriate directories following the sample formats provided.

2. Run the configuration applier:
   ```bash
   python apply_config.py
   ```

The script will:
- Process all YAML files in the configuration directories
- Apply IAM policies
- Create/update Cloud Run services
- Create Cloud Build triggers

## Configuration File Formats

### IAM Configuration
```yaml
bindings:
  - role: roles/example.role
    members:
      - user:user@example.com
      - serviceAccount:service@project.iam.gserviceaccount.com
```

### Cloud Run Configuration
```yaml
name: service-name
location: region
image: gcr.io/project/image:tag
env:
  - name: ENV_VAR
    value: value
resources:
  limits:
    cpu: "1"
    memory: "512Mi"
```

### Cloud Build Configuration
```yaml
name: trigger-name
description: "Trigger description"
steps:
  - name: builder-image
    args:
      - command
      - arguments
```

## Error Handling

The script includes logging and error handling. Check the console output for any issues during configuration application.
