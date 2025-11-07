---
description: "Task list for implementing GitHub Actions build workflows"
---

# Tasks: GitHub Actions Build Workflows

**Input**: Design documents from `/specs/014-github-build-actions/`
**Prerequisites**: plan.md, spec.md, quickstart.md

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each workflow.

## Format: `[ID] [P?] [Story] Description`
- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3)
- Include exact file paths in descriptions

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Create `.github/workflows/` directory structure for GitHub Actions

- [ ] T001 Create `.github/workflows/` directory in repository root

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Verify Makefile targets exist for all three workflows

**⚠️ CRITICAL**: All workflows depend on these Makefile targets being functional

- [ ] T002 Verify `make bundle` and `make bundle-build` targets work correctly
- [ ] T003 Verify `make index-olmv0-build` target works correctly
- [ ] T004 Verify `make catalog-build` and `make catalog-validate` targets work correctly

**Checkpoint**: Makefile targets verified - workflow implementation can begin

---

## Phase 3: User Story 1 - Manual Bundle Image Build (Priority: P1) 🎯 MVP

**Goal**: Developer can manually trigger GitHub Actions workflow to build and push bundle image to `ghcr.io/{owner}/{repo}/bundle:{version}`

**Independent Test**: Manually trigger workflow via GitHub Actions web UI, verify bundle image appears at `ghcr.io/{owner}/{repo}/bundle` with both `:{version}` and `:latest` tags

### Implementation for User Story 1

- [ ] T005 [US1] Create `.github/workflows/build-bundle.yml` workflow file with:
  - `workflow_dispatch` trigger for manual execution (FR-001)
  - `permissions: packages: write` to enable ghcr.io push (FR-009)
  - Job that checks out code
  - Step to install dependencies (yq, operator-sdk) if needed
  - Step to extract VERSION from Makefile using shell command
  - Step to run `make bundle` to generate manifests (FR-005)
  - Step using `docker/login-action@v3` to authenticate to ghcr.io with `GITHUB_TOKEN` (FR-002)
  - Step using `docker/build-push-action@v5` to build bundle using `Containerfile.bundle`
  - Image name: `ghcr.io/${{ github.repository }}/bundle` (FR-003, FR-010)
  - Tags: `{VERSION}` and `latest` (FR-004)
  - Step to echo published image URL to workflow logs (FR-011)

- [ ] T006 [US1] Add error handling to bundle workflow:
  - Fail fast if `make bundle` fails (FR-008)
  - Display clear error message if ghcr.io authentication fails (FR-008)
  - Validate VERSION extraction succeeded before building

**Checkpoint**: Bundle workflow functional - can be triggered manually and publishes to ghcr.io with repository-based naming

---

## Phase 4: User Story 2 - Manual Index Image Build (Priority: P2)

**Goal**: Developer can manually trigger GitHub Actions workflow to build and push OLMv0 index image to `ghcr.io/{owner}/{repo}/index:{version}`

**Independent Test**: Manually trigger workflow, verify index image published to `ghcr.io/{owner}/{repo}/index` with correct tags and references the bundle image

### Implementation for User Story 2

- [ ] T007 [US2] Create `.github/workflows/build-index.yml` workflow file with:
  - `workflow_dispatch` trigger for manual execution (FR-001)
  - `permissions: packages: write` to enable ghcr.io push (FR-009)
  - Job that checks out code
  - Step to install dependencies (opm) if needed
  - Step to extract VERSION from Makefile
  - Step using `docker/login-action@v3` to authenticate to ghcr.io with `GITHUB_TOKEN` (FR-002)
  - Step to run `make index-olmv0-build` to build index image (FR-006)
  - Image name: `ghcr.io/${{ github.repository }}/index` (FR-003, FR-010)
  - Tags: `{VERSION}` and `latest` (FR-004)
  - Step to push index image to ghcr.io using docker push
  - Step to echo published image URL to workflow logs (FR-011)

- [ ] T008 [US2] Add error handling to index workflow:
  - Fail fast if `make index-olmv0-build` fails (FR-008)
  - Display clear error message if bundle image reference is invalid
  - Handle case where bundle image doesn't exist locally or remotely

**Checkpoint**: Index workflow functional - can be triggered manually and publishes OLMv0 index to ghcr.io

---

## Phase 5: User Story 3 - Manual Catalog Image Build (Priority: P3)

**Goal**: Developer can manually trigger GitHub Actions workflow to build and push OLMv1 catalog image to `ghcr.io/{owner}/{repo}/catalog:{version}`

**Independent Test**: Manually trigger workflow, verify catalog image published to `ghcr.io/{owner}/{repo}/catalog` with validated FBC structure

### Implementation for User Story 3

- [ ] T009 [US3] Create `.github/workflows/build-catalog.yml` workflow file with:
  - `workflow_dispatch` trigger for manual execution (FR-001)
  - `permissions: packages: write` to enable ghcr.io push (FR-009)
  - Job that checks out code
  - Step to install dependencies (opm) if needed
  - Step to extract VERSION from Makefile
  - Step to run `make catalog-validate` to validate FBC structure (FR-007)
  - Step using `docker/login-action@v3` to authenticate to ghcr.io with `GITHUB_TOKEN` (FR-002)
  - Step using `docker/build-push-action@v5` to build catalog using `Containerfile.catalog`
  - Image name: `ghcr.io/${{ github.repository }}/catalog` (FR-003, FR-010)
  - Tags: `{VERSION}` and `latest` (FR-004)
  - Step to echo published image URL to workflow logs (FR-011)

- [ ] T010 [US3] Add error handling to catalog workflow:
  - Fail fast if `make catalog-validate` fails (FR-008)
  - Display clear error message if FBC validation fails
  - Prevent pushing invalid catalog images

**Checkpoint**: Catalog workflow functional - can be triggered manually and publishes validated OLMv1 catalog to ghcr.io

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Final validation and documentation updates

- [ ] T011 [P] Update quickstart.md with:
  - Links to the three workflow files for reference
  - Note that workflows are now available and tested
  - Examples showing actual published image URLs from test runs

- [ ] T012 [P] Validate all three workflows against success criteria:
  - SC-001: Each workflow can be triggered manually via GitHub Actions UI ✓
  - SC-002: Each workflow completes in under 5 minutes ✓
  - SC-003: Images appear in ghcr.io within 1 minute ✓
  - SC-004: 100% of images use correct repository-based URL format ✓
  - SC-005: Test in a fork to verify fork-specific ghcr.io namespace ✓
  - SC-006: Trigger all three workflows on same day without conflicts ✓
  - SC-007: Workflow logs display published image URLs ✓

- [ ] T013 Test repository-based naming in both upstream and fork:
  - Trigger bundle workflow in upstream (`stacklok/toolhive-operator-metadata`) → verify publishes to `ghcr.io/stacklok/toolhive-operator-metadata/bundle`
  - Trigger bundle workflow in fork (e.g., `roddiekieley/toolhive-operator-metadata`) → verify publishes to `ghcr.io/roddiekieley/toolhive-operator-metadata/bundle`

- [ ] T014 [P] Add README.md section documenting the new workflows:
  - Brief description of each workflow
  - How to manually trigger
  - Link to quickstart.md for full guide

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup - BLOCKS all user stories
- **User Stories (Phase 3-5)**: All depend on Foundational phase completion
  - User Story 1 (Bundle): Can start after Phase 2
  - User Story 2 (Index): Can start after Phase 2 (but may reference bundle image)
  - User Story 3 (Catalog): Can start after Phase 2
- **Polish (Phase 6)**: Depends on all user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: No dependencies on other stories - MVP candidate
- **User Story 2 (P2)**: Functionally independent (references bundle but doesn't require US1 workflow)
- **User Story 3 (P3)**: Completely independent

### Within Each User Story

- Workflow file creation is single task
- Error handling added to same file after core workflow works
- Can test immediately after each workflow creation

### Parallel Opportunities

- T002, T003, T004 (Foundational verification) can run in parallel if using separate shell sessions
- After Phase 2: T005, T007, T009 (workflow file creation) can theoretically be worked in parallel by different developers
- T011, T012, T014 (Polish phase documentation) can run in parallel

---

## Parallel Example: Workflow Creation

```bash
# After Foundational phase (Phase 2) completes, all three workflows can be created in parallel:

# Developer A:
Task: "Create .github/workflows/build-bundle.yml workflow file"

# Developer B:
Task: "Create .github/workflows/build-index.yml workflow file"

# Developer C:
Task: "Create .github/workflows/build-catalog.yml workflow file"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (create `.github/workflows/` directory)
2. Complete Phase 2: Foundational (verify Makefile targets work)
3. Complete T005-T006: User Story 1 (bundle workflow)
4. **STOP and VALIDATE**: Manually trigger bundle workflow, verify image published to ghcr.io
5. If successful, this is a working MVP

### Incremental Delivery

1. Complete Setup + Foundational → Makefile targets verified
2. Add User Story 1 (bundle workflow) → Test independently → Workflow live (MVP!)
3. Add User Story 2 (index workflow) → Test independently → OLMv0 support added
4. Add User Story 3 (catalog workflow) → Test independently → OLMv1 support complete
5. Polish phase → Documentation updated, all workflows validated

### Sequential Strategy (Recommended)

Given the small scope (3 workflow files), sequential implementation in priority order is recommended:

1. Phase 1-2: Setup + Foundational (required baseline)
2. Phase 3: User Story 1 (bundle) → Test → Commit
3. Phase 4: User Story 2 (index) → Test → Commit
4. Phase 5: User Story 3 (catalog) → Test → Commit
5. Phase 6: Polish and documentation

---

## Notes

- [P] tasks = different files or independent operations
- [Story] label maps task to specific user story
- Each workflow should be independently testable via manual trigger
- Workflows use existing Makefile targets (FR-012) - no duplicate build logic
- Repository-based naming ensures forks work correctly (FR-010)
- GITHUB_TOKEN has built-in permissions for ghcr.io (no PAT needed)
- Test workflows in both upstream and fork environments to verify naming
- Commit after each user story phase for clean git history