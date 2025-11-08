# Usage Examples

## Quick Start

### 1. Screenshot (Visual)
```bash
macos-agent screenshot > screenshot.b64
# Or save to file
macos-agent screenshot --output /tmp/screen.png
```

### 2. Snapshot (Accessibility Tree)
```bash
macos-agent snapshot > snapshot.json
```

### 3. Find Element and Click
```bash
# Get snapshot
SNAPSHOT=$(macos-agent snapshot)

# Parse JSON to find button element (using jq)
ELEMENT_ID=$(echo $SNAPSHOT | jq -r '.elements[0].children[] | select(.role=="AXButton" and .title=="Submit") | .id')

# Click it
macos-agent ax press --element-id $ELEMENT_ID
```

## Complete Workflows

### Fill Form
```bash
# Get snapshot
macos-agent snapshot > current.json

# Find text field (element ID from JSON)
macos-agent ax setvalue --element-id <text-field-id> --value "Hello World"

# Find submit button
macos-agent ax press --element-id <button-id>
```

### Mouse Automation
```bash
# Click at coordinates
macos-agent cg mousedown --x 500 --y 300
macos-agent cg mouseup --x 500 --y 300

# Or use gesture
macos-agent gesture doubleclick --from-x 500 --from-y 300
```

### Drag and Drop
```bash
macos-agent gesture drag --from-x 100 --from-y 200 --to-x 400 --to-y 500
```

### Keyboard Input
```bash
# Type character
macos-agent cg keydown --key h
macos-agent cg keyup --key h

# With modifiers
macos-agent cg keydown --key c --command  # Cmd+C
macos-agent cg keyup --key c --command

# Special keys
macos-agent cg keydown --key return
macos-agent cg keyup --key return
```

### Scroll
```bash
# Scroll down
macos-agent cg scroll --delta-y -100

# Scroll up
macos-agent cg scroll --delta-y 100

# Horizontal scroll
macos-agent cg scroll --delta-x -50
```

## Integration with Python

```python
import subprocess
import json

def take_snapshot():
    result = subprocess.run(
        ['macos-agent', 'snapshot'],
        capture_output=True,
        text=True
    )
    return json.loads(result.stdout)

def click_element(element_id):
    subprocess.run([
        'macos-agent', 'ax', 'press',
        '--element-id', element_id
    ])

def type_text(text):
    for char in text:
        subprocess.run(['macos-agent', 'cg', 'keydown', '--key', char])
        subprocess.run(['macos-agent', 'cg', 'keyup', '--key', char])

# Usage
snapshot = take_snapshot()
# Parse snapshot to find elements
# element_id = find_button(snapshot, "Submit")
# click_element(element_id)
```

## Integration with Node.js

```javascript
const { execSync } = require('child_process');

function takeSnapshot() {
  const output = execSync('macos-agent snapshot').toString();
  return JSON.parse(output);
}

function clickElement(elementId) {
  execSync(`macos-agent ax press --element-id ${elementId}`);
}

function mouseClick(x, y) {
  execSync(`macos-agent cg mousedown --x ${x} --y ${y}`);
  execSync(`macos-agent cg mouseup --x ${x} --y ${y}`);
}

// Usage
const snapshot = takeSnapshot();
// Find and interact with elements
```

## LLM Integration Pattern

### Vision Model Integration (Recommended)

```python
import subprocess
import json
import base64
from anthropic import Anthropic

client = Anthropic()

def get_screen_state():
    """Get both visual and structural screen data"""
    # Get screenshot as base64
    screenshot_b64 = subprocess.run(
        ['macos-agent', 'screenshot'],
        capture_output=True, text=True
    ).stdout.strip()

    # Get accessibility tree
    snapshot = json.loads(subprocess.run(
        ['macos-agent', 'snapshot'],
        capture_output=True, text=True
    ).stdout)

    return screenshot_b64, snapshot

def ask_llm_what_to_do(screenshot_b64, snapshot, goal):
    """Send screenshot + context to Claude vision model"""
    response = client.messages.create(
        model="claude-sonnet-4-5-20250929",
        max_tokens=1024,
        messages=[{
            "role": "user",
            "content": [
                {
                    "type": "image",
                    "source": {
                        "type": "base64",
                        "media_type": "image/png",
                        "data": screenshot_b64
                    }
                },
                {
                    "type": "text",
                    "text": f"""Goal: {goal}

Here's the accessibility tree of the current screen:
{json.dumps(snapshot, indent=2)}

Based on the screenshot and accessibility data, respond with JSON describing what action to take.
Format: {{"action": "ax|cg|gesture", "command": "...", "params": {{...}}}}
"""
                }
            ]
        }]
    )

    # Parse LLM response
    return json.loads(response.content[0].text)

def execute_action(action_spec):
    """Execute the action returned by LLM"""
    action_type = action_spec["action"]
    command = action_spec["command"]
    params = action_spec.get("params", {})

    if action_type == "ax":
        subprocess.run([
            'macos-agent', 'ax', command,
            '--element-id', params['elementId']
        ])
    elif action_type == "cg":
        args = ['macos-agent', 'cg', command]
        for k, v in params.items():
            args.extend([f'--{k}', str(v)])
        subprocess.run(args)
    elif action_type == "gesture":
        args = ['macos-agent', 'gesture', command]
        for k, v in params.items():
            args.extend([f'--{k.replace("_", "-")}', str(v)])
        subprocess.run(args)

# Example usage
screenshot, snapshot = get_screen_state()
action = ask_llm_what_to_do(screenshot, snapshot, "Click the Submit button")
execute_action(action)
```

### Bash Script Integration

```bash
#!/bin/bash

# 1. Get current screen state (visual + structural)
SCREENSHOT=$(macos-agent screenshot)
SNAPSHOT=$(macos-agent snapshot)

# 2. Send to LLM with prompt
# (Using curl - replace with your preferred method)
# Response format: {"action": "ax", "command": "press", "elementId": "..."}

# 3. Execute action
macos-agent ax press --element-id <extracted-id>
```
