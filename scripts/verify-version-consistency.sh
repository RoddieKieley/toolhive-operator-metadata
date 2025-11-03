#!/usr/bin/env bash
# Verify all version references are consistent across the repository
#
# Usage: verify-version-consistency.sh [expected-version]
# Example: verify-version-consistency.sh v0.4.2

set -e

EXPECTED_VERSION="${1}"
EXIT_CODE=0

# Auto-detect expected version from Makefile if not provided
if [ -z "$EXPECTED_VERSION" ]; then
    EXPECTED_VERSION=$(grep "^OPERATOR_TAG" Makefile | grep -oP 'v\d+\.\d+\.\d+' | head -1)
    if [ -z "$EXPECTED_VERSION" ]; then
        echo "❌ Could not detect version from Makefile"
        exit 1
    fi
    echo "Auto-detected expected version: $EXPECTED_VERSION"
fi

echo "========================================"
echo "Version Consistency Verification"
echo "========================================"
echo "Expected Version: $EXPECTED_VERSION"
echo ""

# Function to check version match
check_version() {
    local description="$1"
    local found_version="$2"
    local expected="$3"

    if [ "$found_version" = "$expected" ]; then
        echo "✅ $description: $found_version"
    else
        echo "❌ $description: $found_version (expected: $expected)"
        EXIT_CODE=1
    fi
}

# Function to check unique versions in a result
check_unique_version() {
    local description="$1"
    local versions="$2"
    local expected="$3"
    local count=$(echo "$versions" | sort -u | wc -l)

    if [ "$count" -eq 1 ] && [ "$versions" = "$expected" ]; then
        echo "✅ $description: $versions"
    elif [ "$count" -eq 0 ]; then
        echo "❌ $description: No version found"
        EXIT_CODE=1
    elif [ "$count" -gt 1 ]; then
        echo "❌ $description: Multiple versions found:"
        echo "$versions" | sort -u | sed 's/^/     /'
        EXIT_CODE=1
    else
        echo "❌ $description: $versions (expected: $expected)"
        EXIT_CODE=1
    fi
}

echo "Checking Makefile..."
echo "--------------------"

# Check all version variables in Makefile
OPERATOR_TAG=$(grep "^OPERATOR_TAG" Makefile | grep -oP 'v\d+\.\d+\.\d+' | head -1)
check_version "  OPERATOR_TAG" "$OPERATOR_TAG" "$EXPECTED_VERSION"

BUNDLE_TAG=$(grep "^BUNDLE_TAG" Makefile | grep -oP 'v\d+\.\d+\.\d+' | head -1)
check_version "  BUNDLE_TAG" "$BUNDLE_TAG" "$EXPECTED_VERSION"

CATALOG_TAG=$(grep "^CATALOG_TAG" Makefile | grep -oP 'v\d+\.\d+\.\d+' | head -1)
check_version "  CATALOG_TAG" "$CATALOG_TAG" "$EXPECTED_VERSION"

INDEX_TAG=$(grep "^INDEX_TAG" Makefile | grep -oP 'v\d+\.\d+\.\d+' | head -1)
check_version "  INDEX_TAG" "$INDEX_TAG" "$EXPECTED_VERSION"

echo ""
echo "Checking config/manager/manager.yaml..."
echo "----------------------------------------"

# Check operator image version
MANAGER_OPERATOR_VERSION=$(grep "ghcr.io/stacklok/toolhive/operator:" config/manager/manager.yaml | grep -oP 'v\d+\.\d+\.\d+' | head -1)
check_version "  Operator Image" "$MANAGER_OPERATOR_VERSION" "$EXPECTED_VERSION"

# Check proxyrunner image version
MANAGER_PROXY_VERSION=$(grep "ghcr.io/stacklok/toolhive/proxyrunner:" config/manager/manager.yaml | grep -oP 'v\d+\.\d+\.\d+' | head -1)
check_version "  Proxyrunner Image" "$MANAGER_PROXY_VERSION" "$EXPECTED_VERSION"

echo ""
echo "Checking config/base/params.env..."
echo "-----------------------------------"

# Check params.env versions
PARAMS_OPERATOR=$(grep "toolhive-operator-image=" config/base/params.env | grep -oP 'v\d+\.\d+\.\d+')
check_version "  toolhive-operator-image" "$PARAMS_OPERATOR" "$EXPECTED_VERSION"

PARAMS_PROXY=$(grep "toolhive-proxy-image=" config/base/params.env | grep -oP 'v\d+\.\d+\.\d+')
check_version "  toolhive-proxy-image" "$PARAMS_PROXY" "$EXPECTED_VERSION"

echo ""
echo "Checking generated bundle (if exists)..."
echo "-----------------------------------------"

if [ -f "bundle/manifests/toolhive-operator.clusterserviceversion.yaml" ]; then
    # Check CSV version
    CSV_VERSION=$(yq eval '.spec.version' bundle/manifests/toolhive-operator.clusterserviceversion.yaml 2>/dev/null || echo "")
    if [ -n "$CSV_VERSION" ]; then
        # CSV version doesn't have 'v' prefix
        EXPECTED_CSV_VERSION="${EXPECTED_VERSION#v}"
        check_version "  CSV spec.version" "$CSV_VERSION" "$EXPECTED_CSV_VERSION"
    fi

    # Check CSV name
    CSV_NAME=$(yq eval '.metadata.name' bundle/manifests/toolhive-operator.clusterserviceversion.yaml 2>/dev/null || echo "")
    if [ -n "$CSV_NAME" ]; then
        EXPECTED_CSV_NAME="toolhive-operator.${EXPECTED_VERSION}"
        check_version "  CSV metadata.name" "$CSV_NAME" "$EXPECTED_CSV_NAME"
    fi

    # Check operator image in CSV deployment
    CSV_OPERATOR_IMAGE=$(yq eval '.spec.install.spec.deployments[0].spec.template.spec.containers[0].image' \
        bundle/manifests/toolhive-operator.clusterserviceversion.yaml 2>/dev/null | grep -oP 'v\d+\.\d+\.\d+' || echo "")
    if [ -n "$CSV_OPERATOR_IMAGE" ]; then
        check_version "  CSV Operator Image" "$CSV_OPERATOR_IMAGE" "$EXPECTED_VERSION"
    fi

    # Check TOOLHIVE_RUNNER_IMAGE env var in CSV
    CSV_RUNNER_IMAGE=$(yq eval '.spec.install.spec.deployments[0].spec.template.spec.containers[0].env[] | select(.name == "TOOLHIVE_RUNNER_IMAGE") | .value' \
        bundle/manifests/toolhive-operator.clusterserviceversion.yaml 2>/dev/null | grep -oP 'v\d+\.\d+\.\d+' || echo "")
    if [ -n "$CSV_RUNNER_IMAGE" ]; then
        check_version "  CSV TOOLHIVE_RUNNER_IMAGE" "$CSV_RUNNER_IMAGE" "$EXPECTED_VERSION"
    fi
else
    echo "  ⚠️  Bundle not generated yet (run 'make bundle')"
fi

echo ""
echo "Checking Image Base URLs..."
echo "----------------------------"

# Define expected base URLs for production registry
EXPECTED_BUNDLE_BASE="ghcr.io/stacklok/toolhive/operator-bundle"
EXPECTED_CATALOG_BASE="ghcr.io/stacklok/toolhive/operator-catalog"
EXPECTED_INDEX_BASE="ghcr.io/stacklok/toolhive/operator-index"

# Function to check image base URL
check_image_base() {
    local description="$1"
    local image_url="$2"
    local expected_base="$3"

    # Extract base URL (everything before the tag)
    local image_base=$(echo "$image_url" | sed 's/:v\?[0-9]\+\.[0-9]\+\.[0-9]\+$//' | sed 's/:latest$//')

    if [ "$image_base" = "$expected_base" ]; then
        echo "✅ $description: $image_base"
    else
        echo "❌ $description: $image_base (expected: $expected_base)"
        EXIT_CODE=1
    fi
}

# Check Makefile image base URLs
BUNDLE_IMG_BASE=$(grep "^BUNDLE_REGISTRY\|^BUNDLE_ORG\|^BUNDLE_NAME" Makefile | grep -v "^#" | cut -d'=' -f2 | sed 's/[? ]//g')
BUNDLE_REGISTRY=$(echo "$BUNDLE_IMG_BASE" | sed -n '1p')
BUNDLE_ORG=$(echo "$BUNDLE_IMG_BASE" | sed -n '2p')
BUNDLE_NAME=$(echo "$BUNDLE_IMG_BASE" | sed -n '3p')
if [ -n "$BUNDLE_REGISTRY" ] && [ -n "$BUNDLE_ORG" ] && [ -n "$BUNDLE_NAME" ]; then
    BUNDLE_FULL="$BUNDLE_REGISTRY/$BUNDLE_ORG/$BUNDLE_NAME"
    check_image_base "  Bundle Base URL (Makefile)" "$BUNDLE_FULL" "$EXPECTED_BUNDLE_BASE"
fi

CATALOG_IMG_BASE=$(grep "^CATALOG_REGISTRY\|^CATALOG_ORG\|^CATALOG_NAME" Makefile | grep -v "^#" | cut -d'=' -f2 | sed 's/[? ]//g')
CATALOG_REGISTRY=$(echo "$CATALOG_IMG_BASE" | sed -n '1p')
CATALOG_ORG=$(echo "$CATALOG_IMG_BASE" | sed -n '2p')
CATALOG_NAME=$(echo "$CATALOG_IMG_BASE" | sed -n '3p')
if [ -n "$CATALOG_REGISTRY" ] && [ -n "$CATALOG_ORG" ] && [ -n "$CATALOG_NAME" ]; then
    CATALOG_FULL="$CATALOG_REGISTRY/$CATALOG_ORG/$CATALOG_NAME"
    check_image_base "  Catalog Base URL (Makefile)" "$CATALOG_FULL" "$EXPECTED_CATALOG_BASE"
fi

INDEX_IMG_BASE=$(grep "^INDEX_REGISTRY\|^INDEX_ORG\|^INDEX_NAME" Makefile | grep -v "^#" | cut -d'=' -f2 | sed 's/[? ]//g')
INDEX_REGISTRY=$(echo "$INDEX_IMG_BASE" | sed -n '1p')
INDEX_ORG=$(echo "$INDEX_IMG_BASE" | sed -n '2p')
INDEX_NAME=$(echo "$INDEX_IMG_BASE" | sed -n '3p')
if [ -n "$INDEX_REGISTRY" ] && [ -n "$INDEX_ORG" ] && [ -n "$INDEX_NAME" ]; then
    INDEX_FULL="$INDEX_REGISTRY/$INDEX_ORG/$INDEX_NAME"
    check_image_base "  Index Base URL (Makefile)" "$INDEX_FULL" "$EXPECTED_INDEX_BASE"
fi

# Check bundle CSV containerImage if bundle exists
if [ -f "bundle/manifests/toolhive-operator.clusterserviceversion.yaml" ]; then
    CSV_CONTAINER_IMAGE=$(yq eval '.spec.relatedImages[] | select(.name == "toolhive-operator-bundle") | .image' \
        bundle/manifests/toolhive-operator.clusterserviceversion.yaml 2>/dev/null || echo "")

    # If not found in relatedImages, check annotations
    if [ -z "$CSV_CONTAINER_IMAGE" ]; then
        CSV_CONTAINER_IMAGE=$(yq eval '.metadata.annotations."containerImage"' \
            bundle/manifests/toolhive-operator.clusterserviceversion.yaml 2>/dev/null || echo "")
    fi

    if [ -n "$CSV_CONTAINER_IMAGE" ] && [ "$CSV_CONTAINER_IMAGE" != "null" ]; then
        # For bundle CSV, we expect operator image not bundle image
        # Skip this check as containerImage refers to the operator, not the bundle
        : # no-op
    fi
fi

echo ""
echo "========================================"
if [ $EXIT_CODE -eq 0 ]; then
    echo "✅ All version references are consistent"
    echo "✅ All image base URLs are correct"
    echo "========================================"
else
    echo "❌ Version inconsistencies or incorrect image URLs found"
    echo "========================================"
    echo ""
    echo "To fix version inconsistencies, run:"
    echo "  make upgrade VERSION=$EXPECTED_VERSION"
    echo ""
    echo "To fix image URLs, update the following in Makefile:"
    echo "  BUNDLE_REGISTRY = ghcr.io"
    echo "  BUNDLE_ORG = stacklok/toolhive"
    echo "  BUNDLE_NAME = operator-bundle"
    echo ""
    echo "  CATALOG_REGISTRY = ghcr.io"
    echo "  CATALOG_ORG = stacklok/toolhive"
    echo "  CATALOG_NAME = operator-catalog"
    echo ""
    echo "  INDEX_REGISTRY = ghcr.io"
    echo "  INDEX_ORG = stacklok/toolhive"
    echo "  INDEX_NAME = operator-index"
    echo ""
fi
echo ""

exit $EXIT_CODE
