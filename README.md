# DeployX - VPS Auto Deployment Tool

Modular VPS deployment tool based on Unix philosophy.

## Features

- Hardware detection
- Network detection (IPv4/IPv6/Dual-Stack/NAT)
- Hostname generation: `{country}-{region}-{network_type}-{merchant}-{random8}`
- Cloud-init integration
- Nomad workload orchestration
- **Tailscale VPN** integration for cluster networking
- **Internationalization (i18n)**: English & Chinese
- Kernel tuning (BBR, TCP optimization)

## Quick Start

```bash
git clone https://github.com/nimbus-spec/deployx.git
cd deployx
./generate.sh
```

## Project Structure

```
deployx/
├── bin/                    # Executable scripts
│   ├── detect.sh          # Hardware detection
│   ├── hostname.sh        # Hostname generation
│   └── network.sh         # Network detection
├── lib/                   # Function libraries
│   ├── output.sh          # Output functions
│   ├── detect.sh          # Hardware detection lib
│   ├── network.sh         # Network detection lib
│   ├── i18n.sh            # Internationalization
│   └── template.sh        # Template engine
├── templates/             # Template files
│   ├── user-data.tpl      # Cloud-init config
│   └── meta-data.tpl
├── config/
│   └── region-codes.conf  # Region code mappings
├── translations/          # i18n translations
│   ├── en.sh              # English
│   └── zh.sh              # Chinese
├── generate.sh            # Main entry
└── README.md
```

## Usage

1. Run `./generate.sh`
2. Select language (English/中文)
3. Enter configuration:
   - Merchant/provider name
   - Region (e.g., tokyo, singapore)
   - Country code
   - Nomad role (server/client)
   - SSH port and key
   - **Tailscale VPN** (optional)
4. Confirm and start installation

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

### Auth Key

Generate an auth key from [Tailscale admin console](https://login.tailscale.com/admin/settings/keys):

1. Go to Settings > Keys
2. Click "Generate auth key"
3. Set reusable option if needed
4. Copy the key (starts with `tskey-auth-`)

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

- `jp` - Country code
- `tyo` - Region code (tokyo)
- `v4` - Network type (v4/v6/dual/nat)
- `conoha` - Merchant/provider name
- `a1b2c3d4` - Random 8-character string

## Dependencies

### Runtime

- Linux (bash)
- cloud-init
- openssl
- curl
- ip (iproute2)

### Optional

- Tailscale (if VPN enabled)
- Nomad (if server/client role selected)

## License

MIT
