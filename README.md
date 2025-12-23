# Prisma Cloud Custom Defender Installer

A wrapper script for the Prisma Cloud Defender installation that enables **version rollback** capabilities by allowing you to specify custom Docker image tags.

## The Problem

The standard Prisma Cloud defender installation always deploys the **latest version** from the console. If you need to rollback to a previous defender version (e.g., due to a bug in a new release), there's no built-in way to do this.

## The Solution

This wrapper script:

1. Downloads the official `defender.sh` from your Prisma Cloud console
2. Applies modifications using `sed` to support custom version tags
3. Loads the defender image from your private registry or local backup
4. Runs the installation with your specified version

**No customer data is stored in this repository** - all configuration is provided via environment variables.

## Requirements

- Bash shell
- Docker installed and running
- `curl` command available
- `sudo` access (defender installation requires root)
- Prisma Cloud console access with a valid API token

## Quick Start

### 1. Set Environment Variables

```bash
export PRISMA_API_URL="https://us-east1.cloud.twistlock.com/us-2-XXXXXX"
export PRISMA_TOKEN="your-api-token-here"
export PRISMA_CONSOLE="us-east1.cloud.twistlock.com"
```

### 2. Standard Installation (Latest Version)

```bash
./custom_defender_install.sh -v -m -n
```

### 3. Install Specific Version (Rollback)

```bash
# From private registry
./custom_defender_install.sh --tag _33_00_123 --registry myregistry.example.com/twistlock -v -m -n

# From local backup file
./custom_defender_install.sh --tag _33_00_123 --image ./backups/defender_33_00_123.tar.gz -v -m -n
```

## Important: Image Availability for Rollbacks

**You cannot rollback to a version you don't have the image for.**

The Prisma Cloud console API only serves the current/latest defender image. To enable rollbacks, you must preserve older images using one of these methods:

### Option 1: Private Docker Registry (Recommended)

After each defender installation, push the image to your private registry:

```bash
# Get the current tag from the installed defender
CURRENT_TAG=$(docker images --format "{{.Tag}}" twistlock/private | grep defender | head -1)

# Tag and push to your registry
docker tag twistlock/private:${CURRENT_TAG} myregistry.example.com/twistlock/private:${CURRENT_TAG}
docker push myregistry.example.com/twistlock/private:${CURRENT_TAG}
```

### Option 2: Local Backup Files

Save the image as a tar.gz file:

```bash
CURRENT_TAG=$(docker images --format "{{.Tag}}" twistlock/private | grep defender | head -1)
docker save twistlock/private:${CURRENT_TAG} | gzip > defender_backup_${CURRENT_TAG}.tar.gz
```

### Option 3: Keep Images in Local Docker

Simply don't remove old images from Docker:

```bash
# List available defender versions
docker images twistlock/private --format "{{.Repository}}:{{.Tag}}" | grep defender
```

## Custom Options

| Option | Description |
|--------|-------------|
| `--tag TAG` | Specify the defender version tag (e.g., `_33_00_123`) |
| `--image PATH` | Load defender from a local tar.gz file |
| `--registry URL` | Pull defender image from a private Docker registry |
| `--keep-files` | Preserve the `.twistlock/` folder after installation |
| `--help` | Show detailed help message |

## Standard Defender Options

All standard defender.sh options are passed through:

| Option | Description |
|--------|-------------|
| `-v` | Verify TLS certificates |
| `-m` | Enable advanced custom compliance |
| `-n` | Enable nftables |
| `-u` | Enable unique hostname |
| `-z` | Enable debug logging |
| `-r` | Enable registry scanner |
| `--install-host` | Install as Linux Server Defender |
| `--install-podman` | Install as Podman Defender |
| `--ws-port PORT` | WebSocket port (default: 443) |

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `PRISMA_API_URL` | Yes | Your Prisma Cloud API URL (e.g., `https://us-east1.cloud.twistlock.com/us-2-XXXXXX`) |
| `PRISMA_TOKEN` | Yes | Your Prisma Cloud authentication token |
| `PRISMA_CONSOLE` | Yes | Console address for defender communication (e.g., `us-east1.cloud.twistlock.com`) |

## Examples

### Standard Installation
```bash
./custom_defender_install.sh -v -m -n
```

### Rollback Using Private Registry
```bash
./custom_defender_install.sh \
  --tag _33_00_123 \
  --registry myregistry.example.com/twistlock \
  -v -m -n
```

### Rollback Using Local Backup
```bash
./custom_defender_install.sh \
  --tag _33_00_123 \
  --image ./backups/defender_33_00_123.tar.gz \
  -v -m -n
```

### Install and Keep Configuration Files
```bash
./custom_defender_install.sh --keep-files -v -m -n
```

### Debug Mode
```bash
./custom_defender_install.sh --keep-files -v -m -n -z
```

## How It Works

```
┌──────────────────────────────────────────────────────────────────┐
│  1. Validate environment variables                               │
├──────────────────────────────────────────────────────────────────┤
│  2. If --tag specified:                                          │
│     ├─ Check if image exists locally in Docker                   │
│     ├─ If not, load from --image file                           │
│     ├─ If not, pull from --registry                             │
│     └─ Exit with error if image unavailable                     │
├──────────────────────────────────────────────────────────────────┤
│  3. Download official defender.sh from Prisma Cloud console     │
├──────────────────────────────────────────────────────────────────┤
│  4. Apply sed modifications:                                     │
│     ├─ Inject custom tag into twistlock.cfg after download      │
│     ├─ Skip image download if already loaded locally            │
│     └─ Comment out cleanup if --keep-files specified            │
├──────────────────────────────────────────────────────────────────┤
│  5. Run modified defender.sh with sudo                           │
├──────────────────────────────────────────────────────────────────┤
│  6. Cleanup temporary files                                      │
└──────────────────────────────────────────────────────────────────┘
```

## Rollback Workflow

### Preparation (Do This After Every Update)

```bash
# 1. After installing a new defender version, note the tag
docker images twistlock/private --format "{{.Tag}}" | grep defender
# Output: defender_34_03_138

# 2. Backup the image (choose one method)

# Method A: Push to private registry
docker tag twistlock/private:defender_34_03_138 myregistry.example.com/twistlock/private:defender_34_03_138
docker push myregistry.example.com/twistlock/private:defender_34_03_138

# Method B: Save to file
docker save twistlock/private:defender_34_03_138 | gzip > defender_34_03_138.tar.gz
```

### When Rollback Is Needed

```bash
# 1. First, uninstall the current defender
# (Follow Prisma Cloud documentation for defender removal)

# 2. Install the previous version
./custom_defender_install.sh \
  --tag _33_00_100 \
  --registry myregistry.example.com/twistlock \
  -v -m -n
```

## Troubleshooting

### "Missing required environment variables"

Ensure all three environment variables are set:

```bash
echo "API URL: ${PRISMA_API_URL}"
echo "Token: ${PRISMA_TOKEN:0:20}..."  # Only show first 20 chars
echo "Console: ${PRISMA_CONSOLE}"
```

### "Failed to download defender.sh"

- Verify your `PRISMA_TOKEN` is valid and not expired
- Check that `PRISMA_API_URL` is correct
- Ensure network connectivity to Prisma Cloud

### "Custom tag specified but image not found locally"

You must provide the image using `--registry` or `--image`. The console only serves the latest version.

### "Failed to pull from registry"

- Verify you're authenticated to the registry: `docker login myregistry.example.com`
- Check the image path matches your registry structure
- Ensure the specific tag exists in your registry

## License

MIT License - See LICENSE file for details.

## Contributing

Contributions are welcome! Please submit issues and pull requests on GitHub.
