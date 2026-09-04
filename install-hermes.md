# Hermes Agent Setup Guide

Complete setup guide for **Hermes Agent CLI** (`hermes`) on a client machine that connects to a **remote Ollama server** for local AI inference. This configuration gives you categorized model groups in the `/model` picker, quick-switch aliases, and free DuckDuckGo web search — all running through your own hardware with zero cloud API keys.

---

## Architecture Overview

```
┌──────────────────────┐         LAN (192.168.50.x)         ┌──────────────────────┐
│   Client Machine     │◄──────────────────────────────────► │   CardonPC (GPU)     │
│   (Pop!_OS / Linux)  │         HTTP :11434                 │   (Windows + RTX)    │
│                      │                                     │                      │
│   • Hermes Agent     │         ┌───────────────┐           │   • Ollama Server    │
│   • DDG Web Search   │────────►│  Ollama API   │◄──────────│   • 8GB VRAM         │
│   • config.yaml      │         │  /v1/models   │           │   • 7 Custom Models  │
│                      │         └───────────────┘           │                      │
└──────────────────────┘                                     └──────────────────────┘
```

| Component | Location | Role |
|-----------|----------|------|
| **Ollama** | CardonPC (`192.168.50.192:11434`) | Hosts and runs all models on GPU |
| **Hermes** | Client machine (`~/.hermes/`) | CLI agent that sends prompts to Ollama |
| **Modelfiles** | CardonPC (`~/ollama_modelfiles/`) | Define custom quantized model builds |

---

## Prerequisites

- **Ollama** is already installed and running on the GPU machine (see `install-ollama.sh`)
- The GPU machine's `OLLAMA_HOST` is set to `0.0.0.0` so it accepts LAN connections
- Both machines are on the same network (`192.168.50.x`)

---

## 1. Install Hermes

Run the Hermes installer (it bootstraps Python, Node, and the agent into `~/.hermes/`):

```bash
curl -fsSL https://hermes.nousresearch.com/install.sh | bash
```

Verify:
```bash
hermes --version
# Expected: Hermes Agent v0.15.x
```

---

## 2. Install DuckDuckGo Search

Hermes uses a plugin system for web search. DuckDuckGo (`ddgs`) is free and requires no API key.

Install the Python package into Hermes' venv:
```bash
~/.hermes/hermes-agent/venv/bin/pip install ddgs
```

---

## 3. Configure `~/.hermes/config.yaml`

The config file is the core of the setup. You need to edit these sections:

### 3a. Setting the Default Model

To make Hermes automatically boot into your preferred local model without complaining about missing cloud API keys, set the top-level `model` block to point directly to the model and your curated provider:

```yaml
model:
  default: "qwen2.5-7b-6bit-64k:latest"
  provider: "coding"
  base_url: "http://192.168.50.192:11434/v1"
```

### 3b. Providers — Categorized Model Groups for `/model` Picker

The `/model` command (no args) opens an interactive picker. Hermes only shows entries from the `providers:` block here. By creating **one provider entry per category**, models appear grouped instead of in one flat list.

> **Key details:**
> - `api_key: "ollama"` — Ollama doesn't need a real key, but Hermes requires a non-empty value
> - `discover_models: false` — Prevents Hermes from auto-listing all 16+ models; shows only your curated picks
> - Model names **must include `:latest`** — Ollama tags all models this way and Hermes matches exactly
> - **CRITICAL:** Always explicitly define `context_length` and `ollama_num_ctx` per model to prevent Hermes from caching the wrong GGUF limits!

Add this to `config.yaml` (replace any existing `providers:` block):

```yaml
providers:
  # 📂 1. Large Documents
  docs:
    name: "📂 Large Documents"
    base_url: "http://192.168.50.192:11434/v1"
    api_key: "ollama"
    discover_models: false
    models:
      gemma4:e4b_q4_k_m_128k:
        context_length: 128000
        ollama_num_ctx: 128000
      qwen3.5:9b_q4_k_m_128k:
        context_length: 128000
        ollama_num_ctx: 128000
 
  # 💻 2. Coding & Logic
  coding:
    name: "💻 Coding & Logic"
    base_url: "http://192.168.50.192:11434/v1"
    api_key: "ollama"
    discover_models: false
    models:
      qwen2.5:7b_q6_k_64k:
        context_length: 65536
        ollama_num_ctx: 65536
      qwen3.5:9b_q6_k_65k:
        context_length: 65536
        ollama_num_ctx: 65536
 
  # ⚡ 3. Fast & General
  fast:
    name: "⚡ Fast & General"
    base_url: "http://192.168.50.192:11434/v1"
    api_key: "ollama"
    discover_models: false
    models:
      gemma4:e4b_q4_k_m_64k:
        context_length: 65536
        ollama_num_ctx: 65536
      gemma4:e4b_q6_k_64k:
        context_length: 65536
        ollama_num_ctx: 65536
 
  # 🧠 4. Deep Thinking
  thinking:
    name: "🧠 Deep Thinking"
    base_url: "http://192.168.50.192:11434/v1"
    api_key: "ollama"
    discover_models: false
    models:
      gemma4:12b_iq4_xs_64k:
        context_length: 65536
        ollama_num_ctx: 65536
      gemma4:12b_q4_k_s_64k:
        context_length: 65536
        ollama_num_ctx: 65536
```

### 3c. Model Aliases — Quick-Switch Shortcuts

Aliases let you type `/model code-qwen2.5-7b-6bit-64k` directly instead of navigating the picker. They bypass the catalog and go straight to the model+provider+URL tuple.

```yaml
model_aliases:
  # 📂 1. Large Documents
  docs-gemma4-e4b-q4_k_m-128k:
    model: "gemma4:e4b_q4_k_m_128k"
    provider: custom
    base_url: "http://192.168.50.192:11434/v1"
    context_length: 128000
  docs-qwen3.5-9b-q4_k_m-128k:
    model: "qwen3.5:9b_q4_k_m_128k"
    provider: custom
    base_url: "http://192.168.50.192:11434/v1"
    context_length: 128000

  # 💻 2. Coding & Logic
  code-qwen2.5-7b-q6_k-64k:
    model: "qwen2.5:7b_q6_k_64k"
    provider: custom
    base_url: "http://192.168.50.192:11434/v1"
    context_length: 65536
  code-qwen3.5-9b-q6_k-65k:
    model: "qwen3.5:9b_q6_k_65k"
    provider: custom
    base_url: "http://192.168.50.192:11434/v1"
    context_length: 65536

  # ⚡ 3. Fast & General
  fast-gemma4-e4b-q4_k_m-64k:
    model: "gemma4:e4b_q4_k_m_64k"
    provider: custom
    base_url: "http://192.168.50.192:11434/v1"
    context_length: 65536
  high-gemma4-e4b-q6_k-64k:
    model: "gemma4:e4b_q6_k_64k"
    provider: custom
    base_url: "http://192.168.50.192:11434/v1"
    context_length: 65536

  # 🧠 4. Deep Thinking
  think-gemma4-12b-iq4_xs-64k:
    model: "gemma4:12b_iq4_xs_64k"
    provider: custom
    base_url: "http://192.168.50.192:11434/v1"
    context_length: 65536
  think-gemma4-12b-q4_k_s-64k:
    model: "gemma4:12b_q4_k_s_64k"
    provider: custom
    base_url: "http://192.168.50.192:11434/v1"
    context_length: 65536
```

### 3d. Web Search — DuckDuckGo Backend

```yaml
web:
  search_backend: ddgs
```

---

## 4. Model Zoo Reference

All 7 models are built from Ollama Modelfiles on the GPU machine and optimized for 8GB VRAM. The naming convention is `[name]-[bit]bit-[context]`.

| Category | Model | Quant | Context | VRAM | Best For |
|----------|-------|-------|---------|------|----------|
| 📂 Large Docs | `gemma4:e4b_q4_k_m_128k` | Q4_K_M | 128K | ~6.5GB | Huge document analysis, book-length input |
| 📂 Large Docs | `qwen3.5:9b_q4_k_m_128k` | Q4_K_M | 128K | ~8.0GB | Long-context summaries & coding |
| 💻 Coding | `qwen2.5:7b_q6_k_64k` | Q6_K | 64K | ~6.5GB | High-fidelity coding and logic |
| 💻 Coding | `qwen3.5:9b_q6_k_65k` | Q6_K | 65K | ~8.4GB | Headless standard for heavy coding |
| ⚡ Fast & General | `gemma4:e4b_q4_k_m_64k` | Q4_K_M | 64K | ~6GB | Image understanding, multimodal tasks |
| ⚡ Fast & General | `gemma4:e4b_q6_k_64k` | Q6_K | 64K | ~7GB | Higher-fidelity vision (premium quality) |
| 🧠 Deep Thinking | `gemma4:12b_iq4_xs_64k` | IQ4_XS | 64K | ~6.8GB | High-efficiency 4-bit reasoning |
| 🧠 Deep Thinking | `gemma4:12b_q4_k_s_64k` | Q4_K_S | 64K | ~7.2GB | Standard K-quant 4-bit reasoning |

> **Why Gemma 4 E4B is special:** Uses Shared-KV attention (1 KV head, shared layers), making it dramatically more VRAM-efficient than standard dense models. This is why a Q4 variant can hold a 128K context window on 8GB VRAM.

---

## 5. How `providers:` vs `model_aliases:` Work

These are two different systems inside Hermes that serve different purposes:

| Feature | `providers:` | `model_aliases:` |
|---------|-------------|-----------------|
| **Purpose** | Populates the `/model` interactive picker | Enables direct `/model <alias>` shortcuts |
| **Where it shows** | `/model` (no args) — the visual picker | `/model code-qwen2.5-7b-6bit-64k` — typed directly |
| **Model name format** | Requires `:latest` suffix | Works without `:latest` |
| **How it routes** | Via provider slug → base_url | Direct model → provider → base_url tuple |
| **Grouped display** | ✅ Each provider entry = one group | ❌ Flat list, no grouping |

**You need both** for the full experience:
- `providers:` → so the picker works and shows categories
- `model_aliases:` → so you can quick-switch without opening the picker

---

## 6. Verify Everything Works

### Test Ollama connectivity from the client:
```bash
curl -s http://192.168.50.192:11434/api/tags | python3 -m json.tool | head -20
```

### Test the `/model` picker:
```
hermes
> /model
# Should show 5 categorized groups with emoji labels
```

### Test a direct alias switch:
```
> /model code-qwen2.5-7b-6bit-64k
# Should switch instantly with no warnings
```

### Test DDG web search:
```
> Search for the latest Pop!_OS release notes
# Hermes should invoke web_search via DuckDuckGo
```

---

## 7. Troubleshooting

### `/model` shows "No authenticated providers found"
- The `providers:` block is missing or commented out in `config.yaml`
- Hermes only shows cloud providers (OpenRouter, Nous, etc.) if you have API keys set
- Custom Ollama endpoints **must** be registered under `providers:` to appear in the picker

### Hermes reports the wrong context window size (e.g. 131K or 32K instead of what I set in the Modelfile)
- Ollama's API reports the *base GGUF context length* by default, which Hermes caches.
- Ensure you explicitly set `context_length` and `ollama_num_ctx` under the `models:` in `config.yaml`.
- **CRITICAL:** Delete `~/.hermes/context_length_cache.yaml` to force Hermes to clear the bad cache and read your manual overrides!

### Model switch shows "⚠ Model was not found in this provider's model listing"
- Model names in `providers:` → `models:` must include the `:latest` tag
- Run `curl http://192.168.50.192:11434/api/tags` to see exact names Ollama reports

### Web search returns "ddgs package is not installed"
- Install into Hermes' venv specifically, not system Python:
  ```bash
  ~/.hermes/hermes-agent/venv/bin/pip install ddgs
  ```

### Ollama is unreachable from client
- Verify `OLLAMA_HOST=0.0.0.0` is set on the GPU machine (allows LAN connections)
- Check firewall: `sudo ufw allow 11434/tcp` on the GPU machine (Linux) or allow through Windows Firewall
- Test: `curl http://192.168.50.192:11434/api/tags`

### Models aren't built on the GPU machine
- Run the build script on the **GPU machine** (where Ollama is installed):
  ```bash
  cd ~/ollama_modelfiles
  bash build_models.sh
  ```

---

## 8. File Locations

| File | Machine | Path |
|------|---------|------|
| Hermes config | Client | `~/.hermes/config.yaml` |
| Hermes venv | Client | `~/.hermes/hermes-agent/venv/` |
| Hermes logs | Client | `~/.hermes/logs/errors.log` |
| Ollama Modelfiles | GPU (CardonPC) | `~/ollama_modelfiles/` |
| Build script | GPU (CardonPC) | `~/ollama_modelfiles/build_models.sh` |
| Cleanup script | GPU (CardonPC) | `~/ollama_modelfiles/cleanup_old_models.sh` |

---

## 9. Adding a New Model

To add a new model to the zoo:

1. **On the GPU machine** — Create a Modelfile:
   ```
   FROM qwen2.5:7b
   PARAMETER num_ctx 32768
   ```

2. **On the GPU machine** — Build it:
   ```bash
   ollama create my-model-name -f Modelfile_my_model
   ```

3. **On the client** — Add to `config.yaml` under the appropriate `providers:` category:
   ```yaml
   models:
     my-model-name:latest:
       context_length: 32768
       ollama_num_ctx: 32768
   ```

4. **On the client** — Optionally add a shortcut alias:
   ```yaml
   model_aliases:
     my-alias:
       model: "my-model-name"
       provider: custom
       base_url: "http://192.168.50.192:11434/v1"
       context_length: 32768
   ```

5. **Restart Hermes** — Changes take effect on next launch.
