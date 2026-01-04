#!/bin/bash
# Setup Clerk JWT Authentication for Kong Gateway
#
# This script fetches the public key from Clerk's JWKS endpoint
# and configures Kong to validate JWTs from Clerk.
#
# Prerequisites:
# - Kong Gateway running with Admin API accessible
# - CLERK_JWKS_URL environment variable set
# - jq installed for JSON parsing

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
KONG_ADMIN_URL="${KONG_ADMIN_URL:-http://localhost:8081}"
CLERK_JWKS_URL="${CLERK_JWKS_URL:-}"

echo "=== Clerk JWT Setup for Kong Gateway ==="
echo ""

# Check prerequisites
if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error: jq is required but not installed.${NC}"
    echo "Install with: apt-get install jq"
    exit 1
fi

if [ -z "$CLERK_JWKS_URL" ]; then
    echo -e "${YELLOW}CLERK_JWKS_URL not set. Please provide Clerk JWKS URL.${NC}"
    echo ""
    echo "Usage: CLERK_JWKS_URL=https://your-domain.clerk.accounts.dev/.well-known/jwks.json ./setup-clerk-jwt.sh"
    echo ""
    read -p "Enter Clerk JWKS URL: " CLERK_JWKS_URL

    if [ -z "$CLERK_JWKS_URL" ]; then
        echo -e "${RED}Error: CLERK_JWKS_URL is required${NC}"
        exit 1
    fi
fi

# Extract issuer from JWKS URL
CLERK_ISSUER=$(echo "$CLERK_JWKS_URL" | sed 's|/.well-known/jwks.json||')

echo "1. Fetching JWKS from Clerk..."
echo "   URL: $CLERK_JWKS_URL"

JWKS_RESPONSE=$(curl -s "$CLERK_JWKS_URL")

if [ -z "$JWKS_RESPONSE" ] || [ "$(echo "$JWKS_RESPONSE" | jq -r '.keys | length')" = "0" ]; then
    echo -e "${RED}Error: Failed to fetch JWKS or no keys found${NC}"
    exit 1
fi

echo -e "${GREEN}   Found $(echo "$JWKS_RESPONSE" | jq -r '.keys | length') key(s)${NC}"

# Get the first RS256 key
RSA_KEY=$(echo "$JWKS_RESPONSE" | jq -r '.keys[] | select(.alg == "RS256") | @base64' | head -1)

if [ -z "$RSA_KEY" ]; then
    echo -e "${RED}Error: No RS256 key found in JWKS${NC}"
    exit 1
fi

# Decode key properties
KEY_ID=$(echo "$RSA_KEY" | base64 -d | jq -r '.kid')
KEY_N=$(echo "$RSA_KEY" | base64 -d | jq -r '.n')
KEY_E=$(echo "$RSA_KEY" | base64 -d | jq -r '.e')

echo "   Key ID: $KEY_ID"

echo ""
echo "2. Checking Kong Admin API..."
KONG_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$KONG_ADMIN_URL/status")

if [ "$KONG_STATUS" != "200" ]; then
    echo -e "${RED}Error: Kong Admin API not accessible (HTTP $KONG_STATUS)${NC}"
    echo "Make sure Kong is running: docker compose up -d"
    exit 1
fi
echo -e "${GREEN}   Kong Admin API is accessible${NC}"

echo ""
echo "3. Checking if clerk-jwt consumer exists..."
CONSUMER_EXISTS=$(curl -s -o /dev/null -w "%{http_code}" "$KONG_ADMIN_URL/consumers/clerk-jwt")

if [ "$CONSUMER_EXISTS" != "200" ]; then
    echo "   Creating clerk-jwt consumer..."
    curl -s -X POST "$KONG_ADMIN_URL/consumers" \
        -d "username=clerk-jwt" \
        -d "custom_id=clerk-issuer" \
        -d "tags=clerk,jwt" > /dev/null
    echo -e "${GREEN}   Consumer created${NC}"
else
    echo -e "${GREEN}   Consumer already exists${NC}"
fi

echo ""
echo "4. Converting JWKS to PEM format..."

# Create a temporary Python script to convert JWK to PEM
python3 << EOF
import json
import base64
import sys

def base64url_decode(data):
    padding = 4 - len(data) % 4
    if padding != 4:
        data += '=' * padding
    return base64.urlsafe_b64decode(data)

def int_from_bytes(b):
    return int.from_bytes(b, 'big')

# Key components from JWKS
n = base64url_decode("$KEY_N")
e = base64url_decode("$KEY_E")

# Convert to integers
n_int = int_from_bytes(n)
e_int = int_from_bytes(e)

# Create RSA public key in PEM format using cryptography library if available
try:
    from cryptography.hazmat.primitives.asymmetric import rsa
    from cryptography.hazmat.primitives import serialization
    from cryptography.hazmat.backends import default_backend

    public_numbers = rsa.RSAPublicNumbers(e_int, n_int)
    public_key = public_numbers.public_key(default_backend())

    pem = public_key.public_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PublicFormat.SubjectPublicKeyInfo
    )

    print(pem.decode('utf-8'))
except ImportError:
    # Fallback: output the key info for manual conversion
    print("ERROR: cryptography library not installed")
    print("Install with: pip install cryptography")
    sys.exit(1)
EOF

if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to convert key to PEM format${NC}"
    echo "Install cryptography: pip install cryptography"
    exit 1
fi

# Save PEM to temp file
PEM_FILE=$(mktemp)
python3 << EOF > "$PEM_FILE"
import json
import base64

def base64url_decode(data):
    padding = 4 - len(data) % 4
    if padding != 4:
        data += '=' * padding
    return base64.urlsafe_b64decode(data)

def int_from_bytes(b):
    return int.from_bytes(b, 'big')

n = base64url_decode("$KEY_N")
e = base64url_decode("$KEY_E")
n_int = int_from_bytes(n)
e_int = int_from_bytes(e)

from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.backends import default_backend

public_numbers = rsa.RSAPublicNumbers(e_int, n_int)
public_key = public_numbers.public_key(default_backend())

pem = public_key.public_bytes(
    encoding=serialization.Encoding.PEM,
    format=serialization.PublicFormat.SubjectPublicKeyInfo
)

print(pem.decode('utf-8'), end='')
EOF

echo -e "${GREEN}   PEM key generated${NC}"

echo ""
echo "5. Adding JWT credentials to Kong..."

# Check if JWT already exists
JWT_EXISTS=$(curl -s "$KONG_ADMIN_URL/consumers/clerk-jwt/jwt" | jq -r '.data | length')

if [ "$JWT_EXISTS" != "0" ]; then
    echo "   Removing existing JWT credentials..."
    JWT_IDS=$(curl -s "$KONG_ADMIN_URL/consumers/clerk-jwt/jwt" | jq -r '.data[].id')
    for id in $JWT_IDS; do
        curl -s -X DELETE "$KONG_ADMIN_URL/consumers/clerk-jwt/jwt/$id" > /dev/null
    done
fi

# Add new JWT credential
curl -s -X POST "$KONG_ADMIN_URL/consumers/clerk-jwt/jwt" \
    -F "algorithm=RS256" \
    -F "key=$CLERK_ISSUER" \
    -F "rsa_public_key=<$PEM_FILE" > /dev/null

echo -e "${GREEN}   JWT credentials added${NC}"

# Cleanup
rm -f "$PEM_FILE"

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Configuration:"
echo "  Issuer:  $CLERK_ISSUER"
echo "  Key ID:  $KEY_ID"
echo "  Algorithm: RS256"
echo ""
echo "Test with:"
echo "  curl -H 'Authorization: Bearer \$CLERK_TOKEN' http://localhost:8080/v1/status"
