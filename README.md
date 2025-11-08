# MacOS Agent CLI

A CLI tool for interacting with macOS using Accessibility APIs and CoreGraphics events.

## Setup

### Prerequisites
- macOS 13.0+
- Swift 5.9+
- Xcode Command Line Tools

### Build
```bash
make build        # Debug build
make release      # Optimized release build
make install      # Install to /usr/local/bin
```

### Permissions
Enable Accessibility permissions in:
**System Preferences → Security & Privacy → Privacy → Accessibility**

## Usage

### Snapshot
Capture accessibility tree as JSON:
```bash
macos-agent snapshot                          # Frontmost app
macos-agent snapshot --app Safari             # Specific app
macos-agent snapshot --app com.apple.Safari   # By bundle ID
macos-agent snapshot --system-wide            # All apps
```

### Screenshot
Capture screen as image (ideal for LLM vision models):
```bash
macos-agent screenshot                        # Base64 output (default)
macos-agent screenshot --output screen.png    # Save to file
macos-agent screenshot --both --output screen.png  # Both file + base64 JSON
macos-agent screenshot --all-displays         # All displays as JSON array
```

### AX Actions
```bash
macos-agent ax press --element-id <id>
macos-agent ax increment --element-id <id>
macos-agent ax decrement --element-id <id>
macos-agent ax setvalue --element-id <id> --value "text"
macos-agent ax move --element-id <id> --x 100 --y 200
macos-agent ax size --element-id <id> --width 500 --height 300
```

### CGEvents
```bash
# Mouse
macos-agent cg mousedown --x 100 --y 200
macos-agent cg mouseup --x 100 --y 200
macos-agent cg mousemove --x 300 --y 400

# Keyboard
macos-agent cg keydown --key a
macos-agent cg keyup --key return
macos-agent cg keydown --key a --shift --command

# Scroll
macos-agent cg scroll --delta-y -10
```

### Gestures
```bash
# Drag
macos-agent gesture drag --from-x 100 --from-y 200 --to-x 300 --to-y 400

# Hover
macos-agent gesture hover --from-x 100 --from-y 200 --duration 1000

# Text Selection
macos-agent gesture selecttext --from-x 100 --from-y 200 --to-x 300 --to-y 200

# Clicks
macos-agent gesture doubleclick --from-x 100 --from-y 200
macos-agent gesture rightclick --from-x 100 --from-y 200
```

## Integration

### With LLMs (Vision + Action)
```bash
# 1. Get visual + structural data
SCREENSHOT=$(macos-agent screenshot)
SNAPSHOT=$(macos-agent snapshot)

# 2. Send both to LLM (vision model)
# LLM analyzes screenshot + accessibility tree
# Returns: {"action": "ax", "type": "press", "elementId": "..."}

# 3. Execute action
macos-agent ax press --element-id <id>
```

## Architecture

- `Sources/MacOSAgent.swift` - CLI entry point with ArgumentParser
- `Sources/AccessibilitySnapshot.swift` - Accessibility tree capture
- `Sources/ScreenshotCapture.swift` - Screen image capture (base64/file)
- `Sources/AXActions.swift` - Accessibility actions (AXPress, etc.)
- `Sources/CGEventActions.swift` - CoreGraphics events (mouse, keyboard, scroll)
- `Sources/GestureActions.swift` - Combined gestures (drag, hover, etc.)
- `Sources/Models.swift` - JSON data models
