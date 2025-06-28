#!/usr/bin/env python3

import os
import yaml
import logging
import argparse
from pathlib import Path
from google.cloud import secretmanager_v1
from dotenv import load_dotenv

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class GCPOperationalManager:
    def __init__(self, project_id):
        self.project_id = project_id
        self.secret_client = secretmanager_v1.SecretManagerServiceClient()

    def update_secret_value(self, secret_id, secret_value):
        """Update a secret value in Secret Manager."""
        try:
            secret_path = f"projects/{self.project_id}/secrets/{secret_id}"
            
            # Create the secret version
            parent = self.secret_client.secret_path(self.project_id, secret_id)
            payload = secretmanager_v1.SecretPayload(data=secret_value.encode('UTF-8'))
            
            # Add the secret version
            response = self.secret_client.add_secret_version(
                request={
                    "parent": parent,
                    "payload": payload,
                }
            )
            
            logger.info(f"Updated secret {secret_id} with version: {response.name}")
            return response.name
            
        except Exception as e:
            logger.error(f"Error updating secret {secret_id}: {str(e)}")
            raise

    def list_secrets(self):
        """List all secrets in the project."""
        try:
            parent = f"projects/{self.project_id}"
            request = secretmanager_v1.ListSecretsRequest(parent=parent)
            
            secrets = []
            for secret in self.secret_client.list_secrets(request=request):
                secrets.append({
                    'name': secret.name,
                    'secret_id': secret.secret_id,
                    'create_time': secret.create_time,
                    'labels': dict(secret.labels) if secret.labels else {}
                })
            
            return secrets
            
        except Exception as e:
            logger.error(f"Error listing secrets: {str(e)}")
            raise

    def get_secret_latest_version(self, secret_id):
        """Get the latest version of a secret."""
        try:
            secret_path = f"projects/{self.project_id}/secrets/{secret_id}/versions/latest"
            response = self.secret_client.access_secret_version(request={"name": secret_path})
            return response.payload.data.decode('UTF-8')
            
        except Exception as e:
            logger.error(f"Error getting secret {secret_id}: {str(e)}")
            raise

    def update_secrets_from_env_file(self, env_file_path):
        """Update secrets from a .env file."""
        try:
            if not os.path.exists(env_file_path):
                logger.error(f"Environment file {env_file_path} not found")
                return
            
            # Load environment variables from file
            load_dotenv(env_file_path)
            
            # Common secret names to update
            secret_mappings = {
                'DATABASE_URL': 'DATABASE_URL',
                'OPENAI_API_KEY': 'OPENAI_API_KEY',
                'SESSION_SECRET': 'SESSION_SECRET',
                'GCP_SERVICE_ACCOUNT_KEY': 'GCP_SERVICE_ACCOUNT_KEY'
            }
            
            updated_secrets = []
            for env_var, secret_id in secret_mappings.items():
                value = os.getenv(env_var)
                if value:
                    self.update_secret_value(secret_id, value)
                    updated_secrets.append(secret_id)
                    logger.info(f"Updated secret {secret_id}")
                else:
                    logger.warning(f"Environment variable {env_var} not found in {env_file_path}")
            
            logger.info(f"Updated {len(updated_secrets)} secrets: {', '.join(updated_secrets)}")
            
        except Exception as e:
            logger.error(f"Error updating secrets from env file: {str(e)}")
            raise

    def validate_infrastructure(self):
        """Validate that all required secrets exist."""
        try:
            required_secrets = [
                'DATABASE_URL',
                'OPENAI_API_KEY', 
                'SESSION_SECRET',
                'GCP_SERVICE_ACCOUNT_KEY'
            ]
            
            existing_secrets = [secret['secret_id'] for secret in self.list_secrets()]
            missing_secrets = [secret for secret in required_secrets if secret not in existing_secrets]
            
            if missing_secrets:
                logger.error(f"Missing required secrets: {', '.join(missing_secrets)}")
                return False
            else:
                logger.info("All required secrets exist")
                return True
                
        except Exception as e:
            logger.error(f"Error validating infrastructure: {str(e)}")
            return False

def main():
    parser = argparse.ArgumentParser(description='GCP Operational Management Tool')
    parser.add_argument('--project-id', required=True, help='GCP Project ID')
    parser.add_argument('--action', required=True, 
                       choices=['update-secret', 'list-secrets', 'get-secret', 'update-from-env', 'validate'],
                       help='Action to perform')
    parser.add_argument('--secret-id', help='Secret ID for secret operations')
    parser.add_argument('--secret-value', help='Secret value for update operations')
    parser.add_argument('--env-file', help='Path to .env file for bulk updates')
    
    args = parser.parse_args()
    
    # Load environment variables
    load_dotenv()
    
    manager = GCPOperationalManager(args.project_id)
    
    if args.action == 'update-secret':
        if not args.secret_id or not args.secret_value:
            logger.error("--secret-id and --secret-value are required for update-secret action")
            return
        manager.update_secret_value(args.secret_id, args.secret_value)
        
    elif args.action == 'list-secrets':
        secrets = manager.list_secrets()
        for secret in secrets:
            print(f"Secret: {secret['secret_id']} (Created: {secret['create_time']})")
            
    elif args.action == 'get-secret':
        if not args.secret_id:
            logger.error("--secret-id is required for get-secret action")
            return
        value = manager.get_secret_latest_version(args.secret_id)
        print(f"Secret {args.secret_id}: {value}")
        
    elif args.action == 'update-from-env':
        if not args.env_file:
            logger.error("--env-file is required for update-from-env action")
            return
        manager.update_secrets_from_env_file(args.env_file)
        
    elif args.action == 'validate':
        success = manager.validate_infrastructure()
        if not success:
            exit(1)

if __name__ == "__main__":
    main() 