#!/bin/bash

# Generate Sparkle EdDSA keys for signing updates
# Run this once to create your key pair

set -e

SPARKLE_VERSION="2.8.1"
TEMP_DIR=$(mktemp -d)

echo "Downloading Sparkle ${SPARKLE_VERSION}..."
curl -L -o "${TEMP_DIR}/Sparkle.tar.xz" \
  "https://github.com/sparkle-project/Sparkle/releases/download/${SPARKLE_VERSION}/Sparkle-${SPARKLE_VERSION}.tar.xz"

echo "Extracting..."
mkdir -p "${TEMP_DIR}/Sparkle"
tar -xf "${TEMP_DIR}/Sparkle.tar.xz" -C "${TEMP_DIR}/Sparkle"

echo ""
echo "=========================================="
echo "Generating EdDSA key pair..."
echo "=========================================="
echo ""

"${TEMP_DIR}/Sparkle/bin/generate_keys"

echo ""
echo "=========================================="
echo "NEXT STEPS:"
echo "=========================================="
echo ""
echo "1. Copy the PRIVATE key (starts with 'A]key:') and add it as a GitHub secret:"
echo "   - Go to: https://github.com/desaianand1/BatteryBoi-Recharged/settings/secrets/actions"
echo "   - Click 'New repository secret'"
echo "   - Name: SPARKLE_PRIVATE_KEY"
echo "   - Value: <paste the base64 string after 'A]key:'>"
echo ""
echo "2. Copy the PUBLIC key and update Info.plist:"
echo "   - Open BatteryBoi/Info.plist"
echo "   - Find SUPublicEDKey"
echo "   - Replace the empty string with your public key"
echo ""
echo "3. IMPORTANT: Keep your private key safe! If you lose it, you'll need to"
echo "   generate new keys and users won't be able to update from old versions."
echo ""

# Cleanup
rm -rf "${TEMP_DIR}"
