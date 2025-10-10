# Data Model: Custom Container Image Naming

**Feature**: Custom Container Image Naming
**Date**: 2025-10-10
**Status**: Complete

## Overview

This document defines the data model for container image references in the toolhive-operator-metadata build system. It describes the structure, composition, constraints, and state transitions for the three container image types (catalog, bundle, index) managed by the Makefile.

## 1. Container Image Reference Structure

### 1.1 Four-Component Model

A container image reference comprises exactly four components assembled in a fixed format:

```
{registry}/{organization}/{name}:{tag}
```

**Component Definitions**:

| Component | Description | Example | Required |
|-----------|-------------|---------|----------|
| **Registry** | DNS hostname of container registry | `ghcr.io`, `quay.io`, `docker.io` | Yes |
| **Organization** | Path segments within registry (may include slashes) | `stacklok/toolhive`, `myorg` | Yes |
| **Name** | Container image identifier | `catalog`, `bundle`, `index-olmv0` | Yes |
| **Tag** | Version or variant identifier | `v0.2.17`, `latest`, `feature-branch` | Yes |

### 1.2 Format Pattern

**Structure**:
```
<registry-host>/<org-path>/<image-name>:<version-tag>
```

**Assembly Rules**:
- Components are joined with forward slashes `/` (except tag, which uses colon `:`)
- Registry must not include protocol (no `https://`)
- Organization may contain multiple path segments (e.g., `org/team/project`)
- Name and tag must not contain slashes or colons
- Whitespace is invalid in all components

**Valid Examples**:
```
ghcr.io/stacklok/toolhive/catalog:v0.2.17
quay.io/myuser/bundle:latest
docker.io/org/team/project/index-olmv0:feature-auth-v2
```

**Invalid Examples**:
```
https://ghcr.io/stacklok/catalog:v1.0.0     # Protocol not allowed
ghcr.io/stacklok//catalog:v1.0.0            # Empty path segment
ghcr.io/stacklok/catalog                    # Missing tag
ghcr.io/stacklok/catalog:v1.0.0:extra       # Multiple colons
```

### 1.3 Composition Rules

**Component Concatenation**:
```makefile
# Base components (defaults, overridable)
CATALOG_REGISTRY ?= ghcr.io
CATALOG_ORG ?= stacklok/toolhive
CATALOG_NAME ?= catalog
CATALOG_TAG ?= v0.2.17

# Composite (immediate expansion, derived from components)
CATALOG_IMG := $(CATALOG_REGISTRY)/$(CATALOG_ORG)/$(CATALOG_NAME):$(CATALOG_TAG)
```

**Operator Semantics**:
- `?=` (conditional assignment): Set only if undefined, enables override
- `:=` (simple expansion): Immediate evaluation, prevents deferred expansion issues

**Composition Flow**:
```
Component Variables (Base Layer)
       ↓
    [?= operator]
       ↓
    Override Detection
    ├─ CLI arg present?    → Use CLI value
    ├─ Environment var?    → Use env value
    └─ Otherwise           → Use default
       ↓
    Composite Variables (Derived Layer)
       ↓
    [:= operator]
       ↓
    Immediate Expansion
       ↓
    Final Image Reference
```

## 2. Image Type Definitions

### 2.1 OLMv1 Catalog Image

**Purpose**: OLM v1 file-based catalog for operator distribution

**Default Components**:
```makefile
CATALOG_REGISTRY ?= ghcr.io
CATALOG_ORG      ?= stacklok/toolhive
CATALOG_NAME     ?= catalog
CATALOG_TAG      ?= v0.2.17
```

**Composite Variables**:
```makefile
# Versioned image
CATALOG_IMG := $(CATALOG_REGISTRY)/$(CATALOG_ORG)/$(CATALOG_NAME):$(CATALOG_TAG)
# Example: ghcr.io/stacklok/toolhive/catalog:v0.2.17

# Latest tag variant
CATALOG_IMG_LATEST := $(CATALOG_REGISTRY)/$(CATALOG_ORG)/$(CATALOG_NAME):latest
# Example: ghcr.io/stacklok/toolhive/catalog:latest
```

**Usage Contexts**:
- `catalog-build` target: Build catalog container image
- `catalog-push` target: Push both versioned and `:latest` tags
- `catalog-validate` target: Validate catalog content
- `clean-images` target: Remove local catalog images

### 2.2 OLMv0 Bundle Image

**Purpose**: OLM v0 bundle format for legacy OpenShift compatibility

**Default Components**:
```makefile
BUNDLE_REGISTRY ?= ghcr.io
BUNDLE_ORG      ?= stacklok/toolhive
BUNDLE_NAME     ?= bundle
BUNDLE_TAG      ?= v0.2.17
```

**Composite Variables**:
```makefile
# Versioned image
BUNDLE_IMG := $(BUNDLE_REGISTRY)/$(BUNDLE_ORG)/$(BUNDLE_NAME):$(BUNDLE_TAG)
# Example: ghcr.io/stacklok/toolhive/bundle:v0.2.17

# Latest tag variant
BUNDLE_IMG_LATEST := $(BUNDLE_REGISTRY)/$(BUNDLE_ORG)/$(BUNDLE_NAME):latest
# Example: ghcr.io/stacklok/toolhive/bundle:latest
```

**Usage Contexts**:
- `bundle-build` target: Generate and build bundle image
- `bundle-push` target: Push both versioned and `:latest` tags
- `bundle-validate` target: Validate bundle format
- `index-olmv0-build` target: Referenced as bundle source for index

**Backward Compatibility Note**:
Previously `BUNDLE_IMG` was a monolithic variable (`BUNDLE_IMG ?= ghcr.io/stacklok/toolhive/bundle:v0.2.17`). The refactored model decomposes this into component variables while preserving the `BUNDLE_IMG` composite variable name for backward compatibility.

### 2.3 OLMv0 Index Image

**Purpose**: OLM v0 index/catalog for bundle registry

**Default Components**:
```makefile
INDEX_REGISTRY ?= ghcr.io
INDEX_ORG      ?= stacklok/toolhive
INDEX_NAME     ?= index-olmv0
INDEX_TAG      ?= v0.2.17
```

**Composite Variables**:
```makefile
# Versioned image
INDEX_OLMV0_IMG := $(INDEX_REGISTRY)/$(INDEX_ORG)/$(INDEX_NAME):$(INDEX_TAG)
# Example: ghcr.io/stacklok/toolhive/index-olmv0:v0.2.17

# Latest tag variant
INDEX_OLMV0_IMG_LATEST := $(INDEX_REGISTRY)/$(INDEX_ORG)/$(INDEX_NAME):latest
# Example: ghcr.io/stacklok/toolhive/index-olmv0:latest
```

**Usage Contexts**:
- `index-olmv0-build` target: Build index from bundle using `opm`
- `index-olmv0-push` target: Push both versioned and `:latest` tags
- `index-olmv0-validate` target: Validate index content
- `index-clean` target: Remove local index images

**Backward Compatibility Note**:
Previously `INDEX_OLMV0_IMG` was a monolithic variable. The refactored model preserves the composite variable name while introducing component variables for granular override.

## 3. Component Value Constraints

### 3.1 Registry Component

**Format**: DNS hostname (RFC 1123 compliant)

**Validation Rules**:
- Must be valid DNS hostname
- No protocol prefix (`http://`, `https://`)
- May include port number (e.g., `localhost:5000`)
- No trailing slash
- Character set: alphanumeric, hyphen, period

**Valid Examples**:
```
ghcr.io
quay.io
docker.io
registry.redhat.io
localhost:5000
my-registry.example.com
```

**Invalid Examples**:
```
https://ghcr.io        # Protocol not allowed
ghcr.io/               # Trailing slash
ghcr io                # Whitespace
registry_host          # Underscore not DNS-compliant
```

### 3.2 Organization Component

**Format**: Path segments (slash-separated)

**Validation Rules**:
- One or more path segments separated by `/`
- Each segment: alphanumeric, hyphen, underscore, period
- No leading or trailing slashes
- No empty segments (no `//`)
- May represent nested namespaces

**Valid Examples**:
```
stacklok/toolhive
myuser
org/team
company/division/project
john_doe
my-org
```

**Invalid Examples**:
```
/stacklok              # Leading slash
stacklok/              # Trailing slash
stacklok//toolhive     # Empty segment
org/team/              # Trailing slash
my org                 # Whitespace
```

### 3.3 Name Component

**Format**: Container image identifier

**Validation Rules**:
- Alphanumeric characters, hyphens, underscores, periods
- No slashes (path separators not allowed)
- No colons (tag separator not allowed)
- Typically lowercase (convention, not enforced)
- Length: 1-255 characters (practical limit)

**Valid Examples**:
```
catalog
bundle
index-olmv0
toolhive-operator-catalog
my_custom_bundle
operator.v2
```

**Invalid Examples**:
```
catalog/image          # Slash not allowed
bundle:tag             # Colon not allowed
my bundle              # Whitespace
catalog@sha256         # Special chars (except hyphen, underscore, period)
```

### 3.4 Tag Component

**Format**: Version or variant identifier

**Validation Rules**:
- Alphanumeric characters, hyphen, period, plus sign
- No slashes or colons
- Common patterns: semantic versions, git refs, descriptive labels
- Special tag: `latest` (conventional default)
- Length: 1-128 characters (Docker standard)

**Valid Examples**:
```
v0.2.17
latest
1.0.0-rc1
feature-auth-v2
main
dev
v1.2.3+build.456
20251010-snapshot
```

**Invalid Examples**:
```
v0.2.17/extra          # Slash not allowed
my:tag                 # Colon not allowed
version 1              # Whitespace
tag_with_underscore    # Underscore (convention discourages but technically valid)
```

## 4. Variable Composition Model

### 4.1 Base Component Variables

**Definition Pattern**:
```makefile
{IMAGE_TYPE}_{COMPONENT} ?= {production_default}
```

**Characteristics**:
- Use `?=` operator (conditional assignment)
- Set only if not already defined (enables override)
- Provide production defaults
- Independent per image type

**Complete Variable Set** (15 variables):

```makefile
# Catalog Components
CATALOG_REGISTRY ?= ghcr.io
CATALOG_ORG      ?= stacklok/toolhive
CATALOG_NAME     ?= catalog
CATALOG_TAG      ?= v0.2.17

# Bundle Components
BUNDLE_REGISTRY  ?= ghcr.io
BUNDLE_ORG       ?= stacklok/toolhive
BUNDLE_NAME      ?= bundle
BUNDLE_TAG       ?= v0.2.17

# Index Components
INDEX_REGISTRY   ?= ghcr.io
INDEX_ORG        ?= stacklok/toolhive
INDEX_NAME       ?= index-olmv0
INDEX_TAG        ?= v0.2.17
```

**Variable Count**: 3 image types × 4 components = 12 base variables

### 4.2 Composite Variables

**Definition Pattern**:
```makefile
{IMAGE_TYPE}_IMG := $(IMAGE_TYPE}_REGISTRY)/$(IMAGE_TYPE}_ORG)/$(IMAGE_TYPE}_NAME):$(IMAGE_TYPE)_TAG
{IMAGE_TYPE}_IMG_LATEST := $(IMAGE_TYPE}_REGISTRY)/$(IMAGE_TYPE}_ORG)/$(IMAGE_TYPE}_NAME):latest
```

**Characteristics**:
- Use `:=` operator (simple expansion, immediate evaluation)
- Derived from base component variables
- Evaluated at definition time (not deferred)
- Two variants per image type (versioned + latest)

**Complete Composite Set** (6 variables):

```makefile
# Catalog Composites
CATALOG_IMG := $(CATALOG_REGISTRY)/$(CATALOG_ORG)/$(CATALOG_NAME):$(CATALOG_TAG)
CATALOG_IMG_LATEST := $(CATALOG_REGISTRY)/$(CATALOG_ORG)/$(CATALOG_NAME):latest

# Bundle Composites
BUNDLE_IMG := $(BUNDLE_REGISTRY)/$(BUNDLE_ORG)/$(BUNDLE_NAME):$(BUNDLE_TAG)
BUNDLE_IMG_LATEST := $(BUNDLE_REGISTRY)/$(BUNDLE_ORG)/$(BUNDLE_NAME):latest

# Index Composites
INDEX_OLMV0_IMG := $(INDEX_REGISTRY)/$(INDEX_ORG)/$(INDEX_NAME):$(INDEX_TAG)
INDEX_OLMV0_IMG_LATEST := $(INDEX_REGISTRY)/$(INDEX_ORG)/$(INDEX_NAME):latest
```

**Variable Count**: 3 image types × 2 variants = 6 composite variables

**Total Variable Count**: 12 base + 6 composite = 18 variables

### 4.3 Assignment Operator Semantics

**`?=` Operator (Conditional Assignment)**:
```makefile
CATALOG_REGISTRY ?= ghcr.io
```

**Behavior**:
1. Check if `CATALOG_REGISTRY` is already defined
2. If undefined → assign `ghcr.io`
3. If defined (via CLI or environment) → keep existing value

**Use Case**: Component defaults that can be overridden

**`:=` Operator (Simple Expansion)**:
```makefile
CATALOG_IMG := $(CATALOG_REGISTRY)/$(CATALOG_ORG)/$(CATALOG_NAME):$(CATALOG_TAG)
```

**Behavior**:
1. Expand right-hand side immediately at definition time
2. Substitute current values of referenced variables
3. Store resulting string in `CATALOG_IMG`
4. Later changes to component variables do NOT affect composite

**Use Case**: Derived values that should be stable snapshots

**Why NOT `=` (Recursive Expansion)**:
```makefile
# AVOID THIS PATTERN:
CATALOG_IMG = $(CATALOG_REGISTRY)/$(CATALOG_ORG)/$(CATALOG_NAME):$(CATALOG_TAG)
```

**Problem**:
- Variables are re-evaluated every time `CATALOG_IMG` is referenced
- If component variables change after this definition, composite changes too
- Unpredictable behavior, harder to debug
- Performance overhead from repeated evaluation

### 4.4 Composition Diagram

```
┌─────────────────────────────────────────────────────────────┐
│  MAKEFILE VARIABLE COMPOSITION FLOW                         │
└─────────────────────────────────────────────────────────────┘

┌───────────────────────────────────────────────────────────────┐
│ Layer 1: Base Component Variables (?= operator)              │
├───────────────────────────────────────────────────────────────┤
│                                                               │
│  CATALOG_REGISTRY ?= ghcr.io                                 │
│  CATALOG_ORG      ?= stacklok/toolhive                       │
│  CATALOG_NAME     ?= catalog                                 │
│  CATALOG_TAG      ?= v0.2.17                                 │
│                                                               │
│  ↑ Can be overridden by:                                     │
│    - CLI: make catalog-build CATALOG_REGISTRY=quay.io        │
│    - ENV: export CATALOG_REGISTRY=quay.io                    │
│                                                               │
└───────────────────────────────────────────────────────────────┘
                            ↓
┌───────────────────────────────────────────────────────────────┐
│ Layer 2: Composite Variables (:= operator)                   │
├───────────────────────────────────────────────────────────────┤
│                                                               │
│  CATALOG_IMG := $(CATALOG_REGISTRY)/$(CATALOG_ORG)/ ...      │
│                                                               │
│  Immediate Expansion at Definition:                          │
│  ┌─────────────────────────────────────┐                     │
│  │ $(CATALOG_REGISTRY) → ghcr.io      │                     │
│  │ $(CATALOG_ORG)      → stacklok/... │                     │
│  │ $(CATALOG_NAME)     → catalog      │                     │
│  │ $(CATALOG_TAG)      → v0.2.17      │                     │
│  └─────────────────────────────────────┘                     │
│                   ↓                                           │
│  CATALOG_IMG = ghcr.io/stacklok/toolhive/catalog:v0.2.17    │
│                                                               │
└───────────────────────────────────────────────────────────────┘
                            ↓
┌───────────────────────────────────────────────────────────────┐
│ Layer 3: Build Target Usage                                  │
├───────────────────────────────────────────────────────────────┤
│                                                               │
│  catalog-build:                                              │
│      podman build ... -t $(CATALOG_IMG)                      │
│                                                               │
│  Expands to:                                                 │
│      podman build ... -t ghcr.io/stacklok/.../catalog:v...   │
│                                                               │
└───────────────────────────────────────────────────────────────┘
```

### 4.5 Override Composition Example

**Scenario**: Override registry only, keep other components default

```bash
make catalog-build CATALOG_REGISTRY=quay.io
```

**Variable Resolution**:
```makefile
# Component evaluation with override:
CATALOG_REGISTRY = quay.io              ← CLI override
CATALOG_ORG      = stacklok/toolhive    ← Default (no override)
CATALOG_NAME     = catalog              ← Default (no override)
CATALOG_TAG      = v0.2.17              ← Default (no override)

# Composite evaluation (immediate expansion):
CATALOG_IMG := quay.io/stacklok/toolhive/catalog:v0.2.17
                ↑
                └─ Only registry changed, others remain default
```

**Final Command**:
```bash
podman build ... -t quay.io/stacklok/toolhive/catalog:v0.2.17
```

## 5. State Transitions

### 5.1 Default State (No Overrides)

**Initial Condition**:
- No CLI arguments provided
- No environment variables set
- Makefile defaults apply

**Component State**:
```makefile
CATALOG_REGISTRY = ghcr.io              # Default from Makefile
CATALOG_ORG      = stacklok/toolhive    # Default from Makefile
CATALOG_NAME     = catalog              # Default from Makefile
CATALOG_TAG      = v0.2.17              # Default from Makefile
```

**Composite State**:
```makefile
CATALOG_IMG = ghcr.io/stacklok/toolhive/catalog:v0.2.17
```

**Trigger**: `make catalog-build`

**Result**: Production image reference used

### 5.2 Component Override State

**Trigger**: CLI argument or environment variable

**Example**: Single component override
```bash
make catalog-build CATALOG_REGISTRY=quay.io
```

**Component State Transition**:
```
BEFORE (Makefile defaults):
  CATALOG_REGISTRY = ghcr.io

AFTER (CLI override applied):
  CATALOG_REGISTRY = quay.io

OTHER COMPONENTS (unchanged):
  CATALOG_ORG  = stacklok/toolhive
  CATALOG_NAME = catalog
  CATALOG_TAG  = v0.2.17
```

**Composite State Transition**:
```
BEFORE:
  CATALOG_IMG = ghcr.io/stacklok/toolhive/catalog:v0.2.17

AFTER:
  CATALOG_IMG = quay.io/stacklok/toolhive/catalog:v0.2.17
                ↑ Only this component changed
```

### 5.3 Multiple Component Override State

**Trigger**: Multiple CLI arguments
```bash
make bundle-build BUNDLE_REGISTRY=quay.io BUNDLE_ORG=myteam BUNDLE_TAG=dev
```

**Component State Transition**:
```
BEFORE (Makefile defaults):
  BUNDLE_REGISTRY = ghcr.io
  BUNDLE_ORG      = stacklok/toolhive
  BUNDLE_NAME     = bundle
  BUNDLE_TAG      = v0.2.17

AFTER (Multiple overrides):
  BUNDLE_REGISTRY = quay.io         ← Overridden
  BUNDLE_ORG      = myteam          ← Overridden
  BUNDLE_NAME     = bundle          ← Default (not overridden)
  BUNDLE_TAG      = dev             ← Overridden
```

**Composite State Transition**:
```
BEFORE:
  BUNDLE_IMG = ghcr.io/stacklok/toolhive/bundle:v0.2.17

AFTER:
  BUNDLE_IMG = quay.io/myteam/bundle:dev
               ↑        ↑        ↑     ↑
               Registry Org      Name  Tag
               Override Override Def.  Override
```

### 5.4 Full Custom State

**Trigger**: All components overridden
```bash
make index-olmv0-build \
  INDEX_REGISTRY=docker.io \
  INDEX_ORG=myuser \
  INDEX_NAME=custom-index \
  INDEX_TAG=feature-auth
```

**Component State Transition**:
```
BEFORE (All defaults):
  INDEX_REGISTRY = ghcr.io
  INDEX_ORG      = stacklok/toolhive
  INDEX_NAME     = index-olmv0
  INDEX_TAG      = v0.2.17

AFTER (All overridden):
  INDEX_REGISTRY = docker.io        ← Overridden
  INDEX_ORG      = myuser           ← Overridden
  INDEX_NAME     = custom-index     ← Overridden
  INDEX_TAG      = feature-auth     ← Overridden
```

**Composite State Transition**:
```
BEFORE:
  INDEX_OLMV0_IMG = ghcr.io/stacklok/toolhive/index-olmv0:v0.2.17

AFTER:
  INDEX_OLMV0_IMG = docker.io/myuser/custom-index:feature-auth
                    ↑          ↑      ↑            ↑
                    All components completely customized
```

### 5.5 State Transition Diagram

```
┌────────────────────────────────────────────────────────────┐
│ STATE FLOW: Component Override Resolution                  │
└────────────────────────────────────────────────────────────┘

    START: Makefile Parsed
           ↓
    ┌──────────────────┐
    │ Default State    │  Component variables defined with ?=
    │ All components   │  Defaults: ghcr.io, stacklok/toolhive, etc.
    │ use Makefile     │
    │ defaults         │
    └──────────────────┘
           ↓
    Check for Overrides
           ↓
    ┌─────────────────────────────────────┐
    │ Override Detection                  │
    │                                     │
    │ For each component:                 │
    │  1. CLI arg present?   → Use CLI    │
    │  2. Env var set?       → Use env    │
    │  3. Otherwise          → Use default│
    └─────────────────────────────────────┘
           ↓
    Component Values Resolved
           ↓
    ┌──────────────────────────────────┐
    │ Composite Resolution             │
    │                                  │
    │ Composite variables (:=) expand  │
    │ immediately using resolved       │
    │ component values                 │
    │                                  │
    │ Example:                         │
    │ CATALOG_IMG :=                   │
    │   $(REGISTRY)/$(ORG)/            │
    │   $(NAME):$(TAG)                 │
    └──────────────────────────────────┘
           ↓
    Final Image Reference
           ↓
    ┌──────────────────────────────────┐
    │ Build Target Execution           │
    │                                  │
    │ Composite variables used in      │
    │ podman/opm commands              │
    │                                  │
    │ Example:                         │
    │ podman build -t $(CATALOG_IMG)   │
    └──────────────────────────────────┘
           ↓
    END: Image Built/Tagged
```

## 6. Validation Rules

### 6.1 Format Validation

**Registry Validation**:
```bash
# Valid: DNS hostname pattern
^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?(\\.[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?)*(:[\d]+)?$

# Test cases:
ghcr.io                → VALID
quay.io                → VALID
localhost:5000         → VALID
my-registry.com        → VALID
https://ghcr.io        → INVALID (protocol)
ghcr.io/               → INVALID (trailing slash)
```

**Organization Validation**:
```bash
# Valid: Path segments (no leading/trailing slashes, no empty segments)
^[a-zA-Z0-9._-]+(/[a-zA-Z0-9._-]+)*$

# Test cases:
stacklok/toolhive      → VALID
myuser                 → VALID
org/team/project       → VALID
/stacklok              → INVALID (leading slash)
stacklok//toolhive     → INVALID (empty segment)
```

**Name Validation**:
```bash
# Valid: Image name (no slashes or colons)
^[a-zA-Z0-9._-]+$

# Test cases:
catalog                → VALID
my-bundle_v2           → VALID
catalog/image          → INVALID (slash)
bundle:tag             → INVALID (colon)
```

**Tag Validation**:
```bash
# Valid: Tag (alphanumeric, hyphen, period, plus)
^[a-zA-Z0-9._+-]+$

# Test cases:
v0.2.17                → VALID
latest                 → VALID
v1.0.0-rc1+build.123   → VALID
my tag                 → INVALID (whitespace)
tag:extra              → INVALID (colon)
```

### 6.2 Empty Value Handling

**Detection**:
```makefile
# Check if component is empty
ifeq ($(CATALOG_REGISTRY),)
    $(error CATALOG_REGISTRY cannot be empty)
endif
```

**Behavior**:
- Empty string override: Treated as invalid
- Build target should fail with clear error message
- User must provide non-empty value or omit override to use default

**Example Error**:
```bash
$ make catalog-build CATALOG_REGISTRY=
Makefile:15: *** CATALOG_REGISTRY cannot be empty.  Stop.
```

### 6.3 Invalid Character Handling

**Detection**:
Container tools (podman, docker, opm) will reject invalid image references at build/push time.

**Makefile Strategy**:
- Rely on downstream tool validation (podman, opm)
- Do not implement complex regex validation in Makefile
- Clear error messages from tools are sufficient

**Example Failure**:
```bash
$ make catalog-build CATALOG_REGISTRY="registry with spaces"
podman build ... -t registry with spaces/stacklok/toolhive/catalog:v0.2.17
Error: invalid reference format
```

**Recommendation**: Document valid formats in quickstart.md rather than adding validation overhead to Makefile.

### 6.4 Validation Checklist

**Pre-Build Validation** (Optional, for enhanced UX):
```makefile
catalog-build: validate-catalog-components
	podman build ... -t $(CATALOG_IMG)

validate-catalog-components:
	@test -n "$(CATALOG_REGISTRY)" || \
	  (echo "Error: CATALOG_REGISTRY cannot be empty"; exit 1)
	@test -n "$(CATALOG_TAG)" || \
	  (echo "Error: CATALOG_TAG cannot be empty"; exit 1)
```

**Post-Build Validation** (Existing targets):
```makefile
catalog-validate:
	# Existing validation logic (unchanged)
```

**Validation Points**:
- [ ] Component variables are non-empty
- [ ] Composite variables expand correctly
- [ ] Final image reference follows format pattern
- [ ] Build tools accept resulting image reference
- [ ] Push operations succeed to target registry

## 7. Examples from Research

### 7.1 Production Default (No Overrides)

**Command**:
```bash
make catalog-build
```

**Variable Resolution**:
```makefile
CATALOG_REGISTRY = ghcr.io
CATALOG_ORG      = stacklok/toolhive
CATALOG_NAME     = catalog
CATALOG_TAG      = v0.2.17
CATALOG_IMG      = ghcr.io/stacklok/toolhive/catalog:v0.2.17
```

**Expanded Command**:
```bash
podman build ... -t ghcr.io/stacklok/toolhive/catalog:v0.2.17
```

### 7.2 Override Registry Only

**Command**:
```bash
make catalog-build CATALOG_REGISTRY=quay.io
```

**Variable Resolution**:
```makefile
CATALOG_REGISTRY = quay.io              ← Overridden
CATALOG_ORG      = stacklok/toolhive    ← Default
CATALOG_NAME     = catalog              ← Default
CATALOG_TAG      = v0.2.17              ← Default
CATALOG_IMG      = quay.io/stacklok/toolhive/catalog:v0.2.17
```

**Expanded Command**:
```bash
podman build ... -t quay.io/stacklok/toolhive/catalog:v0.2.17
```

### 7.3 Override Multiple Components

**Command**:
```bash
make bundle-build BUNDLE_REGISTRY=quay.io BUNDLE_ORG=myteam BUNDLE_TAG=dev
```

**Variable Resolution**:
```makefile
BUNDLE_REGISTRY = quay.io           ← Overridden
BUNDLE_ORG      = myteam            ← Overridden
BUNDLE_NAME     = bundle            ← Default
BUNDLE_TAG      = dev               ← Overridden
BUNDLE_IMG      = quay.io/myteam/bundle:dev
```

**Expanded Command**:
```bash
podman build ... -t quay.io/myteam/bundle:dev
```

### 7.4 Full Custom Image

**Command**:
```bash
make index-olmv0-build \
  INDEX_REGISTRY=docker.io \
  INDEX_ORG=myuser \
  INDEX_NAME=toolhive-index \
  INDEX_TAG=feature-branch
```

**Variable Resolution**:
```makefile
INDEX_REGISTRY  = docker.io         ← Overridden
INDEX_ORG       = myuser            ← Overridden
INDEX_NAME      = toolhive-index    ← Overridden
INDEX_TAG       = feature-branch    ← Overridden
INDEX_OLMV0_IMG = docker.io/myuser/toolhive-index:feature-branch
```

**Expanded Command**:
```bash
opm index add ... --tag docker.io/myuser/toolhive-index:feature-branch
```

### 7.5 Environment Variable Override

**Setup**:
```bash
export CATALOG_REGISTRY=quay.io
```

**Command**:
```bash
make catalog-build
```

**Variable Resolution**:
```makefile
CATALOG_REGISTRY = quay.io              ← Environment variable
CATALOG_ORG      = stacklok/toolhive    ← Default
CATALOG_NAME     = catalog              ← Default
CATALOG_TAG      = v0.2.17              ← Default
CATALOG_IMG      = quay.io/stacklok/toolhive/catalog:v0.2.17
```

### 7.6 CLI Precedence Over Environment

**Setup**:
```bash
export CATALOG_REGISTRY=docker.io
```

**Command**:
```bash
make catalog-build CATALOG_REGISTRY=quay.io
```

**Variable Resolution**:
```makefile
CATALOG_REGISTRY = quay.io              ← CLI wins over environment
CATALOG_ORG      = stacklok/toolhive    ← Default
CATALOG_NAME     = catalog              ← Default
CATALOG_TAG      = v0.2.17              ← Default
CATALOG_IMG      = quay.io/stacklok/toolhive/catalog:v0.2.17
```

**Result**: `quay.io` from CLI takes precedence over `docker.io` from environment.

## 8. Relationship Between Base and Composite Variables

### 8.1 Dependency Graph

```
Base Components (Independent)
    ↓
┌───────────────────┐
│ CATALOG_REGISTRY  │ ← Can be overridden independently
│ CATALOG_ORG       │ ← Can be overridden independently
│ CATALOG_NAME      │ ← Can be overridden independently
│ CATALOG_TAG       │ ← Can be overridden independently
└───────────────────┘
    ↓ ↓ ↓ ↓
    Composition (:=)
    ↓
┌──────────────────────────────────────────────────┐
│ CATALOG_IMG (Derived, depends on all 4 above)   │
└──────────────────────────────────────────────────┘
    ↓
┌──────────────────────────────────────────────────┐
│ Build Targets (consume composite variable)      │
│  - catalog-build                                 │
│  - catalog-push                                  │
│  - catalog-validate                              │
└──────────────────────────────────────────────────┘
```

### 8.2 Independence Property

**Key Principle**: Base components are independent; changing one does not affect others.

**Example**:
```bash
# Override only tag
make catalog-build CATALOG_TAG=latest

# Other components unaffected:
CATALOG_REGISTRY = ghcr.io            ← Unchanged
CATALOG_ORG      = stacklok/toolhive  ← Unchanged
CATALOG_NAME     = catalog            ← Unchanged
CATALOG_TAG      = latest             ← Changed
```

**Benefit**: Users can override precisely what they need without specifying all components.

### 8.3 Derivation Property

**Key Principle**: Composite variables are derived from base components at definition time (immediate expansion).

**Implication**:
- Composite variables are "snapshots" of base components
- Once defined, composite does not change even if base components change later
- This ensures predictable behavior

**Example**:
```makefile
# At Makefile parse time:
CATALOG_REGISTRY ?= ghcr.io
CATALOG_ORG      ?= stacklok/toolhive
CATALOG_NAME     ?= catalog
CATALOG_TAG      ?= v0.2.17

# Immediate expansion happens HERE:
CATALOG_IMG := $(CATALOG_REGISTRY)/$(CATALOG_ORG)/$(CATALOG_NAME):$(CATALOG_TAG)
# CATALOG_IMG is now the string: ghcr.io/stacklok/toolhive/catalog:v0.2.17

# Later in Makefile (hypothetical - this does NOT happen in practice):
CATALOG_TAG = different-tag  # This would NOT change CATALOG_IMG
```

**Why This Matters**: Immediate expansion (`:=`) prevents unexpected behavior from deferred evaluation.

## 9. Override Precedence Impact on Final Values

### 9.1 Precedence Hierarchy

**From Highest to Lowest Priority**:

1. **Command-line arguments** (highest)
2. **Environment variables** (middle)
3. **Makefile defaults** (lowest)

**Operator Interaction**:
- `?=` operator respects this precedence
- CLI and environment values prevent `?=` from assigning defaults

### 9.2 Precedence Examples

#### Example 1: CLI Overrides Everything

**Makefile**:
```makefile
CATALOG_REGISTRY ?= ghcr.io
```

**Environment**:
```bash
export CATALOG_REGISTRY=docker.io
```

**Command**:
```bash
make catalog-build CATALOG_REGISTRY=quay.io
```

**Resolution**:
```
Priority Check:
1. CLI arg?         YES → quay.io  ← WINNER
2. Env var?         YES → docker.io (ignored)
3. Makefile default?YES → ghcr.io  (ignored)

Result: CATALOG_REGISTRY = quay.io
```

#### Example 2: Environment Overrides Makefile Default

**Makefile**:
```makefile
CATALOG_REGISTRY ?= ghcr.io
```

**Environment**:
```bash
export CATALOG_REGISTRY=docker.io
```

**Command**:
```bash
make catalog-build
```

**Resolution**:
```
Priority Check:
1. CLI arg?         NO
2. Env var?         YES → docker.io  ← WINNER
3. Makefile default?YES → ghcr.io    (ignored)

Result: CATALOG_REGISTRY = docker.io
```

#### Example 3: Makefile Default (No Overrides)

**Makefile**:
```makefile
CATALOG_REGISTRY ?= ghcr.io
```

**Environment**: (none)

**Command**:
```bash
make catalog-build
```

**Resolution**:
```
Priority Check:
1. CLI arg?         NO
2. Env var?         NO
3. Makefile default?YES → ghcr.io  ← WINNER

Result: CATALOG_REGISTRY = ghcr.io
```

### 9.3 Mixed Override Scenario

**Setup**:
```bash
export BUNDLE_REGISTRY=docker.io
export BUNDLE_TAG=from-env
```

**Command**:
```bash
make bundle-build BUNDLE_ORG=myteam BUNDLE_TAG=from-cli
```

**Component Resolution**:
```makefile
BUNDLE_REGISTRY = docker.io     ← Environment (no CLI override)
BUNDLE_ORG      = myteam        ← CLI (overrides default)
BUNDLE_NAME     = bundle        ← Default (no override)
BUNDLE_TAG      = from-cli      ← CLI (overrides environment!)
```

**Composite Result**:
```makefile
BUNDLE_IMG = docker.io/myteam/bundle:from-cli
```

**Key Insight**: CLI arguments take precedence over environment for `BUNDLE_TAG`, demonstrating the precedence hierarchy.

### 9.4 Precedence Diagram

```
┌──────────────────────────────────────────────────────────────┐
│ OVERRIDE PRECEDENCE RESOLUTION                               │
└──────────────────────────────────────────────────────────────┘

For each component variable (e.g., CATALOG_REGISTRY):

    ┌─────────────────┐
    │ Check CLI Args  │  make catalog-build CATALOG_REGISTRY=quay.io
    └─────────────────┘
           │
           ├─ YES → Use CLI value (DONE)
           │
           └─ NO ↓
    ┌─────────────────────┐
    │ Check Environment   │  export CATALOG_REGISTRY=docker.io
    └─────────────────────┘
           │
           ├─ YES → Use env value (DONE)
           │
           └─ NO ↓
    ┌─────────────────────┐
    │ Use Makefile Default│  CATALOG_REGISTRY ?= ghcr.io
    └─────────────────────┘
           │
           └─ ALWAYS → Use default value (DONE)

Result: Single winning value per component
        ↓
Composite Variable Assembly (:= operator)
        ↓
Final Image Reference
```

## 10. Summary

### 10.1 Data Model Layers

1. **Component Layer**: 12 base variables (4 per image type) with production defaults
2. **Composite Layer**: 6 derived variables (2 per image type: versioned + latest)
3. **Override Layer**: CLI and environment precedence over defaults
4. **Validation Layer**: Format rules and empty value detection

### 10.2 Key Properties

- **Composability**: Components combine deterministically into full references
- **Independence**: Each component overridable without affecting others
- **Predictability**: Immediate expansion ensures stable composite values
- **Backward Compatibility**: Existing variable names preserved (BUNDLE_IMG, INDEX_OLMV0_IMG)

### 10.3 Implementation Requirements

**Makefile Changes**:
- Add 12 base component variables with `?=`
- Refactor 3 existing composites to use `:=` and component references
- Add 3 new `*_IMG_LATEST` composites for `:latest` tag variants
- Update all build/push/validate targets to use composite variables

**Documentation Changes**:
- Document variable naming convention
- Document override mechanism (CLI vs environment)
- Provide usage examples for common scenarios
- Document validation rules and constraints

**Testing Requirements**:
- Verify backward compatibility (defaults unchanged)
- Verify partial overrides (single component changes)
- Verify full overrides (all components custom)
- Verify precedence (CLI over environment)

---

**Document Version**: 1.0
**Last Updated**: 2025-10-10
**Related Documents**:
- [spec.md](spec.md) - Feature specification
- [research.md](research.md) - Makefile variable composition research
- [plan.md](plan.md) - Implementation plan
- [contracts/makefile-variables.md](contracts/makefile-variables.md) - Variable contract (to be created)
- [quickstart.md](quickstart.md) - Developer usage guide (to be created)
