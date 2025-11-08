# Quick Reference Guide

## Screenshot Commands

| Command | Description | Output |
|---------|-------------|--------|
| `macos-agent screenshot` | Capture screen as base64 | Base64 string to stdout |
| `macos-agent screenshot --output file.png` | Save to file | File path to stdout |
| `macos-agent screenshot --both --output file.png` | Both file + base64 | JSON with both |
| `macos-agent screenshot --all-displays` | All displays | JSON array |

## Snapshot Commands

| Command | Description | Output |
|---------|-------------|--------|
| `macos-agent snapshot` | Frontmost app | JSON tree |
| `macos-agent snapshot --app Safari` | Specific app (by name) | JSON tree |
| `macos-agent snapshot --app com.apple.Safari` | Specific app (bundle ID) | JSON tree |
| `macos-agent snapshot --system-wide` | All apps | JSON tree |

## AX Actions

| Action | Command | Required Params |
|--------|---------|-----------------|
| Press | `ax press --element-id ID` | element-id |
| Increment | `ax increment --element-id ID` | element-id |
| Decrement | `ax decrement --element-id ID` | element-id |
| Set Value | `ax setvalue --element-id ID --value "text"` | element-id, value |
| Move | `ax move --element-id ID --x 100 --y 200` | element-id, x, y |
| Size | `ax size --element-id ID --width 500 --height 300` | element-id, width, height |
| Show Menu | `ax showmenu --element-id ID` | element-id |
| Confirm | `ax confirm --element-id ID` | element-id |
| Cancel | `ax cancel --element-id ID` | element-id |

## CG Events

### Mouse
| Action | Command | Required Params |
|--------|---------|-----------------|
| Mouse Down | `cg mousedown --x 100 --y 200` | x, y |
| Mouse Up | `cg mouseup --x 100 --y 200` | x, y |
| Mouse Move | `cg mousemove --x 100 --y 200` | x, y |

**Optional:** `--button left|right|middle`

### Keyboard
| Action | Command | Required Params |
|--------|---------|-----------------|
| Key Down | `cg keydown --key a` | key |
| Key Up | `cg keyup --key a` | key |

**Modifiers:** `--shift --command --option --control`

**Key Examples:** `a-z`, `0-9`, `return`, `escape`, `tab`, `space`, `delete`, `f1-f12`, `up`, `down`, `left`, `right`

### Scroll
| Action | Command | Required Params |
|--------|---------|-----------------|
| Scroll | `cg scroll --delta-y -10` | delta-x or delta-y |

## Gestures

| Gesture | Command | Required Params |
|---------|---------|-----------------|
| Drag | `gesture drag --from-x 100 --from-y 200 --to-x 300 --to-y 400` | from-x, from-y, to-x, to-y |
| Hover | `gesture hover --from-x 100 --from-y 200 --duration 1000` | from-x, from-y |
| Text Selection | `gesture selecttext --from-x 100 --from-y 200 --to-x 300 --to-y 200` | from-x, from-y, to-x, to-y |
| Double Click | `gesture doubleclick --from-x 100 --from-y 200` | from-x, from-y |
| Right Click | `gesture rightclick --from-x 100 --from-y 200` | from-x, from-y |
| Triple Click | `gesture tripleclick --from-x 100 --from-y 200` | from-x, from-y |

## LLM Integration Flow

```
1. Screenshot → macos-agent screenshot
   ↓
2. Snapshot → macos-agent snapshot
   ↓
3. Send both to LLM (vision model)
   ↓
4. LLM returns action spec
   ↓
5. Execute → macos-agent {ax|cg|gesture} ...
```

## Output Formats

### Screenshot
- **Base64**: Raw base64 string
- **File**: File path string
- **Both**: `{"file_path": "...", "base64": "..."}`
- **All Displays**: `[{"displayID": 1, "bounds": {...}, "base64": "...", "isMain": true}, ...]`

### Snapshot
```json
{
  "timestamp": "2025-11-07T...",
  "elements": [{
    "id": "uuid",
    "role": "AXButton",
    "title": "Submit",
    "frame": {"x": 100, "y": 200, "width": 80, "height": 30},
    "actions": ["AXPress"],
    "enabled": true,
    "focused": false,
    "children": [...]
  }],
  "screenSize": {"width": 1920, "height": 1080}
}
```

## Common Patterns

### Click button by title
```bash
ID=$(macos-agent snapshot | jq -r '.. | select(.role?=="AXButton" and .title?=="Submit") | .id')
macos-agent ax press --element-id $ID
```

### Type text and submit
```bash
# Set text field value
macos-agent ax setvalue --element-id $FIELD_ID --value "Hello"
# Press enter
macos-agent cg keydown --key return && macos-agent cg keyup --key return
```

### Click at specific coordinates
```bash
macos-agent cg mousedown --x 500 --y 300
macos-agent cg mouseup --x 500 --y 300
```

### Drag file to destination
```bash
macos-agent gesture drag --from-x 100 --from-y 200 --to-x 500 --to-y 600
```
