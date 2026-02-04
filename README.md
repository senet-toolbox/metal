# Install Metal CLI

Run this command to install metal-cli on your macOS (Apple Silicon):

```bash
curl -sSL https://raw.githubusercontent.com/senet-toolbox/metal/main/install.sh | bash
```

## What this does:
- Downloads the latest version of metal-cli
- Installs it to `/usr/local/bin/metal`
- Makes it executable and available in your PATH

## Requirements:
- macOS with Apple Silicon (M1/M2/M3)
- Administrator privileges (for `sudo` during installation)

After installation, you can run:
```bash
metal --help
```
