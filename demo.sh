#!/bin/bash

# Demo script for MacOS Agent CLI
# This demonstrates the basic functionality

set -e

AGENT=".build/debug/macos-agent"

if [ ! -f "$AGENT" ]; then
    echo "Building agent..."
    swift build
fi

echo "=== MacOS Agent Demo ==="
echo ""

echo "1. Taking screenshot..."
$AGENT screenshot --output /tmp/demo-screenshot.png
echo "   ✓ Screenshot saved to /tmp/demo-screenshot.png"
echo ""

echo "2. Capturing accessibility snapshot (frontmost app)..."
$AGENT snapshot > /tmp/demo-snapshot.json
echo "   ✓ Snapshot saved to /tmp/demo-snapshot.json"
echo ""

echo "3. Getting screenshot as base64 (first 80 chars)..."
$AGENT screenshot | head -c 80
echo "..."
echo ""

echo "4. Checking multi-display support..."
DISPLAY_COUNT=$($AGENT screenshot --all-displays | jq '. | length')
echo "   ✓ Found $DISPLAY_COUNT display(s)"
echo ""

echo "Demo complete!"
echo ""
echo "Next steps:"
echo "  - View snapshot: cat /tmp/demo-snapshot.json | jq"
echo "  - View screenshot: open /tmp/demo-screenshot.png"
echo "  - Try actions: $AGENT ax press --element-id <id>"
echo "  - See examples: cat EXAMPLES.md"
