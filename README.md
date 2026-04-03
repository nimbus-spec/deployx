# DeployX - VPS Auto Deployment Tool

Modular VPS deployment tool based on Unix philosophy.

## Features

- **OS Selection**: Choose from multiple Linux distributions
- **Custom DD Image**: Support for custom disk images
- Hardware detection
- Network detection (IPv4/IPv6/Dual-Stack/NAT)
- Hostname generation: `{country}-{region}-{network_type}-{merchant}-{random8}`
- Cloud-init integration
- Nomad workload orchestration
- **Tailscale VPN** integration for cluster networking
- **Internationalization (i18n)**: English & Chinese
- Kernel tuning (BBR, TCP optimization)

## Quick Start

### Option 1: Download and Run (Recommended for interactive use)

```bash
curl -fsSL https://raw.githubusercontent.com/nimbus-spec/deployx/main/deployx.sh -o deployx.sh
chmod +x deployx.sh
./deployx.sh
```

### Option 2: Clone Repository

```bash
git clone https://github.com/nimbus-spec/deployx.git
cd deployx
./generate.sh
```

> **Note**: `curl ... | bash` does NOT work for interactive scripts because `read` commands require a TTY. You must download the script first, then execute it.

## Supported Operating Systems

| OS | Versions | Install Mode |
|----|----------|-------------|
| Debian | 12, 13 | Native / DD |
| Ubuntu | 20.04, 22.04, 24.04 | Native / DD |
| Alpine | 3.20, 3.21, 3.22 | Native / DD |
| CentOS Stream | 9, 10 | Native / DD |
| Rocky Linux | 8, 9, 10 | Native / DD |
| AlmaLinux | 8, 9, 10 | Native / DD |
| Fedora | 42, 43 | Native / DD |
| Custom DD Image | Any URL | DD only |

## Installation Modes

### Native Install

Uses the reinstall script's native installation to install the selected OS directly from official mirrors. Recommended for:
- Fresh installations
- Systems requiring full disk encryption
- Wanting latest OS versions automatically

### DD (Disk Dump)

Uses the reinstall script to dump a raw disk image directly. Recommended for:
- Using custom/pre-configured images
- Deploying Windows images
- Preserving specific system configurations

## Usage

1. Download and run `deployx.sh`
2. Select language (English/ä¸­æ–‡)
3. Select operating system
4. Choose installation mode (Native/DD)
5. If using DD, enter the custom image URL
6. Enter configuration:
   - Merchant/provider name
   - Region (e.g., tokyo, singapore)
   - Country code
   - Nomad role (server/client)
   - SSH port and key
   - **Tailscale VPN** (optional)
7. Confirm and start installation

## Project Structure

```
deployx/
â”œâ”€â”€ bin/                    # Executable scripts
â”‚   â”œâ”€â”€ detect.sh          # Hardware detection
â”‚   â”œâ”€â”€ hostname.sh        # Hostname generation
â”‚   â””â”€â”€ network.sh         # Network detection
â”œâ”€â”€ lib/                   # Function libraries
â”‚   â”œâ”€â”€ output.sh          # Output functions
â”‚   â”œâ”€â”€ detect.sh          # Hardware detection lib
â”‚   â”œâ”€â”€ network.sh         # Network detection lib
â”‚   â””â”€â”€ i18n.sh            # Internationalization
â”œâ”€â”€ templates/             # Template files
â”‚   â”œâ”€â”€ user-data.tpl      # Cloud-init config
â”‚   â””â”€â”€ meta-data.tpl
â”œâ”€â”€ config/
â”‚   â””â”€â”€ region-codes.conf  # Region code mappings
â”œâ”€â”€ translations/          # i18n translations
â”‚   â”œâ”€â”€ en.sh              # English
â”‚   â””â”€â”€ zh.sh              # Chinese
â”œâ”€â”€ generate.sh            # Main entry
â”œâ”€â”€ deployx.sh             # One-line installer (downloads all files)
â””â”€â”€ README.md
```

## Tailscale Integration

DeployX supports automatic Tailscale VPN setup for cluster networking.

### Configuration

During deployment, you can enable Tailscale:

```
Enable Tailscale VPN? (yes/no): yes
Tailscale auth key: tskey-auth-xxxxx...
Accept routes from tailnet? (yes/no): yes
```

### Features

- Automatic installation via official Tailscale script
- Auth key authentication (no interactive login required)
- Optional route acceptance for subnet router mode
- Connects to your tailnet immediately on first boot

## Nomad Integration

DeployX automatically sets up HashiCorp Nomad:

### Server Mode

- Downloads and installs latest Nomad release
- Creates systemd service
- Configures `server.hcl` with auto-detected hostname
- Enables Prometheus metrics endpoint

### Client Mode

- Installs Nomad client
- Configures for workload scheduling
- Connects to server based on configuration

## Internationalization

The tool supports multiple languages. To add a new language:

1. Copy `translations/en.sh` to `translations/{lang}.sh`
2. Translate all strings in the `T[...]` associative array
3. Add case in `select_language()` function (optional)

## Hostname Convention

Format: `{country}-{region}-{network_type}-{merchant}-{random8}`

Example: `jp-tyo-v4-conoha-a1b2c3d4`

## Dependencies

### Runtime

- Linux (bash)
- cloud-init
- openssl
- curl or wget
- ip (iproute2)

### Optional

- Tailscale (if VPN enabled)
- Nomad (if server/client role selected)

## License

MIT
