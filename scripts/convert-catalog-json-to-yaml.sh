#!/usr/bin/env bash
# Convert olm.bundle.object base64-encoded JSON to YAML in catalog FBC files
#
# Background: opm render outputs olm.bundle.object with base64-encoded JSON,
# but OLM requires base64-encoded YAML for proper CRD/CSV recognition.
#
# Usage: ./scripts/convert-catalog-json-to-yaml.sh catalog/toolhive-operator/catalog.yaml
#
# This script:
# 1. Extracts each base64-encoded JSON blob from olm.bundle.object properties
# 2. Decodes, converts JSON to YAML
# 3. Re-encodes as base64
# 4. Updates the catalog file in place

set -euo pipefail

CATALOG_FILE="${1:-}"

if [ -z "$CATALOG_FILE" ]; then
    echo "Error: Catalog file path required"
    echo "Usage: $0 <catalog-file>"
    exit 1
fi

if [ ! -f "$CATALOG_FILE" ]; then
    echo "Error: File not found: $CATALOG_FILE"
    exit 1
fi

# Check dependencies
command -v yq >/dev/null 2>&1 || { echo "Error: yq not found"; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "Error: python3 not found"; exit 1; }

echo "Converting olm.bundle.object JSON to YAML in: $CATALOG_FILE"

# Create a Python script to do the conversion
# Pass catalog file path via environment variable
export CATALOG_PATH="$CATALOG_FILE"
python3 <<'PYTHON_SCRIPT'
import sys
import yaml
import json
import base64
import re
import os

# Read the catalog file path from environment
catalog_path = os.environ.get('CATALOG_PATH')
if not catalog_path:
    print("Error: CATALOG_PATH environment variable not set", file=sys.stderr)
    sys.exit(1)

with open(catalog_path, 'r') as f:
    content = f.read()

# Track if we made any changes
changes_made = 0

# Find all base64 data fields in olm.bundle.object sections
# Pattern: look for "data: <base64>" after "type: olm.bundle.object"
pattern = r'(- type: olm\.bundle\.object\s+value:\s+data: )([A-Za-z0-9+/=]+)'

def convert_match(match):
    global changes_made
    prefix = match.group(1)
    b64_data = match.group(2)

    try:
        # Decode base64
        json_bytes = base64.b64decode(b64_data)
        json_str = json_bytes.decode('utf-8')

        # Parse JSON
        obj = json.loads(json_str)

        # Convert to YAML (without document separator)
        yaml_str = yaml.dump(obj, default_flow_style=False, sort_keys=False, allow_unicode=True)

        # Re-encode as base64
        yaml_bytes = yaml_str.encode('utf-8')
        new_b64_data = base64.b64encode(yaml_bytes).decode('utf-8')

        changes_made += 1
        return prefix + new_b64_data
    except Exception as e:
        print(f"Warning: Failed to convert data block: {e}", file=sys.stderr)
        return match.group(0)  # Return original if conversion fails

# Perform the replacement
new_content = re.sub(pattern, convert_match, content, flags=re.MULTILINE)

# Write back to file
with open(catalog_path, 'w') as f:
    f.write(new_content)

print(f"✅ Converted {changes_made} olm.bundle.object data blocks from JSON to YAML")
sys.exit(0)

PYTHON_SCRIPT

echo "Conversion complete!"
