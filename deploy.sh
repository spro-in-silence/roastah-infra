#!/bin/bash

# Roastah Infrastructure Deployment Script
# This script orchestrates the Terraform-first deployment approach

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ID="${1:-}"
ENVIRONMENT="${2:-}"
ACTION="${3:-}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Usage function
usage() {
    cat << EOF
Usage: $0 <project_id> <environment> <action>

Arguments:
  project_id   GCP Project ID (e.g., roastah, roastah-d)
  environment  Environment to deploy (dev, prod)
  action       Action to perform (plan, apply, destroy, secrets, validate)

Examples:
  $0 roastah-d dev plan
  $0 roastah prod apply
  $0 roastah-d dev secrets
  $0 roastah prod validate

EOF
    exit 1
}

# Validate arguments
if [[ $# -lt 3 ]]; then
    usage
fi

# Validate project ID
if [[ ! "$PROJECT_ID" =~ ^(roastah|roastah-d)$ ]]; then
    log_error "Invalid project ID: $PROJECT_ID"
    log_error "Valid options: roastah, roastah-d"
    exit 1
fi

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(dev|prod)$ ]]; then
    log_error "Invalid environment: $ENVIRONMENT"
    log_error "Valid options: dev, prod"
    exit 1
fi

# Validate action
if [[ ! "$ACTION" =~ ^(plan|apply|destroy|secrets|validate)$ ]]; then
    log_error "Invalid action: $ACTION"
    log_error "Valid options: plan, apply, destroy, secrets, validate"
    exit 1
fi

# Determine Terraform directory
if [[ "$PROJECT_ID" == "roastah" && "$ENVIRONMENT" == "prod" ]]; then
    TF_DIR="terraform/roastah"
elif [[ "$PROJECT_ID" == "roastah-d" && "$ENVIRONMENT" == "dev" ]]; then
    TF_DIR="terraform/roastah-d"
else
    log_error "Invalid project/environment combination: $PROJECT_ID/$ENVIRONMENT"
    exit 1
fi

# Check if Terraform directory exists
if [[ ! -d "$TF_DIR" ]]; then
    log_error "Terraform directory not found: $TF_DIR"
    exit 1
fi

log_info "Deploying to project: $PROJECT_ID"
log_info "Environment: $ENVIRONMENT"
log_info "Action: $ACTION"
log_info "Terraform directory: $TF_DIR"

# Function to run Terraform commands
run_terraform() {
    local cmd="$1"
    log_info "Running: terraform $cmd"
    
    cd "$TF_DIR"
    
    # Initialize Terraform if needed
    if [[ ! -d ".terraform" ]]; then
        log_info "Initializing Terraform..."
        terraform init
    fi
    
    # Run the command
    terraform $cmd
}

# Function to handle secrets
handle_secrets() {
    log_info "Managing secrets for $PROJECT_ID"
    
    # Check if .env file exists
    local env_file=".env.$ENVIRONMENT"
    if [[ ! -f "$env_file" ]]; then
        log_warning "Environment file $env_file not found"
        log_info "You can create it with the following variables:"
        cat << EOF
DATABASE_URL=your_database_url
OPENAI_API_KEY=your_openai_api_key
SESSION_SECRET=your_session_secret
GCP_SERVICE_ACCOUNT_KEY=your_service_account_key_json
EOF
        return
    fi
    
    # Update secrets from .env file
    log_info "Updating secrets from $env_file"
    python3 apply_config.py --project-id "$PROJECT_ID" --action update-from-env --env-file "$env_file"
}

# Function to validate infrastructure
validate_infrastructure() {
    log_info "Validating infrastructure for $PROJECT_ID"
    
    # Validate secrets
    python3 apply_config.py --project-id "$PROJECT_ID" --action validate
    
    # Validate Terraform
    run_terraform "validate"
    
    log_success "Infrastructure validation completed"
}

# Main execution
case "$ACTION" in
    "plan")
        log_info "Planning Terraform changes..."
        run_terraform "plan"
        ;;
        
    "apply")
        log_info "Applying Terraform changes..."
        run_terraform "apply -auto-approve"
        log_success "Infrastructure deployment completed"
        ;;
        
    "destroy")
        log_warning "This will destroy all infrastructure in $PROJECT_ID"
        read -p "Are you sure? (yes/no): " confirm
        if [[ "$confirm" == "yes" ]]; then
            run_terraform "destroy -auto-approve"
            log_success "Infrastructure destroyed"
        else
            log_info "Destroy cancelled"
        fi
        ;;
        
    "secrets")
        handle_secrets
        ;;
        
    "validate")
        validate_infrastructure
        ;;
        
    *)
        log_error "Unknown action: $ACTION"
        usage
        ;;
esac

log_success "Deployment script completed successfully!" 