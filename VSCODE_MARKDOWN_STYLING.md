# VS Code Custom Markdown Styling

This document explains the setup, challenges, and solutions for achieving sticky headers and persistent language labels in the native VS Code Markdown preview.

## What We Wanted
1. **Sticky Headers:** Headers should stick to the top of the preview pane as you scroll.
2. **Stacked Hierarchy:** Sub-headers should cleanly stack underneath parent headers rather than overlapping them completely.
3. **Language Labels:** Code blocks should persistently display their language in the top-left corner, bypassing VS Code's default hover mechanics.
4. **Native Support:** Must support raw HTML (like `<details>` and `<summary>`) and native syntax highlighting without relying on heavy third-party preview extensions.

---

## Issues We Ran Into

1. **Security Restrictions on Local Files**
   - *The Problem:* VS Code's webview security strictly blocks loading local CSS files via the `markdown.styles` setting if they are located outside of the currently opened workspace. Absolute paths like `/home/user/...` fail silently.
   - *Failed Workaround:* We tried using raw GitHub URLs (`raw.githubusercontent.com`), but VS Code's strict MIME-type checking blocked it because GitHub serves raw files as `text/plain` instead of `text/css`.
   - *Failed Workaround 2:* We tried a CDN (`cdn.jsdelivr.net`), which fixed the MIME type, but CDNs cache files for up to 12 hours, making iterative design and updates impossible.

2. **The `position: sticky` Overflow Trap**
   - *The Problem:* By default, VS Code wraps the markdown preview in hidden container bodies (`html`, `body`, `.markdown-body`). CSS `position: sticky` immediately breaks and fails to stick if any parent container has an `overflow: hidden` property.

3. **Hover State Overrides**
   - *The Problem:* VS Code's native Markdown preview automatically injects a "Copy Code" button on hover. Their internal stylesheets aggressively hid our custom `::before` language labels whenever the mouse hovered over a code block.

4. **Markdown's Flat Hierarchy vs. CSS Stacking**
   - *The Problem:* In Markdown, headers (`h1`, `h2`, etc.) are flat sibling elements, not nested containers. If we tell CSS to make `h4` sticky at `top: 105px` to simulate a nested stack, but there is no `h1` above it, the `h4` will just float 105px down from the top of the screen leaving a massive empty gap.

---

## Our Working Solutions

1. **The "Local Extension" Hack (Bypassing Security)**
   - We abandoned `markdown.styles` entirely. Instead, we created a tiny, local VS Code extension whose sole purpose is to inject our CSS into the preview. This completely bypasses all workspace path restrictions and works 100% offline with instant updates.

2. **Aggressive `!important` Overrides**
   - We explicitly targeted VS Code's hidden containers (`.markdown-body`, `.vscode-body`) and forced `overflow: visible !important`.
   - We forced `display: block !important` and `visibility: visible !important` on the language label hover states to beat VS Code's internal stylesheets in the specificity war.

3. **Custom "H3-Root" Stacking Hierarchy**
   - To fix the floating gap issue, we tailored the CSS offsets to match a specific note-taking workflow where `###` (H3) is always the top-level section. 
   - `H1`, `H2`, and `H3` all snap to `top: 0`.
   - `H4`, `H5`, and `H6` have tightly compacted pixel offsets (e.g., 32px, 60px) and staggered `z-index` values so they cleanly dock underneath the `H3` billboard without wasting screen real estate.

4. **Collapsible Sticky Headers (`<summary>` tags)**
   - *The Problem:* Placing `### header` inside a `<details><summary>` block breaks sticky behavior because the header gets trapped inside the small height of the `<summary>` parent. Additionally, the block-level `###` forces the expand arrow onto a separate line.
   - *The Fix:* We used the modern CSS `:has()` selector to make the `<summary>` itself the sticky element if it contains a header (e.g., `summary:has(h3)`). We then set the nested header to `display: inline-block` and stripped its margins so it sits perfectly on the same line to the right of the default expand arrow.

---

## Installation Instructions

To install this custom styling on any machine, you must create a local VS Code extension that symlinks to the `markdown-styles.css` file in this repository.

Run the following commands in your terminal:

```bash
# 1. Create the local extension directory and package.json
mkdir -p ~/.vscode/extensions/local-markdown-styles && cat << 'EOF' > ~/.vscode/extensions/local-markdown-styles/package.json
{
    "name": "local-markdown-styles",
    "displayName": "Local Markdown Styles",
    "description": "Injects custom markdown CSS from PC-config",
    "version": "1.0.0",
    "publisher": "local",
    "engines": {
        "vscode": "^1.60.0"
    },
    "contributes": {
        "markdown.previewStyles": [
            "markdown-styles.css"
        ]
    }
}
EOF

# 2. Symlink the CSS file from the PC-config repo to the extension folder
# (Adjust the path to PC-config if it is located elsewhere)
ln -sf ~/Github/PC-config/markdown-styles.css ~/.vscode/extensions/local-markdown-styles/markdown-styles.css
```

**Final Step:** Completely close all VS Code windows and reopen them to ensure the new local extension is registered. Your markdown previews will now automatically use the global styling!