# oc-docker

**A secure, sandboxed Docker environment for running OpenCode with complete data isolation and privacy**

**How it works:** 
Run 'ocd' command insitead of 'opencode'. Simple as that.

**oc-docker will automatically:**
* 🐳 Auto-start Docker Desktop if it's not running (macOS)
* 🔐 Load API keys from `.env` file
* ⚙️ Apply OpenCode configuration from `opencode.config.jsonc`
* 📂 Start in your current directory (mapped to `/root/Projects/...`)
* 🤖 Launch OpenCode automatically in the isolated environment
* 💾 Persist all data to `~/.oc_docker` (survives restarts)

## Setup procedure

### 1. Create `.env` File

Create a `.env` file in the oc_docker directory with your API keys and WORKDIR :

```bash
cat > .env << EOF
OPENAI_API_KEY=sk-your-openai-key-here
ZAI_API_KEY=your-zai-key-here
EOF
```

### 2. Configure OpenCode Settings

Edit `opencode.config.jsonc` to customize your OpenCode model preferences. 

```jsonc
{
  "model": "openai/gpt-5",
  "small_model": "zai/glm-4.5-flash",
  "agent": {
    "build": {
      "model": "openai/gpt-5"
    },
    // ... more agent configurations. I left a 6 agent madness for you ;)
  }
}
```

### 3. Verify Docker Setup

Ensure Docker is installed and accessible:

```bash
docker --version
docker compose version
```

### 4. 🚀 Installation and 'ocd' command setup

```bash
docker compose build
sudo ln -sf ./ocd /usr/local/bin/ocd
```

## ⚡ Running

```bash
ocd
```
It will spin up or using exiting docker container and drop you into it's shell, then opencode.

## 🏗️ Container Architecture

The oc-docker container includes:

* **Base Image**: `node:18` (with Python 3.11+ support)
* **OpenCode CLI**: Globally installed via `npm install -g opencode-ai`
* **Development Tools**: Python, pip, git, curl, wget, vim
* **Security**: Dropped capabilities, no-new-privileges, restricted file access
* **Network**: Host mode for seamless connectivity
* **Volume Mounts**:
  - `~/Projects` → `/root/Projects` (your projects)
  - `~/.oc_docker` → `/root` (persistent OpenCode data)
  - `opencode.config.jsonc` → `/tmp/opencode.config.jsonc` (config file)

## 🔍 Features

### ✨ Core Features

* ✅ **Auto-start OpenCode** - Launches automatically when container starts
* ✅ **Smart directory detection** - Starts in your current directory
* ✅ **Interactive shell access** - Drop to shell after OpenCode exits
* ✅ **Data persistence** - All sessions, API keys, and config saved to `~/.oc_docker`
* ✅ **Complete isolation** - Separate from native macOS OpenCode (privacy-focused)
* ✅ **Auto-start Docker** - Automatically starts Docker Desktop on macOS

### 🔒 Security Features

* ✅ **Restricted file access** - Only `~/Projects` is accessible
* ✅ **Dropped capabilities** - Minimal container privileges
* ✅ **No new privileges** - Security hardening enabled
* ✅ **Isolated data** - OpenCode data completely separate from host

### ⚙️ Configuration Features

* ✅ **Environment variables** - API keys from `.env` file
* ✅ **Config file support** - JSONC format with comments
* ✅ **Model customization** - Configure agents and models per your needs
* ✅ **Custom hostname** - Easy identification (`oc-docker`)


## 🚧 Roadmap

* **Server Mode**: Run OpenCode as a server for IDE integration (port 49455)

