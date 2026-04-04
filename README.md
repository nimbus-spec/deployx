# DeployX - CNCF-Aligned VPS Deployment Automation

DeployX is a modular, Unix philosophy-inspired tool for automated VPS deployment with:
- Cloud-init based OS installation via DD (using bin456789/reinstall script)
- Nomad workload orchestration (server/client/server+client modes)
- Tailscale VPN integration for secure networking  
- Internationalization (English/Chinese)
- Hostname convention: `{country}-{region}-{network_type}-{merchant}-{random8}`

## Features

### 🔧 Modular Design (Unix Philosophy)
Each component is a single-purpose tool:
- `bin/detect.sh` - Hardware detection (CPU/RAM/Disk)
- `bin/network.sh` - Network detection (IP/interfaces)
- `bin/location.sh` - Geolocation via IP
- `bin/hostname.sh` - Hostname generation
- `bin/nomad.sh` - Nomad configuration generator
- `bin/tailscale.sh` - Tailscale configuration
- `bin/render.sh` - Template rendering ({{VAR}} substitution)
- `bin/execute.sh` - Installation executor
- `generate.sh` - Interactive configuration wizard

### 🚀 Usage

#### 1. Generate Configuration Only
```bash
curl -fsSL "https://raw.githubusercontent.com/nimbus-spec/deployx/main/deployx.sh" -o deployx.sh && chmod +x deployx.sh && ./deployx.sh
```

#### 2. Generate and Execute Installation
```bash
./deployx.sh --execute
```

#### 3. Unix-Style Composition
```bash
# Generate config to file
./generate.sh > cloud-config.yaml

# Execute with external cloud-init data  
./execute.sh --dd --img "https://example.com/image.raw" --cloud-data ./cloud-data
```

### 🌐 Configuration Options

During the interactive wizard, you'll configure:
- **Language**: English or 中文
- **Provider/Merchant**: Your VPS provider (aws, digitalocean, vultr, etc.)
- **SSH Key**: For secure access
- **SSH Port**: Default 22
- **Nomad Role**: None, Server, Client, or Server+Client
- **Tailscale**: Optional VPN integration
- **Installation Mode**: 
  - DD Mode: Direct disk image URL
  - Native Mode: OS reinstall (Debian/Ubuntu/Alpine/etc.)

### 🏗️ Architecture

```
deployx.sh          # Bootstrap (downloads all components)
generate.sh         # Interactive config generator → stdout
bin/execute.sh      # Installation executor  
bin/*.sh            # Single-purpose detection/tools
lib/i18n.sh         # Internationalization library
lib/output.sh       # Formatted output functions
templates/          # Cloud-init templates
translations/       # Language files (en.sh, zh.sh)
```

### 🔐 Security Features
- SSH key authentication only (no passwords)
- Root login disabled
- Custom SSH port configurable
- Firewall-recommended settings in generated config
- Nomad runs as unprivileged user
- TLS encryption for Nomad telemetry

### 📋 Generated Cloud-Init Includes
- User creation with sudo privileges
- SSH hardening (no root login, key-only auth)
- Nomad installation and service setup
- Tailscale connection (if enabled)
- System updates and basic packages
- Automatic reboot on completion

### 🐳 CNCF Alignment
- Uses Nomad (CNCF graduated project) for orchestration
- Declarative, immutable infrastructure approach
- API-driven design (GitHub CLI for all operations)
- Observable outputs and structured logging

### 📝 Requirements
- bash
- curl
- Core utilities (grep, sed, awk, etc.) - available in most Linux distributions

### 🛡️ License
MIT License - see LICENSE file

### 👥 Contributing
See CONTRIBUTING.md for details on submitting patches and following our Contributor Covenant Code of Conduct.

---

**DeployX** - Automate your VPS deployment with cloud-native tools and Unix philosophy simplicity.