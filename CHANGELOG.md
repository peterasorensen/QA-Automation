# Changelog

## v1.0.0 - Initial Release

### Features

#### Core Capabilities
- **Screenshot Command**: Capture screen as image (base64 or file)
  - Main display or specific display by ID
  - Multi-display support (capture all displays)
  - Base64 output for direct LLM integration
  - File output for debugging/storage
  - Combined output (both file + base64 as JSON)

- **Snapshot Command**: Capture accessibility tree as JSON
  - Frontmost application (default)
  - Specific application by name or bundle ID
  - System-wide capture (all applications)
  - Element caching by UUID for action execution
  - Filters empty/useless elements automatically
  - Configurable depth (default: 500 levels)

- **AX Actions**: Accessibility API element actions
  - AXPress, AXIncrement, AXDecrement
  - AXShowMenu, AXConfirm, AXCancel, AXPick, AXRaise
  - AXScrollToVisible, AXScrollDown
  - AXSetValue (text/number input)
  - AXMove, AXSize (window manipulation)

- **CG Events**: CoreGraphics low-level input
  - Mouse events (down, up, move) with button support
  - Keyboard events (down, up) with modifier keys
  - Scroll events (X/Y delta)
  - Modifier key support (Shift, Cmd, Opt, Ctrl)

- **Gestures**: Combined multi-step actions
  - Drag (interpolated smooth movement)
  - Hover (with duration)
  - Text selection
  - Double-click, triple-click, right-click

#### Developer Experience
- Swift ArgumentParser for clean CLI
- Comprehensive error handling
- JSON output for easy parsing
- Base64 output for direct LLM vision model integration
- Extensive documentation and examples

### Architecture

**Modules:**
- `MacOSAgent.swift` - CLI entry point
- `AccessibilitySnapshot.swift` - AX tree traversal
- `ScreenshotCapture.swift` - Screen capture (CGDisplayCreateImage)
- `AXActions.swift` - Accessibility actions
- `CGEventActions.swift` - CoreGraphics events
- `GestureActions.swift` - Combined gestures
- `Models.swift` - Data structures

### Documentation
- README.md - Overview and quick start
- QUICK_REFERENCE.md - Command reference
- EXAMPLES.md - Usage examples and patterns
- ARCHITECTURE.md - Technical details
- demo.sh - Interactive demo script

### Requirements
- macOS 13.0+
- Swift 5.9+
- Accessibility permissions enabled

### Build
```bash
make build    # Debug
make release  # Release
make install  # Install to /usr/local/bin
```

### Known Limitations
- Element cache is per-execution (not persistent)
- Screenshot requires Screen Recording permission in some cases
- AX tree depth limited to prevent infinite recursion
- Some AX actions may not work on all element types

### Future Enhancements
- Persistent element tracking across snapshots
- Vision API integration for OCR
- Event recording/playback
- Element selectors (CSS-like)
- Better multi-display coordinate handling
