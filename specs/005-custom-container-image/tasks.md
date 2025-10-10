# Tasks: Custom Container Image Naming

**Input**: Design documents from `/specs/005-custom-container-image/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`
- **[P]**: Can run in parallel (different files/sections, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3, US4, US5)
- Include exact file paths in descriptions

## Path Conventions
- Primary modification target: `Makefile` at repository root
- Documentation updates: `specs/005-custom-container-image/` directory
- This is build infrastructure only - no source code changes

---

## Phase 1: Setup & Discovery

**Purpose**: Understand current Makefile structure and prepare for implementation

- [x] T001 [Setup] Review existing Makefile structure and variable definitions
  - Identify lines 7-10 where BUNDLE_IMG and INDEX_OLMV0_IMG are defined
  - Map all targets that reference these variables or hardcoded image names
  - Document current image reference patterns from research.md findings
- [x] T002 [P] [Setup] Review research.md findings on variable composition patterns
  - Understand `?=` vs `:=` operator usage
  - Understand override precedence (CLI > environment > Makefile)
  - Review the 15-variable set design (12 base + 3 composites)
- [x] T003 [P] [Setup] Review data-model.md and contracts/makefile-variables.md
  - Understand component structure (registry, org, name, tag)
  - Review variable naming convention: `{IMAGE_TYPE}_{COMPONENT}`
  - Understand composition pattern: base components → composite variables
- [x] T004 [P] [Setup] Create backup of current Makefile
  - Copy Makefile to Makefile.backup-pre-005
  - Use for comparison testing after implementation

**Checkpoint**: Understanding of current state and target architecture complete

---

## Phase 2: Foundational Infrastructure

**Purpose**: Core variable structure that ALL user stories depend on

**⚠️ CRITICAL**: All user stories require this foundation. Must complete before any US can start.

- [x] T005 [Foundation] Add OLMv1 Catalog component variables to Makefile (after line 10, before help target)
  - Add `CATALOG_REGISTRY ?= ghcr.io`
  - Add `CATALOG_ORG ?= stacklok/toolhive`
  - Add `CATALOG_NAME ?= catalog`
  - Add `CATALOG_TAG ?= v0.2.17`
  - Add comment block explaining OLMv1 catalog image components
- [x] T006 [Foundation] Refactor existing BUNDLE_IMG to component-based composition
  - Add `BUNDLE_REGISTRY ?= ghcr.io` (before existing BUNDLE_IMG line)
  - Add `BUNDLE_ORG ?= stacklok/toolhive`
  - Add `BUNDLE_NAME ?= bundle`
  - Add `BUNDLE_TAG ?= v0.2.17`
  - Change `BUNDLE_IMG ?= ghcr.io/stacklok/toolhive/bundle:v0.2.17` to `BUNDLE_IMG := $(BUNDLE_REGISTRY)/$(BUNDLE_ORG)/$(BUNDLE_NAME):$(BUNDLE_TAG)`
  - Add comment block explaining OLMv0 bundle image components
- [x] T007 [Foundation] Refactor existing INDEX_OLMV0_IMG to component-based composition
  - Add `INDEX_REGISTRY ?= ghcr.io` (before existing INDEX_OLMV0_IMG line)
  - Add `INDEX_ORG ?= stacklok/toolhive`
  - Add `INDEX_NAME ?= index-olmv0`
  - Add `INDEX_TAG ?= v0.2.17`
  - Change `INDEX_OLMV0_IMG ?= ghcr.io/stacklok/toolhive/index-olmv0:v0.2.17` to `INDEX_OLMV0_IMG := $(INDEX_REGISTRY)/$(INDEX_ORG)/$(INDEX_NAME):$(INDEX_TAG)`
  - Add comment block explaining OLMv0 index image components
- [x] T008 [Foundation] Add composite CATALOG_IMG variable using component composition
  - Add `CATALOG_IMG := $(CATALOG_REGISTRY)/$(CATALOG_ORG)/$(CATALOG_NAME):$(CATALOG_TAG)` after catalog components
  - Ensure immediate expansion using `:=` operator

**Checkpoint**: All 15 variables defined (12 base components + 3 composites). Foundation ready for user story implementation.

---

## Phase 3: User Story 1 - Override Production Container Registry (Priority: P1) 🎯 MVP

**Goal**: Enable developers to override the container registry for catalog, bundle, and index images independently

**Independent Test**: Build catalog image with `make catalog-build CATALOG_REGISTRY=quay.io` and verify image name uses `quay.io` instead of `ghcr.io`

### Implementation for User Story 1

- [x] T009 [US1] Update catalog-build target to use CATALOG_IMG variable
  - Replace hardcoded `ghcr.io/stacklok/toolhive/catalog:v0.2.17` with `$(CATALOG_IMG)`
  - Update podman/docker build command to use variable
  - Update echo statements to show resolved image name
- [x] T010 [US1] Update catalog-push target to use CATALOG_IMG variable
  - Replace hardcoded image references with `$(CATALOG_IMG)`
  - Ensure push command uses variable
- [x] T011 [US1] Update catalog-validate target to use CATALOG_IMG variable (if it references image name)
  - Replace any hardcoded catalog image references with `$(CATALOG_IMG)` - N/A (doesn't reference image)
- [x] T012 [US1] Verify bundle-build and bundle-push targets use BUNDLE_IMG composite variable
  - Confirm no hardcoded `ghcr.io/stacklok/toolhive/bundle` references remain
  - All references should use `$(BUNDLE_IMG)` after refactoring in T006
- [x] T013 [US1] Verify index-olmv0-build and index-olmv0-push targets use INDEX_OLMV0_IMG composite variable
  - Confirm no hardcoded `ghcr.io/stacklok/toolhive/index-olmv0` references remain
  - All references should use `$(INDEX_OLMV0_IMG)` after refactoring in T007
- [x] T014 [P] [US1] Test default registry behavior (no overrides)
  - Run `make catalog-build` and verify image uses `ghcr.io/stacklok/toolhive/catalog:v0.2.17`
  - Run `make bundle-build` and verify image uses `ghcr.io/stacklok/toolhive/bundle:v0.2.17`
  - Run `make index-olmv0-build` and verify image uses `ghcr.io/stacklok/toolhive/index-olmv0:v0.2.17`
- [x] T015 [P] [US1] Test registry override for catalog image only
  - Run `make catalog-build CATALOG_REGISTRY=quay.io`
  - Verify catalog image uses `quay.io/stacklok/toolhive/catalog:v0.2.17`
  - Verify bundle and index still use `ghcr.io` (independence test)
- [x] T016 [P] [US1] Test registry override for all three images separately
  - Override BUNDLE_REGISTRY to `quay.io` and verify bundle image
  - Override INDEX_REGISTRY to `docker.io` and verify index image
  - Confirm each override is independent (doesn't affect other images)

**Checkpoint**: User Story 1 complete - developers can override registry for each image type independently. This is a viable MVP.

---

## Phase 4: User Story 2 - Override Organization/Repository Path (Priority: P1)

**Goal**: Enable developers to override organization/repository path within the registry to match their personal account or team namespace

**Independent Test**: Build bundle image with `make bundle-build BUNDLE_ORG=myuser` and verify image uses custom organization

### Implementation for User Story 2

**Note**: Core implementation already complete in Phase 2 (T006, T007, T008). These tasks focus on testing and edge cases.

- [ ] T017 [US2] Test organization override with simple path
  - Run `make catalog-build CATALOG_ORG=myuser`
  - Verify image is `ghcr.io/myuser/catalog:v0.2.17`
- [ ] T018 [US2] Test organization override with nested path (slashes)
  - Run `make bundle-build BUNDLE_ORG=mycompany/engineering/operators`
  - Verify image is `ghcr.io/mycompany/engineering/operators/bundle:v0.2.17`
  - Confirm nested paths are preserved exactly
- [ ] T019 [US2] Test combined registry and organization override
  - Run `make index-olmv0-build INDEX_REGISTRY=quay.io INDEX_ORG=myteam`
  - Verify image is `quay.io/myteam/index-olmv0:v0.2.17`
  - Confirm both overrides combine correctly
- [ ] T020 [P] [US2] Test organization override for all three image types
  - Override CATALOG_ORG, BUNDLE_ORG, INDEX_ORG with different values
  - Verify each image uses its respective custom organization
  - Confirm independence (catalog org doesn't affect bundle org)

**Checkpoint**: User Story 2 complete - developers can override organization paths with simple or nested values

---

## Phase 5: User Story 3 - Override Container Image Name (Priority: P2)

**Goal**: Enable developers to use descriptive image names for test scenarios

**Independent Test**: Build catalog image with `make catalog-build CATALOG_NAME=toolhive-operator-catalog-dev` and verify custom name

### Implementation for User Story 3

**Note**: Core implementation already complete in Phase 2. These tasks focus on testing and validation.

- [ ] T021 [US3] Test image name override with descriptive name
  - Run `make catalog-build CATALOG_NAME=toolhive-operator-catalog-experimental`
  - Verify image is `ghcr.io/stacklok/toolhive-operator-catalog-experimental:v0.2.17`
- [ ] T022 [US3] Test image name override with hyphens and underscores
  - Run `make bundle-build BUNDLE_NAME=toolhive-bundle_test-v2`
  - Verify name preserved exactly with special characters
- [ ] T023 [US3] Test custom names for all three image types simultaneously
  - Override CATALOG_NAME, BUNDLE_NAME, INDEX_NAME with different values
  - Build all three images
  - Verify each uses its respective custom name
- [ ] T024 [P] [US3] Test combined registry, organization, and name override
  - Run `make catalog-build CATALOG_REGISTRY=quay.io CATALOG_ORG=myuser CATALOG_NAME=custom-catalog`
  - Verify image is `quay.io/myuser/custom-catalog:v0.2.17`
  - Confirm all three components combine correctly

**Checkpoint**: User Story 3 complete - developers can use descriptive custom names for images

---

## Phase 6: User Story 4 - Override Container Image Tag (Priority: P2)

**Goal**: Enable developers to use custom version tags for feature branches and parallel testing

**Independent Test**: Build catalog image with `make catalog-build CATALOG_TAG=feature-auth-v2` and verify custom tag

### Implementation for User Story 4

**Note**: Core implementation already complete in Phase 2. These tasks focus on testing tag formats.

- [ ] T025 [US4] Test tag override with feature branch naming
  - Run `make catalog-build CATALOG_TAG=feature-new-api`
  - Verify image is `ghcr.io/stacklok/toolhive/catalog:feature-new-api`
- [ ] T026 [US4] Test tag override with semantic version metadata
  - Run `make bundle-build BUNDLE_TAG=v1.0.0-rc1+build.123`
  - Verify full semantic version format preserved in tag
- [ ] T027 [US4] Test tag override with `latest` tag
  - Run `make index-olmv0-build INDEX_TAG=latest`
  - Verify image is `ghcr.io/stacklok/toolhive/index-olmv0:latest`
- [ ] T028 [P] [US4] Test custom tags for all three image types
  - Override CATALOG_TAG, BUNDLE_TAG, INDEX_TAG with different values
  - Verify each image uses its respective custom tag
- [ ] T029 [P] [US4] Test full custom image reference (all 4 components)
  - Run `make catalog-build CATALOG_REGISTRY=quay.io CATALOG_ORG=myuser CATALOG_NAME=custom-catalog CATALOG_TAG=v2.0.0`
  - Verify image is `quay.io/myuser/custom-catalog:v2.0.0`
  - Confirm complete customization works end-to-end

**Checkpoint**: User Story 4 complete - developers can use custom tags for versioning and testing

---

## Phase 7: User Story 5 - Mix Default and Custom Values (Priority: P3)

**Goal**: Enable partial overrides where only specific components are customized while others use defaults

**Independent Test**: Override only registry, verify org/name/tag remain at defaults

### Implementation for User Story 5

**Note**: Core implementation already complete - this is inherent to the `?=` operator usage in Phase 2. These tasks validate the behavior.

- [ ] T030 [US5] Test single component override (registry only)
  - Run `make catalog-build CATALOG_REGISTRY=quay.io`
  - Verify image is `quay.io/stacklok/toolhive/catalog:v0.2.17`
  - Confirm org, name, tag use defaults
- [ ] T031 [US5] Test single component override (tag only)
  - Run `make bundle-build BUNDLE_TAG=latest`
  - Verify image is `ghcr.io/stacklok/toolhive/bundle:latest`
  - Confirm registry, org, name use defaults
- [ ] T032 [US5] Test two-component override (registry + tag)
  - Run `make index-olmv0-build INDEX_REGISTRY=quay.io INDEX_TAG=dev`
  - Verify image is `quay.io/stacklok/toolhive/index-olmv0:dev`
  - Confirm org and name use defaults
- [ ] T033 [US5] Test partial override precedence with environment variables
  - Set `export CATALOG_REGISTRY=quay.io`
  - Run `make catalog-build`
  - Verify registry override applied via environment
  - Verify other components use Makefile defaults

**Checkpoint**: User Story 5 complete - partial overrides work as designed, maximum flexibility achieved

---

## Phase 8: Documentation & Usability

**Purpose**: Make the feature discoverable and easy to use

- [ ] T034 [P] [Doc] Add inline documentation comments to Makefile variable section
  - Document the variable composition pattern
  - Explain override mechanism (environment vs CLI)
  - Provide usage examples in comments
  - Reference quickstart.md for detailed guide
- [ ] T035 [P] [Doc] Update Makefile help target to show override capabilities
  - Add section explaining override variables
  - Show example: `make catalog-build CATALOG_REGISTRY=quay.io`
  - Reference available component variables
- [ ] T036 [P] [Doc] Add `show-image-vars` debug helper target to Makefile
  - Create `.PHONY: show-image-vars` target
  - Display effective values of CATALOG_IMG, BUNDLE_IMG, INDEX_OLMV0_IMG
  - Display component values (registry, org, name, tag for each)
  - Add to help output under "Debug" section
- [ ] T037 [P] [Doc] Verify quickstart.md examples match implemented behavior
  - Test all 4 quick start scenarios from quickstart.md
  - Confirm example commands work exactly as documented
  - Update any discrepancies between docs and implementation

**Checkpoint**: Documentation complete - feature is discoverable and well-documented

---

## Phase 9: Edge Cases & Polish

**Purpose**: Handle edge cases and improve error messages

- [ ] T038 [Polish] Test environment variable override behavior
  - Set `export CATALOG_REGISTRY=quay.io`
  - Run `make catalog-build`
  - Verify environment variable override works
  - Test CLI override takes precedence: `make catalog-build CATALOG_REGISTRY=docker.io`
- [ ] T039 [Polish] Test override precedence with mixed sources
  - Set environment variable for BUNDLE_ORG
  - Override BUNDLE_TAG via CLI
  - Verify CLI override and environment override both apply
  - Confirm Makefile defaults used for non-overridden components
- [ ] T040 [P] [Polish] Test clean-images target with custom image names
  - Build images with custom names/tags
  - Run `make clean-images`
  - Verify target handles custom images gracefully (may warn about non-standard names)
  - Update clean-images if needed to support standard cleanup
- [ ] T041 [P] [Polish] Add validation for common error cases
  - Document behavior when component contains invalid characters (make will fail on build)
  - Document behavior when registry is unreachable (container tool will error)
  - Confirm errors are understandable (no make variable expansion errors)
- [ ] T042 [Polish] Test backward compatibility with monolithic variable override
  - Try `make bundle-build BUNDLE_IMG=quay.io/test/bundle:v1.0.0`
  - Document that monolithic override is NOT supported (by design)
  - Component-level overrides are the expected pattern
- [ ] T043 [P] [Polish] Update Makefile help target descriptions for build targets
  - Ensure catalog-build, bundle-build, index-olmv0-build help text mentions override capability
  - Add hint: "Supports component overrides (see make show-image-vars)"

**Checkpoint**: Edge cases handled, error messages clear, backward compatibility documented

---

## Phase 10: Constitution Compliance & Final Validation

**Purpose**: Verify constitutional compliance and ensure no regressions

- [ ] T044 [Validation] Run constitution compliance check
  - Execute `make constitution-check` (if target exists)
  - Execute `make kustomize-validate`
  - Verify both `kustomize build config/base` and `kustomize build config/default` succeed
  - Confirm no CRD modifications (git status config/crd/ should be clean)
- [ ] T045 [Validation] Test all existing Makefile targets work with defaults (backward compatibility)
  - Run complete build workflow: `make validate-all catalog-build bundle-build index-olmv0-build`
  - Verify all targets work exactly as before (no behavior changes with defaults)
  - Confirm image names match original defaults
- [ ] T046 [P] [Validation] Execute test scenarios from contracts/override-precedence.md
  - Run all 8 usage examples from the contract
  - Verify each scenario produces expected results
  - Document any discrepancies
- [ ] T047 [P] [Validation] Execute test matrix from research.md
  - Run backward compatibility tests (Test 1-2)
  - Run override validation tests (Test 3-7)
  - Run edge case tests (Test 8-10)
  - Verify all 10 test scenarios pass
- [ ] T048 [Validation] Compare Makefile output with Makefile.backup-pre-005
  - Use `diff` to compare changes
  - Verify only expected sections modified (variable definitions, no target logic changes)
  - Confirm no unintended modifications

**Checkpoint**: All constitutional requirements met, backward compatibility confirmed, feature fully validated

---

## Dependencies & Parallel Execution

### User Story Dependencies

```
Phase 1 (Setup) → Phase 2 (Foundation)
                       ↓
         ┌─────────────┼─────────────────┬─────────────┬─────────────┐
         ↓             ↓                 ↓             ↓             ↓
    Phase 3 (US1)  Phase 4 (US2)   Phase 5 (US3)  Phase 6 (US4)  Phase 7 (US5)
    Registry       Organization     Image Name      Tag           Partial
    Override       Override         Override        Override      Override
    [P1 - MVP]     [P1]            [P2]            [P2]          [P3]
         |             |                 |             |             |
         └─────────────┼─────────────────┼─────────────┼─────────────┘
                       ↓
                 Phase 8 (Documentation)
                       ↓
                 Phase 9 (Polish)
                       ↓
                 Phase 10 (Validation)
```

**Key Insights**:
- **US1 and US2 are both P1** (equally critical for development workflows)
- **All user stories can be tested in parallel** after Phase 2 foundation
- **US5 inherently tests US1-US4** (partial overrides validate all component types)
- **Foundation phase is blocking** - no user story work can begin until T005-T008 complete

### Parallel Execution Opportunities

**After Phase 2 (Foundation) completion, these can run in parallel**:

**Testing Phase (T014-T033)**:
- Group A: T014-T016 (US1 registry tests)
- Group B: T017-T020 (US2 organization tests)
- Group C: T021-T024 (US3 name tests)
- Group D: T025-T029 (US4 tag tests)
- Group E: T030-T033 (US5 partial override tests)

All groups can execute simultaneously as they test independent aspects.

**Documentation Phase (T034-T037)**:
- All 4 tasks can run in parallel (different files/sections)

**Polish Phase (T038-T043)**:
- T038-T039 (precedence tests) - sequential
- T040-T043 - can run in parallel

**Validation Phase (T044-T048)**:
- T044 must complete first (constitution check)
- T045-T048 can run in parallel after T044

### Task Counts by Phase

| Phase | Task Count | Parallelizable | User Story |
|-------|------------|----------------|------------|
| Phase 1: Setup | 4 | 3 (T002-T004) | Setup |
| Phase 2: Foundation | 4 | 0 (sequential) | Foundation |
| Phase 3: US1 | 8 | 4 (T014-T016) | P1 - MVP |
| Phase 4: US2 | 4 | 1 (T020) | P1 |
| Phase 5: US3 | 4 | 2 (T024, T023 partial) | P2 |
| Phase 6: US4 | 5 | 3 (T028-T029) | P2 |
| Phase 7: US5 | 4 | 0 (validation tasks) | P3 |
| Phase 8: Documentation | 4 | 4 (all) | Cross-cutting |
| Phase 9: Polish | 6 | 3 (T040-T043) | Cross-cutting |
| Phase 10: Validation | 5 | 3 (T046-T048) | Cross-cutting |
| **Total** | **48 tasks** | **23 parallelizable** | 5 user stories |

---

## Implementation Strategy

### MVP Scope (Minimum Viable Product)

**Recommended MVP**: Complete through Phase 3 (User Story 1)

**Delivers**:
- Registry override capability for all three image types (catalog, bundle, index)
- Foundation for all other override capabilities
- Core value: Developers can build to personal registries

**Tasks**: T001-T016 (16 tasks)
**Timeline**: 1-2 days for implementation + testing
**Value**: Enables primary development workflow (build to personal registry)

**Rationale**:
- US1 is highest priority (P1) and most impactful
- Provides immediate value for development workflows
- Foundation (Phase 2) enables quick addition of US2-US5 later
- Independently testable and deployable

### Incremental Delivery Plan

**Iteration 1**: MVP (US1)
- Complete Phase 1, 2, 3
- Deliverable: Registry override working for all image types
- **Value**: Developers can use personal registries

**Iteration 2**: Full P1 Features (US1 + US2)
- Complete Phase 4
- Deliverable: Registry + Organization override
- **Value**: Complete control over registry and namespace

**Iteration 3**: Enhanced Naming (US3 + US4)
- Complete Phase 5, 6
- Deliverable: Custom image names and tags
- **Value**: Descriptive names, feature branch support

**Iteration 4**: Maximum Flexibility (US5)
- Complete Phase 7
- Deliverable: Partial override support
- **Value**: Convenience, minimal configuration

**Iteration 5**: Production Ready
- Complete Phase 8, 9, 10
- Deliverable: Documentation, polish, validation
- **Value**: Feature-complete, production-quality

### Testing Strategy

**Manual Testing** (no automated tests - this is build infrastructure):

**Backward Compatibility** (critical):
- Run all existing make targets with defaults
- Verify no behavior changes
- Compare output with pre-implementation backup

**Override Validation**:
- Test each component type (registry, org, name, tag) independently
- Test combined overrides
- Test partial overrides
- Test precedence (CLI vs environment)

**Edge Cases**:
- Invalid characters in components
- Empty values
- Very long image names
- Special characters in organization paths

**Constitution Compliance** (gate):
- kustomize builds must succeed
- CRDs must remain unchanged
- No manifest modifications

### Success Criteria

Each user story has clear success criteria from spec.md:

- **US1**: Build catalog with `CATALOG_REGISTRY=quay.io`, verify quay.io in image name
- **US2**: Build bundle with `BUNDLE_ORG=myuser`, verify custom org in path
- **US3**: Build with `CATALOG_NAME=custom-name`, verify name change
- **US4**: Build with `BUNDLE_TAG=feature-branch`, verify tag change
- **US5**: Override only registry, verify other components use defaults

**Overall Success**:
- ✅ All 48 tasks complete
- ✅ All 5 user stories independently testable
- ✅ Constitution compliance maintained
- ✅ Zero regressions (backward compatibility 100%)
- ✅ Documentation complete and accurate

---

## Notes

### Key Implementation Details

1. **Variable Ordering in Makefile**:
   - Place component variables (CATALOG_REGISTRY, etc.) BEFORE composite variables (CATALOG_IMG)
   - Composite variables must use `:=` (immediate expansion) to capture component values at definition time

2. **Backward Compatibility**:
   - Existing BUNDLE_IMG and INDEX_OLMV0_IMG variables are refactored to composites
   - Variable names remain the same (backward compatible)
   - Only the internal implementation changes (monolithic → component-based)

3. **Testing Approach**:
   - Use `make -n` (dry-run) to verify variable expansion without executing commands
   - Use `show-image-vars` helper to inspect effective values
   - Use `podman images` or `docker images` to verify actual built images

4. **No Source Code Changes**:
   - This feature only modifies Makefile
   - No changes to kustomize manifests, CRDs, or other source files
   - Build targets continue to work identically with defaults

5. **Documentation Pattern**:
   - Inline comments in Makefile for discoverability
   - quickstart.md for developer usage guide
   - contracts/ for detailed specifications
   - help target for quick reference

### References

- Feature Specification: [spec.md](spec.md)
- Implementation Plan: [plan.md](plan.md)
- Research Findings: [research.md](research.md)
- Data Model: [data-model.md](data-model.md)
- Variable Contract: [contracts/makefile-variables.md](contracts/makefile-variables.md)
- Override Contract: [contracts/override-precedence.md](contracts/override-precedence.md)
- Developer Guide: [quickstart.md](quickstart.md)
- Requirements Checklist: [checklists/requirements.md](checklists/requirements.md)
