#!/usr/bin/env bash
# Example workflow demonstrating icon customization for OLM bundles and catalogs
#
# This script shows how to:
# 1. Validate a custom icon
# 2. Build a bundle with a custom icon
# 3. Build a catalog (inheriting or with separate icon)
# 4. Verify the icon was injected correctly

set -euo pipefail

# Configuration
EXAMPLE_ICON="${1:-icons/default-icon.svg}"
CATALOG_ICON="${2:-}"  # Optional separate catalog icon

echo "=== Icon Customization Workflow Example ==="
echo ""
echo "Bundle Icon: $EXAMPLE_ICON"
if [ -n "$CATALOG_ICON" ]; then
  echo "Catalog Icon: $CATALOG_ICON (separate)"
else
  echo "Catalog Icon: Inherited from bundle"
fi
echo ""

# Step 1: Check dependencies
echo "Step 1: Checking dependencies..."
make check-icon-deps
echo ""

# Step 2: Validate the icon
echo "Step 2: Validating icon..."
make validate-icon ICON_FILE="$EXAMPLE_ICON"
echo ""

# Step 3: Build bundle with custom icon
echo "Step 3: Building bundle with custom icon..."
make bundle BUNDLE_ICON="$EXAMPLE_ICON"
echo ""

# Step 4: Build catalog (with or without separate icon)
echo "Step 4: Building catalog..."
if [ -n "$CATALOG_ICON" ]; then
  echo "Using separate catalog icon: $CATALOG_ICON"
  make catalog CATALOG_ICON="$CATALOG_ICON"
else
  echo "Catalog will inherit icon from bundle"
  make catalog
fi
echo ""

# Step 5: Verify icon injection
echo "Step 5: Verifying icon injection..."
echo ""

echo "Bundle CSV icon mediatype:"
yq eval '.spec.icon[0].mediatype' bundle/manifests/toolhive-operator.clusterserviceversion.yaml
echo ""

echo "Catalog package icon mediatype:"
yq eval 'select(.schema == "olm.package") | .icon.mediatype' catalog/toolhive-operator/catalog.yaml
echo ""

echo "Bundle CSV icon size (base64 characters):"
yq eval '.spec.icon[0].base64data | length' bundle/manifests/toolhive-operator.clusterserviceversion.yaml
echo ""

echo "=== Workflow Complete ==="
echo ""
echo "Next steps:"
echo "  1. Build catalog image: make catalog-build"
echo "  2. Test locally: make catalog-test-local"
echo "  3. Push to registry: make catalog-push"
echo ""
