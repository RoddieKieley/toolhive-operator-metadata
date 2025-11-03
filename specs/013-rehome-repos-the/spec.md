# Feature Specification: Repository Rehoming

**Feature Branch**: `013-rehome-repos-the`
**Created**: 2025-11-03
**Status**: Draft
**Input**: User description: "Rehome repos. The git repository home of this project has changed. It is now https://github.com/stacklok/toolhive-operator-metadata. Now the destination for the container images produced by this project can be updated to the production destination with a base url of https://ghcr.io/stacklok/toolhive/. With this base url the new destinations for the bundle, index, and catalog container images are respectively: bundle: https://ghcr.io/stacklok/toolhive/bundle, index: https://ghcr.io/stacklok/toolhive/index, catalog: https://ghcr.io/stacklok/toolhive/catalog. The project requires updating to take the new git repository location and container image destinations into account."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Update Container Image References (Priority: P1)

A developer builds OLM artifacts (bundle, catalog, index) and expects them to use the new production container image locations under `ghcr.io/stacklok/toolhive/` instead of development/test locations.

**Why this priority**: Container image references are embedded in multiple build artifacts and manifests. Incorrect references will cause deployment failures in production environments. This is the core deliverable of the rehoming effort.

**Independent Test**: Can be fully tested by running `make olm-all` and verifying that all generated manifests (bundle CSV, catalog FBC, index) contain only the new production image URLs (`ghcr.io/stacklok/toolhive/bundle`, `ghcr.io/stacklok/toolhive/catalog`, `ghcr.io/stacklok/toolhive/index`).

**Acceptance Scenarios**:

1. **Given** the Makefile defines image destinations, **When** a developer runs `make bundle`, **Then** the generated ClusterServiceVersion contains bundle image reference `ghcr.io/stacklok/toolhive/bundle:v[VERSION]`
2. **Given** the project builds a catalog, **When** a developer runs `make catalog`, **Then** the generated file-based catalog references `ghcr.io/stacklok/toolhive/bundle:v[VERSION]`
3. **Given** the project builds an index for OLMv0, **When** a developer runs `make index-olmv0-build`, **Then** the index image is tagged as `ghcr.io/stacklok/toolhive/index:v[VERSION]`
4. **Given** all build targets complete, **When** a developer inspects all generated artifacts, **Then** no references to old/development image locations remain

---

### User Story 2 - Update Documentation References (Priority: P2)

A developer or operator reads project documentation and sees references to the correct repository location (`github.com/stacklok/toolhive-operator-metadata`) and production container registry (`ghcr.io/stacklok/toolhive/`).

**Why this priority**: Documentation guides users on where to find source code and how to reference container images. Outdated references cause confusion and may lead users to incorrect/deprecated resources. However, this doesn't block builds, making it lower priority than P1.

**Independent Test**: Can be fully tested by searching all documentation files (README.md, CLAUDE.md, VALIDATION.md, etc.) for repository and image URL patterns and verifying they match the new locations.

**Acceptance Scenarios**:

1. **Given** documentation files exist, **When** a user reads the README, **Then** all repository URLs point to `https://github.com/stacklok/toolhive-operator-metadata`
2. **Given** documentation describes container images, **When** a user reads image examples, **Then** all container image references use the `ghcr.io/stacklok/toolhive/` base URL
3. **Given** inline code examples exist, **When** a user copies commands from documentation, **Then** the commands reference the correct repository and image locations

---

### User Story 3 - Verify Version Consistency (Priority: P3)

A developer runs version consistency checks and confirms that all image references across the repository use the correct production locations.

**Why this priority**: The existing `verify-version-consistency.sh` script ensures version numbers are consistent. It should also verify that image base URLs are correct. This is valuable quality assurance but doesn't block immediate functionality.

**Independent Test**: Can be fully tested by running `make verify-version-consistency` and confirming it validates both version numbers and image base URL correctness, failing if development URLs are detected.

**Acceptance Scenarios**:

1. **Given** the verify-version-consistency script exists, **When** a developer runs it with correct image URLs, **Then** validation passes
2. **Given** an incorrect image URL exists in configuration, **When** the script runs, **Then** it fails with a clear error message identifying the incorrect URL
3. **Given** constitutional compliance checks run, **When** validating image references, **Then** the verification includes checking for production URLs

---

### Edge Cases

- What happens when a developer has local image builds with old URL patterns? (Build targets should regenerate with new URLs)
- How does the system handle mixed URL patterns during transition? (All references must be updated atomically in a single change)
- What if documentation references appear in generated artifacts? (CSV descriptions, annotations should use new URLs)
- How are historical references in git history handled? (History remains unchanged; only active branch files are updated)

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: All Makefile image variables MUST reference the production container registry base URL `ghcr.io/stacklok/toolhive/`
- **FR-002**: The bundle image destination MUST be `ghcr.io/stacklok/toolhive/bundle`
- **FR-003**: The catalog image destination MUST be `ghcr.io/stacklok/toolhive/catalog`
- **FR-004**: The index image destination MUST be `ghcr.io/stacklok/toolhive/index`
- **FR-005**: All documentation files MUST reference the repository location as `https://github.com/stacklok/toolhive-operator-metadata`
- **FR-006**: Generated ClusterServiceVersion MUST contain the correct bundle image reference using production URL
- **FR-007**: Generated file-based catalog MUST reference bundle images using production URL
- **FR-008**: The CLAUDE.md project instructions MUST reflect the new repository location
- **FR-009**: README.md MUST contain correct repository URLs in all sections (clone commands, links, references)
- **FR-010**: Version consistency verification MUST validate image base URLs match production registry
- **FR-011**: All kustomize configuration files MUST use correct image references if they specify container images
- **FR-012**: Build targets MUST produce artifacts with only production image URLs (no development/test URLs)

### Key Entities

- **Container Image Reference**: A URL pattern identifying where container images are stored and retrieved from, consisting of registry host, organization/project path, image name, and version tag (e.g., `ghcr.io/stacklok/toolhive/bundle:v0.4.2`)
- **Repository Reference**: A URL identifying the git repository location, used in documentation, clone commands, and metadata (e.g., `https://github.com/stacklok/toolhive-operator-metadata`)
- **Makefile Image Variables**: Configuration variables in the Makefile that define base URLs, image names, and complete image references used throughout the build process
- **Generated Artifacts**: OLM manifests (CSV, FBC catalog, index) that embed container image references and must reflect production URLs

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Running `make olm-all` produces artifacts with 100% of image references using production URLs (`ghcr.io/stacklok/toolhive/`)
- **SC-002**: Running `make verify-version-consistency` validates image base URLs and fails if non-production URLs are detected
- **SC-003**: Searching all documentation files finds zero references to old repository locations
- **SC-004**: A developer can clone the repository using the documented URL and build all artifacts successfully with production image references
- **SC-005**: All generated OLM manifests (CSV, catalog, index) pass validation with production image URLs
- **SC-006**: Constitutional compliance checks pass, confirming correct namespace placement and image references