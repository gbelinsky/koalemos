# Docker Deployment Guide

**Complete guide to running Koalemos with Docker**

---

## Quick Start

### Option 1: Docker Compose (Recommended)

1. **Clone and Configure:**
   ```bash
   git clone https://github.com/yourusername/koalemos.git
   cd koalemos

   # Copy environment template
   cp .env.example .env

   # Edit .env and add your API key
   nano .env
   ```

2. **Start with Docker Compose:**
   ```bash
   docker-compose up
   ```

3. **Open Browser:**
   - Navigate to http://localhost:4000
   - Start building wireframes!

---

### Option 2: Docker Run (Quick Demo)

**With Anthropic:**
```bash
docker run -p 4000:4000 \
  -e ANTHROPIC_API_KEY="sk-ant-your-key" \
  -e LLM_PROVIDER="anthropic" \
  koalemos:latest
```

**With OpenAI:**
```bash
docker run -p 4000:4000 \
  -e OPENAI_API_KEY="sk-your-key" \
  -e LLM_PROVIDER="openai" \
  koalemos:latest
```

**With Ollama (local):**
```bash
docker run -p 4000:4000 \
  --add-host=host.docker.internal:host-gateway \
  -e OLLAMA_BASE_URL="http://host.docker.internal:11434" \
  -e LLM_PROVIDER="ollama" \
  koalemos:latest
```

---

## Building the Image

### From Source

```bash
# Clone repository
git clone https://github.com/yourusername/koalemos.git
cd koalemos

# Build image
docker build -t koalemos:latest .

# Build with specific version tag
docker build -t koalemos:v1.0.0 .
```

### Build Arguments

```bash
# Build for specific environment
docker build \
  --build-arg MIX_ENV=prod \
  -t koalemos:latest .
```

---

## Configuration

### Environment Variables

#### Required (Choose One Provider)

**Anthropic:**
- `ANTHROPIC_API_KEY` - Your Anthropic API key
- `ANTHROPIC_MODEL` - Model to use (default: `claude-sonnet-4-5`)

**OpenAI:**
- `OPENAI_API_KEY` - Your OpenAI API key
- `OPENAI_MODEL` - Model to use (default: `gpt-4o`)

**Ollama:**
- `OLLAMA_BASE_URL` - Ollama server URL (default: `http://localhost:11434`)
- `OLLAMA_MODEL` - Model to use (default: `qwen2.5:7b`)

#### Provider Selection

- `LLM_PROVIDER` - Which provider to use: `anthropic`, `openai`, or `ollama`

#### Server Configuration

- `PORT` - Port to run server on (default: `4000`)
- `PHX_SERVER` - Start Phoenix server (default: `true`)
- `SECRET_KEY_BASE` - Secret for encryption (auto-generated if not provided)

---

### Using .env File

1. **Create .env:**
   ```bash
   cp .env.example .env
   ```

2. **Edit .env:**
   ```bash
   # Set your provider and API key
   LLM_PROVIDER=anthropic
   ANTHROPIC_API_KEY=sk-ant-your-key
   ANTHROPIC_MODEL=claude-sonnet-4-5
   ```

3. **Use with Docker Compose:**
   ```bash
   docker-compose up
   ```

The `.env` file is automatically loaded by Docker Compose.

---

### Using Credentials File (Alternative)

Instead of environment variables, you can mount a credentials file:

1. **Create credentials file:**
   ```bash
   mkdir -p .koalemos
   cat > .koalemos/.credentials.json <<EOF
   {
     "providers": {
       "anthropic": {
         "api_key": "sk-ant-your-key",
         "model": "claude-sonnet-4-5"
       }
     },
     "selected_provider": "anthropic"
   }
   EOF
   ```

2. **Mount as volume:**
   ```bash
   docker run -p 4000:4000 \
     -v $(pwd)/.koalemos:/app/.koalemos:ro \
     koalemos:latest
   ```

3. **Or in docker-compose.yml:**
   ```yaml
   services:
     koalemos:
       volumes:
         - ./.koalemos:/app/.koalemos:ro
   ```

---

## Ollama Configuration

### Ollama on Host Machine

**Setup:**

1. **Install Ollama on host:**
   ```bash
   curl -fsSL https://ollama.com/install.sh | sh
   ```

2. **Start Ollama:**
   ```bash
   ollama serve
   ```

3. **Pull a model:**
   ```bash
   ollama pull qwen2.5:7b
   ```

4. **Run Koalemos container:**
   ```bash
   docker run -p 4000:4000 \
     --add-host=host.docker.internal:host-gateway \
     -e OLLAMA_BASE_URL="http://host.docker.internal:11434" \
     -e OLLAMA_MODEL="qwen2.5:7b" \
     -e LLM_PROVIDER="ollama" \
     koalemos:latest
   ```

**Why `host.docker.internal`?**
- Containers can't access `localhost` (refers to the container, not host)
- `host.docker.internal` is a Docker special hostname that resolves to the host machine
- `--add-host` ensures this works even outside Docker Desktop

---

### Ollama in Separate Container

**docker-compose.yml:**

```yaml
version: '3.8'

services:
  koalemos:
    build: .
    ports:
      - "4000:4000"
    environment:
      - LLM_PROVIDER=ollama
      - OLLAMA_BASE_URL=http://ollama:11434
      - OLLAMA_MODEL=qwen2.5:7b
    depends_on:
      - ollama

  ollama:
    image: ollama/ollama:latest
    ports:
      - "11434:11434"
    volumes:
      - ollama_data:/root/.ollama

volumes:
  ollama_data:
```

**Start both:**
```bash
docker-compose up
```

**Pull model (in Ollama container):**
```bash
docker-compose exec ollama ollama pull qwen2.5:7b
```

---

## Networking

### Port Mapping

**Default:**
```bash
-p 4000:4000
```
- Maps host port 4000 → container port 4000
- Access at: http://localhost:4000

**Custom port:**
```bash
-p 8080:4000 \
-e PORT=4000
```
- Access at: http://localhost:8080
- Container still runs on port 4000 internally

### Host Networking (Linux Only)

For better Ollama connectivity on Linux:

```bash
docker run --network host \
  -e PORT=4000 \
  -e OLLAMA_BASE_URL="http://localhost:11434" \
  koalemos:latest
```

**Benefits:**
- No port mapping needed
- Direct access to host services
- Better performance

**Drawback:**
- Linux only (not supported on macOS/Windows)

---

## Data Persistence

### Credentials Persistence

**Problem:** Credentials configured in web UI are lost when container restarts.

**Solution 1: Environment Variables (Recommended)**
```bash
docker run -p 4000:4000 \
  -e ANTHROPIC_API_KEY="sk-ant-..." \
  koalemos:latest
```

**Solution 2: Volume Mount**
```bash
docker run -p 4000:4000 \
  -v koalemos_data:/app/.koalemos \
  koalemos:latest
```

**Solution 3: Bind Mount**
```bash
docker run -p 4000:4000 \
  -v $(pwd)/.koalemos:/app/.koalemos \
  koalemos:latest
```

---

## Production Deployment

### Security

**DO:**
- ✅ Use environment variables for secrets
- ✅ Set `SECRET_KEY_BASE` explicitly (generate with `mix phx.gen.secret`)
- ✅ Use HTTPS/SSL termination (via reverse proxy)
- ✅ Set resource limits
- ✅ Use non-root user (already configured in Dockerfile)

**DON'T:**
- ❌ Commit `.env` to version control
- ❌ Use default/empty `SECRET_KEY_BASE`
- ❌ Expose container directly to internet without reverse proxy
- ❌ Use `--privileged` mode

### Resource Limits

```bash
docker run -p 4000:4000 \
  --memory="1g" \
  --cpus="2" \
  -e ANTHROPIC_API_KEY="..." \
  koalemos:latest
```

### Reverse Proxy (Nginx)

```nginx
server {
    listen 80;
    server_name koalemos.example.com;

    location / {
        proxy_pass http://localhost:4000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### Health Checks

```bash
docker run -p 4000:4000 \
  --health-cmd="curl -f http://localhost:4000 || exit 1" \
  --health-interval=30s \
  --health-timeout=10s \
  --health-retries=3 \
  -e ANTHROPIC_API_KEY="..." \
  koalemos:latest
```

---

## Troubleshooting

### Container Won't Start

**Check logs:**
```bash
docker logs koalemos
```

**Common issues:**
- Missing required environment variable (API key)
- Port 4000 already in use
- Invalid API key format

### Can't Access Web Interface

**Check container is running:**
```bash
docker ps
```

**Check port mapping:**
```bash
docker port koalemos
```

**Test from inside container:**
```bash
docker exec koalemos curl -f http://localhost:4000
```

### Ollama Connection Failed

**Verify Ollama is running on host:**
```bash
ollama list
```

**Test Ollama API:**
```bash
curl http://localhost:11434/api/version
```

**Check container can reach host:**
```bash
docker run --rm \
  --add-host=host.docker.internal:host-gateway \
  koalemos:latest \
  curl http://host.docker.internal:11434/api/version
```

### Credentials Not Persisting

**Problem:** Credentials set in web UI are lost after restart.

**Solution:** Use environment variables or volume mounts (see [Data Persistence](#data-persistence))

---

## Advanced Usage

### Multi-Stage Build Customization

Customize the build process:

```dockerfile
# Build with different Elixir version
FROM hexpm/elixir:1.16.0-erlang-26.2.1-alpine-3.19.0 AS builder
```

### Build-Time Configuration

```bash
docker build \
  --build-arg MIX_ENV=prod \
  --build-arg NODE_VERSION=20 \
  -t koalemos:latest .
```

### Running Mix Commands

```bash
# Run tests
docker run --rm koalemos:latest mix test

# Get Elixir version
docker run --rm koalemos:latest elixir --version
```

### Interactive Shell

```bash
# Bash shell in running container
docker exec -it koalemos /bin/sh

# IEx console
docker exec -it koalemos bin/koalemos remote
```

---

## Example Deployments

### Development (with Ollama)

```bash
docker-compose -f docker-compose.dev.yml up
```

**docker-compose.dev.yml:**
```yaml
version: '3.8'
services:
  koalemos:
    build: .
    ports:
      - "4000:4000"
    environment:
      - LLM_PROVIDER=ollama
      - OLLAMA_BASE_URL=http://host.docker.internal:11434
    extra_hosts:
      - "host.docker.internal:host-gateway"
```

### Production (with Anthropic)

```bash
docker run -d \
  --name koalemos \
  --restart unless-stopped \
  -p 4000:4000 \
  --memory="1g" \
  --cpus="2" \
  -e SECRET_KEY_BASE="$(openssl rand -base64 48)" \
  -e ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY" \
  -e LLM_PROVIDER="anthropic" \
  koalemos:latest
```

---

## Publishing to Registry

### Docker Hub

```bash
# Tag image
docker tag koalemos:latest yourusername/koalemos:latest
docker tag koalemos:latest yourusername/koalemos:v1.0.0

# Push to Docker Hub
docker login
docker push yourusername/koalemos:latest
docker push yourusername/koalemos:v1.0.0
```

### GitHub Container Registry (GHCR)

```bash
# Tag for GHCR
docker tag koalemos:latest ghcr.io/yourusername/koalemos:latest

# Login to GHCR
echo $GITHUB_TOKEN | docker login ghcr.io -u yourusername --password-stdin

# Push to GHCR
docker push ghcr.io/yourusername/koalemos:latest
```

**Pull from GHCR:**
```bash
docker pull ghcr.io/yourusername/koalemos:latest
```

---

## Next Steps

- **Configure credentials:** See [`CREDENTIALS_SETUP.md`](./CREDENTIALS_SETUP.md)
- **Learn to use the demo:** See [`USAGE_GUIDE.md`](./USAGE_GUIDE.md)
- **Understand architecture:** See [`../ARCHITECTURE.md`](../ARCHITECTURE.md)

---

**Questions?** Open an issue on GitHub.
