# Tasks: Executable Catalog Image

**Feature**: 006-executable-catalog-image
**Input**: Design documents from `/specs/006-executable-catalog-image/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: Tests are NOT explicitly requested in the feature specification. Validation tasks are included instead.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`
- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3, US4)
- Include exact file paths in descriptions

## Path Conventions
- **Repository root**: `/wip/src/github.com/RHEcosystemAppEng/toolhive-operator-metadata/`
- **Primary modification**: `Containerfile.catalog`
- **Validation**: `Makefile` targets and constitution checks

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization, backup, and baseline validation

- [x] T001 Create backup of current Containerfile.catalog as Containerfile.catalog.backup-pre-006
- [x] T002 Document baseline CRD hashes for constitution validation (sha256sum config/crd/bases/*.yaml > specs/006-executable-catalog-image/crd-hashes-baseline.txt)
- [x] T003 [P] Capture baseline kustomize build outputs (kustomize build config/base > specs/006-executable-catalog-image/kustomize-base-baseline.yaml && kustomize build config/default > specs/006-executable-catalog-image/kustomize-default-baseline.yaml)
- [x] T004 [P] Validate current catalog metadata structure (opm validate catalog/)

**Checkpoint**: Baseline captured, ready for Containerfile transformation

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core Containerfile transformation that enables all user stories

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T005 [Foundation] Transform Containerfile.catalog to multi-stage build (add builder stage: FROM quay.io/operator-framework/opm:latest AS builder)
- [x] T006 [Foundation] Add catalog source addition to builder stage (ADD catalog /configs)
- [x] T007 [Foundation] Add cache pre-population command to builder stage (RUN ["/bin/opm", "serve", "/configs", "--cache-dir=/tmp/cache", "--cache-only"])
- [x] T008 [Foundation] Update runtime stage base image (FROM quay.io/operator-framework/opm:latest)
- [x] T009 [Foundation] Add artifact copy commands to runtime stage (COPY --from=builder /configs /configs && COPY --from=builder /tmp/cache /tmp/cache)
- [x] T010 [Foundation] Add ENTRYPOINT configuration (ENTRYPOINT ["/bin/opm"])
- [x] T011 [Foundation] Add CMD configuration (CMD ["serve", "/configs", "--cache-dir=/tmp/cache"])
- [x] T012 [Foundation] Relocate all existing labels after COPY commands (preserve all 7 labels in same order)
- [x] T013 [Foundation] Build the transformed catalog image (make catalog-build)
- [x] T014 [Foundation] Verify build succeeded and cache was generated (check build logs for "cache" messages)

**Checkpoint**: Foundation ready - multi-stage Containerfile.catalog builds successfully, user story validation can now begin

---

## Phase 3: User Story 1 - Deploy Catalog as Running Service (Priority: P1) 🎯 MVP

**Goal**: Enable catalog image deployment as a running pod that serves operator metadata via registry-server

**Independent Test**: Deploy catalog image to Kubernetes/OpenShift cluster via CatalogSource, verify pod enters Running state and OLM can query for operator metadata

### Validation for User Story 1

- [x] T015 [US1] Inspect built catalog image metadata (podman inspect $(CATALOG_IMG) | jq '.[0].Config' to verify ENTRYPOINT and CMD)
- [x] T016 [P] [US1] Verify /configs directory structure in image (podman run --rm $(CATALOG_IMG) ls -R /configs)
- [x] T017 [P] [US1] Verify /tmp/cache directory exists in image (podman run --rm $(CATALOG_IMG) ls -R /tmp/cache)
- [x] T018 [P] [US1] Verify /bin/opm binary is present (podman run --rm $(CATALOG_IMG) ls -la /bin/opm)
- [x] T019 [P] [US1] Verify /bin/grpc_health_probe binary is present (podman run --rm $(CATALOG_IMG) ls -la /bin/grpc_health_probe)
- [x] T020 [US1] Run catalog container locally (podman run -d -p 50051:50051 --name catalog-test $(CATALOG_IMG))
- [x] T021 [US1] Verify registry-server starts successfully (podman logs catalog-test | grep -i "serving")
- [x] T022 [US1] Verify pod startup time is under 10 seconds (measure time from start to serving)
- [x] T023 [US1] Query registry-server with grpcurl (grpcurl -plaintext localhost:50051 api.Registry/ListPackages)
- [x] T024 [US1] Verify toolhive-operator package is returned from query
- [x] T025 [US1] Measure query response time is under 500ms
- [x] T026 [US1] Stop and remove test container (podman stop catalog-test && podman rm catalog-test)

**Checkpoint**: User Story 1 complete - catalog image runs as registry-server and serves metadata with acceptable performance

---

## Phase 4: User Story 2 - Validate Catalog Image Before Deployment (Priority: P2)

**Goal**: Enable developers to validate catalog image functionality locally before pushing to production registries

**Independent Test**: Build catalog image locally, run validation commands to verify registry-server configuration without requiring cluster deployment

### Implementation for User Story 2

- [x] T027 [P] [US2] Add catalog-inspect Make target (displays image labels, entrypoint, CMD, file structure)
- [x] T028 [P] [US2] Add catalog-test-local Make target (starts registry-server locally with port mapping)
- [x] T029 [P] [US2] Add catalog-validate-executable Make target (checks for required binaries and cache)
- [x] T030 [US2] Document validation workflow in quickstart.md (if not already complete)
- [x] T031 [US2] Test catalog-inspect target (make catalog-inspect)
- [x] T032 [US2] Test catalog-test-local target (make catalog-test-local)
- [x] T033 [US2] Test catalog-validate-executable target (make catalog-validate-executable)

**Checkpoint**: User Story 2 complete - developers can validate catalog image locally using Make targets

---

## Phase 5: User Story 3 - Maintain Backward Compatibility with Existing Metadata (Priority: P1)

**Goal**: Ensure executable catalog image preserves all existing OLM labels and catalog metadata structure

**Independent Test**: Compare metadata labels and catalog.yaml structure in new image against baseline, verify 100% preservation

### Validation for User Story 3

- [x] T034 [P] [US3] Verify operators.operatorframework.io.index.configs.v1 label points to /configs (podman inspect $(CATALOG_IMG) | jq -r '.[0].Config.Labels."operators.operatorframework.io.index.configs.v1"')
- [x] T035 [P] [US3] Verify all 7 labels are present (count labels in podman inspect output)
- [x] T036 [P] [US3] Compare label values against baseline (extract labels from both backup and new image, diff them)
- [x] T037 [US3] Verify catalog.yaml content is unchanged (extract from image, compare with catalog/toolhive-operator/catalog.yaml)
- [x] T038 [US3] Verify olm.package schema is preserved (check package name, defaultChannel, description, icon)
- [x] T039 [US3] Verify olm.channel schema is preserved (check channel name, entries)
- [x] T040 [US3] Verify olm.bundle schema is preserved (check bundle name, image reference, CRDs)
- [x] T041 [US3] Run opm validate against built image (opm validate $(CATALOG_IMG))
- [x] T042 [US3] Verify CRD references match expected values (MCPRegistry and MCPServer at toolhive.stacklok.dev/v1alpha1)

**Checkpoint**: User Story 3 complete - backward compatibility verified, all labels and metadata preserved

---

## Phase 6: User Story 4 - Use Pre-cached Catalog Data for Fast Startup (Priority: P3)

**Goal**: Verify catalog image includes pre-cached data for optimized registry-server startup performance

**Independent Test**: Build catalog with cache pre-population, measure startup time and verify it meets performance target (<5 seconds)

### Validation for User Story 4

- [ ] T043 [P] [US4] Inspect cache directory contents (podman run --rm $(CATALOG_IMG) find /tmp/cache -type f)
- [ ] T044 [P] [US4] Verify cache directory is non-empty (podman run --rm $(CATALOG_IMG) du -sh /tmp/cache)
- [ ] T045 [US4] Measure cold start time without pre-cache (build image with --cache-only removed, time startup)
- [ ] T046 [US4] Measure warm start time with pre-cache (use standard image, time startup)
- [ ] T047 [US4] Verify startup time improvement (compare T045 vs T046, expect 3-5x faster)
- [ ] T048 [US4] Verify first query response time with pre-cache (measure time to first successful grpcurl query)
- [ ] T049 [US4] Document cache size in image (add to quickstart.md or research.md)

**Checkpoint**: User Story 4 complete - cache optimization verified and performance benefits documented

---

## Phase 7: Constitution Compliance & Final Validation

**Purpose**: Verify constitutional requirements and overall feature completeness

- [x] T050 [P] [Constitution] Verify kustomize build config/base still succeeds (compare output against baseline from T003)
- [x] T051 [P] [Constitution] Verify kustomize build config/default still succeeds (compare output against baseline from T003)
- [x] T052 [P] [Constitution] Verify CRD files unchanged (sha256sum config/crd/bases/*.yaml, compare against T002 baseline)
- [x] T053 [Constitution] Confirm no Kubernetes manifests were modified (git status config/)
- [x] T054 [Final] Run complete validation workflow from quickstart.md (schema → build → local → optional cluster)
- [x] T055 [P] [Final] Update CLAUDE.md if needed (document Containerfile patterns, if not already updated)
- [x] T056 [P] [Final] Verify all success criteria from spec.md (SC-001 through SC-005)
- [x] T057 [Final] Clean up test containers and images (podman rm -f catalog-test, optionally prune images)

**Checkpoint**: Feature complete - all user stories validated, constitution compliant, ready for deployment

---

## Phase 8: Documentation & Polish

**Purpose**: Finalize documentation and prepare for production use

- [x] T058 [P] [Docs] Review and update quickstart.md with any missing validation steps
- [x] T059 [P] [Docs] Add troubleshooting section to quickstart.md (common issues: cache corruption, port conflicts, OLM query errors)
- [x] T060 [P] [Docs] Document OPM version used in build (add to research.md or plan.md)
- [x] T061 [Docs] Create example CatalogSource YAML for cluster deployment (examples/catalogsource-olmv1.yaml)
- [x] T062 [Polish] Remove backup file if validation passed (rm Containerfile.catalog.backup-pre-006 or document why keeping it)
- [x] T063 [Polish] Clean up baseline files (rm specs/006-executable-catalog-image/*-baseline.* or keep for future reference)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion (T001-T004) - BLOCKS all user stories
- **User Story 1 (Phase 3)**: Depends on Foundational completion (T005-T014) - MVP target
- **User Story 2 (Phase 4)**: Depends on Foundational completion - can run in parallel with US1, US3, US4
- **User Story 3 (Phase 5)**: Depends on Foundational completion - can run in parallel with US1, US2, US4
- **User Story 4 (Phase 6)**: Depends on Foundational completion - can run in parallel with US1, US2, US3
- **Constitution Compliance (Phase 7)**: Depends on all user stories (or subset if MVP only)
- **Documentation & Polish (Phase 8)**: Depends on constitution validation (T050-T053)

### User Story Dependencies

- **User Story 1 (P1) - Deploy Catalog as Running Service**: Can start immediately after Foundational (Phase 2) - No dependencies on other stories
- **User Story 2 (P2) - Validate Catalog Image Before Deployment**: Can start immediately after Foundational (Phase 2) - Independent of other stories
- **User Story 3 (P1) - Maintain Backward Compatibility**: Can start immediately after Foundational (Phase 2) - Independent of other stories
- **User Story 4 (P3) - Use Pre-cached Catalog Data**: Can start immediately after Foundational (Phase 2) - Independent of other stories

### Within Each Phase

**Phase 1 (Setup)**:
- T001 → (T002, T003, T004 can run in parallel)

**Phase 2 (Foundational)**:
- T005 → T006 → T007 → T008 → T009 → T010 → T011 → T012 (sequential - same file edits)
- T013 → T014 (sequential - build then verify)

**Phase 3 (User Story 1)**:
- T015 first (inspect image)
- T016, T017, T018, T019 can run in parallel (different inspection commands)
- T020 → T021 → T022 (sequential - start, verify, measure)
- T023 → T024 → T025 (sequential - query, verify, measure)
- T026 (cleanup)

**Phase 4 (User Story 2)**:
- T027, T028, T029 can run in parallel (different Makefile targets)
- T030 (documentation)
- T031, T032, T033 can run in parallel (test different targets)

**Phase 5 (User Story 3)**:
- T034, T035, T036 can run in parallel (label validation)
- T037 → T038 → T039 → T040 (sequential - catalog.yaml validation)
- T041, T042 can run in parallel (OPM validate and CRD check)

**Phase 6 (User Story 4)**:
- T043, T044 can run in parallel (cache inspection)
- T045 → T046 → T047 (sequential - comparative performance measurement)
- T048, T049 can run in parallel (first query and documentation)

**Phase 7 (Constitution)**:
- T050, T051, T052 can run in parallel (different validation checks)
- T053 (git status check)
- T054 (full workflow)
- T055, T056 can run in parallel (docs and criteria validation)
- T057 (cleanup)

**Phase 8 (Documentation)**:
- T058, T059, T060 can run in parallel (different doc updates)
- T061 (example file creation)
- T062, T063 can run in parallel (cleanup tasks)

### Parallel Opportunities

- **Setup Phase**: T002, T003, T004 can run in parallel (3 tasks)
- **User Story 1**: T016-T019 can run in parallel (4 tasks)
- **User Story 2**: T027-T029 can run in parallel (3 tasks), T031-T033 can run in parallel (3 tasks)
- **User Story 3**: T034-T036 can run in parallel (3 tasks), T041-T042 can run in parallel (2 tasks)
- **User Story 4**: T043-T044 can run in parallel (2 tasks), T048-T049 can run in parallel (2 tasks)
- **Constitution Phase**: T050-T052 can run in parallel (3 tasks), T055-T056 can run in parallel (2 tasks)
- **Documentation Phase**: T058-T060 can run in parallel (3 tasks), T062-T063 can run in parallel (2 tasks)
- **Cross-Story Parallelism**: After Foundational (T014), all user stories (US1-US4) can be worked on in parallel by different team members

---

## Parallel Example: User Story 1 Validation

```bash
# Launch file inspection tasks together:
Task T016: "Verify /configs directory structure in image"
Task T017: "Verify /tmp/cache directory exists in image"
Task T018: "Verify /bin/opm binary is present"
Task T019: "Verify /bin/grpc_health_probe binary is present"

# These four tasks inspect different aspects of the same image
# and can be executed in parallel since they use different commands
```

## Parallel Example: User Story 3 Label Validation

```bash
# Launch label validation tasks together:
Task T034: "Verify operators.operatorframework.io.index.configs.v1 label"
Task T035: "Verify all 7 labels are present"
Task T036: "Compare label values against baseline"

# These three tasks validate different aspects of image labels
# and can be executed in parallel
```

---

## Implementation Strategy

### MVP First (User Stories 1 + 3 Only - Both P1)

1. Complete Phase 1: Setup (T001-T004)
2. Complete Phase 2: Foundational (T005-T014) - CRITICAL, blocks all stories
3. Complete Phase 3: User Story 1 (T015-T026) - Deploy catalog as running service
4. Complete Phase 5: User Story 3 (T034-T042) - Backward compatibility verification
5. Complete Phase 7: Constitution & Final Validation (T050-T057)
6. **STOP and VALIDATE**: Test both P1 stories independently
7. Deploy/demo if ready

**Rationale**: Both US1 and US3 are priority P1. US1 provides the core executable catalog functionality, while US3 ensures no breaking changes. Together they form a complete, production-ready MVP.

### Incremental Delivery (All User Stories)

1. Complete Setup + Foundational → Foundation ready
2. Add User Story 1 + 3 (P1) → Test independently → Deploy/Demo (MVP!)
3. Add User Story 2 (P2) → Test independently → Enhanced validation capabilities
4. Add User Story 4 (P3) → Test independently → Performance optimization verified
5. Complete Constitution validation and Documentation → Production ready
6. Each phase adds value without breaking previous functionality

### Parallel Team Strategy

With multiple developers:

1. Team completes Setup + Foundational together (T001-T014)
2. Once Foundational is done (after T014):
   - Developer A: User Story 1 (T015-T026) - Deploy catalog validation
   - Developer B: User Story 2 (T027-T033) - Pre-deployment validation tooling
   - Developer C: User Story 3 (T034-T042) - Backward compatibility checks
   - Developer D: User Story 4 (T043-T049) - Cache optimization validation
3. Team reconvenes for Constitution validation (T050-T057)
4. Team completes Documentation & Polish together (T058-T063)

**Time Savings**: With 4 developers, Phases 3-6 complete in parallel (est. ~2-4 hours total) vs. sequential (est. ~8-16 hours)

---

## Notes

- [P] tasks = different commands/files, no dependencies, can run in parallel
- [Story] label maps task to specific user story for traceability (US1, US2, US3, US4, Foundation, Constitution, Docs)
- Each user story should be independently completable and testable
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- Foundational phase (T005-T014) is the critical path - all user stories depend on it
- Constitution validation (T050-T053) is mandatory before merging - ensures no manifest/CRD changes
- Avoid: modifying Kubernetes manifests (violates constitution), changing CRDs (violates constitution), breaking existing labels (violates US3)

## Task Count Summary

- **Total Tasks**: 63
- **Phase 1 (Setup)**: 4 tasks (1 sequential, 3 parallelizable)
- **Phase 2 (Foundational)**: 10 tasks (all sequential - same file)
- **Phase 3 (User Story 1)**: 12 tasks (4 parallelizable, 8 sequential)
- **Phase 4 (User Story 2)**: 7 tasks (6 parallelizable, 1 sequential)
- **Phase 5 (User Story 3)**: 9 tasks (5 parallelizable, 4 sequential)
- **Phase 6 (User Story 4)**: 7 tasks (4 parallelizable, 3 sequential)
- **Phase 7 (Constitution)**: 8 tasks (5 parallelizable, 3 sequential)
- **Phase 8 (Documentation)**: 6 tasks (5 parallelizable, 1 sequential)

**Parallel Opportunities**: 31 tasks (49%) can run in parallel with other tasks in their phase
**Critical Path**: Phase 2 (Foundational) - 10 sequential tasks that block all user stories

## MVP Scope Recommendation

**Suggested MVP**: User Stories 1 + 3 (Both P1) + Constitution Validation

- User Story 1 (T015-T026): Core executable catalog functionality - registry-server runs and serves metadata
- User Story 3 (T034-T042): Backward compatibility - no breaking changes to labels/metadata
- Constitution (T050-T053): Mandatory validation - ensures no manifest/CRD violations

**Total MVP Tasks**: 4 (Setup) + 10 (Foundation) + 12 (US1) + 9 (US3) + 4 (Constitution core) = **39 tasks**

**Optional Enhancements** (Post-MVP):
- User Story 2 (T027-T033): Pre-deployment validation tooling (nice-to-have developer UX improvement)
- User Story 4 (T043-T049): Cache optimization verification (performance already meets requirements via US1)
- Documentation & Polish (T054-T063): Can be added incrementally

This MVP delivers a fully functional, backward-compatible executable catalog image that meets all critical success criteria (SC-001 through SC-004) and passes constitutional validation.
