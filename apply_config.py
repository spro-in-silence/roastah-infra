#!/usr/bin/env python3

import os
import yaml
import logging
from pathlib import Path
from google.cloud import resourcemanager_v3
from google.cloud import iam_v2
from google.cloud import run_v2
from google.cloud import cloudbuild_v1
from dotenv import load_dotenv

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class GCPConfigApplier:
    def __init__(self, project_id):
        self.project_id = project_id
        self.resource_manager = resourcemanager_v3.ProjectsClient()
        self.iam_client = iam_v2.IAMClient()
        self.run_client = run_v2.ServicesClient()
        self.build_client = cloudbuild_v1.CloudBuildClient()

    def apply_iam_config(self, config_path):
        """Apply IAM configurations from YAML file."""
        try:
            with open(config_path, 'r') as file:
                iam_config = yaml.safe_load(file)
            
            # Process IAM bindings
            for binding in iam_config.get('bindings', []):
                role = binding.get('role')
                members = binding.get('members', [])
                
                # Apply IAM policy
                policy = self.iam_client.get_iam_policy(
                    resource=f"projects/{self.project_id}"
                )
                
                # Add new binding
                policy.bindings.append({
                    'role': role,
                    'members': members
                })
                
                self.iam_client.set_iam_policy(
                    resource=f"projects/{self.project_id}",
                    policy=policy
                )
                logger.info(f"Applied IAM binding for role: {role}")
                
        except Exception as e:
            logger.error(f"Error applying IAM config: {str(e)}")
            raise

    def apply_cloudrun_config(self, config_path):
        """Apply Cloud Run configurations from YAML file."""
        try:
            with open(config_path, 'r') as file:
                run_config = yaml.safe_load(file)
            
            service = run_v2.Service()
            service.name = f"projects/{self.project_id}/locations/{run_config['location']}/services/{run_config['name']}"
            service.template = run_v2.RevisionTemplate()
            
            # Set container configuration
            container = run_v2.Container()
            container.image = run_config['image']
            container.env = run_config.get('env', [])
            container.resources = run_config.get('resources', {})
            
            service.template.containers = [container]
            
            # Create or update service
            self.run_client.create_service(
                parent=f"projects/{self.project_id}/locations/{run_config['location']}",
                service=service
            )
            logger.info(f"Applied Cloud Run config for service: {run_config['name']}")
            
        except Exception as e:
            logger.error(f"Error applying Cloud Run config: {str(e)}")
            raise

    def apply_cloudbuild_config(self, config_path):
        """Apply Cloud Build configurations from YAML file."""
        try:
            with open(config_path, 'r') as file:
                build_config = yaml.safe_load(file)
            
            build = cloudbuild_v1.Build()
            build.steps = []
            
            # Process build steps
            for step in build_config.get('steps', []):
                build_step = cloudbuild_v1.BuildStep()
                build_step.name = step['name']
                build_step.args = step.get('args', [])
                build.steps.append(build_step)
            
            # Create build trigger
            trigger = cloudbuild_v1.BuildTrigger()
            trigger.name = build_config['name']
            trigger.build = build
            
            self.build_client.create_build_trigger(
                project_id=self.project_id,
                trigger=trigger
            )
            logger.info(f"Applied Cloud Build config for trigger: {build_config['name']}")
            
        except Exception as e:
            logger.error(f"Error applying Cloud Build config: {str(e)}")
            raise

def main():
    # Load environment variables
    load_dotenv()
    
    # Get project ID from environment variable
    project_id = os.getenv('GCP_PROJECT_ID')
    if not project_id:
        raise ValueError("GCP_PROJECT_ID environment variable not set")
    
    applier = GCPConfigApplier(project_id)
    
    # Apply configurations from each directory
    config_dirs = ['iam', 'cloudrun', 'cloudbuild']
    
    for config_dir in config_dirs:
        config_path = Path(config_dir)
        if not config_path.exists():
            logger.warning(f"Directory {config_dir} does not exist, skipping...")
            continue
            
        for yaml_file in config_path.glob('*.yaml'):
            logger.info(f"Processing {yaml_file}")
            
            if config_dir == 'iam':
                applier.apply_iam_config(yaml_file)
            elif config_dir == 'cloudrun':
                applier.apply_cloudrun_config(yaml_file)
            elif config_dir == 'cloudbuild':
                applier.apply_cloudbuild_config(yaml_file)

if __name__ == "__main__":
    main() 