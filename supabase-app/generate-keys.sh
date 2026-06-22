#!/bin/bash
# Generate secure keys for the minimal Supabase self-host setup
set -euo pipefail

cd "$(dirname "$0")"

ENV_FILE=".env"

if [ ! -f "$ENV_FILE" ]; then
  if [ -f .env.example ]; then
    cp .env.example "$ENV_FILE"
    echo "→ Created $ENV_FILE from .env.example"
  else
    echo "ERROR: No .env or .env.example found"
    exit 1
  fi
fi

echo "=== Generating secrets ==="

# 1. POSTGRES_PASSWORD (secure random, alphanumeric for safe connection strings)
PG_PASS=$(openssl rand -base64 32 | tr -d '/+=' | head -c 32)
sed -i "s/^POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=${PG_PASS}/" "$ENV_FILE"
echo "→ POSTGRES_PASSWORD generated"

# 2. JWT_SECRET (at least 32 chars)
JWT_SECRET=$(openssl rand -base64 48 | tr -d '/+=' | head -c 48)
sed -i "s/^JWT_SECRET=.*/JWT_SECRET=${JWT_SECRET}/" "$ENV_FILE"
echo "→ JWT_SECRET generated"

# 3. SECRET_KEY_BASE (at least 64 chars)
SECRET_KEY=$(openssl rand -base64 64 | tr -d '/+=' | head -c 64)
sed -i "s/^SECRET_KEY_BASE=.*/SECRET_KEY_BASE=${SECRET_KEY}/" "$ENV_FILE"
echo "→ SECRET_KEY_BASE generated"

# 4. Generate pre-signed JWT tokens (ANON_KEY and SERVICE_ROLE_KEY)
base64url_encode() {
  echo -n "$1" | base64 -w0 | tr '/+' '_-' | tr -d '='
}

jwt_sign() {
  local role="$1"
  local now
  now=$(date +%s)
  local exp=$((now + 10 * 365 * 24 * 3600)) # 10 years

  local header='{"alg":"HS256","typ":"JWT"}'
  local payload="{\"role\":\"${role}\",\"iss\":\"supabase\",\"iat\":${now},\"exp\":${exp}}"

  local header_b64=$(base64url_encode "$header")
  local payload_b64=$(base64url_encode "$payload")
  local signature=$(echo -n "${header_b64}.${payload_b64}" | openssl dgst -sha256 -hmac "$JWT_SECRET" -binary | base64 -w0 | tr '/+' '_-' | tr -d '=')

  echo "${header_b64}.${payload_b64}.${signature}"
}

ANON_KEY=$(jwt_sign "anon")
SERVICE_ROLE_KEY=$(jwt_sign "service_role")

# Use different sed delimiters since the keys contain base64 chars
sed -i "s|^ANON_KEY=.*|ANON_KEY=${ANON_KEY}|" "$ENV_FILE"
sed -i "s|^SERVICE_ROLE_KEY=.*|SERVICE_ROLE_KEY=${SERVICE_ROLE_KEY}|" "$ENV_FILE"
echo "→ ANON_KEY generated"
echo "→ SERVICE_ROLE_KEY generated"

echo ""
echo "=== Done! Review $ENV_FILE ==="
echo ""
echo "Key credentials:"
echo "  SERVICE_ROLE_KEY (server-only): ${SERVICE_ROLE_KEY:0:30}..."
echo "  ANON_KEY (client-safe):         ${ANON_KEY:0:30}..."
