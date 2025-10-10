# Makefile Variables Contract: Custom Container Image Naming

**Feature**: Custom Container Image Naming
**Date**: 2025-10-10
**Status**: Contract Definition
**Related**: [spec.md](../spec.md), [research.md](../research.md), [plan.md](../plan.md)

## Overview

This document defines the variable naming standard, composition rules, validation requirements, and backward compatibility constraints for the custom container image naming feature. All Makefile modifications must adhere to these contracts to ensure consistency, maintainability, and predictable behavior.

## Variable Naming Standard

### Naming Pattern

All image component variables follow this structure:

```
{IMAGE_TYPE}_{COMPONENT}
```

Where:
- **IMAGE_TYPE**: One of `CATALOG`, `BUNDLE`, `INDEX`
- **COMPONENT**: One of `REGISTRY`, `ORG`, `NAME`, `TAG`
- **Composite**: `{IMAGE_TYPE}_IMG` or `{IMAGE_TYPE}_IMG_LATEST`

### Variable Name Examples

```makefile
# Component variables (user-overridable)
CATALOG_REGISTRY    # Catalog image registry hostname
CATALOG_ORG         # Catalog image organization/path
CATALOG_NAME        # Catalog image name
CATALOG_TAG         # Catalog image version tag

BUNDLE_REGISTRY     # Bundle image registry hostname
BUNDLE_ORG          # Bundle image organization/path
BUNDLE_NAME         # Bundle image name
BUNDLE_TAG          # Bundle image version tag

INDEX_REGISTRY      # Index image registry hostname
INDEX_ORG           # Index image organization/path
INDEX_NAME          # Index image name
INDEX_TAG           # Index image version tag

# Composite variables (computed from components)
CATALOG_IMG         # Full catalog image reference
BUNDLE_IMG          # Full bundle image reference
INDEX_OLMV0_IMG     # Full index image reference

# Latest tag variants
CATALOG_IMG_LATEST     # Catalog image with :latest tag
BUNDLE_IMG_LATEST      # Bundle image with :latest tag
INDEX_OLMV0_IMG_LATEST # Index image with :latest tag
```

### Rationale

**Consistency**: Uniform naming makes variables predictable and self-documenting.
**Clarity**: The pattern clearly indicates both image type and component being configured.
**Discoverability**: Users can infer variable names without documentation (e.g., "I want to override the bundle registry → BUNDLE_REGISTRY").
**Backward Compatible**: Existing composite variables (`BUNDLE_IMG`, `INDEX_OLMV0_IMG`) preserve their names.

## Complete Variable Definitions

### Catalog Image Variables (OLMv1)

```makefile
# Component variables with production defaults
CATALOG_REGISTRY ?= ghcr.io
CATALOG_ORG ?= stacklok/toolhive
CATALOG_NAME ?= catalog
CATALOG_TAG ?= v0.2.17

# Composite variables (immediate expansion)
CATALOG_IMG := $(CATALOG_REGISTRY)/$(CATALOG_ORG)/$(CATALOG_NAME):$(CATALOG_TAG)
CATALOG_IMG_LATEST := $(CATALOG_REGISTRY)/$(CATALOG_ORG)/$(CATALOG_NAME):latest
```

**Production Default**: `ghcr.io/stacklok/toolhive/catalog:v0.2.17`

### Bundle Image Variables (OLMv0)

```makefile
# Component variables with production defaults
BUNDLE_REGISTRY ?= ghcr.io
BUNDLE_ORG ?= stacklok/toolhive
BUNDLE_NAME ?= bundle
BUNDLE_TAG ?= v0.2.17

# Composite variables (immediate expansion)
BUNDLE_IMG := $(BUNDLE_REGISTRY)/$(BUNDLE_ORG)/$(BUNDLE_NAME):$(BUNDLE_TAG)
BUNDLE_IMG_LATEST := $(BUNDLE_REGISTRY)/$(BUNDLE_ORG)/$(BUNDLE_NAME):latest
```

**Production Default**: `ghcr.io/stacklok/toolhive/bundle:v0.2.17`

### Index Image Variables (OLMv0)

```makefile
# Component variables with production defaults
INDEX_REGISTRY ?= ghcr.io
INDEX_ORG ?= stacklok/toolhive
INDEX_NAME ?= index-olmv0
INDEX_TAG ?= v0.2.17

# Composite variables (immediate expansion)
INDEX_OLMV0_IMG := $(INDEX_REGISTRY)/$(INDEX_ORG)/$(INDEX_NAME):$(INDEX_TAG)
INDEX_OLMV0_IMG_LATEST := $(INDEX_REGISTRY)/$(INDEX_ORG)/$(INDEX_NAME):latest
```

**Production Default**: `ghcr.io/stacklok/toolhive/index-olmv0:v0.2.17`

## Validation Rules

### 1. Assignment Operator Requirements

**RULE**: Component variables MUST use `?=` (conditional assignment).

**Rationale**: The `?=` operator assigns only if the variable is not already set, enabling overrides via environment variables or command-line arguments while providing defaults.

**Example - Correct**:
```makefile
CATALOG_REGISTRY ?= ghcr.io  # ✓ Correct - can be overridden
```

**Example - Incorrect**:
```makefile
CATALOG_REGISTRY = ghcr.io   # ✗ Wrong - always assigns, breaks overrides
CATALOG_REGISTRY := ghcr.io  # ✗ Wrong - immediate assignment, breaks overrides
```

---

**RULE**: Composite variables MUST use `:=` (immediate expansion).

**Rationale**: The `:=` operator performs immediate expansion at definition time, preventing deferred expansion issues that could cause unexpected behavior if component values change later.

**Example - Correct**:
```makefile
CATALOG_IMG := $(CATALOG_REGISTRY)/$(CATALOG_ORG)/$(CATALOG_NAME):$(CATALOG_TAG)  # ✓ Correct
```

**Example - Incorrect**:
```makefile
CATALOG_IMG = $(CATALOG_REGISTRY)/$(CATALOG_ORG)/$(CATALOG_NAME):$(CATALOG_TAG)   # ✗ Wrong - deferred expansion
CATALOG_IMG ?= $(CATALOG_REGISTRY)/$(CATALOG_ORG)/$(CATALOG_NAME):$(CATALOG_TAG) # ✗ Wrong - defeats composition
```

### 2. Default Value Requirements

**RULE**: All component variables MUST have production default values.

**Rationale**: Default values ensure backward compatibility - existing workflows continue to work without any configuration changes.

**Example - Correct**:
```makefile
BUNDLE_REGISTRY ?= ghcr.io              # ✓ Has default
BUNDLE_ORG ?= stacklok/toolhive         # ✓ Has default
BUNDLE_NAME ?= bundle                   # ✓ Has default
BUNDLE_TAG ?= v0.2.17                   # ✓ Has default
```

**Example - Incorrect**:
```makefile
BUNDLE_REGISTRY ?=                      # ✗ Wrong - empty default
BUNDLE_ORG ?=                           # ✗ Wrong - empty default
```

### 3. Variable Ordering Requirements

**RULE**: Component variables MUST be defined before composite variables.

**Rationale**: Immediate expansion (`:=`) requires that all referenced variables are already defined.

**Example - Correct**:
```makefile
# Component variables first
CATALOG_REGISTRY ?= ghcr.io
CATALOG_ORG ?= stacklok/toolhive
CATALOG_NAME ?= catalog
CATALOG_TAG ?= v0.2.17

# Composite variables after
CATALOG_IMG := $(CATALOG_REGISTRY)/$(CATALOG_ORG)/$(CATALOG_NAME):$(CATALOG_TAG)
```

**Example - Incorrect**:
```makefile
# ✗ Wrong - composite defined before components
CATALOG_IMG := $(CATALOG_REGISTRY)/$(CATALOG_ORG)/$(CATALOG_NAME):$(CATALOG_TAG)

CATALOG_REGISTRY ?= ghcr.io
CATALOG_ORG ?= stacklok/toolhive
CATALOG_NAME ?= catalog
CATALOG_TAG ?= v0.2.17
```

### 4. Latest Tag Composition

**RULE**: Latest tag variants MUST use the same component variables as versioned composites, only changing the tag to `latest`.

**Rationale**: Ensures consistency between versioned and latest images - they differ only by tag, not by registry/org/name.

**Example - Correct**:
```makefile
CATALOG_IMG := $(CATALOG_REGISTRY)/$(CATALOG_ORG)/$(CATALOG_NAME):$(CATALOG_TAG)
CATALOG_IMG_LATEST := $(CATALOG_REGISTRY)/$(CATALOG_ORG)/$(CATALOG_NAME):latest  # ✓ Uses same components
```

**Example - Incorrect**:
```makefile
CATALOG_IMG := $(CATALOG_REGISTRY)/$(CATALOG_ORG)/$(CATALOG_NAME):$(CATALOG_TAG)
CATALOG_IMG_LATEST := ghcr.io/stacklok/toolhive/catalog:latest  # ✗ Wrong - hardcoded, doesn't respect overrides
```

## Backward Compatibility Requirements

### Preservation of Existing Variables

**REQUIREMENT**: The variables `BUNDLE_IMG` and `INDEX_OLMV0_IMG` MUST continue to exist and function identically to the previous implementation when no overrides are specified.

**Before Refactoring**:
```makefile
BUNDLE_IMG ?= ghcr.io/stacklok/toolhive/bundle:v0.2.17
INDEX_OLMV0_IMG ?= ghcr.io/stacklok/toolhive/index-olmv0:v0.2.17
```

**After Refactoring**:
```makefile
# Component variables
BUNDLE_REGISTRY ?= ghcr.io
BUNDLE_ORG ?= stacklok/toolhive
BUNDLE_NAME ?= bundle
BUNDLE_TAG ?= v0.2.17

INDEX_REGISTRY ?= ghcr.io
INDEX_ORG ?= stacklok/toolhive
INDEX_NAME ?= index-olmv0
INDEX_TAG ?= v0.2.17

# Composite variables (SAME NAMES as before)
BUNDLE_IMG := $(BUNDLE_REGISTRY)/$(BUNDLE_ORG)/$(BUNDLE_NAME):$(BUNDLE_TAG)
INDEX_OLMV0_IMG := $(INDEX_REGISTRY)/$(INDEX_ORG)/$(INDEX_NAME):$(INDEX_TAG)
```

**Verification**:
```bash
# These commands must produce identical results before and after refactoring
make -n bundle-build
make -n index-olmv0-build
```

### Preservation of Existing Targets

**REQUIREMENT**: All existing Makefile targets MUST continue to work unchanged when invoked with no override variables.

Affected targets:
- `catalog-build`, `catalog-push`, `catalog-validate`
- `bundle-build`, `bundle-push`, `bundle-validate`
- `index-olmv0-build`, `index-olmv0-push`, `index-olmv0-validate`
- `index-clean`, `clean-images`

**Test Matrix**:
```bash
# All of these must work exactly as before
make catalog-build
make catalog-push
make bundle-build
make bundle-push
make index-olmv0-build
make index-olmv0-push
make clean-images
```

### No Breaking Changes to Default Values

**REQUIREMENT**: Production default values MUST remain unchanged from current hardcoded values.

**Current Hardcoded Values** (MUST be preserved):
- Catalog: `ghcr.io/stacklok/toolhive/catalog:v0.2.17`
- Bundle: `ghcr.io/stacklok/toolhive/bundle:v0.2.17`
- Index: `ghcr.io/stacklok/toolhive/index-olmv0:v0.2.17`

**Verification**:
```bash
# These should output the production defaults
make show-image-vars | grep CATALOG_IMG
make show-image-vars | grep BUNDLE_IMG
make show-image-vars | grep INDEX_OLMV0_IMG
```

## Code Examples

### Example 1: Using Production Defaults

```bash
# No overrides - uses all defaults
make catalog-build
# Expands to: podman build -f catalog.Dockerfile -t ghcr.io/stacklok/toolhive/catalog:v0.2.17 .
```

**Verification**: Output image reference matches production default exactly.

### Example 2: Override Registry Only

```bash
# Override registry, keep org/name/tag as defaults
make catalog-build CATALOG_REGISTRY=quay.io
# Expands to: podman build -f catalog.Dockerfile -t quay.io/stacklok/toolhive/catalog:v0.2.17 .
```

**Verification**: Only the registry component changes in the output.

### Example 3: Override Multiple Components

```bash
# Override registry and organization, keep name/tag as defaults
make bundle-build BUNDLE_REGISTRY=quay.io BUNDLE_ORG=myteam
# Expands to: podman build -f bundle.Dockerfile -t quay.io/myteam/bundle:v0.2.17 .
```

**Verification**: Both specified components change, others remain default.

### Example 4: Full Custom Image Reference

```bash
# Override all components
make index-olmv0-build \
  INDEX_REGISTRY=docker.io \
  INDEX_ORG=myuser \
  INDEX_NAME=custom-index \
  INDEX_TAG=feature-auth
# Expands to: opm index add --bundles ... --tag docker.io/myuser/custom-index:feature-auth
```

**Verification**: All components reflect the override values.

### Example 5: Environment Variable Override

```bash
# Set via environment variable
export CATALOG_REGISTRY=quay.io
make catalog-build
# Expands to: podman build -f catalog.Dockerfile -t quay.io/stacklok/toolhive/catalog:v0.2.17 .

# Clean up
unset CATALOG_REGISTRY
```

**Verification**: Environment variable override takes effect.

### Example 6: Verify Effective Values (Debug Helper)

```bash
# Show what values will be used (without building)
make show-image-vars

# Output:
# Catalog Image Variables:
#   CATALOG_REGISTRY = ghcr.io
#   CATALOG_ORG      = stacklok/toolhive
#   CATALOG_NAME     = catalog
#   CATALOG_TAG      = v0.2.17
#   CATALOG_IMG      = ghcr.io/stacklok/toolhive/catalog:v0.2.17
#
# Bundle Image Variables:
#   BUNDLE_REGISTRY  = ghcr.io
#   BUNDLE_ORG       = stacklok/toolhive
#   BUNDLE_NAME      = bundle
#   BUNDLE_TAG       = v0.2.17
#   BUNDLE_IMG       = ghcr.io/stacklok/toolhive/bundle:v0.2.17
#
# Index Image Variables:
#   INDEX_REGISTRY   = ghcr.io
#   INDEX_ORG        = stacklok/toolhive
#   INDEX_NAME       = index-olmv0
#   INDEX_TAG        = v0.2.17
#   INDEX_OLMV0_IMG  = ghcr.io/stacklok/toolhive/index-olmv0:v0.2.17
```

**Verification**: Helper target displays all effective variable values for debugging.

## Contract Compliance Checklist

Implementation MUST satisfy all of these criteria:

- [ ] All component variables use `?=` operator
- [ ] All composite variables use `:=` operator
- [ ] All component variables have production default values
- [ ] Component variables are defined before composite variables
- [ ] Latest tag variants use `latest` literal, not `$(TAG)`
- [ ] Variable names follow `{IMAGE_TYPE}_{COMPONENT}` pattern
- [ ] `BUNDLE_IMG` and `INDEX_OLMV0_IMG` variables preserved
- [ ] All existing Makefile targets work with defaults (zero regression)
- [ ] Production default values match current hardcoded values exactly
- [ ] `show-image-vars` debug helper target exists
- [ ] All 15 variables defined (12 components + 3 composites for versioned images)
- [ ] All 3 latest tag variants defined (6 additional composite variables)

## References

- Feature Specification: [spec.md](../spec.md)
- Research Findings: [research.md](../research.md) - Variable composition patterns and operator reference
- Implementation Plan: [plan.md](../plan.md) - Phase 1 design artifacts
- Override Precedence Contract: [override-precedence.md](./override-precedence.md)
- GNU Make Manual: [Variable Assignment Operators](https://www.gnu.org/software/make/manual/html_node/Setting.html)

---

**Contract Version**: 1.0
**Last Updated**: 2025-10-10
**Compliance**: REQUIRED for all Makefile modifications in feature 005-custom-container-image
