#!/bin/bash
# =============================================================================
# E2EE KMS Infrastructure Setup Script
# =============================================================================
#
# Sets up Google Cloud KMS keys and IAM policies required for the
# E2EE chat encryption system.
#
# Prerequisites:
#   - gcloud CLI installed and authenticated
#   - Billing enabled on the GCP project
#   - Cloud KMS API enabled: gcloud services enable cloudkms.googleapis.com
#
# Usage:
#   chmod +x scripts/setup_e2ee_kms.sh
#   ./scripts/setup_e2ee_kms.sh <PROJECT_ID>
#
# =============================================================================

set -euo pipefail

PROJECT_ID="${1:?Usage: $0 <PROJECT_ID>}"
LOCATION="global"
KEY_RING="e2ee-chat"

echo "🔐 Setting up E2EE KMS infrastructure for project: ${PROJECT_ID}"
echo "   Location: ${LOCATION}"
echo "   Key Ring: ${KEY_RING}"
echo ""

# Ensure KMS API is enabled
echo "📦 Enabling Cloud KMS API..."
gcloud services enable cloudkms.googleapis.com --project="${PROJECT_ID}"

# Create key ring (idempotent — errors if exists, which is fine)
echo "🔑 Creating KMS key ring: ${KEY_RING}..."
gcloud kms keyrings create "${KEY_RING}" \
  --location="${LOCATION}" \
  --project="${PROJECT_ID}" 2>/dev/null || echo "   Key ring already exists"

# =============================================================================
# Key 1: PreKey Attestation Key (EC P-256 Asymmetric Signing)
# Used by Cloud Functions to sign PreKeyBundles, proving they were
# published through an authorized channel.
# =============================================================================
echo "🔑 Creating prekey-attestation-key..."
gcloud kms keys create prekey-attestation-key \
  --keyring="${KEY_RING}" \
  --location="${LOCATION}" \
  --project="${PROJECT_ID}" \
  --purpose=asymmetric-signing \
  --default-algorithm=ec-sign-p256-sha256 2>/dev/null || echo "   Key already exists"

# =============================================================================
# Key 2: Backup Wrapping Key (AES-256-GCM Symmetric, 90-day auto-rotation)
# Used to add a server-side encryption layer on key backups
# (defense in depth — client already encrypts with passphrase).
# =============================================================================
echo "🔑 Creating backup-wrapping-key..."
gcloud kms keys create backup-wrapping-key \
  --keyring="${KEY_RING}" \
  --location="${LOCATION}" \
  --project="${PROJECT_ID}" \
  --purpose=encryption \
  --default-algorithm=google-symmetric-encryption \
  --rotation-period=7776000s 2>/dev/null || echo "   Key already exists"

# =============================================================================
# Key 3: Audit Log Signing Key (EC P-256 Asymmetric Signing)
# Used to sign entries in the key transparency log, ensuring
# tamper-evidence of key change events.
# =============================================================================
echo "🔑 Creating audit-log-signing-key..."
gcloud kms keys create audit-log-signing-key \
  --keyring="${KEY_RING}" \
  --location="${LOCATION}" \
  --project="${PROJECT_ID}" \
  --purpose=asymmetric-signing \
  --default-algorithm=ec-sign-p256-sha256 2>/dev/null || echo "   Key already exists"

# =============================================================================
# IAM: Grant Cloud Functions service account access
# =============================================================================
SERVICE_ACCOUNT="${PROJECT_ID}@appspot.gserviceaccount.com"
echo ""
echo "🔒 Granting IAM permissions to: ${SERVICE_ACCOUNT}"

# PreKey Attestation — sign + verify
echo "   → prekey-attestation-key: signerVerifier"
gcloud kms keys add-iam-policy-binding prekey-attestation-key \
  --keyring="${KEY_RING}" \
  --location="${LOCATION}" \
  --project="${PROJECT_ID}" \
  --member="serviceAccount:${SERVICE_ACCOUNT}" \
  --role="roles/cloudkms.signerVerifier" \
  --quiet

# Backup Wrapping — encrypt + decrypt
echo "   → backup-wrapping-key: cryptoKeyEncrypterDecrypter"
gcloud kms keys add-iam-policy-binding backup-wrapping-key \
  --keyring="${KEY_RING}" \
  --location="${LOCATION}" \
  --project="${PROJECT_ID}" \
  --member="serviceAccount:${SERVICE_ACCOUNT}" \
  --role="roles/cloudkms.cryptoKeyEncrypterDecrypter" \
  --quiet

# Audit Log — sign only
echo "   → audit-log-signing-key: signer"
gcloud kms keys add-iam-policy-binding audit-log-signing-key \
  --keyring="${KEY_RING}" \
  --location="${LOCATION}" \
  --project="${PROJECT_ID}" \
  --member="serviceAccount:${SERVICE_ACCOUNT}" \
  --role="roles/cloudkms.signer" \
  --quiet

echo ""
echo "✅ E2EE KMS infrastructure setup complete!"
echo ""
echo "Key ring: projects/${PROJECT_ID}/locations/${LOCATION}/keyRings/${KEY_RING}"
echo "Keys:"
echo "  1. prekey-attestation-key  (EC P-256 asymmetric signing)"
echo "  2. backup-wrapping-key     (AES-256-GCM symmetric, 90-day rotation)"
echo "  3. audit-log-signing-key   (EC P-256 asymmetric signing)"
