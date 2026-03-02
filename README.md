# Prisma Cloud Custom Defender Installer

A wrapper script for the Prisma Cloud Defender installation that enables **version rollback** capabilities by allowing you to install a specific defender version from a backup image.

## The Problem

The standard Prisma Cloud defender installation always deploys the **latest version** from the console. If you need to rollback to a previous defender version (e.g., due to a bug in a new release), there's no built-in way to do this.

## The Solution

This wrapper script:

1. Downloads the official `defender.sh` from your Prisma Cloud console
2. Applies modifications using `sed` to support custom version tags
3. Loads the defender image from your backup file or existing Docker image
4. Runs the installation with your specified version

**No customer data is stored in this repository** - all configuration is provided via environment variables or command-line parameters.

## Requirements

- Bash shell
- Docker installed and running
- `curl` command available
- `sudo` access (defender installation requires root)
- Prisma Cloud console access with a valid API token or service account credentials

## Quick Start

### 1. Set Environment Variables

**Using a token:**
```bash
export PRISMA_CONSOLE="https://us-east1.cloud.twistlock.com/us-2-XXXXXX"
export PRISMA_TOKEN="your-api-token-here"
```

**Or using service account credentials (auto-generates a token):**
```bash
export PRISMA_CONSOLE="https://us-east1.cloud.twistlock.com/us-2-XXXXXX"
export PRISMA_ACCESS_KEY="your-access-key-id"
export PRISMA_SECRET_KEY="your-secret-key"
```

### 2. Standard Installation (Latest Version)

```bash
./custom_defender_install.sh -v -m -n
```

### 3. Install Specific Version (Rollback)

**From a tar.gz backup file:**
```bash
./custom_defender_install.sh --tag _34_01_132 --image ./defender_backup.tar.gz -v -m -n
```

**From an existing Docker image:**
```bash
./custom_defender_install.sh --tag _34_01_132 --source-image registry-auth.twistlock.com/xxx/twistlock/defender:_34_01_132 -v -m -n
```

## Custom Options

| Option | Description |
|--------|-------------|
| `--console URL` | Prisma Cloud console URL (overrides `PRISMA_CONSOLE` env var) |
| `--token TOKEN` | API authentication token (overrides `PRISMA_TOKEN` env var) |
| `--user KEY_ID` | Access Key ID for service account auth (overrides `PRISMA_ACCESS_KEY` env var) |
| `--password SECRET` | Access Key Secret for service account auth (overrides `PRISMA_SECRET_KEY` env var) |
| `--tag TAG` | Specify the defender version tag (requires `--image` or `--source-image`) |
| `--image PATH` | Load defender from a local tar.gz file |
| `--source-image IMG` | Use an existing Docker image (will be re-tagged for twistlock.sh) |
| `--keep-files` | Preserve the `.twistlock/` folder after installation |
| `--cpu-limit CPUS` | Limit container to specific CPU cores (e.g., `0-3` or `0,2`) |
| `--memory-limit MEM` | Limit container memory (e.g., `512m`, `2g`) |
| `--help` | Show detailed help message |

## Standard Defender Options

All standard defender.sh options are passed through:

| Option | Description |
|--------|-------------|
| `-v` | Verify TLS certificates |
| `-m` | Enable advanced custom compliance |
| `-n` | Enable nftables |
| `-u` | Assign globally unique names to hosts (for autoscale groups, overlapping IPs, or hosts with identical hostnames) |
| `-z` | Enable debug logging |
| `-r` | Enable registry scanner |
| `--install-host` | Install as Linux Server Defender |
| `--install-podman` | Install as Podman Defender |
| `--ws-port PORT` | WebSocket port (default: 443) |

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `PRISMA_CONSOLE` | Yes | Your Prisma Cloud console URL (e.g., `https://us-east1.cloud.twistlock.com/us-2-XXXXXX`) |
| `PRISMA_TOKEN` | Auth option 1 | Your Prisma Cloud authentication token |
| `PRISMA_ACCESS_KEY` | Auth option 2 | Access Key ID for service account authentication |
| `PRISMA_SECRET_KEY` | Auth option 2 | Access Key Secret for service account authentication |

You must provide either `PRISMA_TOKEN` **or** both `PRISMA_ACCESS_KEY` and `PRISMA_SECRET_KEY`. If a token is provided, it takes precedence over credentials.

## Examples

### Standard Installation
```bash
./custom_defender_install.sh -v -m -n
```

### Using Service Account Credentials via Parameters
```bash
./custom_defender_install.sh \
  --console "https://us-east1.cloud.twistlock.com/us-2-XXXXXX" \
  --user "your-access-key-id" --password "your-secret-key" \
  -v -m -n
```

### Rollback Using Backup File
```bash
./custom_defender_install.sh \
  --tag _34_01_132 \
  --image ./backups/defender_34_01_132.tar.gz \
  -v -m -n
```

### Rollback Using Existing Docker Image
```bash
# If the image was pulled from Twistlock registry
./custom_defender_install.sh \
  --tag _34_01_132 \
  --source-image "registry-auth.twistlock.com/TOKEN/twistlock/defender:_34_01_132" \
  -v -m -n

# If the image is from your private registry
./custom_defender_install.sh \
  --tag _34_01_132 \
  --source-image "myregistry.example.com/twistlock/private:defender_34_01_132" \
  -v -m -n
```

### Install and Keep Configuration Files
```bash
./custom_defender_install.sh --keep-files -v -m -n
```

### Install with Unique Hostnames
```bash
# Use -u when hosts may share the same hostname (e.g., autoscale groups)
# Prisma Cloud will append a unique identifier (e.g., ResourceId) to each host's DNS name
./custom_defender_install.sh -v -m -n -u
```

### Install with Resource Limits
```bash
# Limit to CPU cores 0-3
./custom_defender_install.sh --cpu-limit 0-3 -v -m -n

# Limit to 2GB memory
./custom_defender_install.sh --memory-limit 2g -v -m -n

# Combine CPU and memory limits
./custom_defender_install.sh --cpu-limit 0-3 --memory-limit 2g -v -m -n
```

## How It Works

```
┌──────────────────────────────────────────────────────────────────┐
│  1. Validate configuration (console URL + auth)                  │
├──────────────────────────────────────────────────────────────────┤
│  2. If using --user/--password (no token provided):              │
│     └─ Authenticate via CWP API to obtain a Bearer token        │
├──────────────────────────────────────────────────────────────────┤
│  3. If --tag specified with --image:                             │
│     └─ Load image from tar.gz file                              │
│     If --tag specified with --source-image:                      │
│     └─ Re-tag existing Docker image to expected name            │
├──────────────────────────────────────────────────────────────────┤
│  4. Download official defender.sh from Prisma Cloud console      │
├──────────────────────────────────────────────────────────────────┤
│  5. Apply sed modifications:                                     │
│     ├─ Inject custom tag into twistlock.cfg after download      │
│     ├─ Skip image download if already loaded locally            │
│     ├─ Comment out cleanup if --keep-files specified            │
│     ├─ Add --cpuset-cpus to docker run if --cpu-limit specified │
│     └─ Add --memory to docker run if --memory-limit specified   │
├──────────────────────────────────────────────────────────────────┤
│  6. Run modified defender.sh with sudo                           │
├──────────────────────────────────────────────────────────────────┤
│  7. Cleanup temporary files                                      │
└──────────────────────────────────────────────────────────────────┘
```

## Backup Workflow for Future Rollbacks

After each successful defender installation, create a backup:

### Option 1: Save as tar.gz file
```bash
# Find the current tag
docker images twistlock/private --format "{{.Tag}}" | grep defender
# Output: defender_34_03_138

# Save to file
docker save twistlock/private:defender_34_03_138 | gzip > defender_34_03_138.tar.gz
```

### Option 2: Push to private registry
```bash
docker tag twistlock/private:defender_34_03_138 myregistry.example.com/twistlock/private:defender_34_03_138
docker push myregistry.example.com/twistlock/private:defender_34_03_138
```

## Troubleshooting

### "Missing required configuration"

Ensure your console URL and authentication are set:

```bash
echo "Console: ${PRISMA_CONSOLE}"
echo "Token: ${PRISMA_TOKEN:0:20}..."  # Only show first 20 chars
# Or if using service account:
echo "Access Key: ${PRISMA_ACCESS_KEY}"
echo "Secret Key: ${PRISMA_SECRET_KEY:+[set]}"  # Just confirm it's set
```

### "Authentication failed"

- Verify your access key ID and secret are correct (values are case-sensitive)
- Check that `PRISMA_CONSOLE` includes your tenant ID (e.g., `us-2-XXXXXX`)
- Ensure network connectivity to Prisma Cloud

### "Failed to download defender.sh"

- Verify your token is valid and not expired (manually provided tokens expire after ~10 minutes, auto-generated tokens via `--user`/`--password` expire after ~30 minutes)
- Check that `PRISMA_CONSOLE` includes your tenant ID (e.g., `us-2-XXXXXX`)
- Ensure network connectivity to Prisma Cloud
- Try using `--user` and `--password` to auto-generate a fresh token

### "--tag requires either --image or --source-image"

When using `--tag`, you must provide the image source:
```bash
# From file
./custom_defender_install.sh --tag _34_01_132 --image ./backup.tar.gz -v -m -n

# From existing Docker image
./custom_defender_install.sh --tag _34_01_132 --source-image myimage:tag -v -m -n
```

### "Source image not found"

The image specified with `--source-image` doesn't exist in local Docker. Check available images:
```bash
docker images | grep -i twistlock
docker images | grep -i defender
```

## License

MIT License - See LICENSE file for details.

## Contributing

Contributions are welcome! Please submit issues and pull requests on GitHub.
