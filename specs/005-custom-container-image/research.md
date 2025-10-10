# Research: Makefile Variable Composition for Custom Container Image Naming

**Feature**: Custom Container Image Naming
**Date**: 2025-10-10
**Status**: Research Complete

## Overview

This document consolidates research findings on Makefile variable composition patterns, override mechanisms, and the current image reference inventory in the toolhive-operator-metadata repository. The goal is to enable decomposition of hardcoded image references into component variables (registry, organization, name, tag) that can be independently overridden via environment variables or CLI arguments while maintaining backward compatibility.

## Variable Composition Pattern

### Decision

**Use hierarchical variable composition with `?=` for components and `:=` for composites**.

This pattern enables:
- Default values for production builds
- Independent override of any component (registry, org, name, tag)
- Immediate expansion to prevent recursive reference issues
- Clear separation between base components and composite image references

### Pattern Structure

```makefile
# Base component variables (use ?= for conditional assignment)
CATALOG_REGISTRY ?= ghcr.io
CATALOG_ORG ?= stacklok/toolhive
CATALOG_NAME ?= catalog
CATALOG_TAG ?= v0.2.17

# Composite variable (use := for immediate expansion)
CATALOG_IMG := $(CATALOG_REGISTRY)/$(CATALOG_ORG)/$(CATALOG_NAME):$(CATALOG_TAG)
```

### Rationale

**Component Variables (`?=`)**:
- `?=` means "assign only if not already set"
- Allows overrides via environment variables or CLI arguments
- Provides default values for production builds
- Maintains backward compatibility when no overrides specified

**Composite Variables (`:=`)**:
- `:=` performs immediate expansion at definition time
- Prevents deferred expansion issues that could cause unexpected behavior
- Ensures composite values reflect component values at assignment time
- More predictable than recursive expansion (`=`)

**Why NOT `=` (recursive assignment)**:
- Deferred expansion can cause subtle bugs if component values change
- Makes debugging harder (variable value depends on evaluation context)
- Performance overhead from repeated re-evaluation

**Why NOT `+=` (append)**:
- Not applicable for this use case (we're composing, not appending)
- Used for adding to lists, not building image references

### Variable Assignment Operator Reference

| Operator | Name | Timing | Override Behavior | Use Case |
|----------|------|--------|-------------------|----------|
| `?=` | Conditional | Immediate | Set only if undefined | Component defaults |
| `:=` | Simple | Immediate | Always set | Composite values |
| `=` | Recursive | Deferred | Always set | Rarely needed |
| `+=` | Append | Context-dependent | Adds to existing | Lists/paths |

**Source**: [GNU Make Manual - Setting Variables](https://www.gnu.org/software/make/manual/html_node/Setting.html)

### Example Usage

```makefile
# Production build (uses all defaults)
make catalog-build
# Expands to: podman build ... -t ghcr.io/stacklok/toolhive/catalog:v0.2.17

# Override registry only
make catalog-build CATALOG_REGISTRY=quay.io
# Expands to: podman build ... -t quay.io/stacklok/toolhive/catalog:v0.2.17

# Override multiple components
make bundle-build BUNDLE_REGISTRY=quay.io BUNDLE_ORG=myteam BUNDLE_TAG=dev
# Expands to: podman build ... -t quay.io/myteam/bundle:dev

# Full custom image for index
make index-olmv0-build \
  INDEX_REGISTRY=docker.io \
  INDEX_ORG=myuser \
  INDEX_NAME=toolhive-index \
  INDEX_TAG=feature-branch
# Expands to: opm index add --tag docker.io/myuser/toolhive-index:feature-branch
```

---

## Override Mechanism

### Precedence Rules

Make variables follow this precedence order (highest to lowest):

1. **Command-line arguments** (highest precedence)
   ```bash
   make catalog-build CATALOG_REGISTRY=quay.io
   ```

2. **Environment variables**
   ```bash
   export CATALOG_REGISTRY=quay.io
   make catalog-build
   ```

3. **Makefile defaults** (lowest precedence, via `?=`)
   ```makefile
   CATALOG_REGISTRY ?= ghcr.io  # Used only if not set by CLI or env
   ```

**Important**: Command-line arguments override environment variables, which override Makefile defaults. This is standard GNU Make behavior.

### Override Testing Strategy

**Test 1: Default behavior (no overrides)**
```bash
make catalog-build
# Expected: Uses all production defaults
# Verifies: Backward compatibility
```

**Test 2: Single component override (CLI)**
```bash
make catalog-build CATALOG_REGISTRY=quay.io
# Expected: Only registry changes, org/name/tag remain default
# Verifies: Partial override support
```

**Test 3: Multiple component override (CLI)**
```bash
make bundle-build BUNDLE_ORG=myteam BUNDLE_TAG=dev
# Expected: Registry and name use defaults, org and tag use overrides
# Verifies: Independent component control
```

**Test 4: Environment variable override**
```bash
export INDEX_REGISTRY=docker.io
make index-olmv0-build
# Expected: Registry uses env value, others use defaults
# Verifies: Environment variable support
```

**Test 5: CLI precedence over environment**
```bash
export CATALOG_REGISTRY=docker.io
make catalog-build CATALOG_REGISTRY=quay.io
# Expected: Uses quay.io (CLI wins)
# Verifies: Correct precedence order
```

**Test 6: Verify composite expansion**
```bash
make -n catalog-build CATALOG_REGISTRY=quay.io
# Expected: Shows expanded podman command with quay.io
# Verifies: Composite variables expand correctly
```

### Debug Helper Pattern

Add a Makefile target to show effective variable values:

```makefile
.PHONY: show-image-vars
show-image-vars: ## Display effective image variable values
	@echo "Catalog Image Variables:"
	@echo "  CATALOG_REGISTRY = $(CATALOG_REGISTRY)"
	@echo "  CATALOG_ORG      = $(CATALOG_ORG)"
	@echo "  CATALOG_NAME     = $(CATALOG_NAME)"
	@echo "  CATALOG_TAG      = $(CATALOG_TAG)"
	@echo "  CATALOG_IMG      = $(CATALOG_IMG)"
	@echo ""
	@echo "Bundle Image Variables:"
	@echo "  BUNDLE_REGISTRY  = $(BUNDLE_REGISTRY)"
	@echo "  BUNDLE_ORG       = $(BUNDLE_ORG)"
	@echo "  BUNDLE_NAME      = $(BUNDLE_NAME)"
	@echo "  BUNDLE_TAG       = $(BUNDLE_TAG)"
	@echo "  BUNDLE_IMG       = $(BUNDLE_IMG)"
	@echo ""
	@echo "Index Image Variables:"
	@echo "  INDEX_REGISTRY   = $(INDEX_REGISTRY)"
	@echo "  INDEX_ORG        = $(INDEX_ORG)"
	@echo "  INDEX_NAME       = $(INDEX_NAME)"
	@echo "  INDEX_TAG        = $(INDEX_TAG)"
	@echo "  INDEX_OLMV0_IMG  = $(INDEX_OLMV0_IMG)"
```

---

## Image Reference Inventory

### Current Makefile Analysis

**Existing Variables** (lines 7-10):
```makefile
BUNDLE_IMG ?= ghcr.io/stacklok/toolhive/bundle:v0.2.17
INDEX_OLMV0_IMG ?= ghcr.io/stacklok/toolhive/index-olmv0:v0.2.17
OPM_MODE ?= semver
CONTAINER_TOOL ?= podman
```

**Observation**:
- `BUNDLE_IMG` and `INDEX_OLMV0_IMG` already use `?=` (good for overrides)
- BUT: These are monolithic (can't override just registry or tag independently)
- No variable exists for `CATALOG_IMG` (hardcoded in targets)

### Hardcoded Image References

**Catalog Image** (appears 11 times in Makefile):

| Line | Context | Image Reference |
|------|---------|----------------|
| 91 | `catalog-build` target | `ghcr.io/stacklok/toolhive/catalog:v0.2.17` |
| 92 | `catalog-build` target | `ghcr.io/stacklok/toolhive/catalog:v0.2.17` (tag) |
| 93 | `catalog-build` target | `ghcr.io/stacklok/toolhive/catalog:v0.2.17` (echo) |
| 94 | `catalog-build` target | `ghcr.io/stacklok/toolhive/catalog` (images) |
| 99 | `catalog-push` target | `ghcr.io/stacklok/toolhive/catalog:v0.2.17` |
| 100 | `catalog-push` target | `ghcr.io/stacklok/toolhive/catalog:latest` |
| 285 | `clean-images` target | `ghcr.io/stacklok/toolhive/catalog:v0.2.17` |
| 286 | `clean-images` target | `ghcr.io/stacklok/toolhive/catalog:latest` |

**Bundle Image** (appears 13 times, mix of variable and hardcoded):

| Line | Context | Image Reference |
|------|---------|----------------|
| 7 | Variable definition | `BUNDLE_IMG ?= ghcr.io/stacklok/toolhive/bundle:v0.2.17` |
| 114 | `bundle-build` target | `ghcr.io/stacklok/toolhive/bundle:v0.2.17` (hardcoded) |
| 115 | `bundle-build` target | `ghcr.io/stacklok/toolhive/bundle:v0.2.17` (hardcoded tag) |
| 116 | `bundle-build` target | `ghcr.io/stacklok/toolhive/bundle:v0.2.17` (hardcoded echo) |
| 117 | `bundle-build` target | `ghcr.io/stacklok/toolhive/bundle` (hardcoded images) |
| 122 | `bundle-push` target | `ghcr.io/stacklok/toolhive/bundle:v0.2.17` (hardcoded) |
| 123 | `bundle-push` target | `ghcr.io/stacklok/toolhive/bundle:latest` (hardcoded) |
| 161 | `index-olmv0-build` target | Uses `$(BUNDLE_IMG)` (correct - variable) |

**Index Image** (appears 8 times, mix of variable and hardcoded):

| Line | Context | Image Reference |
|------|---------|----------------|
| 8 | Variable definition | `INDEX_OLMV0_IMG ?= ghcr.io/stacklok/toolhive/index-olmv0:v0.2.17` |
| 163 | `index-olmv0-build` target | Uses `$(INDEX_OLMV0_IMG)` (correct - variable) |
| 168 | `index-olmv0-build` target | Uses `$(INDEX_OLMV0_IMG)` (correct - variable) |
| 171 | `index-olmv0-build` target | `ghcr.io/stacklok/toolhive/index-olmv0:latest` (hardcoded) |
| 172 | `index-olmv0-build` target | `ghcr.io/stacklok/toolhive/index-olmv0:latest` (hardcoded echo) |
| 196 | `index-olmv0-push` target | Uses `$(INDEX_OLMV0_IMG)` (correct - variable) |
| 197 | `index-olmv0-push` target | `ghcr.io/stacklok/toolhive/index-olmv0:latest` (hardcoded) |
| 200 | `index-olmv0-push` target | `ghcr.io/stacklok/toolhive/index-olmv0:latest` (hardcoded echo) |
| 221-222 | `index-clean` target | Hardcoded (both v0.2.17 and latest) |
| 287-288 | `clean-images` target | Hardcoded (both v0.2.17 and latest) |

### Required Changes Summary

**1. Add CATALOG_IMG variable** (currently missing):
```makefile
CATALOG_REGISTRY ?= ghcr.io
CATALOG_ORG ?= stacklok/toolhive
CATALOG_NAME ?= catalog
CATALOG_TAG ?= v0.2.17
CATALOG_IMG := $(CATALOG_REGISTRY)/$(CATALOG_ORG)/$(CATALOG_NAME):$(CATALOG_TAG)
```

**2. Refactor BUNDLE_IMG** (change from monolithic to composite):
```makefile
# OLD:
BUNDLE_IMG ?= ghcr.io/stacklok/toolhive/bundle:v0.2.17

# NEW:
BUNDLE_REGISTRY ?= ghcr.io
BUNDLE_ORG ?= stacklok/toolhive
BUNDLE_NAME ?= bundle
BUNDLE_TAG ?= v0.2.17
BUNDLE_IMG := $(BUNDLE_REGISTRY)/$(BUNDLE_ORG)/$(BUNDLE_NAME):$(BUNDLE_TAG)
```

**3. Refactor INDEX_OLMV0_IMG** (change from monolithic to composite):
```makefile
# OLD:
INDEX_OLMV0_IMG ?= ghcr.io/stacklok/toolhive/index-olmv0:v0.2.17

# NEW:
INDEX_REGISTRY ?= ghcr.io
INDEX_ORG ?= stacklok/toolhive
INDEX_NAME ?= index-olmv0
INDEX_TAG ?= v0.2.17
INDEX_OLMV0_IMG := $(INDEX_REGISTRY)/$(INDEX_ORG)/$(INDEX_NAME):$(INDEX_TAG)
```

**4. Replace all hardcoded image references** with variables:
- Catalog targets: Replace hardcoded `ghcr.io/stacklok/toolhive/catalog:*` with `$(CATALOG_IMG)`
- Bundle targets: Replace hardcoded `ghcr.io/stacklok/toolhive/bundle:*` with `$(BUNDLE_IMG)`
- Index targets: Replace hardcoded `ghcr.io/stacklok/toolhive/index-olmv0:*` with `$(INDEX_OLMV0_IMG)`

**5. Handle `:latest` tag references**:
- Add composite variables for latest tags:
  ```makefile
  CATALOG_IMG_LATEST := $(CATALOG_REGISTRY)/$(CATALOG_ORG)/$(CATALOG_NAME):latest
  BUNDLE_IMG_LATEST := $(BUNDLE_REGISTRY)/$(BUNDLE_ORG)/$(BUNDLE_NAME):latest
  INDEX_OLMV0_IMG_LATEST := $(INDEX_REGISTRY)/$(INDEX_ORG)/$(INDEX_NAME):latest
  ```

**6. Update targets** (affected count):
- `catalog-build`: 4 hardcoded references → use `$(CATALOG_IMG)`
- `catalog-push`: 2 hardcoded references → use `$(CATALOG_IMG)` and `$(CATALOG_IMG_LATEST)`
- `bundle-build`: 4 hardcoded references → use `$(BUNDLE_IMG)`
- `bundle-push`: 2 hardcoded references → use `$(BUNDLE_IMG)` and `$(BUNDLE_IMG_LATEST)`
- `index-olmv0-build`: 2 hardcoded `:latest` → use `$(INDEX_OLMV0_IMG_LATEST)`
- `index-olmv0-push`: 2 hardcoded `:latest` → use `$(INDEX_OLMV0_IMG_LATEST)`
- `index-clean`: 2 hardcoded references → use variables
- `clean-images`: 4 hardcoded references → use variables

---

## Testing Strategy

### Backward Compatibility Approach

**Goal**: Verify that existing Makefile invocations produce identical results after refactoring.

**Method**: Capture image references before and after, compare output.

#### Test 1: Default Build Behavior

```bash
# BEFORE refactoring - capture current behavior
make -n catalog-build | grep "podman build" > /tmp/before-catalog.txt
make -n bundle-build | grep "podman build" > /tmp/before-bundle.txt
make -n index-olmv0-build | grep "opm index" > /tmp/before-index.txt

# AFTER refactoring - capture new behavior
make -n catalog-build | grep "podman build" > /tmp/after-catalog.txt
make -n bundle-build | grep "podman build" > /tmp/after-bundle.txt
make -n index-olmv0-build | grep "opm index" > /tmp/after-index.txt

# Compare (should be identical)
diff /tmp/before-catalog.txt /tmp/after-catalog.txt
diff /tmp/before-bundle.txt /tmp/after-bundle.txt
diff /tmp/before-index.txt /tmp/after-index.txt
```

**Expected Result**: All diffs should show zero differences for default builds.

#### Test 2: Existing Variable Override (BUNDLE_IMG)

```bash
# This override should continue to work (backward compatibility)
make -n bundle-build BUNDLE_IMG=custom.io/myimage:tag | grep "podman build"

# After refactoring, we should warn users that component variables are preferred
# but BUNDLE_IMG override should still work OR fail gracefully with clear message
```

**Expected Result**:
- Option A: Override continues to work (full backward compat)
- Option B: Clear error message suggesting component variables instead

**Decision**: Implement Option B with deprecation notice - old variable still works but prints warning.

### Override Validation

#### Test 3: Component Override - Registry Only

```bash
make -n catalog-build CATALOG_REGISTRY=quay.io | grep "podman build"
# Expected output should contain: quay.io/stacklok/toolhive/catalog:v0.2.17
```

#### Test 4: Component Override - Multiple Components

```bash
make -n bundle-build BUNDLE_ORG=myteam BUNDLE_TAG=dev | grep "podman build"
# Expected output should contain: ghcr.io/myteam/bundle:dev
```

#### Test 5: Full Custom Image

```bash
make -n index-olmv0-build \
  INDEX_REGISTRY=docker.io \
  INDEX_ORG=myuser \
  INDEX_NAME=custom-index \
  INDEX_TAG=test \
  | grep "opm index"
# Expected output should contain: --tag docker.io/myuser/custom-index:test
```

#### Test 6: Environment Variable Override

```bash
export CATALOG_REGISTRY=quay.io
make -n catalog-build | grep "podman build"
unset CATALOG_REGISTRY
# Expected output should contain: quay.io/stacklok/toolhive/catalog:v0.2.17
```

#### Test 7: CLI Precedence Over Environment

```bash
export CATALOG_REGISTRY=docker.io
make -n catalog-build CATALOG_REGISTRY=quay.io | grep "podman build"
unset CATALOG_REGISTRY
# Expected output should contain: quay.io (CLI wins over env)
```

### Edge Case Testing

#### Test 8: Empty Component Value

```bash
make -n catalog-build CATALOG_TAG= | grep "podman build"
# Expected: Error or malformed image reference (should fail gracefully)
# Goal: Validate that we don't silently accept invalid values
```

#### Test 9: Component with Spaces

```bash
make -n catalog-build CATALOG_REGISTRY="registry with spaces" | grep "podman build"
# Expected: Build command failure (invalid registry)
# Goal: Ensure no shell injection vulnerabilities
```

#### Test 10: Verify :latest Tag Composition

```bash
make -n catalog-push | grep "podman push"
# Expected output should contain TWO push commands:
#   1. ghcr.io/stacklok/toolhive/catalog:v0.2.17
#   2. ghcr.io/stacklok/toolhive/catalog:latest
```

### Validation Checklist

**Pre-Implementation Baseline**:
- [ ] Capture current `make -n` output for all build targets
- [ ] Document current behavior for `BUNDLE_IMG` override (if any users rely on it)
- [ ] Identify all targets that reference image variables

**Post-Implementation Verification**:
- [ ] All default builds produce identical output (backward compatibility)
- [ ] Component overrides correctly modify image references
- [ ] Environment variable overrides work as expected
- [ ] CLI arguments override environment variables
- [ ] `make show-image-vars` displays correct effective values
- [ ] `:latest` tags compose correctly in push targets
- [ ] Clean targets reference variables (no hardcoded cleanup)

**Edge Case Coverage**:
- [ ] Empty component values handled gracefully (error or warning)
- [ ] Invalid registry formats detected (e.g., with spaces)
- [ ] Multiple simultaneous overrides work independently
- [ ] Partial overrides leave other components at default

---

## Variable Naming Convention

### Pattern Structure

```
{IMAGE_TYPE}_{COMPONENT}
```

Where:
- **IMAGE_TYPE**: `CATALOG`, `BUNDLE`, `INDEX`
- **COMPONENT**: `REGISTRY`, `ORG`, `NAME`, `TAG`
- **Composite**: `{IMAGE_TYPE}_IMG`

### Complete Variable Set

```makefile
# Catalog Image (OLMv1)
CATALOG_REGISTRY ?= ghcr.io
CATALOG_ORG ?= stacklok/toolhive
CATALOG_NAME ?= catalog
CATALOG_TAG ?= v0.2.17
CATALOG_IMG := $(CATALOG_REGISTRY)/$(CATALOG_ORG)/$(CATALOG_NAME):$(CATALOG_TAG)
CATALOG_IMG_LATEST := $(CATALOG_REGISTRY)/$(CATALOG_ORG)/$(CATALOG_NAME):latest

# Bundle Image (OLMv0)
BUNDLE_REGISTRY ?= ghcr.io
BUNDLE_ORG ?= stacklok/toolhive
BUNDLE_NAME ?= bundle
BUNDLE_TAG ?= v0.2.17
BUNDLE_IMG := $(BUNDLE_REGISTRY)/$(BUNDLE_ORG)/$(BUNDLE_NAME):$(BUNDLE_TAG)
BUNDLE_IMG_LATEST := $(BUNDLE_REGISTRY)/$(BUNDLE_ORG)/$(BUNDLE_NAME):latest

# Index Image (OLMv0)
INDEX_REGISTRY ?= ghcr.io
INDEX_ORG ?= stacklok/toolhive
INDEX_NAME ?= index-olmv0
INDEX_TAG ?= v0.2.17
INDEX_OLMV0_IMG := $(INDEX_REGISTRY)/$(INDEX_ORG)/$(INDEX_NAME):$(INDEX_TAG)
INDEX_OLMV0_IMG_LATEST := $(INDEX_REGISTRY)/$(INDEX_ORG)/$(INDEX_NAME):latest

# Utility variables (unchanged)
OPM_MODE ?= semver
CONTAINER_TOOL ?= podman
```

### Naming Rationale

**Consistency**: All variables follow `{TYPE}_{COMPONENT}` pattern
**Clarity**: Variable name reveals both image type and component
**Predictability**: Users can infer variable names without documentation
**Backward Compatible**: Composite variables (`BUNDLE_IMG`, `INDEX_OLMV0_IMG`) preserve existing variable names

---

## Implementation Risks and Mitigation

### Risk 1: Breaking Existing Workflows

**Scenario**: Users or CI systems directly override `BUNDLE_IMG` or `INDEX_OLMV0_IMG`.

**Mitigation**:
1. Preserve composite variables (`BUNDLE_IMG`, `INDEX_OLMV0_IMG`) - they become derived instead of direct assignments
2. Add deprecation warning if monolithic variables are overridden:
   ```makefile
   ifdef BUNDLE_IMG_OVERRIDE_DETECTED
       $(warning "BUNDLE_IMG override detected. Consider using component variables instead:")
       $(warning "  BUNDLE_REGISTRY, BUNDLE_ORG, BUNDLE_NAME, BUNDLE_TAG")
   endif
   ```
3. Document migration path in CLAUDE.md and quickstart.md

### Risk 2: Variable Expansion Complexity

**Scenario**: Composite variables expand incorrectly due to timing issues.

**Mitigation**:
1. Use `:=` (immediate expansion) for all composite variables
2. Test with `make -n` to verify expanded commands
3. Add `show-image-vars` debug target for troubleshooting

### Risk 3: Inconsistent Tag References

**Scenario**: `:latest` tags don't update when version tag changes.

**Mitigation**:
1. Always derive `:latest` from same components (just different TAG value)
2. Use separate `*_IMG_LATEST` variables for clarity
3. Update both versioned and latest tags in push targets

### Risk 4: Empty or Invalid Component Values

**Scenario**: User provides empty string or invalid value for component.

**Mitigation**:
1. Document expected value formats in quickstart.md
2. Consider adding validation in build targets (optional):
   ```makefile
   catalog-build:
       @test -n "$(CATALOG_REGISTRY)" || (echo "Error: CATALOG_REGISTRY cannot be empty"; exit 1)
       @test -n "$(CATALOG_TAG)" || (echo "Error: CATALOG_TAG cannot be empty"; exit 1)
       # ... actual build commands
   ```

---

## References

### GNU Make Documentation
- [Variable Assignment Operators](https://www.gnu.org/software/make/manual/html_node/Setting.html)
- [Flavors of Variables](https://www.gnu.org/software/make/manual/html_node/Flavors.html)
- [Overriding Variables](https://www.gnu.org/software/make/manual/html_node/Overriding.html)

### Repository Context
- Current Makefile: [/wip/src/github.com/RHEcosystemAppEng/toolhive-operator-metadata/Makefile](/wip/src/github.com/RHEcosystemAppEng/toolhive-operator-metadata/Makefile)
- Feature specification: [specs/005-custom-container-image/spec.md](/wip/src/github.com/RHEcosystemAppEng/toolhive-operator-metadata/specs/005-custom-container-image/spec.md)
- Implementation plan: [specs/005-custom-container-image/plan.md](/wip/src/github.com/RHEcosystemAppEng/toolhive-operator-metadata/specs/005-custom-container-image/plan.md)

### Similar Patterns in Other Projects
- Kubernetes Makefile patterns (component-based image naming)
- Docker Compose environment variable substitution
- CI/CD matrix builds with parameterized image references

---

## Next Steps

Proceed to **Phase 1: Design & Contracts** to:
1. Define data model for container image reference structure (`data-model.md`)
2. Create variable contract specification (`contracts/makefile-variables.md`)
3. Define override precedence rules (`contracts/override-precedence.md`)
4. Generate quickstart guide for developers (`quickstart.md`)

The research findings support the technical approach outlined in plan.md and provide concrete patterns for implementation.
