---
description: "Implementation tasks for OLMv1 File-Based Catalog Bundle"
---

# Tasks: OLMv1 File-Based Catalog Bundle

**Input**: Design documents from `/specs/001-build-an-olmv1/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: No test tasks included - validation tasks replace traditional testing in this manifest-based project.

**Organization**: Tasks are grouped by user story to enable independent implementation and validation of each story.

## Format: `[ID] [P?] [Story] Description`
- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3, US4)
- Include exact file paths in descriptions

## Path Conventions
- Repository root: Kubernetes manifest-based repository
- New directories: `bundle/`, `catalog/`
- Existing directories: `config/` (unchanged per constitution)

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and directory structure

- [x] T001 Create bundle directory structure: `bundle/manifests/` and `bundle/metadata/`
- [x] T002 [P] Create catalog directory structure: `catalog/toolhive-operator/`
- [x] T003 [P] Verify kustomize builds pass (constitution I): `kustomize build config/default` and `kustomize build config/base`

**Checkpoint**: Directory structure ready for bundle and catalog generation

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core manifests and metadata that ALL user stories depend on

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T004 Copy MCPRegistry CRD from config/crd/bases/toolhive.stacklok.dev_mcpregistries.yaml to bundle/manifests/mcpregistries.crd.yaml (constitution III - immutability)
- [x] T005 [P] Copy MCPServer CRD from config/crd/bases/toolhive.stacklok.dev_mcpservers.yaml to bundle/manifests/mcpservers.crd.yaml (constitution III - immutability)
- [x] T006 Create ClusterServiceVersion (CSV) manifest in bundle/manifests/toolhive-operator.clusterserviceversion.yaml with required metadata (displayName, description, version: 0.2.17, minKubeVersion: 1.16.0)
- [x] T007 Add deployment specification to CSV from config/manager/manager.yaml (operator image: ghcr.io/stacklok/toolhive/operator:v0.2.17, proxyrunner image: ghcr.io/stacklok/toolhive/proxyrunner:v0.2.17)
- [x] T008 Add RBAC permissions to CSV from config/rbac/role.yaml
- [x] T009 Add owned CRD definitions to CSV spec.customresourcedefinitions.owned (MCPRegistry v1alpha1, MCPServer v1alpha1)
- [x] T010 Add recommended metadata to CSV: icon (base64), keywords (mcp, model-context-protocol, ai, toolhive), maintainers (Stacklok), provider, links
- [x] T011 Create bundle metadata annotations in bundle/metadata/annotations.yaml with required OLM annotations (mediatype, manifests path, metadata path, package, channels, default channel)

**Checkpoint**: Foundation ready - bundle directory is complete with all manifests

---

## Phase 3: User Story 1 - Bundle Metadata Creation (Priority: P1) 🎯 MVP

**Goal**: Create OLMv1 catalog metadata files with valid FBC schemas (olm.package, olm.channel, olm.bundle)

**Independent Test**: Validate catalog metadata with `opm validate catalog/` passes without errors and contains all three required schemas

### Implementation for User Story 1

- [x] T012 [US1] Create olm.package schema in catalog/toolhive-operator/catalog.yaml defining package name "toolhive-operator", defaultChannel "stable", description, and icon
- [x] T013 [US1] Create olm.channel schema in catalog/toolhive-operator/catalog.yaml defining channel name "stable", package reference, and entries list with toolhive-operator.v0.2.17
- [x] T014 [US1] Render bundle to FBC format: run `opm render bundle/ --output yaml` and capture olm.bundle schema
- [x] T015 [US1] Extract olm.bundle schema and append to catalog/toolhive-operator/catalog.yaml with bundle name "toolhive-operator.v0.2.17", package reference, image "ghcr.io/stacklok/toolhive/bundle:v0.2.17"
- [x] T016 [US1] Add required properties to olm.bundle: olm.package property (packageName: toolhive-operator, version: 0.2.17)
- [x] T017 [US1] Add olm.gvk properties to olm.bundle for MCPRegistry (group: toolhive.stacklok.dev, kind: MCPRegistry, version: v1alpha1)
- [x] T018 [US1] Add olm.gvk properties to olm.bundle for MCPServer (group: toolhive.stacklok.dev, kind: MCPServer, version: v1alpha1)

### Validation for User Story 1

- [x] T019 [US1] Run `opm validate catalog/` to verify FBC schema correctness - must pass with no errors
- [x] T020 [US1] Verify olm.package schema has all required fields (schema, name, defaultChannel)
- [x] T021 [US1] Verify olm.channel schema has all required fields (schema, name, package, entries) and references valid package
- [x] T022 [US1] Verify olm.bundle schema has all required fields (schema, name, package, image, properties) and correct bundle name format
- [x] T023 [US1] Verify referential integrity: channel.package → package.name, bundle.package → package.name, package.defaultChannel → channel.name
- [x] T024 [US1] Verify constitution compliance: run `kustomize build config/default` and `kustomize build config/base` - both must still pass (constitution I)

**Checkpoint**: User Story 1 complete - catalog metadata is valid and ready for image building

---

## Phase 4: User Story 2 - Container Image Build (Priority: P2)

**Goal**: Build FBC metadata into a container image using opm and containerization tools

**Independent Test**: Build catalog image with podman/docker, validate with `opm validate <image>`, and verify image can be served locally

### Implementation for User Story 2

- [x] T025 [US2] Create Containerfile.catalog at repository root with FROM scratch, ADD catalog /configs, and required OLM label (operators.operatorframework.io.index.configs.v1=/configs)
- [x] T026 [US2] Add optional metadata labels to Containerfile.catalog (title, description, vendor, source, version, licenses)
- [x] T027 [US2] Build catalog container image: run `podman build -f Containerfile.catalog -t ghcr.io/stacklok/toolhive/catalog:v0.2.17 .`
- [x] T028 [US2] Tag catalog image as latest: `podman tag ghcr.io/stacklok/toolhive/catalog:v0.2.17 ghcr.io/stacklok/toolhive/catalog:latest`

### Validation for User Story 2

- [x] T029 [US2] Validate catalog image with opm: run `opm validate ghcr.io/stacklok/toolhive/catalog:v0.2.17` - must pass with no errors
- [x] T030 [US2] Test catalog serving locally: run `opm serve ghcr.io/stacklok/toolhive/catalog:v0.2.17 -p 50051` and verify it starts without errors
- [x] T031 [US2] Query local catalog with grpcurl: run `grpcurl -plaintext localhost:50051 api.Registry/ListPackages` and verify "toolhive-operator" package is returned
- [x] T032 [US2] Inspect image layers: verify catalog directory exists at /configs with all FBC schemas intact
- [x] T033 [US2] Verify image size is minimal (scratch-based image should be < 10MB)

**Checkpoint**: User Story 2 complete - catalog image is built, validated, and ready for distribution

---

## Phase 5: User Story 3 - Operator SDK Validation (Priority: P3)

**Goal**: Validate bundle using operator-sdk to ensure Operator Framework compliance and quality standards

**Independent Test**: Run `operator-sdk bundle validate ./bundle --select-optional suite=operatorframework` and verify all validators pass

### Implementation for User Story 3

- [x] T034 [US3] Run basic bundle validation: `operator-sdk bundle validate ./bundle`
- [x] T035 [US3] Run Operator Framework suite validation: `operator-sdk bundle validate ./bundle --select-optional suite=operatorframework`
- [x] T036 [US3] Run bundle validation with Kubernetes version check: `operator-sdk bundle validate ./bundle --select-optional suite=operatorframework --optional-values=k8s-version=1.16`
- [x] T037 [US3] Run operator-sdk scorecard tests: `operator-sdk scorecard ./bundle` (if bundle image is built and accessible)

### Validation Results Review for User Story 3

- [x] T038 [US3] Review validation output and ensure zero errors for basic validation
- [x] T039 [US3] Review validation output and ensure zero errors for operatorframework suite
- [x] T040 [US3] Review scorecard results and ensure passing score (if scorecard was run)
- [x] T041 [US3] Verify CSV has all required fields (displayName, description, version, minKubeVersion, install.spec.deployments, install.spec.permissions, customresourcedefinitions.owned)
- [x] T042 [US3] Verify bundle metadata/annotations.yaml has all required OLM annotations
- [x] T043 [US3] Verify semantic versioning format is correct (0.2.17, not v0.2.17) throughout bundle and catalog

**Checkpoint**: User Story 3 complete - bundle and catalog pass all Operator Framework validations

---

## Phase 6: User Story 4 - Multi-Channel Support (Priority: P4)

**Goal**: Add multiple release channels (stable, candidate, fast) to catalog metadata for flexible update management

**Independent Test**: Add additional channels, validate with `opm validate`, and verify each channel defines valid upgrade paths

### Implementation for User Story 4

- [ ] T044 [US4] Add "candidate" channel schema to catalog/toolhive-operator/catalog.yaml with name "candidate", package reference "toolhive-operator", and entries list
- [ ] T045 [P] [US4] Add "fast" channel schema to catalog/toolhive-operator/catalog.yaml with name "fast", package reference "toolhive-operator", and entries list
- [ ] T046 [US4] Define channel-specific version entries: stable (thoroughly tested versions), candidate (release candidates), fast (cutting edge)
- [ ] T047 [US4] Add upgrade edges to channel entries using "replaces" and "skipRange" fields to define version progression
- [ ] T048 [US4] Update bundle/metadata/annotations.yaml to include all channels in operators.operatorframework.io.bundle.channels.v1 (stable,candidate,fast)

### Validation for User Story 4

- [ ] T049 [US4] Run `opm validate catalog/` to verify multi-channel structure - must pass with no errors
- [ ] T050 [US4] Verify each channel has unique name within the package
- [ ] T051 [US4] Verify all channel.entries[].name references point to valid olm.bundle names
- [ ] T052 [US4] Verify upgrade graph (replaces/skips) does not create cycles
- [ ] T053 [US4] Verify version ordering follows semantic versioning in each channel
- [ ] T054 [US4] Rebuild catalog image with multi-channel support: `podman build -f Containerfile.catalog -t ghcr.io/stacklok/toolhive/catalog:v0.2.17-multiarch .`
- [ ] T055 [US4] Validate rebuilt catalog image with `opm validate` to ensure multi-channel structure is preserved

**Checkpoint**: User Story 4 complete - catalog supports multiple release channels with valid upgrade paths

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories and production readiness

- [x] T056 [P] Create Makefile targets for bundle generation (make bundle, make bundle-validate)
- [x] T057 [P] Create Makefile targets for catalog generation (make catalog, make catalog-validate, make catalog-build, make catalog-push)
- [x] T058 [P] Create Makefile target for complete OLM workflow (make olm-all: bundle → validate → catalog → build)
- [x] T059 [P] Add .indexignore file to catalog/toolhive-operator/ if needed (to exclude specific files from catalog build)
- [x] T060 Document bundle and catalog build process in repository README.md with quickstart commands
- [x] T061 [P] Add CI/CD integration for automated bundle validation (if CI system exists)
- [x] T062 [P] Add CI/CD integration for automated catalog validation (if CI system exists)
- [x] T063 Create example CatalogSource manifest for deploying catalog to Kubernetes/OpenShift clusters
- [x] T064 Create example Subscription manifest for installing operator from catalog
- [x] T065 Final constitution compliance check: verify `kustomize build config/default` and `kustomize build config/base` still pass
- [x] T066 Final constitution compliance check: verify CRD files in config/crd/ are unchanged (git diff --exit-code config/crd/)
- [x] T067 Verify quickstart.md accuracy by following all steps manually
- [x] T068 Commit all changes with message referencing feature spec and constitution compliance

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Story 1 (Phase 3)**: Depends on Foundational phase - creates catalog metadata
- **User Story 2 (Phase 4)**: Depends on User Story 1 (needs catalog metadata to build image)
- **User Story 3 (Phase 5)**: Depends on User Story 1 (needs bundle to validate) - can run in parallel with User Story 2
- **User Story 4 (Phase 6)**: Depends on User Story 1 (extends existing catalog metadata)
- **Polish (Phase 7)**: Depends on desired user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Depends on Foundational phase - No dependencies on other user stories
- **User Story 2 (P2)**: Depends on User Story 1 (needs catalog/ directory with metadata)
- **User Story 3 (P3)**: Depends on User Story 1 (needs bundle/ directory) - Independent of User Story 2
- **User Story 4 (P4)**: Depends on User Story 1 (extends catalog metadata) - Independent of User Story 2 and 3

### Critical Path

```
Setup (Phase 1)
    ↓
Foundational (Phase 2) - BLOCKING for all user stories
    ↓
User Story 1 (Phase 3) - Bundle Metadata Creation
    ↓
    ├─→ User Story 2 (Phase 4) - Container Image Build
    ├─→ User Story 3 (Phase 5) - Operator SDK Validation (can run in parallel with US2)
    └─→ User Story 4 (Phase 6) - Multi-Channel Support
    ↓
Polish (Phase 7)
```

### Parallel Opportunities

- **Within Setup (Phase 1)**: T002 and T003 can run in parallel
- **Within Foundational (Phase 2)**: T005 can run in parallel with T004
- **After User Story 1 completes**: User Story 2 and User Story 3 can run in parallel (both depend only on US1)
- **Within User Story 4 (Phase 6)**: T044 and T045 can run in parallel (different channel schemas)
- **Within Polish (Phase 7)**: T056, T057, T058, T059, T061, T062 can all run in parallel

---

## Parallel Example: User Story 1 Tasks

```bash
# After Foundational phase completes, launch FBC schema creation tasks:
Task: "T012 [US1] Create olm.package schema in catalog/toolhive-operator/catalog.yaml"
# Wait for T012-T015 to complete (they modify same file sequentially)
# Then launch parallel validation tasks:
Task: "T019 [US1] Run opm validate catalog/"
Task: "T024 [US1] Verify constitution compliance: kustomize builds"
```

---

## Parallel Example: After User Story 1 Complete

```bash
# User Story 2 and User Story 3 can proceed in parallel:
# Developer A works on User Story 2 (Container Image Build):
Task: "T025 [US2] Create Containerfile.catalog"
Task: "T026 [US2] Add metadata labels to Containerfile"
Task: "T027 [US2] Build catalog container image"
# ... continue with US2 tasks

# Developer B works on User Story 3 (Operator SDK Validation):
Task: "T034 [US3] Run basic bundle validation"
Task: "T035 [US3] Run Operator Framework suite validation"
Task: "T036 [US3] Run bundle validation with k8s version check"
# ... continue with US3 tasks
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL - creates bundle with CSV and CRDs)
3. Complete Phase 3: User Story 1 (creates catalog metadata)
4. **STOP and VALIDATE**: Run `opm validate catalog/` and verify FBC schemas are valid
5. Deliverable: Repository contains valid FBC metadata that can be used for catalog image building

**MVP Success Criteria**:
- catalog/toolhive-operator/catalog.yaml exists with all three schemas (olm.package, olm.channel, olm.bundle)
- `opm validate catalog/` passes with zero errors
- bundle/ directory contains valid CSV and CRDs
- Kustomize builds still pass (constitution compliance)

### Incremental Delivery

1. **Setup + Foundational** → Foundation ready (bundle directory with CSV and CRDs)
2. **Add User Story 1** → Catalog metadata created and validated → Deploy/Demo (MVP!)
3. **Add User Story 2** → Catalog image built and validated → Deploy/Demo (distributable catalog)
4. **Add User Story 3** → Bundle passes all validations → Deploy/Demo (production-ready)
5. **Add User Story 4** → Multi-channel support added → Deploy/Demo (flexible update management)
6. Each story adds value without breaking previous stories

### Parallel Team Strategy

With multiple developers:

1. Team completes Setup + Foundational together (CRITICAL - shared dependencies)
2. Once Foundational is done:
   - **Developer A**: User Story 1 (catalog metadata)
3. Once User Story 1 is done:
   - **Developer A**: User Story 2 (catalog image build)
   - **Developer B**: User Story 3 (operator-sdk validation) - parallel with US2
   - **Developer C**: User Story 4 (multi-channel) - can start after US1
4. Stories complete and integrate independently

---

## Task Summary

- **Total Tasks**: 68
- **Phase 1 (Setup)**: 3 tasks
- **Phase 2 (Foundational)**: 8 tasks (BLOCKING)
- **Phase 3 (User Story 1 - P1)**: 13 tasks - **MVP Scope**
- **Phase 4 (User Story 2 - P2)**: 9 tasks
- **Phase 5 (User Story 3 - P3)**: 10 tasks
- **Phase 6 (User Story 4 - P4)**: 12 tasks
- **Phase 7 (Polish)**: 13 tasks

### Parallel Opportunities Identified

- 5 tasks marked [P] in Setup/Foundational phases
- User Story 2 and User Story 3 can run in parallel after User Story 1
- 2 tasks marked [P] within User Story 4
- 6 tasks marked [P] in Polish phase

### Independent Test Criteria

- **User Story 1**: `opm validate catalog/` passes with zero errors
- **User Story 2**: Catalog image builds, validates, and can be served locally
- **User Story 3**: `operator-sdk bundle validate --select-optional suite=operatorframework` passes
- **User Story 4**: Multi-channel catalog validates with `opm validate` and all channels have valid upgrade graphs

### Suggested MVP Scope

**Phases 1-3 only** (Setup + Foundational + User Story 1):
- Creates bundle directory with CSV and CRDs (Foundational)
- Creates catalog metadata with valid FBC schemas (User Story 1)
- Validates catalog structure with opm (User Story 1)
- Maintains constitution compliance (User Story 1)
- Deliverable: Valid FBC metadata ready for image building

This MVP provides immediate value: catalog metadata that can be manually built into an image or used for further development.

---

## Notes

- [P] tasks = different files, no dependencies, can run in parallel
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Validation tasks replace traditional tests in this manifest-based project
- Constitution compliance verified at multiple checkpoints
- Commit after each checkpoint or logical group
- Stop at any checkpoint to validate story independently
- Avoid: Modifying files in config/ (constitution II), Changing CRDs (constitution III), Breaking kustomize builds (constitution I)
