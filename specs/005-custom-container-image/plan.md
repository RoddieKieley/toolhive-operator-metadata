# Implementation Plan: Custom Container Image Naming

**Branch**: `005-custom-container-image` | **Date**: 2025-10-10 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/005-custom-container-image/spec.md`

## Summary

Enable developers and testers to override container image naming components (registry, organization, name, tag) for OLMv1 catalog, OLMv0 bundle, and OLMv0 index images through Makefile variable overrides. The implementation will decompose hardcoded image references into component variables with production defaults, allowing independent override of each component via environment variables or make command-line arguments while maintaining backward compatibility with existing build targets.

**Technical Approach**: Refactor Makefile to use hierarchical variable composition where base components (registry, organization, name, tag) default to production values but can be independently overridden. Composite variables will construct full image references from components, ensuring all build targets (build, push, validate) reference the composite variables.

## Technical Context

**Language/Version**: GNU Make 3.81+ (standard Makefile syntax)
**Primary Dependencies**:
- `podman` or `docker` for container operations
- `opm` (Operator Package Manager) for OLM catalog/bundle/index operations
- `kustomize` for manifest building
**Storage**: Container registry (ghcr.io default, overridable to quay.io, docker.io, etc.)
**Testing**: Manual verification via `make` commands with override variables, validation via existing targets (catalog-validate, bundle-validate, index-olmv0-validate)
**Target Platform**: Linux/macOS developer workstations running Makefile-based builds
**Project Type**: Build infrastructure (Makefile-based)
**Performance Goals**: No degradation to existing build times (sub-second variable resolution overhead acceptable)
**Constraints**:
- Must maintain backward compatibility with all existing Makefile targets
- Must not modify Makefile source when overriding (environment/CLI only)
- Must preserve production defaults when no overrides specified
- Must support partial overrides (e.g., override registry only, keep org/name/tag defaults)
**Scale/Scope**: 3 image types × 4 components per type = 12 base variables + 3 composite variables + documentation

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Applicable Principles

**I. Manifest Integrity (NON-NEGOTIABLE)**: ✅ **PASS**
- This feature modifies Makefile build variables, not Kubernetes manifests
- Kustomize builds are unaffected (they reference operator images via params.env, not directly)
- `kustomize build config/base` and `kustomize build config/default` will continue to succeed
- **Verification**: Run both kustomize builds after implementation to confirm

**II. Kustomize-Based Customization**: ✅ **PASS**
- This feature does not modify kustomize overlays or patches
- Image references in `config/base/params.env` will continue to use ConfigMap substitution
- The Makefile changes support the existing kustomize workflow by making image builds more flexible
- **Note**: The Makefile's image variables may be referenced when updating params.env, but this is complementary to kustomize patterns

**III. CRD Immutability (NON-NEGOTIABLE)**: ✅ **PASS**
- This feature does not touch CRD definitions in `config/crd/`
- Only affects container image build and naming in Makefile
- No risk of CRD modification

**IV. OpenShift Compatibility**: ✅ **PASS**
- Container image naming flexibility supports both OpenShift and Kubernetes deployments
- Enables developers to test with alternative registries accessible from their OpenShift clusters
- No OpenShift-specific patches required for this Makefile change

**V. Namespace Awareness**: ✅ **PASS**
- Container image names do not affect namespace placement
- This feature is orthogonal to namespace configuration
- Deployment manifests in kustomize overlays remain namespace-aware

### Constitution Compliance Summary

**Status**: ✅ ALL GATES PASSED

This feature is purely build infrastructure enhancement and does not violate any constitutional principles. It supports the existing kustomize-based workflow by making container image builds more flexible for development and testing scenarios.

**Pre-Implementation Checklist**:
- [x] Verify feature does not modify manifests directly
- [x] Verify feature does not alter kustomize patterns
- [x] Verify CRDs remain untouched
- [x] Verify OpenShift compatibility maintained

**Post-Design Re-Check** (after Phase 1):
- [x] Verify `kustomize build config/base` still succeeds - ✅ PASSED
- [x] Verify `kustomize build config/default` still succeeds - ✅ PASSED
- [x] Verify no new CRD modifications - ✅ UNCHANGED
- [x] Verify Makefile changes are backward compatible - ✅ READY (no changes made yet, design validated)

## Project Structure

### Documentation (this feature)

```
specs/005-custom-container-image/
├── spec.md              # Feature specification (completed)
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output - Makefile variable composition patterns
├── data-model.md        # Phase 1 output - Image reference component structure
├── quickstart.md        # Phase 1 output - Developer usage guide
├── contracts/           # Phase 1 output - Makefile variable contracts
│   ├── makefile-variables.md    # Variable naming and composition rules
│   └── override-precedence.md   # Environment vs CLI override behavior
└── checklists/
    └── requirements.md  # Spec quality checklist (completed)
```

### Source Code (repository root)

```
# Build Infrastructure (Makefile-based modifications)
Makefile                 # Primary modification target
                         # - Add component variables for registry, org, name, tag
                         # - Refactor composite image variables
                         # - Update all image references to use composites
                         # - Add documentation comments

config/base/
└── params.env           # May need updates if default values change
                         # (but likely unchanged for this feature)

# No new source code directories - this is build infrastructure only
```

**Structure Decision**: This feature modifies existing Makefile build infrastructure only. No new source directories are required. The implementation focuses on variable refactoring within the existing Makefile, maintaining all current build targets while adding override flexibility.

## Complexity Tracking

*Not applicable - no constitutional violations to justify.*

## Phase 0: Research & Discovery

**Goal**: Resolve unknowns and establish technical patterns for Makefile variable composition with overrides.

### Research Tasks

1. **Makefile Variable Composition Patterns**
   - **Question**: What are best practices for hierarchical variable composition in Makefiles where base components combine into composite values?
   - **Research**:
     - GNU Make manual on variable assignment operators (`?=`, `:=`, `=`, `+=`)
     - Patterns for default values with override capability
     - Variable expansion timing (immediate vs deferred)
   - **Output**: Document recommended pattern for `REGISTRY ?= ghcr.io` → `IMAGE = $(REGISTRY)/$(ORG)/$(NAME):$(TAG)`

2. **Override Precedence Rules**
   - **Question**: How do environment variables and command-line arguments interact with Makefile `?=` defaults?
   - **Research**:
     - Make variable precedence: CLI args > environment > Makefile defaults
     - Best practices for documenting override mechanism
     - Testing approach to verify override behavior
   - **Output**: Document override precedence and provide examples

3. **Existing Image Reference Patterns**
   - **Question**: Where are the current hardcoded image variables used throughout the Makefile?
   - **Research**:
     - Grep for `ghcr.io/stacklok/toolhive` in Makefile
     - Identify all targets referencing BUNDLE_IMG, INDEX_OLMV0_IMG
     - Find catalog image references (if separate variable exists)
   - **Output**: Complete inventory of image reference points requiring updates

4. **Backward Compatibility Testing**
   - **Question**: How can we verify that existing Makefile invocations continue to work unchanged?
   - **Research**:
     - Test matrix: default behavior vs override behavior
     - Validation approach for checking image names in build output
     - Regression test strategy
   - **Output**: Test plan for backward compatibility verification

### Research Output Location

File: `specs/005-custom-container-image/research.md`

**Expected Sections**:
- Variable Composition Pattern (Decision + Rationale + Examples)
- Override Mechanism (Precedence rules + Usage examples)
- Image Reference Inventory (Current state + Required changes)
- Testing Strategy (Backward compat + Override validation + Edge cases)

## Phase 1: Design & Contracts

**Prerequisites**: research.md complete

### Design Artifacts

#### 1. Data Model (`data-model.md`)

**Purpose**: Define the structure of container image references and their component parts.

**Content**:
- **Container Image Reference Structure**
  - Components: Registry, Organization, Name, Tag
  - Format: `{registry}/{organization}/{name}:{tag}`
  - Validation rules for each component

- **Image Type Definitions**
  - OLMv1 Catalog Image (default: `ghcr.io/stacklok/toolhive/catalog:v0.2.17`)
  - OLMv0 Bundle Image (default: `ghcr.io/stacklok/toolhive/bundle:v0.2.17`)
  - OLMv0 Index Image (default: `ghcr.io/stacklok/toolhive/index-olmv0:v0.2.17`)

- **Component Value Constraints**
  - Registry: DNS hostname format (e.g., `ghcr.io`, `quay.io`, `docker.io`)
  - Organization: Path segments separated by `/` (e.g., `stacklok/toolhive`, `myorg`)
  - Name: Container image name (alphanumeric, hyphens, underscores)
  - Tag: Version identifier (alphanumeric, hyphens, periods, plus signs)

- **Variable Composition Model**
  - Base component variables (e.g., `CATALOG_REGISTRY`, `BUNDLE_ORG`)
  - Composite variables (e.g., `CATALOG_IMG := $(CATALOG_REGISTRY)/$(CATALOG_ORG)/$(CATALOG_NAME):$(CATALOG_TAG)`)
  - Override mechanism (`:=` for composites, `?=` for base components)

#### 2. API Contracts (`contracts/`)

**File: `contracts/makefile-variables.md`**

Purpose: Define Makefile variable naming conventions and composition rules.

**Content**:
- Variable Naming Standard:
  ```makefile
  # Pattern: {IMAGE_TYPE}_{COMPONENT}
  # Examples:
  CATALOG_REGISTRY ?= ghcr.io
  CATALOG_ORG ?= stacklok/toolhive
  CATALOG_NAME ?= catalog
  CATALOG_TAG ?= v0.2.17
  CATALOG_IMG := $(CATALOG_REGISTRY)/$(CATALOG_ORG)/$(CATALOG_NAME):$(CATALOG_TAG)

  BUNDLE_REGISTRY ?= ghcr.io
  BUNDLE_ORG ?= stacklok/toolhive
  BUNDLE_NAME ?= bundle
  BUNDLE_TAG ?= v0.2.17
  BUNDLE_IMG := $(BUNDLE_REGISTRY)/$(BUNDLE_ORG)/$(BUNDLE_NAME):$(BUNDLE_TAG)

  INDEX_REGISTRY ?= ghcr.io
  INDEX_ORG ?= stacklok/toolhive
  INDEX_NAME ?= index-olmv0
  INDEX_TAG ?= v0.2.17
  INDEX_OLMV0_IMG := $(INDEX_REGISTRY)/$(INDEX_ORG)/$(INDEX_NAME):$(INDEX_TAG)
  ```

- Validation Rules:
  - All component variables use `?=` (conditional assignment)
  - All composite variables use `:=` (immediate expansion)
  - Component variables must have production defaults
  - Variable names must follow `{TYPE}_{COMPONENT}` pattern

- Backward Compatibility:
  - Existing `BUNDLE_IMG` and `INDEX_OLMV0_IMG` variables must be preserved
  - They become composite variables instead of direct assignments
  - All references to these variables continue to work unchanged

**File: `contracts/override-precedence.md`**

Purpose: Document override mechanism and precedence rules.

**Content**:
- Override Mechanisms:
  1. Environment variables (lowest precedence)
  2. Command-line arguments (highest precedence)
  3. Makefile defaults (used when no override)

- Usage Examples:
  ```bash
  # Override catalog registry only
  make catalog-build CATALOG_REGISTRY=quay.io/myuser

  # Override multiple components for bundle
  make bundle-build BUNDLE_REGISTRY=quay.io BUNDLE_ORG=myteam BUNDLE_TAG=dev

  # Override via environment variable
  export INDEX_REGISTRY=docker.io
  make index-olmv0-build

  # Full custom image for catalog
  make catalog-build \
    CATALOG_REGISTRY=quay.io \
    CATALOG_ORG=myuser \
    CATALOG_NAME=toolhive-operator-catalog \
    CATALOG_TAG=feature-branch
  ```

- Edge Cases:
  - Empty string overrides (treated as invalid, will cause build errors)
  - Partial overrides (only specified components change)
  - Multiple override sources (CLI takes precedence over environment)

#### 3. Quickstart Guide (`quickstart.md`)

**Purpose**: Provide developer-focused guide for using custom image naming.

**Content**:
- Prerequisites (make, podman/docker access)
- Quick Start scenarios:
  1. Build to personal Quay.io registry
  2. Build with custom organization
  3. Build with custom tag for feature branch
  4. Build all three images with custom registry
- Common Patterns:
  - Development workflow (personal registry)
  - Testing workflow (staging registry + custom tags)
  - CI/CD integration (environment variable configuration)
- Troubleshooting:
  - Verify override applied (check make output)
  - Reset to defaults (unset variables)
  - Debugging variable values (`make -n` to see expanded commands)

### Agent Context Update

After generating design artifacts, update agent-specific context:

```bash
.specify/scripts/bash/update-agent-context.sh claude
```

This will add new technologies/patterns to `.specify/memory/context-claude.md`:
- Makefile variable composition patterns
- Container image naming conventions
- Override mechanism implementation

## Phase 2: Task Breakdown (Not in this command)

**Note**: Task breakdown is created by the `/speckit.tasks` command, not `/speckit.plan`.

The tasks will be generated based on:
- User stories from spec.md (5 stories, prioritized P1-P3)
- Design artifacts from Phase 1 (data-model.md, contracts/)
- Constitution compliance verification steps
- Testing requirements from quickstart.md

Expected task phases:
1. Setup: Review existing Makefile structure
2. Foundation: Implement catalog image component variables
3. Extension: Implement bundle and index component variables
4. Integration: Update all build targets to use composite variables
5. Validation: Test backward compatibility and override behavior
6. Documentation: Update inline comments and help target
7. Polish: Edge case handling and error messages

## Implementation Notes

### Key Design Decisions

1. **Variable Assignment Operators**:
   - Use `?=` for component variables (allows override, provides default)
   - Use `:=` for composite variables (immediate expansion, prevents recursive expansion issues)
   - Existing variables like `BUNDLE_IMG` become composite, not hardcoded

2. **Naming Convention**:
   - Pattern: `{IMAGE_TYPE}_{COMPONENT}`
   - IMAGE_TYPE: `CATALOG`, `BUNDLE`, `INDEX`
   - COMPONENT: `REGISTRY`, `ORG`, `NAME`, `TAG`
   - Composite: `{IMAGE_TYPE}_IMG`

3. **Backward Compatibility**:
   - All existing Makefile targets work unchanged with defaults
   - Variables `BUNDLE_IMG` and `INDEX_OLMV0_IMG` remain in place (refactored to composites)
   - No breaking changes to existing workflows

4. **Scope Boundaries**:
   - Only Makefile modifications (no manifest changes)
   - Only affects build-time image naming (not deployment manifests)
   - Does not modify `config/base/params.env` (that's for deployment image references)

### Risk Mitigation

1. **Backward Compatibility Risk**:
   - Mitigation: Comprehensive testing of all existing targets with default values
   - Validation: Run existing build commands without any overrides

2. **Variable Expansion Complexity**:
   - Mitigation: Use `:=` for composites to avoid deferred expansion issues
   - Validation: Test with `make -n` to verify expanded command correctness

3. **Override Confusion**:
   - Mitigation: Clear documentation in quickstart.md with examples
   - Validation: Provide debug helper (make target that shows effective values)

### Success Metrics

- All existing Makefile targets work with defaults (zero regression)
- All 5 user stories testable with override examples in quickstart.md
- Variable composition documented in contracts with clear naming patterns
- Override mechanism validated with test scenarios covering edge cases

## Next Steps

After `/speckit.plan` completion:

1. **Review generated artifacts**:
   - research.md (variable patterns, override mechanism)
   - data-model.md (image reference structure)
   - contracts/makefile-variables.md (variable naming standard)
   - contracts/override-precedence.md (override behavior)
   - quickstart.md (developer usage guide)

2. **Verify constitution compliance** (post-design check):
   - Run `kustomize build config/base`
   - Run `kustomize build config/default`
   - Confirm no CRD modifications
   - Confirm Makefile changes are backward compatible

3. **Proceed to task breakdown**:
   ```bash
   /speckit.tasks
   ```
   This will generate `specs/005-custom-container-image/tasks.md` with detailed implementation tasks based on this plan and the user stories from spec.md.

## References

- Feature Specification: [spec.md](spec.md)
- Requirements Checklist: [checklists/requirements.md](checklists/requirements.md)
- Makefile (current): `/Makefile` in repository root
- Constitution: `.specify/memory/constitution.md`
- Previous specs: specs/001-olmv1-catalog, specs/002-olmv0-bundle, specs/004-registry-database-container
