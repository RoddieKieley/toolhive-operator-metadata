# Tasks: Fix Security Context for OpenShift Compatibility

**Input**: Design documents from `/specs/008-fix-security-context/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`
- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions
- Manifest repository structure: `config/base/`, `config/default/`, `config/manager/`
- Catalog structure: `catalogs/toolhive-catalog/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Verify repository state and tooling before making changes

- [x] T001 [P] Verify kustomize CLI version 5.0+ is installed
- [x] T002 [P] Verify yq YAML processor is installed for validation
- [x] T003 [P] Verify OpenShift CLI (oc) is installed for testing
- [x] T004 Verify current branch is `008-fix-security-context`
- [x] T005 Verify repository is clean with no uncommitted changes

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Validate current state and identify the exact issue

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T006 [US1] Verify current patch file exists at `config/base/openshift_sec_patches.yaml`
- [x] T007 [US1] Verify patch is referenced in `config/base/kustomization.yaml` patchesJson6902 section
- [x] T008 [US1] Run `kustomize build config/base` and save output to verify current state
- [x] T009 [US1] Check if runAsUser field exists in build output using yq
- [x] T010 [US1] Verify upstream manifest at `config/manager/manager.yaml` contains runAsUser: 1000
- [x] T011 [US1] Document current patch application status (working vs not working)

**Checkpoint**: Issue diagnosis complete - **PATCHES ARE ALREADY WORKING CORRECTLY**
- ✅ Patch file exists and is properly referenced
- ✅ runAsUser is successfully removed from build output (returns null)
- ✅ seccompProfile is added to pod security context
- ✅ No manifest changes needed - patches are already correct

---

## Phase 3: User Story 1 - Successful Operator Pod Startup in OpenShift (Priority: P1) 🎯 MVP

**Goal**: Fix security context so operator pod starts successfully in OpenShift with restricted-v2 SCC

**Independent Test**: Install operator via OperatorHub in OpenShift cluster, verify pod enters Running state with all containers ready, and confirm no security context violation errors in pod events or logs.

### Patch Verification and Fix for User Story 1

- [x] T012 [US1] Verify patch removes runAsUser at path `/spec/template/spec/containers/0/securityContext/runAsUser` ✅
- [x] T013 [US1] Verify patch adds seccompProfile at path `/spec/template/spec/securityContext/seccompProfile` ✅
- [x] T014 [US1] If patch paths are incorrect, update `config/base/openshift_sec_patches.yaml` with correct container index (N/A - paths correct)
- [x] T015 [US1] If patch is not referenced, add patch reference to `config/base/kustomization.yaml` (N/A - already referenced)
- [x] T016 [US1] Add inline comments to `config/base/openshift_sec_patches.yaml` documenting why each patch is needed ✅

### Build Validation for User Story 1

- [x] T017 [P] [US1] Run `kustomize build config/base` and verify exit code 0 ✅
- [x] T018 [P] [US1] Run `kustomize build config/default` and verify it still builds successfully ✅
- [x] T019 [US1] Validate runAsUser is absent in base build output: returns null ✅
- [x] T020 [US1] Validate seccompProfile is present: returns "RuntimeDefault" ✅
- [x] T021 [US1] Validate runAsNonRoot at pod level: returns true ✅
- [x] T022 [US1] Validate runAsNonRoot at container level: returns true ✅
- [x] T023 [US1] Validate allowPrivilegeEscalation: returns false ✅
- [x] T024 [US1] Validate readOnlyRootFilesystem: returns true ✅
- [x] T025 [US1] Validate capabilities drop ALL: returns true ✅

### OpenShift Deployment Testing for User Story 1

**NOTE**: Tasks T026-T034 require deployment to an OpenShift cluster. These should be executed manually by the operator to verify the fix works in a real environment.

- [ ] T026 [US1] Deploy to OpenShift test cluster: `oc apply -k config/base`
- [ ] T027 [US1] Wait for pod creation and ready status: `oc wait --for=condition=Ready pod -l control-plane=controller-manager --timeout=120s`
- [ ] T028 [US1] Check pod events for security violations: `oc describe pod -l control-plane=controller-manager | grep -i "security\|violation\|forbidden"`
- [ ] T029 [US1] Verify pod status is Running: `oc get pod -l control-plane=controller-manager -o jsonpath='{.items[0].status.phase}'`
- [ ] T030 [US1] Verify container ready condition is true: `oc get pod -l control-plane=controller-manager -o jsonpath='{.items[0].status.containerStatuses[0].ready}'`
- [ ] T031 [US1] Check assigned UID is not 1000: `oc get pod -l control-plane=controller-manager -o jsonpath='{.items[0].status.containerStatuses[0].user.uid}'`
- [ ] T032 [US1] Check operator logs for successful startup: `oc logs -l control-plane=controller-manager --tail=50`
- [ ] T033 [US1] Verify operator is functional by creating a test MCPServer resource
- [ ] T034 [US1] Clean up test deployment: `oc delete -k config/base`

**Checkpoint**: Manifests are correctly configured and validated. OpenShift deployment testing should be performed manually to confirm operator starts successfully with restricted-v2 SCC.

---

## Phase 4: User Story 2 - Verification Across OpenShift Versions (Priority: P2)

**Goal**: Verify operator works across different OpenShift versions (4.12+) with restricted security policies

**Independent Test**: Deploy operator to OpenShift 4.12, 4.13, and 4.14+ clusters, verify successful pod startup on each version.

### Multi-Version Testing for User Story 2

- [ ] T035 [P] [US2] Deploy to OpenShift 4.12 cluster and verify pod startup using steps T026-T032
- [ ] T036 [P] [US2] Deploy to OpenShift 4.13 cluster and verify pod startup using steps T026-T032
- [ ] T037 [P] [US2] Deploy to OpenShift 4.14+ cluster and verify pod startup using steps T026-T032
- [ ] T038 [US2] Document any version-specific issues or differences in security context handling
- [ ] T039 [US2] Verify security context settings are compatible across all tested versions
- [ ] T040 [P] [US2] Clean up deployments from all test clusters

**Checkpoint**: At this point, User Stories 1 AND 2 should both work - operator verified across multiple OpenShift versions

---

## Phase 5: User Story 3 - Catalog Build and Installation Flow (Priority: P3)

**Goal**: Rebuild OLM catalog with fixed manifests and validate end-to-end installation via OperatorHub

**Independent Test**: Rebuild catalog with updated manifests, push to registry, install via OperatorHub, verify operator becomes operational.

### Catalog Rebuild for User Story 3

- [ ] T041 [US3] Navigate to catalog directory: `catalogs/toolhive-catalog/`
- [ ] T042 [US3] Run catalog validation: `opm validate .` or equivalent validation command
- [ ] T043 [US3] Rebuild catalog with updated manifests (follow project-specific catalog build process)
- [ ] T044 [US3] Verify catalog build completes without validation errors
- [ ] T045 [US3] Verify updated bundle includes fixed security context manifests

### OperatorHub Installation Testing for User Story 3

- [ ] T046 [US3] Clean up any previous operator installations from test cluster
- [ ] T047 [US3] Deploy updated catalog to OpenShift cluster (catalog source creation)
- [ ] T048 [US3] Wait for catalog source to be ready: `oc wait --for=condition=Ready catalogsource/toolhive-catalog --timeout=300s`
- [ ] T049 [US3] Verify operator appears in OperatorHub UI
- [ ] T050 [US3] Install operator via OperatorHub (create Subscription resource)
- [ ] T051 [US3] Monitor CSV installation: `oc get csv -n opendatahub -w`
- [ ] T052 [US3] Verify operator pod starts successfully: `oc wait --for=condition=Ready pod -l control-plane=controller-manager -n opendatahub --timeout=180s`
- [ ] T053 [US3] Check for security context violations in pod events
- [ ] T054 [US3] Verify operator functionality by creating MCPServer and MCPRegistry test resources
- [ ] T055 [US3] Clean up test resources and operator installation

**Checkpoint**: All user stories should now be independently functional - complete end-to-end flow validated

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Documentation and verification of constitutional compliance

- [x] T056 [P] Update CHANGELOG.md or release notes with security context fix details (N/A - no CHANGELOG exists)
- [x] T057 [P] Add OpenShift compatibility notes to README.md ✅
- [x] T058 [P] Verify all constitutional principles are satisfied per plan.md Post-Design Check ✅
- [x] T059 Run all validation commands from `specs/008-fix-security-context/contracts/README.md` ✅
- [x] T060 Run through complete quickstart.md validation steps (build validations complete, deployment pending)
- [x] T061 Document any edge cases encountered during testing (none encountered)
- [x] T062 Create summary of changes for pull request description ✅ (see IMPLEMENTATION_SUMMARY.md)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3-5)**: All depend on Foundational phase completion
  - User Story 1 (P1) MUST complete first - it's the MVP
  - User Story 2 (P2) depends on US1 fixes being in place
  - User Story 3 (P3) depends on US1 fixes being in place
- **Polish (Phase 6)**: Depends on all user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2) - No dependencies on other stories - **MUST COMPLETE FIRST**
- **User Story 2 (P2)**: Can start after User Story 1 is complete - Uses same fixes, just tests on different versions
- **User Story 3 (P3)**: Can start after User Story 1 is complete - Requires working manifests from US1

### Within Each User Story

- Phase 1 Setup tasks (T001-T005) can all run in parallel
- Phase 2 Foundational: T006-T007 can run in parallel, then T008-T011 sequential
- User Story 1:
  - T012-T016 are sequential (patch verification/fixes)
  - T017-T018 can run in parallel (different kustomize builds)
  - T019-T025 are sequential validations
  - T026-T034 are sequential deployment tests
- User Story 2:
  - T035-T037 can run in parallel (different clusters)
  - T038-T039 sequential
  - T040 can run in parallel (cleanup different clusters)
- User Story 3:
  - T041-T045 sequential (catalog build)
  - T046-T055 sequential (installation flow)
- Phase 6 Polish:
  - T056-T058 can run in parallel (different documentation files)
  - T059-T062 sequential

### Parallel Opportunities

- All Setup tasks (T001-T003) can run in parallel
- Kustomize builds for base and default (T017-T018) can run in parallel
- Multi-version OpenShift testing (T035-T037) can run in parallel if multiple clusters available
- Documentation tasks (T056-T058) can run in parallel

---

## Parallel Example: User Story 1 Build Validation

```bash
# Launch parallel kustomize builds (different targets):
Task T017: "Run kustomize build config/base and verify exit code 0"
Task T018: "Run kustomize build config/default and verify it still builds successfully"

# Sequential validation after builds complete:
Task T019: "Validate runAsUser is absent in base build output"
Task T020: "Validate seccompProfile is present"
Task T021: "Validate runAsNonRoot at pod level"
# ... etc
```

## Parallel Example: User Story 2 Multi-Cluster Testing

```bash
# Launch parallel deployments (different clusters):
Task T035: "Deploy to OpenShift 4.12 cluster and verify"
Task T036: "Deploy to OpenShift 4.13 cluster and verify"
Task T037: "Deploy to OpenShift 4.14+ cluster and verify"

# Parallel cleanup after testing:
Task T040: "Clean up deployments from all test clusters"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001-T005)
2. Complete Phase 2: Foundational (T006-T011) - CRITICAL issue diagnosis
3. Complete Phase 3: User Story 1 (T012-T034)
   - Fix patches if needed
   - Validate build output
   - Test in OpenShift
4. **STOP and VALIDATE**: Operator must start successfully in OpenShift
5. If successful, this is the MVP - ready for initial deployment

### Incremental Delivery

1. Complete Setup + Foundational → Issue diagnosed
2. Add User Story 1 → Test independently → **Deploy/Demo (MVP!)** - Operator works in OpenShift
3. Add User Story 2 → Test independently → Deploy/Demo - Multi-version compatibility proven
4. Add User Story 3 → Test independently → Deploy/Demo - End-to-end catalog flow validated
5. Each story adds confidence without breaking previous validation

### Sequential Execution (Recommended for this Feature)

Given the dependencies between user stories for this feature, sequential execution is recommended:

1. Complete Phase 1 + Phase 2 (Setup + Foundational)
2. **Complete User Story 1** (P1) - Core fix MUST work before proceeding
3. **Complete User Story 2** (P2) - Extends validation to multiple versions
4. **Complete User Story 3** (P3) - Validates complete distribution flow
5. Complete Phase 6 (Polish)

**Rationale**: US2 and US3 test the same fixes from US1 in different scenarios, so US1 must be proven working first.

---

## Notes

- **No test tasks**: This is a manifest configuration fix, not application code. Testing is done via build validation and deployment verification.
- [P] tasks = different files/clusters, no dependencies
- [Story] label maps task to specific user story for traceability
- User Story 1 is the critical MVP - operator MUST start in OpenShift
- User Stories 2 and 3 are validation extensions that build confidence
- All constitutional principles are satisfied per plan.md
- Commit after completing each user story phase
- Stop at any checkpoint to validate story independently
- Most validation commands are provided in contracts/ and quickstart.md

## Critical Success Factors

1. **T019 MUST pass**: runAsUser field absent in build output
2. **T027 MUST pass**: Pod becomes ready in OpenShift cluster
3. **T028 MUST pass**: No security violation events
4. **T033 MUST pass**: Operator is functional (can manage resources)

If any of these critical tasks fail, the MVP is not complete and requires additional fixes.
