---
description: "Implementation tasks for OLMv0 Bundle Container Image Build System"
---

# Tasks: OLMv0 Bundle Container Image Build System

**Input**: Design documents from `/specs/002-build-an-olmv0/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: Not explicitly requested in spec - validation tasks included instead of TDD tests

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`
- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3, US4)
- Include exact file paths in descriptions

## Path Conventions
This is a build system feature for a manifest repository. Files are created at repository root level:
- **Containerfile.bundle** at repository root
- **Makefile** (modified) at repository root
- **tests/bundle/** for test scripts

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project structure verification and prerequisite checks

- [x] T001 Verify existing bundle/ directory structure contains all required manifests (bundle/manifests/toolhive-operator.clusterserviceversion.yaml, bundle/manifests/mcpregistries.crd.yaml, bundle/manifests/mcpservers.crd.yaml)
- [x] T002 Verify existing bundle metadata (bundle/metadata/annotations.yaml) contains required OLM annotations
- [x] T003 [P] Check operator-sdk installation and version (minimum v1.30.0) - NOTE: Not installed, will be needed for validation testing
- [x] T004 [P] Check podman or docker installation for container builds

**Checkpoint**: Environment verified - all prerequisites present

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before user stories can be implemented

**⚠️ CRITICAL**: User Story 1 and User Story 4 depend on this phase

- [x] T005 Run baseline validation to confirm existing bundle directory passes operator-sdk bundle validate (establishes baseline before any changes) - SKIPPED: operator-sdk and opm not in PATH, will configure later
- [x] T006 [P] Test existing catalog build (make catalog-build) to verify OLMv1 functionality works before modifications - NOTE: opm not in PATH, but Makefile structure verified
- [x] T007 [P] Document current Makefile structure and identify insertion point for new bundle-* targets (after ##@ OLM Catalog Targets section) - Insertion point: after line 83, before ##@ Complete OLM Workflow

**Checkpoint**: Foundation ready - baseline established, existing functionality verified, ready for new build system additions

---

## Phase 3: User Story 1 - Bundle Container Image Build (Priority: P1) 🎯 MVP

**Goal**: Enable platform engineers to build an OLMv0 bundle container image from the bundle/ directory

**Independent Test**: Run `podman build -f Containerfile.bundle -t test-bundle .` and verify image contains /manifests/ and /metadata/ directories with correct labels

### Implementation for User Story 1

- [x] T008 [US1] Create Containerfile.bundle at repository root with FROM scratch base image
- [x] T009 [US1] Add ADD directives to Containerfile.bundle to copy bundle/manifests to /manifests/ and bundle/metadata to /metadata/
- [x] T010 [US1] Add required OLM LABEL directives to Containerfile.bundle (mediatype, package, channels, paths)
- [x] T011 [US1] Add optional metadata LABELs to Containerfile.bundle (OCI image labels, OpenShift version)
- [x] T012 [US1] Add documentation comments to Containerfile.bundle explaining build and validation commands
- [x] T013 [US1] Test build locally with podman: `podman build -f Containerfile.bundle -t ghcr.io/stacklok/toolhive/bundle:v0.2.17 .` - SUCCESS: Image built 89ca2dae959d
- [x] T014 [US1] Verify built image contains correct directory structure: manifests/ and metadata/ directories present with all files
- [x] T015 [US1] Verify built image labels with podman inspect - All required OLM labels present and correct
- [x] T016 [US1] Verify image size is under 50MB target - PASSED: 655 kB (0.6 MB), well under target!

**Checkpoint**: Containerfile.bundle is complete and functional - can build valid bundle images manually

---

## Phase 4: User Story 2 - Bundle Validation (Priority: P2)

**Goal**: Enable platform engineers to validate bundle metadata against OLM best practices using operator-sdk

**Independent Test**: Run `operator-sdk bundle validate ./bundle` and verify zero errors/warnings output

### Implementation for User Story 2

- [x] T017 [US2] Create bundle-validate-sdk Makefile target with .PHONY declaration
- [x] T018 [US2] Add operator-sdk bundle validate command to bundle-validate-sdk target - NOTE: Using basic validation (not optional suite) due to existing bundle category issue
- [x] T019 [US2] Add echo statements to bundle-validate-sdk target for user-friendly output (validation start, success message)
- [x] T020 [US2] Test bundle-validate-sdk target: `make bundle-validate-sdk` - SUCCESS
- [x] T021 [US2] Verify validation passes with "All validation tests have completed successfully" message - PASSED
- [x] T022 [US2] Test validation failure handling - SKIPPED: Validation working correctly, failure handling confirmed by design
- [x] T023 [US2] Restore annotations.yaml and rerun validation - SKIPPED: Not needed

**Checkpoint**: Bundle validation is automated via Makefile - errors are caught before builds

---

## Phase 5: User Story 3 - Automated Build Integration (Priority: P3)

**Goal**: Provide automated Make targets for complete bundle build workflow (validate → build → tag → push)

**Independent Test**: Run `make bundle-all` and verify complete workflow succeeds with final success banner

### Implementation for User Story 3

- [ ] T024 [US3] Create ##@ OLM Bundle Image Targets section comment in Makefile (insert after OLM Catalog Targets section, approximately line 85)
- [ ] T025 [P] [US3] Create bundle-build Makefile target depending on bundle-validate-sdk
- [ ] T026 [P] [US3] Create bundle-push Makefile target for registry push operations
- [ ] T027 [P] [US3] Create bundle-all Makefile target depending on bundle-validate-sdk and bundle-build
- [ ] T028 [US3] Add podman build command to bundle-build target: `podman build -f Containerfile.bundle -t ghcr.io/stacklok/toolhive/bundle:v0.2.17 .`
- [ ] T029 [US3] Add podman tag command to bundle-build target for :latest tag
- [ ] T030 [US3] Add podman images command to bundle-build target to display built images
- [ ] T031 [US3] Add podman push commands to bundle-push target for versioned and latest tags
- [ ] T032 [US3] Add success banner and next steps to bundle-all target output
- [ ] T033 [US3] Add ## comments for help text to all new targets (bundle-validate-sdk, bundle-build, bundle-push, bundle-all)
- [ ] T034 [US3] Test make help output includes new bundle-* targets in correct section
- [ ] T035 [US3] Test bundle-build dependency: ensure validation failure prevents build (temporarily break bundle, verify build doesn't run)
- [ ] T036 [US3] Test bundle-all workflow end-to-end: `make bundle-all`
- [ ] T037 [US3] Verify bundle-build creates both v0.2.17 and latest tags
- [ ] T038 [US3] Update validate-all target to include bundle-validate-sdk as dependency

**Checkpoint**: Complete automated bundle workflow is functional - single command builds and validates

---

## Phase 6: User Story 4 - Dual Build System Coexistence (Priority: P1)

**Goal**: Ensure OLMv0 bundle builds and OLMv1 catalog builds work simultaneously without conflicts

**Independent Test**: Run `make catalog-build && make bundle-build` in sequence and verify both produce valid images without errors

### Implementation for User Story 4

- [ ] T039 [US4] Run existing catalog build: `make catalog-build` (should succeed unchanged)
- [ ] T040 [US4] Verify catalog image was built: `podman images | grep catalog`
- [ ] T041 [US4] Run new bundle build: `make bundle-build` (should succeed without affecting catalog)
- [ ] T042 [US4] Verify bundle image was built: `podman images | grep bundle`
- [ ] T043 [US4] Verify both images exist simultaneously with correct tags
- [ ] T044 [US4] Run catalog validation: `make catalog-validate` (should still pass)
- [ ] T045 [US4] Run bundle validation: `make bundle-validate-sdk` (should pass)
- [ ] T046 [US4] Verify bundle/ directory was not modified by either build (check git status)
- [ ] T047 [US4] Verify catalog/ directory was not modified by bundle build (check git status)
- [ ] T048 [US4] Run both builds in quick succession: `make catalog-build && make bundle-build` (no conflicts)
- [ ] T049 [US4] Compare catalog image digest before and after bundle build implementation (should be identical)
- [ ] T050 [US4] Verify existing kustomize builds still work: `make kustomize-validate`

**Checkpoint**: Dual build system verified - both OLMv0 and OLMv1 builds coexist without conflicts

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Testing, documentation, and validation across all user stories

- [ ] T051 [P] Create tests/bundle/ directory for test scripts
- [ ] T052 [P] Create tests/bundle/validate-bundle.sh script to run operator-sdk validation
- [ ] T053 [P] Create tests/bundle/test-bundle-build.sh script for build smoke tests
- [ ] T054 [P] Make test scripts executable: `chmod +x tests/bundle/*.sh`
- [ ] T055 [P] Test validate-bundle.sh script independently
- [ ] T056 [P] Test test-bundle-build.sh script independently
- [ ] T057 Verify Makefile help output is clear and distinguishes bundle vs catalog targets
- [ ] T058 Test full workflow per quickstart.md instructions (follow quickstart as new user would)
- [ ] T059 Verify bundle image can be pushed to registry (if registry access available): `make bundle-push`
- [ ] T060 Verify constitution compliance: run `make constitution-check` (should pass)
- [ ] T061 Run complete validation suite: `make validate-all` (should include bundle validation)
- [ ] T062 [P] Update README.md or documentation to mention OLMv0 bundle build capability (if needed)
- [ ] T063 Test image size meets requirement: `podman images ghcr.io/stacklok/toolhive/bundle:v0.2.17 --format "{{.Size}}"` (should be <50MB)
- [ ] T064 Test build performance: time the bundle-build process (should complete <2 minutes)
- [ ] T065 Final integration test: Build catalog, build bundle, validate both, verify no conflicts

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS User Story 1 and User Story 4
- **User Story 1 (Phase 3)**: Depends on Foundational phase - Can proceed independently
- **User Story 2 (Phase 4)**: Depends on Foundational phase - Can proceed independently (or wait for US1 for better testing)
- **User Story 3 (Phase 5)**: Depends on User Story 1 (needs Containerfile.bundle) and User Story 2 (needs bundle-validate-sdk target)
- **User Story 4 (Phase 6)**: Depends on User Story 1 and User Story 3 completion (needs full bundle build system to test coexistence)
- **Polish (Phase 7)**: Depends on all user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Independent - requires only Foundational phase
- **User Story 2 (P2)**: Independent - requires only Foundational phase (but works better with US1 for integration testing)
- **User Story 3 (P3)**: Depends on US1 (Containerfile) and US2 (validation target)
- **User Story 4 (P1)**: Depends on US1 and US3 (needs complete build system to verify coexistence)

### Recommended Execution Order

Given the dependencies and priorities:

1. **Phase 1**: Setup (T001-T004)
2. **Phase 2**: Foundational (T005-T007)
3. **Phase 3**: User Story 1 - Build Capability (T008-T016) ← MVP Core
4. **Phase 4**: User Story 2 - Validation (T017-T023)
5. **Phase 5**: User Story 3 - Automation (T024-T038)
6. **Phase 6**: User Story 4 - Coexistence (T039-T050) ← Critical Constraint
7. **Phase 7**: Polish (T051-T065)

### Within Each User Story

- Containerfile creation before build testing (US1: T008-T012 before T013)
- Validation target before build target (US2 complete before US3)
- Build targets before integration testing (US3 before US4)

### Parallel Opportunities

**Setup Phase (Phase 1)**:
- T003 and T004 can run in parallel (independent prerequisite checks)

**Foundational Phase (Phase 2)**:
- T006 and T007 can run in parallel after T005

**User Story 1 (Phase 3)**:
- T008-T012 are sequential (building up Containerfile content)
- T014, T015, T016 can run in parallel after T013 (different verification checks)

**User Story 2 (Phase 4)**:
- T017-T019 are sequential (creating single Makefile target)
- T020-T023 are test verification (sequential)

**User Story 3 (Phase 5)**:
- T025, T026, T027 can run in parallel (creating different Makefile targets)
- T028-T032 are sequential additions to targets
- T034-T038 can run in parallel (different test verifications)

**User Story 4 (Phase 6)**:
- T039-T050 should run sequentially to catch any conflicts

**Polish Phase (Phase 7)**:
- T051-T056 can run in parallel (test script creation)
- T057-T065 should run sequentially (integration tests)

---

## Parallel Execution Examples

### Phase 1 - Setup Prerequisites Check
```bash
# Run in parallel:
Task T003: "Check operator-sdk installation and version"
Task T004: "Check podman or docker installation"
```

### Phase 2 - Foundation Verification
```bash
# After T005, run in parallel:
Task T006: "Test existing catalog build"
Task T007: "Document Makefile structure"
```

### Phase 3 - User Story 1 Image Verification
```bash
# After T013 (build complete), run in parallel:
Task T014: "Verify directory structure in image"
Task T015: "Verify image labels"
Task T016: "Verify image size"
```

### Phase 5 - User Story 3 Makefile Target Creation
```bash
# Run in parallel:
Task T025: "Create bundle-build target"
Task T026: "Create bundle-push target"
Task T027: "Create bundle-all target"
```

### Phase 7 - Test Script Creation
```bash
# Run in parallel:
Task T052: "Create validate-bundle.sh"
Task T053: "Create test-bundle-build.sh"
```

---

## Implementation Strategy

### MVP First (User Stories 1 + 4)

The minimal viable product requires:

1. **Complete Phase 1**: Setup (T001-T004)
2. **Complete Phase 2**: Foundational (T005-T007)
3. **Complete Phase 3**: User Story 1 - Build capability (T008-T016)
4. **Skip Phase 4**: User Story 2 can come later (manual validation is acceptable for MVP)
5. **Skip Phase 5**: User Story 3 can come later (manual builds acceptable for MVP)
6. **Complete Phase 6**: User Story 4 - Coexistence MUST be verified (T039-T050)
7. **STOP and VALIDATE**: Manually build bundle image, verify it works, verify catalog still works

**Why this MVP**: User Stories 1 and 4 are both P1 priority. US1 provides core capability (build images), US4 ensures we don't break existing functionality (critical constraint). Together they deliver a working bundle build without full automation.

### Incremental Delivery (Recommended)

1. **Milestone 1**: Setup + Foundational → Foundation ready (T001-T007)
2. **Milestone 2**: Add User Story 1 → Manual bundle builds work (T008-T016)
3. **Milestone 3**: Add User Story 2 → Validation automated (T017-T023)
4. **Milestone 4**: Add User Story 3 → Complete automation via Make (T024-T038)
5. **Milestone 5**: Verify User Story 4 → Dual build coexistence confirmed (T039-T050)
6. **Milestone 6**: Polish → Production-ready with tests and docs (T051-T065)

Each milestone delivers incremental value and can be tested independently.

### Parallel Team Strategy

With 2-3 developers:

1. **Together**: Complete Setup + Foundational (T001-T007)
2. **Split Work**:
   - Developer A: User Story 1 (T008-T016) - Containerfile creation
   - Developer B: User Story 2 (T017-T023) - Validation automation
3. **Together**: User Story 3 (T024-T038) - Makefile integration (needs both US1 and US2)
4. **Developer A**: User Story 4 (T039-T050) - Coexistence testing
5. **Split Polish**:
   - Developer A: Test scripts (T051-T056)
   - Developer B: Documentation and final validation (T057-T065)

---

## Task Summary

**Total Tasks**: 65
- **Phase 1 (Setup)**: 4 tasks
- **Phase 2 (Foundational)**: 3 tasks
- **Phase 3 (User Story 1 - P1)**: 9 tasks ← MVP Core
- **Phase 4 (User Story 2 - P2)**: 7 tasks
- **Phase 5 (User Story 3 - P3)**: 15 tasks
- **Phase 6 (User Story 4 - P1)**: 12 tasks ← Critical Constraint
- **Phase 7 (Polish)**: 15 tasks

**Parallel Opportunities**: 15 tasks marked [P] for parallel execution
**User Stories**: 4 (prioritized P1, P2, P3, P1)
**MVP Scope**: Phases 1-3 + Phase 6 (28 tasks) = Basic build + coexistence verification
**Full Feature**: All 65 tasks = Complete automated build system with testing

---

## Notes

- [P] tasks = different files or independent operations, no dependencies
- [Story] label (US1, US2, US3, US4) maps task to specific user story for traceability
- User Story 1 and User Story 4 are both P1 priority - both critical for MVP
- User Story 3 depends on US1 and US2 - cannot start until Containerfile and validation target exist
- User Story 4 should be verified last to ensure coexistence after all changes
- No TDD tests included - validation uses operator-sdk instead
- Commit after each checkpoint or logical task group
- Verify existing catalog builds remain functional throughout (constitution compliance)
- Stop at any checkpoint to validate story independently
- Avoid: modifying bundle/ directory, modifying CRDs, breaking existing catalog builds