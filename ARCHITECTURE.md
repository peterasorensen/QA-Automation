# Architecture

## Overview

MacOS Agent is a Swift-based CLI tool that provides programmatic access to macOS UI automation via two primary APIs:

1. **Accessibility API** - High-level UI element inspection and manipulation
2. **CoreGraphics Events** - Low-level input simulation

## Component Structure

```
Sources/
├── MacOSAgent.swift           # CLI entry point (ArgumentParser)
├── Models.swift               # JSON data structures
├── AccessibilitySnapshot.swift # AX tree traversal
├── AXActions.swift            # AX element actions
├── CGEventActions.swift       # Mouse/keyboard events
└── GestureActions.swift       # Composite gestures
```

## Core Components

### 1. AccessibilitySnapshot
- Traverses the AX tree using `AXUIElementCreateApplication`
- Caches elements by UUID for later action execution
- Filters out empty/useless elements
- Exports to JSON with coordinates, roles, attributes

**Key APIs:**
- `AXUIElementCopyAttributeValue` - Read element attributes
- `AXUIElementCopyActionNames` - Get available actions
- `AXIsProcessTrusted()` - Check permissions

### 2. AXActions
- Performs accessibility actions on cached elements
- Supports: Press, Increment, Decrement, SetValue, Move, Size, etc.
- Uses element IDs from snapshot cache

**Key APIs:**
- `AXUIElementPerformAction` - Execute actions
- `AXUIElementSetAttributeValue` - Modify attributes

### 3. CGEventActions
- Creates and posts low-level input events
- Supports mouse, keyboard, scroll events
- Modifier key support (Shift, Cmd, Opt, Ctrl)

**Key APIs:**
- `CGEvent(mouseEventSource:...)` - Mouse events
- `CGEvent(keyboardEventSource:...)` - Keyboard events
- `CGEvent(scrollWheelEvent2Source:...)` - Scroll events
- `.post(tap: .cghidEventTap)` - Post event to system

### 4. GestureActions
- Combines multiple CGEvents into gestures
- Interpolates smooth movements
- Timing control with `usleep()`

**Gestures:**
- Drag: mousedown → move → mouseup
- Hover: move → wait
- Selection: mousedown → drag → mouseup
- Multi-click: multiple down/up cycles

## Data Flow

```
User Command
    ↓
ArgumentParser
    ↓
[Snapshot] → AccessibilitySnapshot → JSON → stdout
    ↓
[Action] → ElementID → Cache Lookup → AXUIElement
    ↓
AXUIElementPerformAction / CGEvent.post
```

## Element Caching

The snapshot maintains an in-memory cache mapping UUIDs to AXUIElements:
```swift
private var elementCache: [String: AXUIElement] = [:]
```

This allows:
1. Snapshot returns JSON with element IDs
2. Actions reference elements by ID
3. No need to re-traverse tree for actions

**Limitation:** Cache is per-execution. Elements must be from same snapshot run.

## Permissions

Required permissions in System Preferences:
- **Accessibility** - For AX API access
- Checked via `AXIsProcessTrusted()`

## Coordinates

All coordinates use macOS screen coordinates:
- Origin (0,0) is top-left
- Y increases downward
- Multi-display: coordinates extend across displays

## Error Handling

Each module defines custom error types:
- `SnapshotError` - AX tree traversal issues
- `AXActionError` - Action execution failures
- `CGEventError` - Event creation failures
- `GestureError` - Gesture parameter issues

All errors conform to `CustomStringConvertible` for user-friendly messages.

## Performance Considerations

- **Snapshot depth limit**: Max 50 levels to prevent infinite traversal
- **Element filtering**: Skips elements with empty descriptions and no useful data
- **Gesture interpolation**: 10-20 steps for smooth movement
- **Timing**: usleep() for delays (50-100ms typical)

## Future Enhancements

1. **Persistent element tracking** - Track elements across snapshots
2. **Vision API integration** - OCR for visual element detection
3. **Event recording** - Record user actions for playback
4. **Multi-display support** - Better screen coordinate handling
5. **Element selectors** - CSS-like selectors for finding elements
