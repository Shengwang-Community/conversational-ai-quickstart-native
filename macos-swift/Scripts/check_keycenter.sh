#!/bin/bash

# Script to check and create KeyCenter.swift from template
# This should be added to Xcode Build Phases
# This script will FAIL the build if KeyCenter is not properly configured

set -e

KEYCENTER_FILE="${SRCROOT}/VoiceAgent/KeyCenter.swift"
TEMPLATE_FILE="${SRCROOT}/KeyCenter.swift.example"

echo "🔍 Checking KeyCenter.swift configuration..."

# Check if KeyCenter.swift exists
if [ ! -f "$KEYCENTER_FILE" ]; then
    echo ""
    echo "❌ ERROR: KeyCenter.swift not found!"
    echo ""
    
    # Check if template exists
    if [ -f "$TEMPLATE_FILE" ]; then
        echo "📝 Creating KeyCenter.swift from template..."
        cp "$TEMPLATE_FILE" "$KEYCENTER_FILE"
        echo ""
        echo "╔════════════════════════════════════════════════════════╗"
        echo "║  ⚠️  BUILD FAILED: KeyCenter needs configuration     ║"
        echo "╚════════════════════════════════════════════════════════╝"
        echo ""
        echo "KeyCenter.swift has been created from template at:"
        echo "  $KEYCENTER_FILE"
        echo ""
        echo "Please update it with your actual Agora credentials:"
        echo "  • AGORA_APP_ID"
        echo "  • AGORA_APP_CERTIFICATE"
        echo "  • LLM_API_KEY"
        echo "  • TTS_BYTEDANCE_APP_ID"
        echo "  • TTS_BYTEDANCE_TOKEN"
        echo ""
        echo "Get your credentials from: https://console.agora.io/"
        echo ""
        echo "Then rebuild the project."
        echo ""
        exit 1
    else
        echo "❌ FATAL ERROR: Template file not found!"
        echo ""
        echo "Expected template at: $TEMPLATE_FILE"
        echo ""
        echo "Please restore KeyCenter.swift.example to project root"
        echo ""
        exit 1
    fi
fi

# Validate that KeyCenter.swift has been properly configured
if grep -q "YOUR_APP_ID_HERE" "$KEYCENTER_FILE"; then
    echo ""
    echo "╔════════════════════════════════════════════════════════╗"
    echo "║  ❌ BUILD FAILED: KeyCenter not configured           ║"
    echo "╚════════════════════════════════════════════════════════╝"
    echo ""
    echo "KeyCenter.swift still contains placeholder values!"
    echo ""
    echo "File location:"
    echo "  $KEYCENTER_FILE"
    echo ""
    echo "Required actions:"
    echo "  1. Open KeyCenter.swift"
    echo "  2. Replace 'YOUR_APP_ID_HERE' with your actual Agora App ID"
    echo "  3. Replace 'YOUR_APP_CERTIFICATE_HERE' with your App Certificate"
    echo "  4. Replace 'YOUR_LLM_API_KEY_HERE' with your LLM API Key"
    echo "  5. Replace ByteDance TTS placeholders with your provider credentials"
    echo ""
    echo "Get credentials from: https://console.agora.io/"
    echo ""
    exit 1
fi

# Additional validation: check if essential fields are not empty
if grep -q 'AGORA_APP_ID = ""' "$KEYCENTER_FILE"; then
    echo ""
    echo "❌ BUILD FAILED: AGORA_APP_ID is empty in KeyCenter.swift"
    echo ""
    echo "Please configure your Agora App ID and rebuild."
    echo ""
    exit 1
fi

echo "✅ KeyCenter.swift validation passed"
echo ""
