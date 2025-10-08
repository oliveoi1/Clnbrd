#!/bin/bash

# Clnbrd EdDSA Signature Generation Script
# Generates EdDSA signature for Sparkle updates using private key

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
PRIVATE_KEY_FILE="../../../.sparkle_keys/sparkle_eddsa_private.key"
SIGN_UPDATE_TOOL="/opt/homebrew/Caskroom/sparkle/2.8.0/bin/sign_update"

# Check for file argument
if [ -z "$1" ]; then
    echo -e "${RED}❌ Error: File path required${NC}"
    echo "Usage: $0 <FILE_PATH>"
    echo "Example: $0 ./Clnbrd-1.3.43.dmg"
    exit 1
fi

FILE_PATH="$1"

# Check if file exists
if [ ! -f "$FILE_PATH" ]; then
    echo -e "${RED}❌ Error: File not found: $FILE_PATH${NC}"
    exit 1
fi

# Check if private key exists
if [ ! -f "$PRIVATE_KEY_FILE" ]; then
    echo -e "${RED}❌ Error: Private key not found: $PRIVATE_KEY_FILE${NC}"
    echo "Please ensure the Sparkle private key is available."
    exit 1
fi

# Check if sign_update tool exists
if [ ! -f "$SIGN_UPDATE_TOOL" ]; then
    echo -e "${RED}❌ Error: sign_update tool not found: $SIGN_UPDATE_TOOL${NC}"
    echo "Please install Sparkle via Homebrew: brew install sparkle"
    exit 1
fi

echo -e "${CYAN}🔐 Generating EdDSA signature for: $(basename "$FILE_PATH")${NC}"

# Generate signature
SIGNATURE_OUTPUT=$("$SIGN_UPDATE_TOOL" "$FILE_PATH" "$PRIVATE_KEY_FILE")

# Extract signature and length
EDDSA_SIGNATURE=$(echo "$SIGNATURE_OUTPUT" | grep -o 'sparkle:edSignature="[^"]*"' | cut -d'"' -f2)
FILE_LENGTH=$(echo "$SIGNATURE_OUTPUT" | grep -o 'length="[^"]*"' | cut -d'"' -f2)

if [ -z "$EDDSA_SIGNATURE" ] || [ -z "$FILE_LENGTH" ]; then
    echo -e "${RED}❌ Error: Failed to generate signature${NC}"
    echo "Output: $SIGNATURE_OUTPUT"
    exit 1
fi

echo -e "${GREEN}✅ EdDSA signature generated successfully!${NC}"
echo -e "${BLUE}📝 Signature: $EDDSA_SIGNATURE${NC}"
echo -e "${BLUE}📏 Length: $FILE_LENGTH bytes${NC}"

# Output in format suitable for appcast.xml
echo ""
echo -e "${YELLOW}📋 Appcast XML attributes:${NC}"
echo "sparkle:edSignature=\"$EDDSA_SIGNATURE\""
echo "length=\"$FILE_LENGTH\""

# Also output as JSON for automation
echo ""
echo -e "${YELLOW}📋 JSON format:${NC}"
echo "{\"edSignature\":\"$EDDSA_SIGNATURE\",\"length\":\"$FILE_LENGTH\"}"
