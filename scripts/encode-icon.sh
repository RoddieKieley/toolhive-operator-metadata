#!/usr/bin/env bash
# Icon encoding script for OLM bundle/catalog builds
# Encodes icon files to base64 for embedding in ClusterServiceVersion

set -euo pipefail

# Usage
if [ $# -lt 1 ]; then
  echo "Usage: $0 <icon-file-path> [mediatype]" >&2
  exit 1
fi

icon_file="$1"
mediatype="${2:-}"

# Check file readability
if [ ! -r "$icon_file" ]; then
  echo "ERROR: Cannot read icon file: $icon_file" >&2
  exit 1
fi

# Auto-detect mediatype from extension if not provided
if [ -z "$mediatype" ]; then
  case "${icon_file##*.}" in
    png) mediatype="image/png" ;;
    jpg|jpeg) mediatype="image/jpeg" ;;
    gif) mediatype="image/gif" ;;
    svg) mediatype="image/svg+xml" ;;
    *)
      echo "ERROR: Cannot detect mediatype for extension: ${icon_file##*.}" >&2
      exit 1
      ;;
  esac
fi

# Output mediatype to stderr for caller parsing
echo "MEDIATYPE:$mediatype" >&2

# Encode with platform-specific flags
if [[ "$OSTYPE" == "darwin"* ]]; then
  # macOS: base64 outputs without wrapping by default
  base64 -i "$icon_file" 2>&1 || {
    echo "ERROR: Base64 encoding failed for: $icon_file" >&2
    exit 1
  }
else
  # Linux: use -w 0 to disable wrapping
  base64 -w 0 "$icon_file" 2>&1 || {
    echo "ERROR: Base64 encoding failed for: $icon_file" >&2
    exit 1
  }
fi
