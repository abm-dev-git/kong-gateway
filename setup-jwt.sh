#!/bin/bash
# Kong JWT Setup Script for Clerk Authentication
# This script configures JWT authentication by fetching Clerk's public key
# and adding it to the Kong consumer via Admin API

set -e

echo "Setting up Kong JWT authentication for Clerk..."

# Configuration
KONG_ADMIN_URL="http://127.0.0.1:8001"
CONSUMER_NAME="clerk-jwt"
# Clerk prod runs in proxy mode: iss claim is the frontend_api_url, NOT the
# CNAME host. Kong's JWT plugin matches `key` against the `iss` claim
# (key_claim_name: iss in kong.yml), so this MUST be the proxy URL.
# Verified via GET https://api.clerk.com/v1/domains (2026-04-19):
#   frontend_api_url / proxy_url = "https://abm.dev/api/clerk-proxy"
ISSUER="https://abm.dev/api/clerk-proxy"
JWKS_URL="https://abm.dev/api/clerk-proxy/.well-known/jwks.json"

# Wait for Kong Admin API to be available
echo "Waiting for Kong Admin API to be ready..."
for i in {1..30}; do
    if curl -s "${KONG_ADMIN_URL}/status" > /dev/null 2>&1; then
        echo "Kong Admin API is ready"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "ERROR: Kong Admin API not available after 30 seconds"
        exit 1
    fi
    sleep 1
done

# Check if JWT credential already exists
echo "Checking for existing JWT credentials..."
existing_jwt=$(curl -s "${KONG_ADMIN_URL}/consumers/${CONSUMER_NAME}/jwt" || echo "")

if echo "$existing_jwt" | grep -q '"key"'; then
    echo "JWT credentials already exist for ${CONSUMER_NAME}"
    echo "Skipping setup..."
    exit 0
fi

# Fetch JWKS and extract public key
echo "Fetching JWKS from ${JWKS_URL}..."
jwks=$(curl -s "${JWKS_URL}")

if [ -z "$jwks" ]; then
    echo "ERROR: Failed to fetch JWKS from ${JWKS_URL}"
    exit 1
fi

# Extract n and e values from JWKS
n=$(echo "$jwks" | jq -r '.keys[0].n')
e=$(echo "$jwks" | jq -r '.keys[0].e')
kid=$(echo "$jwks" | jq -r '.keys[0].kid')

if [ "$n" = "null" ] || [ "$e" = "null" ]; then
    echo "ERROR: Invalid JWKS response - missing n or e values"
    echo "JWKS response: $jwks"
    exit 1
fi

echo "Successfully extracted public key components (kid: $kid)"

# Convert JWKS to PEM format using Node.js (if available) or Python
if command -v node > /dev/null 2>&1; then
    echo "Converting JWKS to PEM format using Node.js..."
    pem_key=$(node -e "
        const crypto = require('crypto');
        const jwks = $jwks;
        const key = jwks.keys[0];

        // Convert base64url to base64
        const base64urlToBase64 = (str) => {
            return str.replace(/-/g, '+').replace(/_/g, '/').padEnd(str.length + (4 - str.length % 4) % 4, '=');
        };

        // Create RSA key object
        const n = Buffer.from(base64urlToBase64(key.n), 'base64');
        const e = Buffer.from(base64urlToBase64(key.e), 'base64');

        // Create public key in PEM format
        const publicKey = crypto.createPublicKey({
            key: {
                kty: 'RSA',
                n: key.n,
                e: key.e
            },
            format: 'jwk'
        });

        const pem = publicKey.export({ type: 'spki', format: 'pem' });
        console.log(pem);
    ")

    if [ $? -eq 0 ] && [ -n "$pem_key" ]; then
        echo "Successfully converted to PEM format"
    else
        echo "ERROR: Failed to convert JWKS to PEM format"
        exit 1
    fi
else
    echo "ERROR: Node.js not available for PEM conversion"
    echo "Please install Node.js or manually configure JWT credentials"
    exit 1
fi

# Add JWT credential to Kong consumer
echo "Adding JWT credential to Kong consumer ${CONSUMER_NAME}..."

response=$(curl -s -X POST "${KONG_ADMIN_URL}/consumers/${CONSUMER_NAME}/jwt" \
    -d "algorithm=RS256" \
    -d "key=${ISSUER}" \
    -d "rsa_public_key=${pem_key}")

if echo "$response" | grep -q '"key"'; then
    echo "✓ Successfully configured JWT authentication for ${CONSUMER_NAME}"
    echo "✓ Issuer: ${ISSUER}"
    echo "✓ Algorithm: RS256"
else
    echo "ERROR: Failed to add JWT credential"
    echo "Response: $response"
    exit 1
fi

echo "JWT setup completed successfully!"