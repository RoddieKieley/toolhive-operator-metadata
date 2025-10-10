# Override Precedence Contract: Custom Container Image Naming

**Feature**: Custom Container Image Naming
**Date**: 2025-10-10
**Status**: Contract Definition
**Related**: [spec.md](../spec.md), [research.md](../research.md), [plan.md](../plan.md)

## Overview

This document defines the override mechanism, precedence rules, and expected behavior when developers customize container image naming components via environment variables or command-line arguments. All Makefile modifications must adhere to these contracts to ensure predictable, consistent override behavior.

## Override Mechanisms

The custom container image naming feature supports three sources for variable values, listed from lowest to highest precedence:

### 1. Makefile Defaults (Lowest Precedence)

**Mechanism**: Conditional assignment operator (`?=`) in Makefile.

**Behavior**: Variable is assigned the default value ONLY if it has not been set by a higher-precedence source.

**Example**:
```makefile
CATALOG_REGISTRY ?= ghcr.io
```

**When Used**: Always provides a fallback when no override is specified.

**Override Capability**: Can be overridden by environment variables or CLI arguments.

---

### 2. Environment Variables (Medium Precedence)

**Mechanism**: Shell environment variables set before invoking `make`.

**Behavior**: Environment variables override Makefile defaults but are themselves overridden by CLI arguments.

**Example**:
```bash
export CATALOG_REGISTRY=quay.io
make catalog-build
```

**When Used**: Suitable for:
- Session-wide configuration (developer's preferred registry for multiple builds)
- CI/CD pipeline configuration (set once, applies to all make invocations)
- Default overrides without modifying Makefile or adding CLI arguments

**Override Capability**: Can override Makefile defaults; is overridden by CLI arguments.

---

### 3. Command-Line Arguments (Highest Precedence)

**Mechanism**: Variable assignment on the `make` command line.

**Behavior**: CLI arguments always win, overriding both environment variables and Makefile defaults.

**Example**:
```bash
make catalog-build CATALOG_REGISTRY=docker.io
```

**When Used**: Suitable for:
- One-off builds with custom configuration
- Overriding environment variable settings temporarily
- Explicit control over a specific build invocation

**Override Capability**: Overrides all other sources (highest precedence).

---

## Precedence Rules Summary

**Precedence Order** (highest to lowest):

```
1. Command-Line Arguments  (highest precedence)
   ↓
2. Environment Variables
   ↓
3. Makefile Defaults        (lowest precedence)
```

**Rule**: If the same variable is defined in multiple sources, the highest-precedence source wins.

**GNU Make Behavior**: This precedence order is built into GNU Make and cannot be changed. It is standard behavior for all Makefile variables using the `?=` operator.

## Concrete Usage Examples

### Scenario 1: Default Behavior (No Overrides)

**Setup**: No environment variables, no CLI arguments.

**Command**:
```bash
make catalog-build
```

**Expected Behavior**:
- All component variables use Makefile defaults
- `CATALOG_REGISTRY = ghcr.io`
- `CATALOG_ORG = stacklok/toolhive`
- `CATALOG_NAME = catalog`
- `CATALOG_TAG = v0.2.17`
- `CATALOG_IMG = ghcr.io/stacklok/toolhive/catalog:v0.2.17`

**Expanded Command**:
```bash
podman build -f catalog.Dockerfile -t ghcr.io/stacklok/toolhive/catalog:v0.2.17 .
```

**Verification**: Image reference matches production default exactly.

---

### Scenario 2: Environment Variable Override

**Setup**: Environment variable set, no CLI arguments.

**Command**:
```bash
export CATALOG_REGISTRY=quay.io
make catalog-build
```

**Expected Behavior**:
- `CATALOG_REGISTRY = quay.io` (from environment)
- `CATALOG_ORG = stacklok/toolhive` (Makefile default)
- `CATALOG_NAME = catalog` (Makefile default)
- `CATALOG_TAG = v0.2.17` (Makefile default)
- `CATALOG_IMG = quay.io/stacklok/toolhive/catalog:v0.2.17`

**Expanded Command**:
```bash
podman build -f catalog.Dockerfile -t quay.io/stacklok/toolhive/catalog:v0.2.17 .
```

**Verification**: Only registry component changes; others remain default.

**Cleanup**:
```bash
unset CATALOG_REGISTRY
```

---

### Scenario 3: CLI Argument Override

**Setup**: No environment variables, CLI argument provided.

**Command**:
```bash
make bundle-build BUNDLE_REGISTRY=docker.io
```

**Expected Behavior**:
- `BUNDLE_REGISTRY = docker.io` (from CLI)
- `BUNDLE_ORG = stacklok/toolhive` (Makefile default)
- `BUNDLE_NAME = bundle` (Makefile default)
- `BUNDLE_TAG = v0.2.17` (Makefile default)
- `BUNDLE_IMG = docker.io/stacklok/toolhive/bundle:v0.2.17`

**Expanded Command**:
```bash
podman build -f bundle.Dockerfile -t docker.io/stacklok/toolhive/bundle:v0.2.17 .
```

**Verification**: Only registry component changes; CLI argument takes effect.

---

### Scenario 4: CLI Argument Overrides Environment Variable

**Setup**: Environment variable set, CLI argument provided for same variable.

**Command**:
```bash
export CATALOG_REGISTRY=docker.io
make catalog-build CATALOG_REGISTRY=quay.io
```

**Expected Behavior**:
- CLI argument wins
- `CATALOG_REGISTRY = quay.io` (from CLI, NOT docker.io from environment)
- `CATALOG_ORG = stacklok/toolhive` (Makefile default)
- `CATALOG_NAME = catalog` (Makefile default)
- `CATALOG_TAG = v0.2.17` (Makefile default)
- `CATALOG_IMG = quay.io/stacklok/toolhive/catalog:v0.2.17`

**Expanded Command**:
```bash
podman build -f catalog.Dockerfile -t quay.io/stacklok/toolhive/catalog:v0.2.17 .
```

**Verification**: CLI argument value (quay.io) used, NOT environment value (docker.io).

**Cleanup**:
```bash
unset CATALOG_REGISTRY
```

---

### Scenario 5: Multiple Component Overrides (CLI)

**Setup**: Override multiple components via CLI arguments.

**Command**:
```bash
make bundle-build BUNDLE_REGISTRY=quay.io BUNDLE_ORG=myteam BUNDLE_TAG=dev
```

**Expected Behavior**:
- `BUNDLE_REGISTRY = quay.io` (from CLI)
- `BUNDLE_ORG = myteam` (from CLI)
- `BUNDLE_NAME = bundle` (Makefile default)
- `BUNDLE_TAG = dev` (from CLI)
- `BUNDLE_IMG = quay.io/myteam/bundle:dev`

**Expanded Command**:
```bash
podman build -f bundle.Dockerfile -t quay.io/myteam/bundle:dev .
```

**Verification**: All overridden components change; non-overridden component (name) remains default.

---

### Scenario 6: Full Custom Image (All Components)

**Setup**: Override all four components via CLI arguments.

**Command**:
```bash
make index-olmv0-build \
  INDEX_REGISTRY=docker.io \
  INDEX_ORG=myuser \
  INDEX_NAME=custom-index \
  INDEX_TAG=feature-auth
```

**Expected Behavior**:
- `INDEX_REGISTRY = docker.io` (from CLI)
- `INDEX_ORG = myuser` (from CLI)
- `INDEX_NAME = custom-index` (from CLI)
- `INDEX_TAG = feature-auth` (from CLI)
- `INDEX_OLMV0_IMG = docker.io/myuser/custom-index:feature-auth`

**Expanded Command**:
```bash
opm index add --bundles ... --tag docker.io/myuser/custom-index:feature-auth
```

**Verification**: All components use override values; no defaults remain.

---

### Scenario 7: Mixed Environment and CLI Overrides

**Setup**: Some components from environment, some from CLI.

**Command**:
```bash
export CATALOG_REGISTRY=quay.io
export CATALOG_ORG=myteam
make catalog-build CATALOG_TAG=dev
```

**Expected Behavior**:
- `CATALOG_REGISTRY = quay.io` (from environment)
- `CATALOG_ORG = myteam` (from environment)
- `CATALOG_NAME = catalog` (Makefile default)
- `CATALOG_TAG = dev` (from CLI)
- `CATALOG_IMG = quay.io/myteam/catalog:dev`

**Expanded Command**:
```bash
podman build -f catalog.Dockerfile -t quay.io/myteam/catalog:dev .
```

**Verification**: Environment and CLI overrides both apply; CLI does not block environment overrides for different variables.

**Cleanup**:
```bash
unset CATALOG_REGISTRY CATALOG_ORG
```

---

### Scenario 8: Latest Tag Variant (Push Target)

**Setup**: Override registry, push both versioned and latest tags.

**Command**:
```bash
make catalog-push CATALOG_REGISTRY=quay.io CATALOG_TAG=v1.0.0
```

**Expected Behavior**:
- Versioned image: `quay.io/stacklok/toolhive/catalog:v1.0.0`
- Latest image: `quay.io/stacklok/toolhive/catalog:latest`
- Both images pushed to the same registry/org

**Expanded Commands**:
```bash
podman push quay.io/stacklok/toolhive/catalog:v1.0.0
podman tag quay.io/stacklok/toolhive/catalog:v1.0.0 quay.io/stacklok/toolhive/catalog:latest
podman push quay.io/stacklok/toolhive/catalog:latest
```

**Verification**: Registry override applies to both versioned and latest tags.

---

## Edge Cases

### Edge Case 1: Empty String Override

**Scenario**: Developer provides empty string as override value.

**Command**:
```bash
make catalog-build CATALOG_TAG=
```

**Expected Behavior**:
- Malformed image reference: `ghcr.io/stacklok/toolhive/catalog:` (missing tag)
- Build likely fails with container tool error (invalid image reference)
- OR: Make pre-validation detects empty value and fails with clear error

**Recommendation**: Document that empty strings are invalid; consider adding validation in build targets.

**Validation Example** (optional enhancement):
```makefile
catalog-build:
	@test -n "$(CATALOG_TAG)" || (echo "Error: CATALOG_TAG cannot be empty"; exit 1)
	# ... actual build commands
```

---

### Edge Case 2: Partial Override (Only Some Components)

**Scenario**: Developer overrides only registry, leaving org/name/tag at defaults.

**Command**:
```bash
make bundle-build BUNDLE_REGISTRY=quay.io
```

**Expected Behavior**:
- `BUNDLE_REGISTRY = quay.io` (overridden)
- `BUNDLE_ORG = stacklok/toolhive` (default)
- `BUNDLE_NAME = bundle` (default)
- `BUNDLE_TAG = v0.2.17` (default)
- `BUNDLE_IMG = quay.io/stacklok/toolhive/bundle:v0.2.17`

**Verification**: Partial override works correctly; non-overridden components use defaults.

**Status**: SUPPORTED - This is a core use case, not an edge case. Listed here for completeness.

---

### Edge Case 3: Precedence Conflict (Same Variable from Multiple Sources)

**Scenario**: Developer sets environment variable, then provides different value via CLI.

**Command**:
```bash
export INDEX_REGISTRY=docker.io
make index-olmv0-build INDEX_REGISTRY=quay.io
```

**Expected Behavior**:
- CLI argument wins
- `INDEX_REGISTRY = quay.io` (CLI takes precedence over environment)

**Verification**: CLI argument always overrides environment variable (standard GNU Make behavior).

**Status**: EXPECTED BEHAVIOR - Not truly an edge case, but a fundamental precedence rule.

---

### Edge Case 4: Invalid Registry Format

**Scenario**: Developer provides invalid registry hostname (e.g., with spaces).

**Command**:
```bash
make catalog-build CATALOG_REGISTRY="registry with spaces"
```

**Expected Behavior**:
- Malformed image reference: `registry with spaces/stacklok/toolhive/catalog:v0.2.17`
- Container build tool (podman/docker) fails with error about invalid image reference
- Make does not validate registry format (container tool does)

**Recommendation**: Document expected formats; rely on container tooling for validation.

---

### Edge Case 5: Multiple Overrides for Different Images

**Scenario**: Developer overrides different components for different image types in a single invocation.

**Command**:
```bash
make catalog-build bundle-build \
  CATALOG_REGISTRY=quay.io \
  BUNDLE_REGISTRY=docker.io
```

**Expected Behavior**:
- Catalog image: `quay.io/stacklok/toolhive/catalog:v0.2.17`
- Bundle image: `docker.io/stacklok/toolhive/bundle:v0.2.17`
- Each image type uses its own overrides

**Verification**: Independent component overrides work correctly for multiple image types.

**Status**: SUPPORTED - Variables are scoped per image type.

---

### Edge Case 6: Override Persistence Across Make Invocations

**Scenario**: Developer sets environment variable, runs multiple make targets.

**Command**:
```bash
export CATALOG_REGISTRY=quay.io
make catalog-build
make catalog-push
```

**Expected Behavior**:
- Both `catalog-build` and `catalog-push` use `quay.io`
- Environment variable persists for the shell session
- Both invocations use the same override value

**Verification**: Environment variable overrides apply consistently across multiple make invocations.

**Status**: EXPECTED BEHAVIOR - Standard shell environment behavior.

**Cleanup**:
```bash
unset CATALOG_REGISTRY
```

---

## Debug and Troubleshooting Techniques

### Debug Helper: Show Effective Variable Values

**Target**: `show-image-vars`

**Purpose**: Display all image component and composite variable values without executing any build commands.

**Usage**:
```bash
# Show default values
make show-image-vars

# Show values with overrides applied
make show-image-vars CATALOG_REGISTRY=quay.io BUNDLE_TAG=dev
```

**Expected Output**:
```
Catalog Image Variables:
  CATALOG_REGISTRY = ghcr.io
  CATALOG_ORG      = stacklok/toolhive
  CATALOG_NAME     = catalog
  CATALOG_TAG      = v0.2.17
  CATALOG_IMG      = ghcr.io/stacklok/toolhive/catalog:v0.2.17

Bundle Image Variables:
  BUNDLE_REGISTRY  = ghcr.io
  BUNDLE_ORG       = stacklok/toolhive
  BUNDLE_NAME      = bundle
  BUNDLE_TAG       = v0.2.17
  BUNDLE_IMG       = ghcr.io/stacklok/toolhive/bundle:v0.2.17

Index Image Variables:
  INDEX_REGISTRY   = ghcr.io
  INDEX_ORG        = stacklok/toolhive
  INDEX_NAME       = index-olmv0
  INDEX_TAG        = v0.2.17
  INDEX_OLMV0_IMG  = ghcr.io/stacklok/toolhive/index-olmv0:v0.2.17
```

**Implementation**:
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

### Debug Technique: Dry-Run with Make -n

**Purpose**: See expanded commands without executing them.

**Usage**:
```bash
# Show what catalog-build would execute with defaults
make -n catalog-build

# Show what bundle-build would execute with overrides
make -n bundle-build BUNDLE_REGISTRY=quay.io BUNDLE_TAG=dev
```

**Expected Output**: Full expanded commands with variable substitutions applied.

**Example**:
```bash
$ make -n catalog-build CATALOG_REGISTRY=quay.io
podman build -f catalog.Dockerfile -t quay.io/stacklok/toolhive/catalog:v0.2.17 .
```

**Verification**: Inspect expanded command to confirm overrides applied correctly.

---

### Debug Technique: Check Environment Variables

**Purpose**: Verify which environment variables are set.

**Usage**:
```bash
# Show all environment variables (filter for image-related ones)
env | grep -E '(CATALOG|BUNDLE|INDEX)_'

# Check specific variable
echo $CATALOG_REGISTRY
```

**Expected Output**: List of set environment variables and their values.

---

### Debug Technique: Verify Precedence with Test Invocation

**Purpose**: Confirm CLI arguments override environment variables.

**Usage**:
```bash
# Set environment variable
export CATALOG_REGISTRY=docker.io

# Override with CLI argument
make -n catalog-build CATALOG_REGISTRY=quay.io

# Verify output shows quay.io (CLI value), not docker.io (env value)

# Cleanup
unset CATALOG_REGISTRY
```

**Expected Output**: Expanded command shows CLI value (quay.io), confirming precedence.

---

## Test Scenarios Matrix

### Test Matrix: Override Source Validation

| Test | Environment Variable | CLI Argument | Expected Result | Precedence Rule |
|------|----------------------|--------------|-----------------|-----------------|
| T1 | Not set | Not provided | Use Makefile default | Default applies |
| T2 | Set to `quay.io` | Not provided | Use `quay.io` | Environment overrides default |
| T3 | Not set | Set to `quay.io` | Use `quay.io` | CLI overrides default |
| T4 | Set to `docker.io` | Set to `quay.io` | Use `quay.io` | CLI overrides environment |
| T5 | Set to `quay.io` | Set to `quay.io` | Use `quay.io` | Both match (no conflict) |

**Variable Under Test**: `CATALOG_REGISTRY`

**Commands**:
```bash
# T1: No overrides
make -n catalog-build
# Expected: ghcr.io

# T2: Environment only
export CATALOG_REGISTRY=quay.io
make -n catalog-build
unset CATALOG_REGISTRY
# Expected: quay.io

# T3: CLI only
make -n catalog-build CATALOG_REGISTRY=quay.io
# Expected: quay.io

# T4: Environment vs CLI
export CATALOG_REGISTRY=docker.io
make -n catalog-build CATALOG_REGISTRY=quay.io
unset CATALOG_REGISTRY
# Expected: quay.io (CLI wins)

# T5: Both match
export CATALOG_REGISTRY=quay.io
make -n catalog-build CATALOG_REGISTRY=quay.io
unset CATALOG_REGISTRY
# Expected: quay.io (no conflict)
```

---

### Test Matrix: Component Independence

| Image Type | Component Overridden | Other Images Affected? | Expected Behavior |
|------------|----------------------|------------------------|-------------------|
| Catalog | `CATALOG_REGISTRY` | No | Bundle and Index use their own defaults |
| Bundle | `BUNDLE_ORG` | No | Catalog and Index use their own defaults |
| Index | `INDEX_TAG` | No | Catalog and Bundle use their own defaults |
| All | `*_REGISTRY` for all | No | Each image type uses its own override |

**Commands**:
```bash
# Override catalog registry only
make -n catalog-build bundle-build CATALOG_REGISTRY=quay.io
# Expected: Catalog uses quay.io, Bundle uses ghcr.io

# Override bundle org only
make -n bundle-build index-olmv0-build BUNDLE_ORG=myteam
# Expected: Bundle uses myteam, Index uses stacklok/toolhive

# Override index tag only
make -n index-olmv0-build catalog-build INDEX_TAG=dev
# Expected: Index uses dev, Catalog uses v0.2.17

# Override registry for all three images
make -n catalog-build bundle-build index-olmv0-build \
  CATALOG_REGISTRY=quay.io \
  BUNDLE_REGISTRY=quay.io \
  INDEX_REGISTRY=quay.io
# Expected: All three use quay.io
```

---

### Test Matrix: Partial Override Combinations

| Registry | Org | Name | Tag | Expected Image Reference |
|----------|-----|------|-----|--------------------------|
| Default | Default | Default | Default | `ghcr.io/stacklok/toolhive/catalog:v0.2.17` |
| `quay.io` | Default | Default | Default | `quay.io/stacklok/toolhive/catalog:v0.2.17` |
| Default | `myteam` | Default | Default | `ghcr.io/myteam/catalog:v0.2.17` |
| Default | Default | `myimage` | Default | `ghcr.io/stacklok/toolhive/myimage:v0.2.17` |
| Default | Default | Default | `dev` | `ghcr.io/stacklok/toolhive/catalog:dev` |
| `quay.io` | `myteam` | Default | Default | `quay.io/myteam/catalog:v0.2.17` |
| `quay.io` | Default | Default | `dev` | `quay.io/stacklok/toolhive/catalog:dev` |
| Default | `myteam` | `myimage` | `dev` | `ghcr.io/myteam/myimage:dev` |
| `quay.io` | `myteam` | `myimage` | `dev` | `quay.io/myteam/myimage:dev` |

**Commands** (examples):
```bash
# Registry override only
make -n catalog-build CATALOG_REGISTRY=quay.io

# Org override only
make -n catalog-build CATALOG_ORG=myteam

# Name override only
make -n catalog-build CATALOG_NAME=myimage

# Tag override only
make -n catalog-build CATALOG_TAG=dev

# Registry + Org
make -n catalog-build CATALOG_REGISTRY=quay.io CATALOG_ORG=myteam

# Registry + Tag
make -n catalog-build CATALOG_REGISTRY=quay.io CATALOG_TAG=dev

# Org + Name + Tag
make -n catalog-build CATALOG_ORG=myteam CATALOG_NAME=myimage CATALOG_TAG=dev

# All four components
make -n catalog-build \
  CATALOG_REGISTRY=quay.io \
  CATALOG_ORG=myteam \
  CATALOG_NAME=myimage \
  CATALOG_TAG=dev
```

---

## Contract Compliance Checklist

Implementation MUST satisfy all of these criteria:

- [ ] CLI arguments override environment variables (highest precedence)
- [ ] Environment variables override Makefile defaults (medium precedence)
- [ ] Makefile defaults apply when no overrides specified (lowest precedence)
- [ ] Partial overrides work (only specified components change)
- [ ] Multiple component overrides work independently (no cross-contamination)
- [ ] Different image types use independent variables (catalog, bundle, index)
- [ ] Empty string overrides handled gracefully (error or validation)
- [ ] `show-image-vars` debug helper target exists
- [ ] `make -n` dry-run shows expanded commands correctly
- [ ] Precedence behavior matches test matrix scenarios
- [ ] Component independence matches test matrix scenarios
- [ ] Partial override combinations match test matrix scenarios

## References

- Feature Specification: [spec.md](../spec.md) - User stories with override scenarios
- Research Findings: [research.md](../research.md) - Override testing strategy and precedence rules
- Implementation Plan: [plan.md](../plan.md) - Phase 1 design artifacts
- Makefile Variables Contract: [makefile-variables.md](./makefile-variables.md) - Variable naming and composition
- GNU Make Manual: [Overriding Variables](https://www.gnu.org/software/make/manual/html_node/Overriding.html)

---

**Contract Version**: 1.0
**Last Updated**: 2025-10-10
**Compliance**: REQUIRED for all Makefile modifications in feature 005-custom-container-image
