# VS Code Sidebar Toggle Extension

Adds a native `$(layout-sidebar-left)` icon button to the editor tab bar that toggles the primary sidebar — without any dependencies, compilation, or publishing.

---

## How It Works

VS Code doesn't let you reassign built-in command icons in the UI arbitrarily. The workaround is a minimal "proxy" extension that:

1. Registers a new command with a native Codicon (`$(layout-sidebar-left)`)
2. Places that command in the `editor/title` menu (the tab bar)
3. When clicked, fires the built-in `workbench.action.toggleSidebarVisibility` command

---

## Files Required

Only **two files** are needed — no `npm install`, no build step.

---

## Step 1 — Create the Extension Folder

Navigate to your VS Code extensions directory and create a new folder:

```
~/.vscode/extensions/editor-sidebar-toggle/
```

---

## Step 2 — Create `package.json`

Create `~/.vscode/extensions/editor-sidebar-toggle/package.json`:

```json
{
  "name": "editor-sidebar-toggle",
  "displayName": "Editor Sidebar Toggle",
  "version": "1.0.0",
  "publisher": "local-user",
  "engines": {
    "vscode": "^1.75.0"
  },
  "main": "./extension.js",
  "contributes": {
    "commands": [
      {
        "command": "editor-sidebar-toggle.toggle",
        "title": "Toggle Side Bar",
        "icon": "$(layout-sidebar-left)"
      }
    ],
    "menus": {
      "editor/title": [
        {
          "command": "editor-sidebar-toggle.toggle",
          "group": "navigation"
        }
      ]
    }
  }
}
```

**Key fields:**
- `icon`: Uses the native VS Code Codicon `$(layout-sidebar-left)` — the same icon in the title bar
- `editor/title`: Places the button in the editor tab bar
- `group: "navigation"`: Puts it in the right-side icon cluster alongside Split Editor buttons

---

## Step 3 — Create `extension.js`

Create `~/.vscode/extensions/editor-sidebar-toggle/extension.js`:

```javascript
const vscode = require('vscode');

function activate(context) {
    let disposable = vscode.commands.registerCommand('editor-sidebar-toggle.toggle', () => {
        // This fires the native command to toggle the sidebar
        vscode.commands.executeCommand('workbench.action.toggleSidebarVisibility');
    });

    context.subscriptions.push(disposable);
}

function deactivate() {}

module.exports = {
    activate,
    deactivate
}
```

---

## Step 4 — Restart VS Code

Fully close and reopen VS Code. The icon will appear in the top-right of the active editor tab bar.

> VS Code automatically loads any valid extension folder in `~/.vscode/extensions/` on startup — no install command needed.

---

## Variant: Toggle the Secondary (Right) Sidebar

To target the **right-hand Secondary Sidebar** instead, make two changes:

| File | Change |
|---|---|
| `package.json` | `$(layout-sidebar-left)` → `$(layout-sidebar-right)` |
| `extension.js` | `workbench.action.toggleSidebarVisibility` → `workbench.action.toggleAuxiliaryBar` |

---

## File Locations (Linux)

| File | Path |
|---|---|
| Extension folder | `~/.vscode/extensions/editor-sidebar-toggle/` |
| package.json | `~/.vscode/extensions/editor-sidebar-toggle/package.json` |
| extension.js | `~/.vscode/extensions/editor-sidebar-toggle/extension.js` |
