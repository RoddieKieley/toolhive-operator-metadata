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
echo "========================================"
if [ $EXIT_CODE -eq 0 ]; then
    echo "✅ All version references are consistent"
    echo "========================================"
else
    echo "❌ Version inconsistencies found"
    echo "========================================"
    echo ""
    echo "To fix inconsistencies, run:"
    echo "  make upgrade VERSION=$EXPECTED_VERSION"
    echo ""
    echo "Or manually update the files listed above."
fi
echo ""

exit $EXIT_CODE
