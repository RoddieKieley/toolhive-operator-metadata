# Tasks: Upgrade ToolHive Operator to v0.4.2

**Input**: Design documents from `/specs/012-upgrade-to-0/`
**Prerequisites**: plan.md, spec.md

**Tests**: Not applicable - this is a metadata-only upgrade with validation via kustomize builds and operator-sdk bundle validation.

**Organization**: Tasks are grouped by user story to enable independent implementation and verification of each upgrade component.

## Format: `[ID] [P?] [Story] Description`
- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3, US4)
- Include exact file paths in descriptions

## Path Conventions

This is a Kubernetes operator metadata repository with no application source code. All paths are relative to repository root:

- **Manifests**: `config/` (kustomize overlays)
- **CRDs**: `config/crd/bases/`
- **Downloaded**: `downloaded/toolhive-operator/0.4.2/`
- **Generated**: `bundle/`, `catalog/`
- **Build**: `Makefile`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Prepare the downloaded v0.4.2 manifests that all user stories depend on

- [ ] T001 [P] Create directory structure at `downloaded/toolhive-operator/0.4.2/`
- [ ] T002 [P] Download MCPExternalAuthConfigs CRD from `https://raw.githubusercontent.com/stacklok/toolhive/v0.4.2/deploy/charts/operator-crds/crds/toolhive.stacklok.dev_mcpexternalauthconfigs.yaml` to `downloaded/toolhive-operator/0.4.2/mcpexternalauthconfigs.crd.yaml`
- [ ] T003 [P] Download MCPGroups CRD from `https://raw.githubusercontent.com/stacklok/toolhive/v0.4.2/deploy/charts/operator-crds/crds/toolhive.stacklok.dev_mcpgroups.yaml` to `downloaded/toolhive-operator/0.4.2/mcpgroups.crd.yaml`
- [ ] T004 [P] Download MCPRegistries CRD from `https://raw.githubusercontent.com/stacklok/toolhive/v0.4.2/deploy/charts/operator-crds/crds/toolhive.stacklok.dev_mcpregistries.yaml` to `downloaded/toolhive-operator/0.4.2/mcpregistries.crd.yaml`
- [ ] T005 [P] Download MCPRemoteProxies CRD from `https://raw.githubusercontent.com/stacklok/toolhive/v0.4.2/deploy/charts/operator-crds/crds/toolhive.stacklok.dev_mcpremoteproxies.yaml` to `downloaded/toolhive-operator/0.4.2/mcpremoteproxies.crd.yaml`
- [ ] T006 [P] Download MCPServers CRD from `https://raw.githubusercontent.com/stacklok/toolhive/v0.4.2/deploy/charts/operator-crds/crds/toolhive.stacklok.dev_mcpservers.yaml` to `downloaded/toolhive-operator/0.4.2/mcpservers.crd.yaml`
- [ ] T007 [P] Download MCPToolConfigs CRD from `https://raw.githubusercontent.com/stacklok/toolhive/v0.4.2/deploy/charts/operator-crds/crds/toolhive.stacklok.dev_mcptoolconfigs.yaml` to `downloaded/toolhive-operator/0.4.2/mcptoolconfigs.crd.yaml`
- [ ] T008 Copy ClusterServiceVersion from `downloaded/toolhive-operator/0.3.11/toolhive-operator.clusterserviceversion.yaml` to `downloaded/toolhive-operator/0.4.2/toolhive-operator.clusterserviceversion.yaml` as baseline for updates

**Checkpoint**: Downloaded manifests directory ready with all 6 CRDs and baseline CSV

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core version reference updates that MUST be complete before any specific feature work

**⚠️ CRITICAL**: These version updates are the foundation for all subsequent user stories

- [ ] T009 Update CATALOG_TAG variable in `Makefile` from `v0.3.11` to `v0.4.2` (line 12)
- [ ] T010 Update BUNDLE_TAG variable in `Makefile` from `v0.3.11` to `v0.4.2` (line 21)
- [ ] T011 Update INDEX_TAG variable in `Makefile` from `v0.3.11` to `v0.4.2` (line 30)
- [ ] T012 Update bundle target directory reference in `Makefile` from `downloaded/toolhive-operator/0.3.11` to `downloaded/toolhive-operator/0.4.2` (lines 84-86)
- [ ] T013 Update bundle target error message in `Makefile` from `0.3.11` to `0.4.2` (line 133)
- [ ] T014 Update catalog target version entry in `Makefile` from `toolhive-operator.v0.3.11` to `toolhive-operator.v0.4.2` (line 208)

**Checkpoint**: All Makefile version variables updated to v0.4.2 - foundation ready for feature implementation

---

## Phase 3: User Story 1 - Core Version Upgrade (Priority: P1) 🎯 MVP

**Goal**: Update all container image references and version tags from v0.3.11 to v0.4.2 so that the project deploys the latest stable ToolHive Operator release

**Independent Test**: Build bundle and catalog, verify all version references show v0.4.2, deploy to test cluster, confirm operator pod runs with v0.4.2 images

### Implementation for User Story 1

- [ ] T015 [P] [US1] Update toolhive-operator-image value in `config/base/params.env` from `ghcr.io/stacklok/toolhive/operator:v0.3.11` to `ghcr.io/stacklok/toolhive/operator:v0.4.2`
- [ ] T016 [P] [US1] Update toolhive-proxy-image value in `config/base/params.env` from `ghcr.io/stacklok/toolhive/proxyrunner:v0.3.11` to `ghcr.io/stacklok/toolhive/proxyrunner:v0.4.2`
- [ ] T017 [P] [US1] Update operator container image in `config/manager/manager.yaml` from `ghcr.io/stacklok/toolhive/operator:v0.3.11` to `ghcr.io/stacklok/toolhive/operator:v0.4.2` (line ~48)
- [ ] T018 [US1] Update CSV metadata.name in `downloaded/toolhive-operator/0.4.2/toolhive-operator.clusterserviceversion.yaml` from `toolhive-operator.v0.3.11` to `toolhive-operator.v0.4.2`
- [ ] T019 [US1] Update CSV spec.version in `downloaded/toolhive-operator/0.4.2/toolhive-operator.clusterserviceversion.yaml` from `0.3.11` to `0.4.2`
- [ ] T020 [US1] Update CSV containerImage in `downloaded/toolhive-operator/0.4.2/toolhive-operator.clusterserviceversion.yaml` from `ghcr.io/stacklok/toolhive/operator:v0.3.11` to `ghcr.io/stacklok/toolhive/operator:v0.4.2`
- [ ] T021 [US1] Update operator container image in CSV deployment spec at `downloaded/toolhive-operator/0.4.2/toolhive-operator.clusterserviceversion.yaml` from `v0.3.11` to `v0.4.2`
- [ ] T022 [US1] Update TOOLHIVE_RUNNER_IMAGE env var in CSV deployment spec at `downloaded/toolhive-operator/0.4.2/toolhive-operator.clusterserviceversion.yaml` from `ghcr.io/stacklok/toolhive/proxyrunner:v0.3.11` to `ghcr.io/stacklok/toolhive/proxyrunner:v0.4.2`
- [ ] T023 [US1] Validate kustomize build for config/default: Run `kustomize build config/default > /dev/null` to verify no errors
- [ ] T024 [US1] Validate kustomize build for config/base: Run `kustomize build config/base > /dev/null` to verify no errors

**Checkpoint**: At this point, User Story 1 (core version upgrade) should be complete - all version references updated to v0.4.2 and kustomize builds pass

---

## Phase 4: User Story 2 - Add MCPGroup CRD Support (Priority: P2)

**Goal**: Add the MCPGroup custom resource definition to enable organizing and managing related MCP servers as logical groups

**Independent Test**: Deploy only the MCPGroup CRD to test cluster, create sample MCPGroup resource, verify it's accepted by API server with proper status tracking

### Implementation for User Story 2

- [ ] T025 [US2] Copy MCPGroup CRD from `downloaded/toolhive-operator/0.4.2/mcpgroups.crd.yaml` to `config/crd/bases/toolhive.stacklok.dev_mcpgroups.yaml`
- [ ] T026 [US2] Add `toolhive.stacklok.dev_mcpgroups.yaml` to resources list in `config/crd/kustomization.yaml` (maintain alphabetical order with other 5 CRDs)
- [ ] T027 [US2] Validate kustomize build for config/default includes MCPGroup CRD: Run `kustomize build config/default | grep -c "kind: CustomResourceDefinition"` should return 6
- [ ] T028 [US2] Validate kustomize build for config/base includes MCPGroup CRD: Run `kustomize build config/base | grep -c "kind: CustomResourceDefinition"` should return 6

**Checkpoint**: At this point, User Story 2 (MCPGroup CRD support) should be complete - CRD integrated and kustomize builds include all 6 CRDs

---

## Phase 5: User Story 3 - Update CSV with MCPGroup Ownership (Priority: P3)

**Goal**: Update ClusterServiceVersion to declare ownership of MCPGroup CRD for proper OLM catalog metadata

**Independent Test**: Validate bundle with operator-sdk and verify no CRD ownership warnings are generated

### Implementation for User Story 3

- [ ] T029 [US3] Add MCPGroup to CSV description in `downloaded/toolhive-operator/0.4.2/toolhive-operator.clusterserviceversion.yaml` - insert `- **MCPGroup**: Organize and manage groups of related MCP servers` after MCPServer entry in description section
- [ ] T030 [US3] Add MCPGroup CRD to owned CRDs section in `downloaded/toolhive-operator/0.4.2/toolhive-operator.clusterserviceversion.yaml` - insert full CRD ownership entry with name `mcpgroups.toolhive.stacklok.dev`, version `v1alpha1`, kind `MCPGroup`, displayName, and description after MCPServer entry
- [ ] T031 [US3] Add mcpgroups to cluster RBAC resources in `downloaded/toolhive-operator/0.4.2/toolhive-operator.clusterserviceversion.yaml` - add `mcpgroups` to toolhive.stacklok.dev resources array with full CRUD verbs (create, delete, get, list, patch, update, watch)
- [ ] T032 [US3] Add mcpgroups/finalizers to cluster RBAC in `downloaded/toolhive-operator/0.4.2/toolhive-operator.clusterserviceversion.yaml` - add `mcpgroups/finalizers` to toolhive.stacklok.dev resources array with update verb
- [ ] T033 [US3] Add mcpgroups/status to cluster RBAC in `downloaded/toolhive-operator/0.4.2/toolhive-operator.clusterserviceversion.yaml` - add `mcpgroups/status` to toolhive.stacklok.dev resources array with get, patch, update verbs

**Checkpoint**: At this point, User Story 3 (CSV MCPGroup ownership) should be complete - CSV properly declares ownership and RBAC for MCPGroup CRD

---

## Phase 6: User Story 4 - Update RBAC for MCPGroup (Priority: P3)

**Goal**: Update operator's ClusterRole to include permissions for MCPGroup resources to prevent permission errors

**Independent Test**: Deploy operator and create MCPGroup resource, verify no permission denied errors appear in operator logs

### Implementation for User Story 4

- [ ] T034 [US4] Add mcpgroups to ClusterRole resources in `config/rbac/role.yaml` - add `mcpgroups` to the toolhive.stacklok.dev resources list with full CRUD verbs (create, delete, get, list, patch, update, watch)
- [ ] T035 [US4] Add mcpgroups/finalizers to ClusterRole in `config/rbac/role.yaml` - add `mcpgroups/finalizers` subresource with update verb
- [ ] T036 [US4] Add mcpgroups/status to ClusterRole in `config/rbac/role.yaml` - add `mcpgroups/status` subresource with get, patch, update verbs
- [ ] T037 [US4] Validate kustomize build includes MCPGroup RBAC: Run `kustomize build config/default | grep -A 10 "kind: ClusterRole" | grep mcpgroups` to verify permissions present
- [ ] T038 [US4] Validate kustomize build for base includes MCPGroup RBAC: Run `kustomize build config/base | grep -A 10 "kind: ClusterRole" | grep mcpgroups` to verify permissions present

**Checkpoint**: At this point, User Story 4 (RBAC for MCPGroup) should be complete - operator has necessary permissions to manage MCPGroup resources

---

## Phase 7: Polish & Validation

**Purpose**: Generate OLM artifacts and validate complete upgrade

- [ ] T039 [P] Generate bundle: Run `make bundle` to create bundle with v0.4.2 CSV and all 6 CRDs in `bundle/manifests/`
- [ ] T040 Validate bundle structure: Verify `bundle/manifests/` contains exactly 7 files (1 CSV + 6 CRDs)
- [ ] T041 Validate bundle with operator-sdk: Run `operator-sdk --plugins go.kubebuilder.io/v4 bundle validate ./bundle` to ensure no errors
- [ ] T042 [P] Generate catalog: Run `make catalog` to create FBC catalog with v0.4.2 entry in `catalog/toolhive-operator/catalog.yaml`
- [ ] T043 Validate catalog structure: Verify `catalog/toolhive-operator/catalog.yaml` contains 7 olm.bundle.object entries (6 CRDs + 1 CSV)
- [ ] T044 Validate catalog with opm: Run `opm validate catalog/` to ensure catalog is valid
- [ ] T045 [P] Update README.md version references from v0.3.11 to v0.4.2 where applicable
- [ ] T046 [P] Update VALIDATION.md version references from v0.3.11 to v0.4.2 where applicable
- [ ] T047 [P] Update examples/README.md version references from v0.3.11 to v0.4.2 where applicable
- [ ] T048 Verify all version references project-wide: Run `grep -r "0\.3\.11" --exclude-dir=downloaded --exclude-dir=.git --exclude-dir=specs` to confirm no stray v0.3.11 references remain

**Checkpoint**: All user stories complete, OLM artifacts validated, ready for deployment

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - downloads v0.4.2 manifests from upstream
- **Foundational (Phase 2)**: Depends on Setup - updates Makefile version variables - BLOCKS all user stories
- **User Story 1 (Phase 3)**: Depends on Foundational - core version upgrade
- **User Story 2 (Phase 4)**: Can start after Foundational - independent of US1 (adds new CRD)
- **User Story 3 (Phase 5)**: Depends on Foundational (needs updated CSV from Phase 1) - can run parallel to US2 and US4
- **User Story 4 (Phase 6)**: Can start after Foundational - independent of US1, US2, US3 (updates different file)
- **Polish (Phase 7)**: Depends on all user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Core version upgrade - independent, can complete first
- **User Story 2 (P2)**: Add MCPGroup CRD - independent of US1, updates different files
- **User Story 3 (P3)**: Update CSV with MCPGroup ownership - requires CSV from Setup, independent of US1/US2/US4
- **User Story 4 (P3)**: Update RBAC for MCPGroup - independent of all other stories, updates different file

### Within Each User Story

- US1: Image updates can run in parallel [P], CSV updates sequential, validation last
- US2: CRD copy and kustomization update sequential, validations can be parallel [P]
- US3: All CSV updates sequential (same file), order matters
- US4: All RBAC updates sequential (same file), validations can be parallel [P]

### Parallel Opportunities

- **Phase 1 Setup**: All download tasks (T002-T007) can run in parallel [P]
- **Phase 2 Foundational**: Makefile updates are sequential (same file)
- **After Foundational completes**:
  - US1 image updates (T015, T016, T017) can run in parallel [P]
  - US2, US3, US4 can start in parallel (different files)
  - Validation tasks within each story can be parallel [P] where marked

---

## Parallel Example: After Foundational Phase

```bash
# After Phase 2 completes, these can run in parallel:

# User Story 1 - Image updates in different files:
Task T015: Update config/base/params.env operator image
Task T016: Update config/base/params.env proxy image
Task T017: Update config/manager/manager.yaml operator image

# User Story 2 - Can start independently:
Task T025: Copy MCPGroup CRD to config/crd/bases/

# User Story 3 - Can start independently:
Task T029: Add MCPGroup to CSV description

# User Story 4 - Can start independently:
Task T034: Add mcpgroups to ClusterRole
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (download manifests)
2. Complete Phase 2: Foundational (Makefile version updates)
3. Complete Phase 3: User Story 1 (core version upgrade)
4. **STOP and VALIDATE**: Run `kustomize build` for both config/default and config/base
5. Generate bundle and catalog
6. Deploy to test cluster to verify operator runs with v0.4.2 images

### Incremental Delivery

1. Complete Setup + Foundational → Version foundation ready
2. Add User Story 1 → Test independently → Operator runs with v0.4.2 (MVP!)
3. Add User Story 2 → Test independently → MCPGroup CRD available
4. Add User Story 3 → Test independently → CSV properly declares MCPGroup ownership
5. Add User Story 4 → Test independently → Operator has MCPGroup permissions
6. Each story adds capability without breaking previous functionality

### Parallel Team Strategy

With multiple developers:

1. Team completes Setup + Foundational together
2. Once Foundational is done:
   - Developer A: User Story 1 (core version upgrade)
   - Developer B: User Story 2 (MCPGroup CRD integration)
   - Developer C: User Story 3 + 4 (CSV and RBAC updates for MCPGroup)
3. Stories merge independently, validate together

---

## Notes

- [P] tasks = different files, can run in parallel without conflicts
- [Story] label maps task to specific user story for traceability
- Each user story is independently completable and testable
- Constitutional requirement: Both `kustomize build config/base` and `kustomize build config/default` MUST succeed after each story
- Validation gates after each user story ensure incremental quality
- Makefile version updates (Phase 2) are foundational and block all feature work
- MCPGroup-related changes (US2, US3, US4) can largely proceed in parallel after Foundational completes

---

## Task Summary

**Total Tasks**: 48
- Phase 1 (Setup): 8 tasks
- Phase 2 (Foundational): 6 tasks
- Phase 3 (US1 - Core Version Upgrade): 10 tasks
- Phase 4 (US2 - MCPGroup CRD): 4 tasks
- Phase 5 (US3 - CSV Ownership): 5 tasks
- Phase 6 (US4 - RBAC): 5 tasks
- Phase 7 (Polish & Validation): 10 tasks

**Parallel Opportunities**: 22 tasks marked [P] for parallel execution

**Independent Test Criteria**:
- US1: Deploy operator, verify v0.4.2 images running
- US2: Deploy MCPGroup CRD, create sample resource
- US3: Validate bundle shows MCPGroup ownership
- US4: Deploy operator, create MCPGroup, check logs for no permission errors

**Suggested MVP Scope**: Phases 1-3 (Setup + Foundational + User Story 1 = Core v0.4.2 upgrade)
