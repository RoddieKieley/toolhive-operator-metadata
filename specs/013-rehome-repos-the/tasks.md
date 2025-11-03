# Tasks: Repository Rehoming

**Input**: Design documents from `/specs/013-rehome-repos-the/`
**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md), [quickstart.md](quickstart.md)

**Tests**: No explicit test tasks - validation is done via existing Makefile targets (kustomize-validate, bundle-validate, catalog-validate, scorecard-test, verify-version-consistency)

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`
- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions
- Repository root: `/wip/src/github.com/RHEcosystemAppEng/toolhive-operator-metadata/`
- Configuration files: `Makefile`, `config/base/params.env`, `scripts/`, documentation at root

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Prepare environment for URL updates

- [ ] T001 Verify current branch is `013-rehome-repos-the`
- [ ] T002 [P] Create backup of current Makefile for comparison
- [ ] T003 [P] Document current image URLs for rollback reference

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Identify all locations requiring URL updates - MUST be complete before ANY user story changes

**⚠️ CRITICAL**: No file modifications can begin until all URL locations are identified

- [ ] T004 Search and document all repository URL references (github.com) in Makefile, *.md, *.sh files
- [ ] T005 Search and document all container image URL references (ghcr.io) in Makefile, *.md, *.yaml, *.sh files
- [ ] T006 Search and document all bundle/catalog/index image references in Makefile and scripts/
- [ ] T007 Review `config/manager/manager.yaml` to verify no hardcoded image URLs exist

**Checkpoint**: All URL reference locations identified - configuration updates can now begin

---

## Phase 3: User Story 1 - Update Container Image References (Priority: P1) 🎯 MVP

**Goal**: Update all Makefile variables, configuration files, and scripts to use production container image URLs (ghcr.io/stacklok/toolhive/operator-bundle, operator-catalog, operator-index)

**Independent Test**: Run `make clean-all && make olm-all` and verify all generated manifests contain only production image URLs

### Implementation for User Story 1

- [ ] T008 [P] [US1] Update `BUNDLE_IMAGE` variable in `Makefile` to `ghcr.io/stacklok/toolhive/operator-bundle:v$(VERSION)`
- [ ] T009 [P] [US1] Update `CATALOG_IMAGE` variable in `Makefile` to `ghcr.io/stacklok/toolhive/operator-catalog:latest`
- [ ] T010 [P] [US1] Update `INDEX_IMAGE` variable in `Makefile` to `ghcr.io/stacklok/toolhive/operator-index:v$(VERSION)`
- [ ] T011 [US1] Update image base URLs in `config/base/params.env` if present (check for toolhive-bundle-image, toolhive-catalog-image, toolhive-index-image parameters)
- [ ] T012 [US1] Update bundle image reference in `scripts/generate-csv-from-kustomize.sh` CSV containerImage field to `ghcr.io/stacklok/toolhive/operator-bundle:${VERSION}`
- [ ] T013 [US1] Clean all generated artifacts with `make clean-all`
- [ ] T014 [US1] Rebuild all OLM artifacts with `make olm-all`
- [ ] T015 [US1] Verify generated bundle CSV contains `ghcr.io/stacklok/toolhive/operator-bundle:v[VERSION]` with `grep "containerImage:" bundle/manifests/toolhive-operator.clusterserviceversion.yaml`
- [ ] T016 [US1] Verify generated catalog FBC references `ghcr.io/stacklok/toolhive/operator-bundle:v[VERSION]` with `grep "image:" catalog/toolhive-operator-catalog.yaml`
- [ ] T017 [US1] Verify index image tagged as `ghcr.io/stacklok/toolhive/operator-index:v[VERSION]` with `podman images | grep index`
- [ ] T018 [US1] Run `make kustomize-validate` to ensure both config/base and config/default build successfully
- [ ] T019 [US1] Run `make bundle-validate` to ensure bundle structure is valid
- [ ] T020 [US1] Run `make catalog-validate` to ensure catalog FBC is valid
- [ ] T021 [US1] Run `make scorecard-test` to ensure all 6 tests pass with new image URLs

**Checkpoint**: At this point, all OLM artifacts should contain production image URLs and pass all validations

---

## Phase 4: User Story 2 - Update Documentation References (Priority: P2)

**Goal**: Update all documentation files to reference correct repository location (github.com/stacklok/toolhive-operator-metadata) and production container registry (ghcr.io/stacklok/toolhive/)

**Independent Test**: Search all documentation files for repository and image URL patterns and verify they match production locations

### Implementation for User Story 2

- [ ] T022 [P] [US2] Update repository URL references in `README.md` (git clone examples, repository links)
- [ ] T023 [P] [US2] Update container image examples in `README.md` to use `ghcr.io/stacklok/toolhive/operator-bundle`, `operator-catalog`, `operator-index`
- [ ] T024 [P] [US2] Update repository location reference in `CLAUDE.md` to `https://github.com/stacklok/toolhive-operator-metadata`
- [ ] T025 [P] [US2] Update image URL examples in `VALIDATION.md` if any exist
- [ ] T026 [P] [US2] Search for any additional documentation files with `find . -name "*.md" -not -path "./specs/*"` and update as needed
- [ ] T027 [US2] Verify no old repository URLs remain with `grep -r "RHEcosystemAppEng" --include="*.md" . || echo "No old URLs found"`
- [ ] T028 [US2] Verify documentation uses production image URLs with `grep -r "ghcr.io/stacklok/toolhive/operator-" --include="*.md" . | grep -v "^specs/" | head -10`

**Checkpoint**: At this point, all documentation should reference correct repository and production image URLs

---

## Phase 5: User Story 3 - Verify Version Consistency (Priority: P3)

**Goal**: Enhance version consistency verification to validate image base URLs match production registry

**Independent Test**: Run `make verify-version-consistency` and confirm it validates both version numbers and image base URL correctness

### Implementation for User Story 3

- [ ] T029 [US3] Add image base URL validation section to `scripts/verify-version-consistency.sh` after version checks
- [ ] T030 [US3] Define expected base URLs: `EXPECTED_BUNDLE_BASE="ghcr.io/stacklok/toolhive/operator-bundle"`, `EXPECTED_CATALOG_BASE="ghcr.io/stacklok/toolhive/operator-catalog"`, `EXPECTED_INDEX_BASE="ghcr.io/stacklok/toolhive/operator-index"`
- [ ] T031 [US3] Add check for BUNDLE_IMAGE in Makefile matches expected bundle base URL
- [ ] T032 [US3] Add check for CATALOG_IMAGE in Makefile matches expected catalog base URL
- [ ] T033 [US3] Add check for INDEX_IMAGE in Makefile matches expected index base URL
- [ ] T034 [US3] Add check for bundle CSV containerImage field in `bundle/manifests/toolhive-operator.clusterserviceversion.yaml` if bundle exists
- [ ] T035 [US3] Add failure reporting for any non-production URLs detected with clear error messages
- [ ] T036 [US3] Run `make verify-version-consistency` to test enhanced validation
- [ ] T037 [US3] Verify script passes with production URLs
- [ ] T038 [US3] Test script fails correctly by temporarily changing one URL to old pattern, verify error message, then revert

**Checkpoint**: At this point, version consistency script validates both versions and image base URLs

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Final validation and constitutional compliance verification

- [ ] T039 [P] Run complete validation suite with `make olm-all` from clean state
- [ ] T040 [P] Run `make verify-version-consistency` to confirm all version numbers and image URLs are correct
- [ ] T041 Run all constitutional compliance checks: `make kustomize-validate && make bundle-validate && make catalog-validate && make scorecard-test`
- [ ] T042 Verify no development/test URLs remain in any committed files with comprehensive grep searches
- [ ] T043 Review `git diff` to ensure all changes are intentional and correct
- [ ] T044 [P] Update quickstart.md if any implementation details changed from original plan
- [ ] T045 Clean workspace with `make clean-all` to remove build artifacts before commit

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3-5)**: All depend on Foundational phase completion
  - US1 (Container Images): Independent - can start after Foundational
  - US2 (Documentation): Independent - can start after Foundational (parallel with US1)
  - US3 (Version Consistency): Depends on US1 completion (needs production URLs in place to validate)
- **Polish (Phase 6)**: Depends on all user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2) - No dependencies on other stories
- **User Story 2 (P2)**: Can start after Foundational (Phase 2) - Independent, can run in parallel with US1
- **User Story 3 (P3)**: Depends on User Story 1 completion (validates the URLs that US1 updates)

### Within Each User Story

**User Story 1 (Container Images)**:
- T008-T010 (Makefile variables) can run in parallel [P]
- T011-T012 must run sequentially (different files but logical order)
- T013-T014 must run sequentially (clean before build)
- T015-T021 validation tasks must run sequentially after build

**User Story 2 (Documentation)**:
- T022-T026 can all run in parallel [P] (different files)
- T027-T028 must run sequentially after updates (verification)

**User Story 3 (Version Consistency)**:
- T029-T035 must run sequentially (all editing same script file)
- T036-T038 must run sequentially (testing the script)

### Parallel Opportunities

- Phase 1: All tasks (T001-T003) can run in parallel
- Phase 2: All search tasks (T004-T006) can run in parallel, T007 can run in parallel with others
- User Story 1: Makefile variables (T008-T010) can run in parallel
- User Story 2: All documentation updates (T022-T026) can run in parallel
- User Story 1 and User Story 2: Can run completely in parallel (different files, independent goals)
- Phase 6: Tasks T039-T040 and T044 can run in parallel

---

## Parallel Example: User Story 1

```bash
# Launch Makefile variable updates together:
Task: "Update BUNDLE_IMAGE variable in Makefile"
Task: "Update CATALOG_IMAGE variable in Makefile"
Task: "Update INDEX_IMAGE variable in Makefile"

# Sequential after parallel block:
Task: "Update params.env"
Task: "Update generate-csv script"
Task: "Clean and rebuild"
```

## Parallel Example: User Story 2

```bash
# Launch all documentation updates together:
Task: "Update repository URL in README.md"
Task: "Update image examples in README.md"
Task: "Update repository location in CLAUDE.md"
Task: "Update image URLs in VALIDATION.md"
Task: "Search and update additional documentation"
```

## Parallel Example: User Story 1 + User Story 2

```bash
# These two user stories can run completely in parallel:
Developer A: Complete all of User Story 1 (T008-T021)
Developer B: Complete all of User Story 2 (T022-T028)

# User Story 3 must wait for User Story 1 to complete
Developer C: Wait for US1 → Start User Story 3 (T029-T038)
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001-T003)
2. Complete Phase 2: Foundational (T004-T007) - CRITICAL identification phase
3. Complete Phase 3: User Story 1 (T008-T021) - Container image updates
4. **STOP and VALIDATE**: Run all validation targets
5. **DELIVERABLE**: All OLM artifacts use production image URLs

### Incremental Delivery

1. **Foundation** (Phases 1-2): Environment prepared, all URL locations identified
2. **MVP** (Phase 3 - US1): Container images updated → Artifacts build with production URLs → Deploy/Demo
3. **Enhanced** (Phase 4 - US2): Documentation updated → Users find correct repo and images → Deploy/Demo
4. **Complete** (Phase 5 - US3): Automated validation prevents drift → Quality gates enforced → Deploy/Demo
5. **Polished** (Phase 6): All compliance checks pass → Production ready

### Parallel Team Strategy

With multiple developers:

1. **Together**: Complete Setup (Phase 1) and Foundational (Phase 2)
2. **Parallel work** (after Phase 2 completes):
   - Developer A: User Story 1 (T008-T021) - Container images
   - Developer B: User Story 2 (T022-T028) - Documentation
3. **Sequential** (after US1 completes):
   - Developer C: User Story 3 (T029-T038) - Version validation
4. **Together**: Phase 6 Polish (T039-T045) - Final validation

---

## Task Summary

- **Total Tasks**: 45
- **Setup Phase**: 3 tasks
- **Foundational Phase**: 4 tasks
- **User Story 1 (P1)**: 14 tasks (Container Image Updates)
- **User Story 2 (P2)**: 7 tasks (Documentation Updates)
- **User Story 3 (P3)**: 10 tasks (Version Consistency Validation)
- **Polish Phase**: 7 tasks
- **Parallel Opportunities**: 12 tasks can run in parallel within phases
- **Critical Path**: Setup → Foundational → US1 → US3 → Polish

---

## Notes

- [P] tasks = different files, can run in parallel
- [Story] label maps task to specific user story (US1, US2, US3)
- No test tasks - validation done via existing Makefile targets
- Each user story delivers independent value:
  - US1: Production-ready artifacts
  - US2: Correct documentation
  - US3: Automated quality gates
- Constitutional compliance verified at multiple checkpoints
- All changes are configuration-only (no code, no CRDs, no manifests)
- Stop at any checkpoint to validate independently
- Commit after each user story phase completion