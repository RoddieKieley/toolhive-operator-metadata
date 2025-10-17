#!/usr/bin/env bash
# Icon validation script for OLM bundle/catalog builds
# Validates icon format, dimensions, and aspect ratio against OLM requirements

set -euo pipefail

# Check required tools
command -v file >/dev/null 2>&1 || {
  echo "ERROR: 'file' command not found. Install file package." >&2
  exit 127
}

command -v identify >/dev/null 2>&1 || {
  echo "ERROR: ImageMagick 'identify' not found. Install imagemagick package." >&2
  exit 127
}

command -v bc >/dev/null 2>&1 || {
  echo "ERROR: 'bc' command not found. Install bc package." >&2
  exit 127
}

# Usage
if [ $# -lt 1 ]; then
  echo "Usage: $0 <icon-file-path>" >&2
  exit 1
fi

icon_file="$1"

# Check file existence
if [ ! -f "$icon_file" ]; then
  echo "ERROR: Icon file not found: $icon_file" >&2
  exit 1
fi

# Check readability
if [ ! -r "$icon_file" ]; then
  echo "ERROR: Cannot read icon file: $icon_file" >&2
  exit 5
fi

# Detect and validate format
MIME_TYPE=$(file --brief --mime-type "$icon_file")
case "$MIME_TYPE" in
  image/png|image/jpeg|image/gif|image/svg+xml)
    # Valid format
    ;;
  *)
    echo "ERROR: Unsupported format '$MIME_TYPE'. Use PNG, JPEG, GIF, or SVG only" >&2
    exit 2
    ;;
esac

# Extract dimensions using identify
if ! DIMENSIONS=$(identify -format "%w %h" "$icon_file" 2>/dev/null); then
  echo "ERROR: Cannot read icon file: $icon_file" >&2
  echo "Possible causes: file corrupted, insufficient permissions, or unsupported encoding" >&2
  exit 5
fi

read WIDTH HEIGHT <<< "$DIMENSIONS"

# Validate dimensions (max 80x40)
if [ "$WIDTH" -gt 80 ] || [ "$HEIGHT" -gt 40 ]; then
  echo "ERROR: Icon dimensions ${WIDTH}x${HEIGHT} exceed maximum 80x40" >&2
  exit 3
fi

# Validate aspect ratio (1:2 height:width, ±5% tolerance: 0.475-0.525)
RATIO=$(echo "scale=3; $HEIGHT / $WIDTH" | bc)
WITHIN_RANGE=$(echo "$RATIO >= 0.475 && $RATIO <= 0.525" | bc)

if [ "$WITHIN_RANGE" -ne 1 ]; then
  echo "ERROR: Icon aspect ratio $RATIO must be 1:2 (height:width)" >&2
  echo "Expected: 0.5 (±5% tolerance: 0.475-0.525)" >&2
  echo "Actual: $RATIO" >&2
  exit 4
fi

# All validations passed
exit 0
