#!/bin/bash

# Secure Docker Migration Script: Home Assistant -> Private GitHub Container Registry
# Pulls Home Assistant Docker images and pushes to private GitHub registry

set -euo pipefail

# Configuration
readonly GITHUB_REGISTRY="ghcr.io"
readonly HA_REGISTRY="ghcr.io/home-assistant"
readonly DOCKERHUB_HA="homeassistant"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Security: Validate environment variables
if [[ -z "${GITHUB_USERNAME:-}" ]] || [[ -z "${GITHUB_TOKEN:-}" ]]; then
    echo -e "${RED}ERROR: Required environment variables not set${NC}" >&2
    echo -e "${YELLOW}Please set: GITHUB_USERNAME and GITHUB_TOKEN${NC}" >&2
    exit 1
fi

# Logging functions
log() { echo -e "${GREEN}[$(date +'%H:%M:%S')] $1${NC}"; }
warn() { echo -e "${YELLOW}[WARN] $1${NC}"; }
error() { echo -e "${RED}[ERROR] $1${NC}" >&2; }
info() { echo -e "${BLUE}[INFO] $1${NC}"; }

# Security: Clean up on exit
cleanup() {
    log "Cleaning up..."
    docker logout "$GITHUB_REGISTRY" &>/dev/null || true
    docker image prune -f &>/dev/null || true
}
trap cleanup EXIT

# Validate Docker setup
check_docker() {
    if ! command -v docker &>/dev/null; then
        error "Docker not found. Please install Docker first."
        exit 1
    fi

    if ! docker info &>/dev/null; then
        error "Docker daemon not running. Please start Docker."
        exit 1
    fi

    log "Docker validation passed"
}

# Secure GitHub login
github_login() {
    log "Authenticating with GitHub Container Registry..."

    # Security: Use stdin to prevent token exposure in process list
    if echo "$GITHUB_TOKEN" | docker login "$GITHUB_REGISTRY" \
        --username "$GITHUB_USERNAME" --password-stdin &>/dev/null; then
        log "GitHub authentication successful"
    else
        error "GitHub authentication failed. Check your credentials."
        exit 1
    fi
}

# Pull, retag, and push image with error handling
migrate_image() {
    local source_image="$1"
    local target_image="$2"

    info "Migrating: $source_image → $target_image"

    # Pull with retry logic
    local retry_count=0
    local max_retries=3

    while [[ $retry_count -lt $max_retries ]]; do
        if docker pull "$source_image" &>/dev/null; then
            break
        else
            ((retry_count++))
            warn "Pull attempt $retry_count failed, retrying..."
            sleep 2
        fi
    done

    if [[ $retry_count -eq $max_retries ]]; then
        error "Failed to pull $source_image after $max_retries attempts"
        return 1
    fi

    # Tag for target registry
    if ! docker tag "$source_image" "$target_image"; then
        error "Failed to tag image"
        return 1
    fi

    # Push to private registry
    if ! docker push "$target_image"; then
        error "Failed to push to private registry"
        return 1
    fi

    # Clean up to save space
    docker rmi "$source_image" "$target_image" &>/dev/null || true

    log "✓ Successfully migrated $(basename "$source_image")"
    return 0
}

# Define Home Assistant images to migrate
get_image_list() {
    # Core Home Assistant images
    cat << EOF
$HA_REGISTRY/home-assistant:stable,$GITHUB_REGISTRY/$GITHUB_USERNAME/home-assistant:stable
$HA_REGISTRY/home-assistant:latest,$GITHUB_REGISTRY/$GITHUB_USERNAME/home-assistant:latest
$HA_REGISTRY/home-assistant:beta,$GITHUB_REGISTRY/$GITHUB_USERNAME/home-assistant:beta
$HA_REGISTRY/supervisor:latest,$GITHUB_REGISTRY/$GITHUB_USERNAME/supervisor:latest

# Popular Add-ons (uncomment as needed)
# $HA_REGISTRY/addon-mosquitto:latest,$GITHUB_REGISTRY/$GITHUB_USERNAME/addon-mosquitto:latest
# $HA_REGISTRY/addon-node-red:latest,$GITHUB_REGISTRY/$GITHUB_USERNAME/addon-node-red:latest
# $HA_REGISTRY/addon-vscode:latest,$GITHUB_REGISTRY/$GITHUB_USERNAME/addon-vscode:latest
# $HA_REGISTRY/addon-mariadb:latest,$GITHUB_REGISTRY/$GITHUB_USERNAME/addon-mariadb:latest
# $HA_REGISTRY/addon-nginx-proxy-manager:latest,$GITHUB_REGISTRY/$GITHUB_USERNAME/addon-nginx-proxy-manager:latest
# $HA_REGISTRY/addon-ssh:latest,$GITHUB_REGISTRY/$GITHUB_USERNAME/addon-ssh:latest
# $HA_REGISTRY/addon-file-editor:latest,$GITHUB_REGISTRY/$GITHUB_USERNAME/addon-file-editor:latest

# Legacy Docker Hub (if needed)
# $DOCKERHUB_HA/home-assistant:stable,$GITHUB_REGISTRY/$GITHUB_USERNAME/home-assistant-legacy:stable
EOF
}

# Main migration process
run_migration() {
    local success_count=0
    local total_count=0
    local failed_images=()

    while IFS=',' read -r source_image target_image; do
        # Skip comments and empty lines
        [[ "$source_image" =~ ^[[:space:]]*# ]] || [[ -z "$source_image" ]] && continue

        ((total_count++))

        if migrate_image "$source_image" "$target_image"; then
            ((success_count++))
        else
            failed_images+=("$source_image")
        fi

        # Brief pause to avoid overwhelming registries
        sleep 1

    done < <(get_image_list)

    # Summary
    echo
    log "Migration Summary:"
    log "  ✓ Successful: $success_count/$total_count"

    if [[ ${#failed_images[@]} -gt 0 ]]; then
        warn "  ✗ Failed images:"
        printf '    - %s\n' "${failed_images[@]}"
    fi
}

# Interactive mode for custom images
interactive_mode() {
    echo
    info "Interactive mode: Add custom images to migrate"
    echo "Format: source_image target_image (or 'done' to finish)"

    while true; do
        read -rp "Enter image pair: " input
        [[ "$input" == "done" ]] && break

        if [[ "$input" =~ ^([^[:space:]]+)[[:space:]]+([^[:space:]]+)$ ]]; then
            local source="${BASH_REMATCH[1]}"
            local target="${BASH_REMATCH[2]}"
            migrate_image "$source" "$target"
        else
            warn "Invalid format. Use: source_image target_image"
        fi
    done
}

# Help message
show_help() {
    cat << 'EOF'
Home Assistant Docker Migration Script

DESCRIPTION:
    Securely pulls Home Assistant Docker images and pushes them to your
    private GitHub Container Registry.

USAGE:
    ./script.sh [OPTIONS]

REQUIRED ENVIRONMENT VARIABLES:
    GITHUB_USERNAME    Your GitHub username
    GITHUB_TOKEN       GitHub Personal Access Token with packages:write scope

OPTIONS:
    -i, --interactive  Run in interactive mode to add custom images
    -h, --help        Show this help message

EXAMPLES:
    # Basic migration
    export GITHUB_USERNAME="myuser"
    export GITHUB_TOKEN="ghp_xxxxxxxxxxxx"
    ./script.sh

    # Interactive mode
    ./script.sh --interactive

SECURITY NOTES:
    - Token is passed securely via stdin
    - Automatic cleanup on script exit
    - No credentials stored in process list or logs
    - Images cleaned up locally after migration

GitHub Token Permissions Required:
    - packages:write
    - packages:read
EOF
}

# Main execution
main() {
    local interactive=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -i|--interactive)
                interactive=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done

    log "Starting Home Assistant Docker migration to private GitHub registry"
    log "Target registry: $GITHUB_REGISTRY/$GITHUB_USERNAME/*"
    echo

    check_docker
    github_login

    run_migration

    if [[ "$interactive" == true ]]; then
        interactive_mode
    fi

    log "Migration completed successfully!"
}

# Execute main function with all arguments
main "$@"
