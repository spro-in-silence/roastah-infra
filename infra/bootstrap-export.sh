#!/bin/bash

# === CONFIG ===
INFRA_REPO_DIR="/Users/awinash/IdeaProjects/rate-grid-infra"
DEV_PROJECT="rate-grid-d"
PROD_PROJECT="rate-grid"
REGION="us-central1"
DEV_SERVICE="rate-grid-d"
PROD_SERVICE="rate-grid"
DEV_TRIGGER="rate-grid-d"
PROD_TRIGGER="rate-grid"

# === SETUP ===
echo "Creating infra repo structure at $INFRA_REPO_DIR..."
mkdir -p "$INFRA_REPO_DIR"/{cloudbuild,cloudrun,iam,secrets}

# === CLOUD RUN EXPORT ===
echo "Exporting Cloud Run services..."

if gcloud run services describe "$DEV_SERVICE" \
  --project="$DEV_PROJECT" \
  --region="$REGION" &> /dev/null; then
  gcloud run services describe "$DEV_SERVICE" \
    --project="$DEV_PROJECT" \
    --region="$REGION" \
    --format yaml > "$INFRA_REPO_DIR/cloudrun/dev-service.yaml"
else
  echo "⚠️ Dev Cloud Run service [$DEV_SERVICE] does not exist yet — skipping export"
fi

if gcloud run services describe "$PROD_SERVICE" \
  --project="$PROD_PROJECT" \
  --region="$REGION" &> /dev/null; then
  gcloud run services describe "$PROD_SERVICE" \
    --project="$PROD_PROJECT" \
    --region="$REGION" \
    --format yaml > "$INFRA_REPO_DIR/cloudrun/prod-service.yaml"
else
  echo "⚠️ Prod Cloud Run service [$PROD_SERVICE] does not exist — skipping export"
fi

# === CLOUD BUILD TRIGGER EXPORT ===
echo "Exporting Cloud Build triggers..."

gcloud beta builds triggers export "$DEV_TRIGGER" \
  --project="$DEV_PROJECT" \
  --destination="$INFRA_REPO_DIR/cloudbuild/dev-trigger.yaml" || echo "⚠️ Dev trigger export failed or not found"

gcloud beta builds triggers export "$PROD_TRIGGER" \
  --project="$PROD_PROJECT" \
  --destination="$INFRA_REPO_DIR/cloudbuild/prod-trigger.yaml" || echo "⚠️ Prod trigger export failed or not found"

# === IAM POLICY EXPORT ===
echo "Exporting IAM policies..."
gcloud projects get-iam-policy "$DEV_PROJECT" \
  --format yaml > "$INFRA_REPO_DIR/iam/rate-grid-d-policy.yaml"

gcloud projects get-iam-policy "$PROD_PROJECT" \
  --format yaml > "$INFRA_REPO_DIR/iam/rate-grid-policy.yaml"

# === SECRET METADATA EXPORT ===
echo "Exporting Secret Manager metadata (no values)..."
SECRETS=$(gcloud secrets list --project="$PROD_PROJECT" --format="value(name)")
for secret in $SECRETS; do
  gcloud secrets describe "$secret" \
    --project="$PROD_PROJECT" \
    --format yaml > "$INFRA_REPO_DIR/secrets/${secret}.yaml"
done

# === GIT INIT (optional) ===
echo "Initializing Git repo (optional)..."
cd "$INFRA_REPO_DIR"
git init
git add .
git commit -m "Initial infrastructure export"
echo "✅ Infra repo initialized at: $INFRA_REPO_DIR"
