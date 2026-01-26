#!/bin/bash
#########
# Custom Defender Install Wrapper
#
# Downloads the official defender.sh from Prisma Cloud and applies modifications
# to support custom Docker tags for version rollback scenarios.
#
# This script does NOT contain any customer-specific data - all configuration
# is provided via environment variables or command-line arguments.
#
# Required Environment Variables:
#   PRISMA_API_URL     - Your Prisma Cloud API URL (e.g., https://us-east1.cloud.twistlock.com/us-2-XXXXXX)
#   PRISMA_TOKEN       - Your Prisma Cloud authentication token
#   PRISMA_CONSOLE     - Console address (e.g., us-east1.cloud.twistlock.com)
#
# Custom Options (must come BEFORE standard options):
#   --tag TAG          - Use a specific defender version tag (e.g., _33_00_123)
#   --image PATH       - Use a local Docker image tar.gz file
#   --registry URL     - Pull image from a private Docker registry
#   --keep-files       - Preserve the .twistlock folder after installation
#   --cpu-limit CPUS   - Limit container to specific CPU cores (e.g., 0-3 or 0,2)
#   --memory-limit MEM - Limit container memory (e.g., 512m, 2g)
#
# Usage:
#   ./custom_defender_install.sh [CUSTOM_OPTIONS] [STANDARD_DEFENDER_OPTIONS]
#
# Examples:
#   # Standard install (latest version)
#   ./custom_defender_install.sh -v -m -n
#
#   # Install specific version from private registry
#   ./custom_defender_install.sh --tag _33_00_123 --registry myregistry.example.com/twistlock -v -m -n
#
#   # Install from local image file
#   ./custom_defender_install.sh --tag _33_00_123 --image ./defender_backup.tar.gz -v -m -n
#
#   # Install with CPU core limit (restrict to cores 0-3)
#   ./custom_defender_install.sh --cpu-limit 0-3 -v -m -n
#
#   # Install with memory limit (2GB) and CPU limit
#   ./custom_defender_install.sh --cpu-limit 0-3 --memory-limit 2g -v -m -n
#########

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
print_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Custom parameters
CUSTOM_TAG=""
CUSTOM_IMAGE=""
SOURCE_IMAGE=""
KEEP_FILES="false"
CPU_LIMIT=""
MEMORY_LIMIT=""

# Show help
show_help() {
    cat << 'EOF'
Custom Prisma Cloud Defender Installer
=======================================

Downloads the official defender.sh and applies modifications to support
custom Docker tags for version rollback scenarios.

REQUIRED ENVIRONMENT VARIABLES:
  PRISMA_API_URL     Your Prisma Cloud API URL
                     Example: https://us-east1.cloud.twistlock.com/us-2-XXXXXX

  PRISMA_TOKEN       Your Prisma Cloud authentication token (Bearer token)

  PRISMA_CONSOLE     Console address for defender communication
                     Example: us-east1.cloud.twistlock.com

CUSTOM OPTIONS (must come before standard options):
  --tag TAG          Use a specific defender version tag (required with --image or --source-image)
                     Example: --tag _34_01_132

  --image PATH       Load defender from a local tar.gz file (requires --tag)
                     Example: --image /path/to/twistlock_defender.tar.gz

  --source-image IMG Use an existing Docker image by full name (requires --tag)
                     The image will be re-tagged to match what twistlock.sh expects
                     Example: --source-image registry-auth.twistlock.com/xxx/twistlock/defender:_34_01_132
                     Example: --source-image myregistry.com/twistlock/private:defender_34_01_132

  --keep-files       Preserve the .twistlock folder after installation
                     (default: deleted after install, matching original behavior)

  --cpu-limit CPUS   Limit the container to specific CPU cores using --cpuset-cpus
                     Example: --cpu-limit 0-3 (use cores 0, 1, 2, 3)
                     Example: --cpu-limit 0,2 (use cores 0 and 2)

  --memory-limit MEM Limit the container memory using --memory
                     Example: --memory-limit 512m (limit to 512 megabytes)
                     Example: --memory-limit 2g (limit to 2 gigabytes)

  --help             Show this help message

STANDARD DEFENDER OPTIONS (passed through to defender.sh):
  -v                 Verify TLS certificates
  -m                 Enable advanced custom compliance
  -n                 Enable nftables
  -u                 Enable unique hostname
  -z                 Enable debug logging
  -r                 Enable registry scanner
  --install-host     Install as Linux Server Defender
  --install-podman   Install as Podman Defender
  --ws-port PORT     WebSocket port (default: 443)

EXAMPLES:
  # Set environment variables first
  export PRISMA_API_URL="https://us-east1.cloud.twistlock.com/us-2-XXXXXX"
  export PRISMA_TOKEN="your-token-here"
  export PRISMA_CONSOLE="us-east1.cloud.twistlock.com"

  # Standard install (latest version from console)
  ./custom_defender_install.sh -v -m -n

  # Install specific version from a tar.gz backup
  ./custom_defender_install.sh --tag _34_01_132 --image ./defender_backup.tar.gz -v -m -n

  # Install specific version from an existing Docker image
  ./custom_defender_install.sh --tag _34_01_132 --source-image registry-auth.twistlock.com/xxx/twistlock/defender:_34_01_132 -v -m -n

  # Install and keep configuration files for inspection
  ./custom_defender_install.sh --keep-files -v -m -n

  # Install with CPU core limit (restrict to cores 0-3)
  ./custom_defender_install.sh --cpu-limit 0-3 -v -m -n

  # Install with memory limit (2GB) and CPU limit
  ./custom_defender_install.sh --cpu-limit 0-3 --memory-limit 2g -v -m -n

IMAGE MANAGEMENT FOR ROLLBACKS:
  To rollback to older versions, you need the older image available as either:

  1. A local tar.gz file (use --image)
  2. An existing Docker image (use --source-image)

  Backup after each install:
    docker save twistlock/private:defender_XX_XX_XXX | gzip > defender_backup.tar.gz

EOF
}

# Parse custom arguments (before standard defender args)
PASSTHROUGH_ARGS=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --tag)
            CUSTOM_TAG="$2"
            shift 2
            ;;
        --image)
            CUSTOM_IMAGE="$2"
            shift 2
            ;;
        --source-image)
            SOURCE_IMAGE="$2"
            shift 2
            ;;
        --keep-files)
            KEEP_FILES="true"
            shift
            ;;
        --cpu-limit)
            CPU_LIMIT="$2"
            shift 2
            ;;
        --memory-limit)
            MEMORY_LIMIT="$2"
            shift 2
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            # Pass through to defender.sh
            PASSTHROUGH_ARGS+=("$1")
            shift
            ;;
    esac
done

# Validate required environment variables
validate_env() {
    local missing=""

    if [ -z "${PRISMA_API_URL}" ]; then
        missing="${missing}  PRISMA_API_URL\n"
    fi
    if [ -z "${PRISMA_TOKEN}" ]; then
        missing="${missing}  PRISMA_TOKEN\n"
    fi
    if [ -z "${PRISMA_CONSOLE}" ]; then
        missing="${missing}  PRISMA_CONSOLE\n"
    fi

    if [ -n "${missing}" ]; then
        print_error "Missing required environment variables:"
        echo -e "${missing}"
        echo "Run with --help for usage information."
        exit 1
    fi
}

# Check if Docker image exists locally
check_image_exists() {
    local image_name="$1"
    docker images --format "{{.Repository}}:{{.Tag}}" 2>/dev/null | grep -q "^${image_name}$"
}

# Re-tag an existing Docker image to the expected name
retag_image() {
    local source="$1"
    local target="$2"

    print_info "Re-tagging image: ${source} -> ${target}"

    # Check if source image exists
    if ! docker image inspect "${source}" >/dev/null 2>&1; then
        print_error "Source image not found: ${source}"
        return 1
    fi

    if docker tag "${source}" "${target}"; then
        print_info "Successfully re-tagged image"
        return 0
    else
        print_error "Failed to re-tag image"
        return 1
    fi
}

# Load image from tar.gz file
load_image_from_file() {
    local image_file="$1"

    if [ ! -f "${image_file}" ]; then
        print_error "Image file not found: ${image_file}"
        return 1
    fi

    print_info "Loading image from file: ${image_file}"
    if docker load < "${image_file}"; then
        print_info "Image loaded successfully"
        return 0
    else
        print_error "Failed to load image"
        return 1
    fi
}

# Main execution
main() {
    validate_env

    print_info "Prisma Cloud Custom Defender Installer"
    print_info "======================================="

    if [ -n "${CUSTOM_TAG}" ]; then
        print_info "Custom tag requested: ${CUSTOM_TAG}"
    fi

    # Validate custom tag usage - must have --image or --source-image
    if [ -n "${CUSTOM_TAG}" ]; then
        if [ -z "${CUSTOM_IMAGE}" ] && [ -z "${SOURCE_IMAGE}" ]; then
            print_error "--tag requires either --image or --source-image"
            print_error ""
            print_error "Usage:"
            print_error "  --tag TAG --image /path/to/defender.tar.gz"
            print_error "  --tag TAG --source-image registry.example.com/twistlock/defender:TAG"
            exit 1
        fi
    fi

    # Prepare image if custom tag specified
    if [ -n "${CUSTOM_TAG}" ]; then
        # Normalize the tag - remove "defender" prefix if present
        local original_tag="${CUSTOM_TAG}"
        CUSTOM_TAG="${CUSTOM_TAG#defender}"  # Remove "defender" prefix if present

        print_info "Tag: '${original_tag}' -> '${CUSTOM_TAG}'"

        local target_image="twistlock/private:defender${CUSTOM_TAG}"

        # Load from tar.gz file if specified
        if [ -n "${CUSTOM_IMAGE}" ]; then
            if load_image_from_file "${CUSTOM_IMAGE}"; then
                print_info "Image loaded from file"
            else
                print_error "Failed to load image from file. Aborting."
                exit 1
            fi
        # Re-tag existing Docker image if specified
        elif [ -n "${SOURCE_IMAGE}" ]; then
            if retag_image "${SOURCE_IMAGE}" "${target_image}"; then
                print_info "Image ready: ${target_image}"
            else
                print_error "Failed to re-tag image. Aborting."
                exit 1
            fi
        fi
    fi

    # Download the original defender.sh
    print_info "Downloading defender.sh from Prisma Cloud..."

    local temp_dir=$(mktemp -d)
    local defender_script="${temp_dir}/defender.sh"

    # Normalize the API URL - remove trailing slash and /api/v1 if present
    local api_base="${PRISMA_API_URL%/}"  # Remove trailing slash
    api_base="${api_base%/api/v1}"        # Remove /api/v1 if present
    api_base="${api_base%/api}"           # Remove /api if present

    local full_url="${api_base}/api/v1/scripts/defender.sh"
    print_info "API URL: ${full_url}"

    local http_code
    http_code=$(curl -sSL -w "%{http_code}" \
        --header "authorization: Bearer ${PRISMA_TOKEN}" \
        -X POST \
        "${full_url}" \
        -o "${defender_script}" 2>/dev/null)

    if [ "${http_code}" != "200" ]; then
        print_error "Failed to download defender.sh (HTTP ${http_code})"
        print_error ""
        print_error "Possible causes:"
        print_error "  - Token expired (tokens typically expire after ~10 minutes)"
        print_error "  - Incorrect PRISMA_API_URL"
        print_error "  - Network connectivity issues"
        print_error ""
        print_error "To get a fresh token, run the defender download command from the"
        print_error "Prisma Cloud console and copy the token from the curl command."
        rm -rf "${temp_dir}"
        exit 1
    fi

    print_info "Downloaded defender.sh successfully"

    # Apply modifications using sed
    print_info "Applying custom modifications..."

    # Modification 1: If custom tag specified, inject sed command after twistlock.cfg download
    if [ -n "${CUSTOM_TAG}" ]; then
        print_info "Injecting tag modification for: ${CUSTOM_TAG}"
        # Add sed command to modify DOCKER_TWISTLOCK_TAG in twistlock.cfg after it's downloaded
        # Find the line that downloads twistlock.cfg and add our modification after it
        sed -i.bak '/scripts\/twistlock.cfg -o twistlock.cfg/a\
	# Custom tag modification\
	sed -i.bak "s/^DOCKER_TWISTLOCK_TAG=.*/DOCKER_TWISTLOCK_TAG='"${CUSTOM_TAG}"'/" twistlock.cfg\
	print_info "Applied custom tag: '"${CUSTOM_TAG}"'"
' "${defender_script}"
    fi

    # Modification 2: If keep-files, comment out the cleanup line
    if [ "${KEEP_FILES}" == "true" ]; then
        # Comment out the rm and rmdir line at the end
        sed -i.bak 's/^rm "\${working_folder}"\/\* && rmdir "\${working_folder}"/# KEEP_FILES: rm "\${working_folder}"\/* \&\& rmdir "\${working_folder}"/' "${defender_script}"
        print_info "Modified to preserve .twistlock folder"
    fi

    # Modification 3: Skip image download if we already have it (for custom tag scenarios)
    if [ -n "${CUSTOM_TAG}" ]; then
        # The image is already loaded, but defender.sh will still try to download it
        # We modify it to skip the download if image exists
        # This is done by adding a check before the curl download
        sed -i.bak '/\${curl}.*\${image_path}\/\${image_name}/i\
	# Skip download if image already exists locally\
	if docker images --format "{{.Repository}}:{{.Tag}}" 2>/dev/null | grep -q "twistlock/private:defender'"${CUSTOM_TAG}"'"; then\
		print_info "Image already exists locally, skipping download"\
		touch ${image_name}\
	else
' "${defender_script}"

        # Close the else block after the curl command
        sed -i.bak '/exit_on_failure \$? "Failed to download Defender image from Console"/a\
	fi
' "${defender_script}"
    fi

    # Modification 4: Add --cpuset-cpus to docker run command if cpu-limit specified
    if [ -n "${CPU_LIMIT}" ]; then
        print_info "Injecting CPU limit: --cpuset-cpus=${CPU_LIMIT}"
        # Replace "docker run" with "docker run --cpuset-cpus=VALUE" in the defender script
        sed -i.bak "s/docker run /docker run --cpuset-cpus=${CPU_LIMIT} /g" "${defender_script}"
    fi

    # Modification 5: Add --memory to docker run command if memory-limit specified
    if [ -n "${MEMORY_LIMIT}" ]; then
        print_info "Injecting memory limit: --memory=${MEMORY_LIMIT}"
        # Replace "docker run" with "docker run --memory=VALUE" in the defender script
        sed -i.bak "s/docker run /docker run --memory=${MEMORY_LIMIT} /g" "${defender_script}"
    fi

    # Clean up backup files
    rm -f "${defender_script}.bak"

    # Build the command arguments
    local cmd_args="-c ${PRISMA_CONSOLE}"

    # Add custom tag override for twistlock.sh
    if [ -n "${CUSTOM_TAG}" ]; then
        # The -t flag in twistlock.sh overrides the tag
        cmd_args="${cmd_args}"
    fi

    # Add passthrough arguments
    for arg in "${PASSTHROUGH_ARGS[@]}"; do
        cmd_args="${cmd_args} ${arg}"
    done

    print_info "Running defender.sh with args: ${cmd_args}"
    print_info "======================================="

    # Run the modified script
    sudo bash "${defender_script}" ${cmd_args}
    local result=$?

    # Cleanup temp directory
    rm -rf "${temp_dir}"

    if [ ${result} -eq 0 ]; then
        print_info "======================================="
        print_info "Defender installation completed successfully!"
        if [ "${KEEP_FILES}" == "true" ]; then
            print_info "Configuration files preserved in .twistlock/"
        fi
        if [ -n "${CUSTOM_TAG}" ]; then
            print_info "Installed version: ${CUSTOM_TAG}"
            print_info ""
            print_info "TIP: To backup this version for future rollbacks:"
            print_info "  docker save twistlock/private:defender${CUSTOM_TAG} | gzip > defender${CUSTOM_TAG}.tar.gz"
        fi
    else
        print_error "Defender installation failed with exit code ${result}"
    fi

    return ${result}
}

# Run main
main "$@"
