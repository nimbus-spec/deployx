# DeployX - VPS Auto Deployment Tool

Modular VPS deployment tool based on Unix philosophy.

## Features

- Hardware detection
- Network detection
- Hostname generation
- Cloud-init integration
- Nomad workload orchestration
- **Internationalization (i18n)**: English & Chinese

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
│   ├── template.sh        # Template engine
│   └── i18n.sh            # Internationalization
├── templates/             # Template files
│   ├── user-data.tpl      # Cloud-init config
│   ├── meta-data.tpl
│   └── nomad/
│       ├── server.hcl.tpl
│       └── client.hcl.tpl
├── config/
│   └── region-codes.conf  # Region code mappings
├── translations/            # i18n translations
│   ├── en.sh              # English
│   └── zh.sh              # Chinese
├── generate.sh             # Main entry
└── README.md
```

## Usage

1. Run `./generate.sh`
2. Select language (English/中文)
3. Enter configuration
4. Confirm and start installation

## Internationalization

The tool supports multiple languages. To add a new language:

1. Copy `translations/en.sh` to `translations/{lang}.sh`
2. Translate all strings in the `T[...]` array
3. The tool auto-detects language from `LANG` environment variable

## Dependencies

- Linux (bash)
- cloud-init
- openssl
- curl

## License

MIT
