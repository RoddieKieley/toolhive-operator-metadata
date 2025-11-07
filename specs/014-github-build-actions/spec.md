# Feature Specification: GitHub Actions Build Workflows

**Feature Branch**: `014-github-build-actions`
**Created**: 2025-11-06
**Status**: Draft
**Input**: User description: "Github build actions to build bundle, index (OLMv0), and catalog (OLMv1) container images with manual trigger capability. Images publish to ghcr.io using repository-based naming (ghcr.io/{owner}/{repo}/{type})."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Manual Bundle Image Build (Priority: P1)

A developer needs to publish a new bundle image version to GitHub Container Registry. They navigate to the GitHub Actions tab, manually trigger the bundle build workflow, and the workflow builds and pushes the bundle image to `ghcr.io/{owner}/{repo}/bundle:{version}`.

**Why this priority**: Bundle images are the core OLM artifact required for operator distribution. Without bundle images published to ghcr.io, the operator cannot be installed via OLM.

**Independent Test**: Can be fully tested by manually triggering the workflow via GitHub web UI and verifying the bundle image appears in ghcr.io packages with correct repository-based naming.

**Acceptance Scenarios**:

1. **Given** a developer has push access to the repository, **When** they trigger the bundle build workflow manually via GitHub Actions UI, **Then** the workflow builds the bundle image and pushes it to `ghcr.io/{owner}/{repo}/bundle:{version}`
2. **Given** the workflow runs in `stacklok/toolhive-operator-metadata`, **When** the bundle image is pushed, **Then** it is published to `ghcr.io/stacklok/toolhive-operator-metadata/bundle`
3. **Given** the workflow runs in `roddiekieley/toolhive-operator-metadata`, **When** the bundle image is pushed, **Then** it is published to `ghcr.io/roddiekieley/toolhive-operator-metadata/bundle`
4. **Given** the workflow completes successfully, **When** a user checks ghcr.io packages, **Then** both `:{version}` and `:latest` tags are available

---

### User Story 2 - Manual Index Image Build (Priority: P2)

A developer needs to publish an OLMv0 index image for legacy OpenShift compatibility. They manually trigger the index build workflow, which builds the SQLite-based index image and pushes it to `ghcr.io/{owner}/{repo}/index:{version}`.

**Why this priority**: Index images support legacy OpenShift 4.15-4.18 deployments. While important for backward compatibility, it's lower priority than the bundle which is required for all OLM versions.

**Independent Test**: Can be fully tested by manually triggering the workflow and verifying the index image is published to ghcr.io with correct repository-based naming, and that it contains the bundle reference.

**Acceptance Scenarios**:

1. **Given** a developer has push access to the repository, **When** they trigger the index build workflow manually, **Then** the workflow builds the OLMv0 index image and pushes it to `ghcr.io/{owner}/{repo}/index:{version}`
2. **Given** the bundle image exists locally or in ghcr.io, **When** the index workflow runs, **Then** it successfully creates an index referencing the bundle image
3. **Given** the workflow completes successfully, **When** checking the index image, **Then** both `:{version}` and `:latest` tags are published

---

### User Story 3 - Manual Catalog Image Build (Priority: P3)

A developer needs to publish an OLMv1 catalog image for modern OpenShift 4.19+ deployments. They manually trigger the catalog build workflow, which builds the File-Based Catalog image and pushes it to `ghcr.io/{owner}/{repo}/catalog:{version}`.

**Why this priority**: Catalog images are for modern OLMv1 deployments. While this is the future direction, bundle and index images are needed first for complete OLM support across all versions.

**Independent Test**: Can be fully tested by manually triggering the workflow and verifying the catalog image is published with correct FBC metadata and repository-based naming.

**Acceptance Scenarios**:

1. **Given** a developer has push access to the repository, **When** they trigger the catalog build workflow manually, **Then** the workflow builds the catalog image and pushes it to `ghcr.io/{owner}/{repo}/catalog:{version}`
2. **Given** the workflow validates the FBC structure, **When** building the catalog, **Then** `opm validate` passes before the image is pushed
3. **Given** the workflow completes successfully, **When** checking ghcr.io packages, **Then** both `:{version}` and `:latest` tags are available

---

### Edge Cases

- What happens when the workflow runs without required dependencies (yq, podman)? → Workflow fails with clear error message
- How does the system handle authentication failures to ghcr.io? → Workflow fails with authentication error, suggests checking GITHUB_TOKEN permissions
- What happens when a developer without push permissions tries to run the workflow? → Workflow fails with permission denied error
- How are concurrent workflow runs handled (two developers trigger same workflow)? → GitHub Actions queues runs, executes sequentially
- What happens when pushing an image that already exists with the same tag? → Image is overwritten (standard registry behavior)
- How does repository-based naming work in forks? → Each fork publishes to its own ghcr.io namespace (e.g., `ghcr.io/fork-owner/repo-name/bundle`)

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Each workflow (bundle, index, catalog) MUST be manually triggerable via GitHub Actions web UI using `workflow_dispatch`
- **FR-002**: Each workflow MUST use the built-in `GITHUB_TOKEN` for ghcr.io authentication
- **FR-003**: Each workflow MUST push images to `ghcr.io/{repository_owner}/{repository_name}/{image_type}` where image_type is `bundle`, `index`, or `catalog`
- **FR-004**: Each workflow MUST tag images with both the specific version (e.g., `v0.4.2`) and `latest`
- **FR-005**: The bundle workflow MUST generate bundle manifests using `make bundle` before building the image
- **FR-006**: The index workflow MUST build an OLMv0 SQLite-based index using `make index-olmv0-build`
- **FR-007**: The catalog workflow MUST validate FBC structure using `make catalog-validate` before building the image
- **FR-008**: Each workflow MUST fail fast with clear error messages if prerequisites (build tools, manifests) are missing
- **FR-009**: Each workflow MUST set proper permissions to write to packages (`packages: write`)
- **FR-010**: The image naming MUST work correctly regardless of which repository fork is running the workflow
- **FR-011**: Each workflow MUST display the published image URL in the workflow logs for easy verification
- **FR-012**: Workflows MUST use the existing Makefile targets for consistency with local development

### Key Entities

- **GitHub Workflow**: An automated process defined in `.github/workflows/` that builds and publishes container images
- **Container Image**: A packaged artifact (bundle, index, or catalog) pushed to ghcr.io with repository-specific naming
- **Image Tag**: A version identifier (e.g., `v0.4.2`, `latest`) applied to published images
- **Repository Context**: GitHub-provided variables (`github.repository`, `github.repository_owner`) used to construct image URLs dynamically

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A developer can trigger any of the three workflows (bundle, index, catalog) manually via the GitHub Actions web UI
- **SC-002**: Each workflow completes successfully in under 5 minutes on average
- **SC-003**: Published images appear in ghcr.io packages within 1 minute of workflow completion
- **SC-004**: 100% of images are published to the correct repository-based URL (`ghcr.io/{owner}/{repo}/{type}`)
- **SC-005**: When testing in a fork (e.g., `roddiekieley/toolhive-operator-metadata`), images are published to the fork's ghcr.io namespace, not the upstream repository
- **SC-006**: All three workflows can run successfully on the same day without conflicts or failures
- **SC-007**: Workflow logs clearly display the published image URL for immediate verification

## Assumptions

- GitHub Actions has built-in `GITHUB_TOKEN` with sufficient permissions for ghcr.io (standard for repo workflows)
- Developers have push access to the repository to trigger workflows manually
- The repository already has correct Makefile targets for building bundle, index, and catalog
- The project version (e.g., `v0.4.2`) is defined in the Makefile and can be extracted by workflows
- Podman/Docker-compatible build tools are available in GitHub Actions runners (standard ubuntu-latest has Docker)
- Repository naming change to `ghcr.io/{owner}/{repo}/bundle` (vs `ghcr.io/{owner}/project/bundle`) has already been applied to Makefile variables