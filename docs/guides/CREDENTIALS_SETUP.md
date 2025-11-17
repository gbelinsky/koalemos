# Credentials Setup Guide

**Complete guide to configuring LLM providers in Koalemos**

---

## Overview

Koalemos supports three LLM providers:
- **Anthropic Claude** (cloud API with API key or OAuth)
- **OpenAI** (cloud API with API key)
- **Ollama** (local models, free)

This guide walks you through setting up credentials for each provider.

---

## Quick Start

**Location:** `.koalemos/.credentials.json` in the project root

**Basic Structure:**
```json
{
  "providers": {
    "anthropic": {
      "api_key": "sk-ant-...",
      "model": "claude-sonnet-4-5"
    },
    "openai": {
      "api_key": "sk-...",
      "model": "gpt-4o"
    },
    "ollama": {
      "base_url": "http://localhost:11434",
      "model": "qwen2.5"
    }
  },
  "selected_provider": "anthropic"
}
```

**Note:** You only need to configure ONE provider to get started. Choose whichever you prefer or have access to.

---

## Provider Setup

### Option 1: Anthropic Claude (Recommended)

**Why choose Anthropic:**
- Best performance for conversational AI
- Excellent tool use (critical for wireframe editor)
- Extended context window
- Fast response times

**Setup Steps:**

1. **Get an API Key:**
   - Visit https://console.anthropic.com
   - Sign up or log in
   - Go to "API Keys" section
   - Click "Create Key"
   - Copy the key (starts with `sk-ant-`)

2. **Add to Credentials File:**
   Create or edit `.koalemos/.credentials.json`:
   ```json
   {
     "providers": {
       "anthropic": {
         "api_key": "sk-ant-api03-YOUR_KEY_HERE",
         "model": "claude-sonnet-4-5"
       }
     },
     "selected_provider": "anthropic"
   }
   ```

3. **Available Models:**
   - `claude-sonnet-4-5` (recommended - best balance)
   - `claude-opus-4` (most capable, slower, expensive)
   - `claude-haiku-4-5` (fastest, cheapest, good for testing)

4. **Start Koalemos:**
   ```bash
   mix phx.server
   ```

**OAuth Setup (Optional):**

If you prefer OAuth authentication:

1. **Get OAuth Credentials:**
   - Contact Anthropic for OAuth access
   - You'll receive: `client_id`, `client_secret`

2. **Configure OAuth:**
   ```json
   {
     "providers": {
       "anthropic": {
         "use_oauth": true,
         "client_id": "your_client_id",
         "client_secret": "your_client_secret",
         "model": "claude-sonnet-4-5"
       }
     },
     "selected_provider": "anthropic"
   }
   ```

3. **First Run:**
   - Start Koalemos: `mix phx.server`
   - You'll be redirected to Anthropic for authorization
   - After approval, tokens are saved automatically
   - Tokens refresh automatically (no manual intervention needed)

---

### Option 2: OpenAI

**Why choose OpenAI:**
- Widely available and well-documented
- Good performance for most tasks
- Multiple model tiers

**Setup Steps:**

1. **Get an API Key:**
   - Visit https://platform.openai.com/account/api-keys
   - Sign up or log in
   - Click "Create new secret key"
   - Copy the key (starts with `sk-`)

2. **Add to Credentials File:**
   Create or edit `.koalemos/.credentials.json`:
   ```json
   {
     "providers": {
       "openai": {
         "api_key": "sk-YOUR_OPENAI_KEY_HERE",
         "model": "gpt-4o"
       }
     },
     "selected_provider": "openai"
   }
   ```

3. **Available Models:**
   - `gpt-4o` (recommended - best multimodal)
   - `gpt-4-turbo` (fast, capable)
   - `gpt-3.5-turbo` (cheapest, good for testing)

4. **Start Koalemos:**
   ```bash
   mix phx.server
   ```

---

### Option 3: Ollama (Local, Free)

**Why choose Ollama:**
- **Free** - no API costs
- **Private** - data stays on your machine
- **Fast** - no network latency (once model is loaded)
- **Offline** - works without internet

**Requirements:**
- Sufficient RAM (8GB minimum, 16GB+ recommended)
- Disk space for models (4-8GB per model)

**Setup Steps:**

1. **Install Ollama:**

   **macOS/Linux:**
   ```bash
   # Install Ollama
   curl -fsSL https://ollama.com/install.sh | sh
   ```

   **Windows:**
   - Download from https://ollama.com/download
   - Run installer

   **Docker Users:**
   - Ollama runs on your host machine
   - Koalemos in Docker needs to reach host Ollama

2. **Start Ollama:**
   ```bash
   ollama serve
   ```

   This starts Ollama server at `http://localhost:11434`

3. **Pull a Model:**
   ```bash
   # Recommended models (choose ONE):
   ollama pull qwen2.5:7b           # Best overall (7GB)
   ollama pull llama3.2:3b          # Smaller, faster (2GB)
   ollama pull mistral:7b           # Good alternative (4.1GB)

   # List available models:
   ollama list
   ```

4. **Add to Credentials File:**
   Create or edit `.koalemos/.credentials.json`:
   ```json
   {
     "providers": {
       "ollama": {
         "base_url": "http://localhost:11434",
         "model": "qwen2.5:7b"
       }
     },
     "selected_provider": "ollama"
   }
   ```

5. **Start Koalemos:**
   ```bash
   mix phx.server
   ```

**Docker Users:**

If running Koalemos in Docker:

```bash
# Use host.docker.internal to reach host Ollama
docker run -p 4000:4000 \
  -e OLLAMA_BASE_URL=http://host.docker.internal:11434 \
  koalemos:latest
```

Or with `docker-compose.yml`:
```yaml
services:
  koalemos:
    image: koalemos:latest
    ports:
      - "4000:4000"
    environment:
      - OLLAMA_BASE_URL=http://host.docker.internal:11434
```

**Linux with host networking:**
```bash
docker run --network host \
  -e OLLAMA_BASE_URL=http://localhost:11434 \
  koalemos:latest
```

---

## Multi-Provider Configuration

You can configure multiple providers and switch between them:

```json
{
  "providers": {
    "anthropic": {
      "api_key": "sk-ant-...",
      "model": "claude-sonnet-4-5"
    },
    "openai": {
      "api_key": "sk-...",
      "model": "gpt-4o"
    },
    "ollama": {
      "base_url": "http://localhost:11434",
      "model": "qwen2.5:7b"
    }
  },
  "selected_provider": "anthropic"
}
```

**Switching Providers:**

Change the `selected_provider` field and restart Koalemos:
```json
"selected_provider": "ollama"  // or "anthropic" or "openai"
```

---

## Environment Variables (Docker/Production)

For containerized deployments, you can use environment variables instead of the credentials file:

**Anthropic:**
```bash
export ANTHROPIC_API_KEY="sk-ant-..."
export ANTHROPIC_MODEL="claude-sonnet-4-5"
```

**OpenAI:**
```bash
export OPENAI_API_KEY="sk-..."
export OPENAI_MODEL="gpt-4o"
```

**Ollama:**
```bash
export OLLAMA_BASE_URL="http://localhost:11434"
export OLLAMA_MODEL="qwen2.5:7b"
```

**Provider Selection:**
```bash
export LLM_PROVIDER="anthropic"  # or "openai" or "ollama"
```

**Docker Example:**
```bash
docker run -p 4000:4000 \
  -e ANTHROPIC_API_KEY="sk-ant-..." \
  -e ANTHROPIC_MODEL="claude-sonnet-4-5" \
  -e LLM_PROVIDER="anthropic" \
  koalemos:latest
```

---

## Troubleshooting

### "Invalid API Key" Error

**Anthropic:**
- Verify key starts with `sk-ant-`
- Check key at https://console.anthropic.com/settings/keys
- Ensure key has not been revoked
- Try generating a new key

**OpenAI:**
- Verify key starts with `sk-`
- Check key at https://platform.openai.com/account/api-keys
- Verify account has credits
- Check for usage limits/billing issues

### "Can't Connect to Ollama" Error

**Check Ollama is running:**
```bash
# Should return list of models
ollama list

# If not running, start it:
ollama serve
```

**Check Ollama URL:**
- Default: `http://localhost:11434`
- Docker: Use `http://host.docker.internal:11434`
- Custom port: Update `base_url` in credentials

**Test connection:**
```bash
curl http://localhost:11434/api/version
# Should return: {"version":"0.x.x"}
```

### "Model Not Found" Error (Ollama)

**Pull the model:**
```bash
ollama pull qwen2.5:7b

# Verify it's installed:
ollama list
```

**Check model name:**
- Must include tag: `qwen2.5:7b` (not just `qwen2.5`)
- Case-sensitive: `llama3.2:3b` (not `Llama3.2`)

### "Rate Limit" Errors

**Anthropic/OpenAI:**
- You're making too many requests
- Wait a few minutes
- Check API usage dashboard
- Consider upgrading plan for higher limits

**Ollama:**
- No rate limits (local)
- If slow, check system resources (RAM/CPU)

### Credentials File Not Found

**Create the directory:**
```bash
mkdir -p .koalemos
```

**Create credentials file:**
```bash
# Create .koalemos/.credentials.json
# Add your provider configuration (see examples above)
```

**Check file location:**
```bash
# Should be in project root
ls -la .koalemos/.credentials.json
```

### OAuth Token Refresh Failures (Anthropic)

**Symptoms:**
- Works initially, then fails after ~1 hour
- Error: "invalid_grant" or "token expired"

**Solution:**
- Tokens auto-refresh in background
- If persistent issues, delete `.koalemos/.credentials.json` and re-authenticate
- Check logs for refresh errors

---

## Security Best Practices

### API Keys

**DO:**
- ✅ Keep `.koalemos/` directory in `.gitignore`
- ✅ Use environment variables in production
- ✅ Rotate keys periodically
- ✅ Use minimum required permissions

**DON'T:**
- ❌ Commit credentials to Git
- ❌ Share API keys
- ❌ Use production keys in development (create separate keys)
- ❌ Store keys in plaintext outside `.koalemos/`

### OAuth Tokens

**DO:**
- ✅ Store tokens in `.koalemos/.credentials.json` (ignored by Git)
- ✅ Let system handle refresh automatically
- ✅ Revoke OAuth access if device is compromised

**DON'T:**
- ❌ Commit token files to Git
- ❌ Manually edit refresh tokens (they're managed automatically)

---

## Testing Your Setup

After configuring credentials, verify they work:

1. **Start Koalemos:**
   ```bash
   mix phx.server
   ```

2. **Open Browser:**
   - Navigate to http://localhost:4000
   - Click "Start Chat" or "Open Tutorial"

3. **Send Test Message:**
   - Type: "Hello, can you hear me?"
   - You should get a response within 5-10 seconds

4. **Check for Errors:**
   - No errors = setup successful! ✅
   - See errors = check troubleshooting section above

---

## Cost Estimates

### Anthropic Claude
- **Sonnet 4.5**: ~$3 per 1M input tokens, ~$15 per 1M output tokens
- **Haiku 4.5**: ~$0.25 per 1M input tokens, ~$1.25 per 1M output tokens
- **Typical session**: $0.01-$0.10 (Sonnet), $0.001-$0.01 (Haiku)

### OpenAI
- **GPT-4o**: ~$2.50 per 1M input tokens, ~$10 per 1M output tokens
- **GPT-3.5-turbo**: ~$0.50 per 1M input tokens, ~$1.50 per 1M output tokens
- **Typical session**: $0.01-$0.10 (GPT-4o), $0.001-$0.01 (GPT-3.5-turbo)

### Ollama
- **Free** - no API costs
- Cost: Electricity + hardware depreciation (minimal)

**Recommendation for demo:**
- Start with Ollama (free, private)
- Upgrade to Claude Sonnet/Haiku for best experience
- Use GPT-3.5-turbo if on tight budget

---

## Next Steps

Once credentials are configured:

1. **Try the Tutorial:** http://localhost:4000/example/login-form
2. **Read Usage Guide:** [`docs/guides/USAGE_GUIDE.md`](./USAGE_GUIDE.md)
3. **Explore Test Pages:** http://localhost:4000/test/wireframe

---

## Getting Help

**Common issues resolved here:** [Troubleshooting](#troubleshooting)

**Still stuck?**
- Check logs: Look for error messages in terminal
- Verify credentials file: `cat .koalemos/.credentials.json`
- Test provider directly:
  - Anthropic: https://console.anthropic.com/workbench
  - OpenAI: https://platform.openai.com/playground
  - Ollama: `ollama run qwen2.5:7b "Hello"`

**Need more help?**
- Open an issue on GitHub
- Include: Provider, error message, relevant logs (redact API keys!)

---

**Happy building! 🚀**
