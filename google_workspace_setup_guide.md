# Google Workspace Setup Guide for Antigravity CLI

This guide explains the root causes of why the Google Workspace plugin doesn't work out of the box in the **Antigravity CLI** (`agy`), and provides step-by-step instructions to configure it on another PC.

---

## 1. Root Causes & Technical Diagnosis

When you run `agy plugin install https://github.com/gemini-cli-extensions/workspace`, four specific bugs/limitations prevent the plugin from functioning:

### Bug A: Missing Source Code (Legacy Plugin Installation Bug)
The `agy plugin install` tool is designed for newer, pre-built Antigravity plugins. When given a legacy Gemini CLI extension repository, it parses the metadata, imports the agent `skills/`, but **fails to copy the actual source code** (`workspace-server/` folder, `package.json`, build scripts). This leaves the plugin directory empty of the code needed to run the server.

### Bug B: Hardcoded Temporary Directory (`/tmp`)
During installation, the CLI clones the repository into a temporary directory under `/tmp/plugin-install-XXXX/` to run its analysis. It writes this temporary directory as the working directory (`cwd`) inside the plugin's internal `mcp_config.json`. Once installation completes, the `/tmp` folder is deleted, leaving the CLI pointing to a non-existent path.

### Bug C: No Auto-Discovery for MCP Servers
The CLI does not automatically scan the `plugins/` folders to load MCP servers. Instead, it relies on two global configuration files:
* `~/.gemini/config/mcp_config.json`
* `~/.gemini/antigravity-cli/mcp_config.json`

If the workspace MCP server is not registered in these global files, the CLI remains unaware of it.

### Bug D: Server Startup Build Timeout (Direct Exec vs `start.js`)
By default, the plugin is configured to run using `node scripts/start.js`. This script is designed for developers: on every startup, it runs `npm install` and `npm run build` (which compiles the entire TypeScript source code into a bundled JavaScript file using `esbuild`).

This build step takes **3 to 4 seconds** to complete. Because of this slow startup delay, the Antigravity CLI client hits its connection timeout while waiting for the MCP initialization handshake. When it times out, the CLI silently disables the `google-workspace` plugin for that session.
* **The Fallback Behavior:** Because the Workspace tools (like `google-workspace/drive.search`) are disabled, the agent running inside the CLI cannot see them. It then falls back to secondary strategies to access Google Docs, such as listing your local workspace files (`ListDir`) or searching open Chrome browser tabs (`chrome-devtools/list_pages`).

---

## 2. Step-by-Step Setup Guide for Another PC

Follow these steps on any new PC to get the Google Workspace integration working.

### Step 1: Run the Default Installation
First, register the plugin metadata and agent skills using the CLI's standard command:
```bash
agy plugin install https://github.com/gemini-cli-extensions/workspace
```

### Step 2: Clone the Source Code into the Plugin Directory
Because the installer omitted the source code, manually clone the repository into the plugin folder:
```bash
# Define the plugin folder path
PLUGIN_DIR="$HOME/.gemini/antigravity-cli/plugins/google-workspace"

# Clone the repository to a temporary location
git clone https://github.com/gemini-cli-extensions/workspace.git /tmp/workspace-temp

# Copy the source files (including hidden files) into the plugin folder
cp -a /tmp/workspace-temp/. "$PLUGIN_DIR/"

# Clean up the temporary folder
rm -rf /tmp/workspace-temp
```

### Step 3: Automate Configuration of Global MCP Settings
To bypass the 3-4s compilation timeout, we configure the CLI to launch the pre-compiled JavaScript file (`workspace-server/dist/index.js`) directly.

Rather than manually editing files and typing your username, run the following automated Node.js command in your terminal. It will safely add or update the `google-workspace` entry in both of the global configuration files without affecting other configured MCP servers (such as `chrome-devtools`):

```bash
node -e "
const fs = require('fs');
const path = require('path');
const configPaths = [
  path.join(process.env.HOME, '.gemini/config/mcp_config.json'),
  path.join(process.env.HOME, '.gemini/antigravity-cli/mcp_config.json')
];
configPaths.forEach(configPath => {
  let config = { mcpServers: {} };
  if (fs.existsSync(configPath)) {
    try {
      config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
      if (!config.mcpServers) config.mcpServers = {};
    } catch (e) {
      console.warn('Warning: Could not parse ' + configPath + ', creating new.');
    }
  } else {
    fs.mkdirSync(path.dirname(configPath), { recursive: true });
  }
  config.mcpServers['google-workspace'] = {
    command: 'node',
    args: ['workspace-server/dist/index.js', '--debug', '--use-dot-names'],
    cwd: path.join(process.env.HOME, '.gemini/antigravity-cli/plugins/google-workspace')
  };
  fs.writeFileSync(configPath, JSON.stringify(config, null, 2), 'utf8');
  console.log('Successfully updated ' + configPath);
});
"
```

### Step 4: Install Dependencies & Compile the Server
Navigate to the plugin directory and run `npm install`. This will install all packages and trigger the `postinstall` script to build the production bundle (`dist/index.js`) once:
```bash
cd "$HOME/.gemini/antigravity-cli/plugins/google-workspace"
npm install
```

---

## 3. Authentication & Security (Why you must re-authenticate)

The Google Workspace plugin stores its credentials (OAuth tokens) either in your OS keychain or inside the plugin folder as:
* `gemini-cli-workspace-token.json` (encrypted token storage)
* `.gemini-cli-workspace-master-key` (encryption master key)

### Security Binding
To prevent credential theft, the master key encrypts the tokens using a key derived from:
1. The master key file itself.
2. The current machine's `hostname`.
3. The current machine's OS `username`.

Because the encryption is salted with these machine-specific details, **you cannot simply copy token files from one PC to another**. If you do, it will result in decryption errors ("Invalid encrypted data format" or "Token file corrupted"). Therefore, you must perform the authentication step on the new PC.

### Step 5: Perform Initial Authentication
Run the headless authentication utility in the plugin directory:
```bash
cd "$HOME/.gemini/antigravity-cli/plugins/google-workspace"
npm run auth-utils -- login
```
1. This will print a Google authentication link.
2. Open the link in any web browser, sign in with your Google account, and grant access.
3. Copy the authorization code from the browser and paste it back into your terminal.

---

## 4. Verification

Verify the setup by launching the CLI and asking it to check your Google Docs:
```bash
agy -p "list my recent Google Docs"
```
Because the server is launched directly from `dist/index.js`, it boots in less than 50ms, completely avoiding the startup timeout and listing your documents immediately.
