# Feature Specification: Custom Container Image Naming

**Feature Branch**: `005-custom-container-image`
**Created**: 2025-10-10
**Status**: Draft
**Input**: User description: "Custom container image naming. This project successfully builds an OLMv1 catalog container image, an OLMv0 bundle container image and as well the required index container image to use when the OLMv0 bundle is being utilized for older OpenShift versions. For each of these three container images; catalog, bundle, and index the container image registry in use, the organization within that registry in use as well as each individually unique container image name and tag combination are hard coded at the top of the Makefile for the eventual production destination. This is inflexible for development and testing purposes where a different registry, organization, and container image naming scheme may be required..."

## User Scenarios & Testing

### User Story 1 - Override Production Container Registry (Priority: P1)

A developer needs to build and test operator container images (catalog, bundle, index) using their personal container registry instead of the production registry, allowing them to iterate on changes without affecting production images or requiring production registry access.

**Why this priority**: This is the core capability that enables development and testing workflows. Without it, developers cannot build images to alternative registries, blocking all development work.

**Independent Test**: Can be fully tested by building a catalog image with a custom registry (e.g., `quay.io/developer/custom-catalog:test`) and verifying the resulting image name matches the override value instead of the production default.

**Acceptance Scenarios**:

1. **Given** a developer wants to use their own Quay.io registry, **When** they build a catalog image with custom registry specified, **Then** the image is built with the custom registry name (e.g., `quay.io/developer/toolhive-catalog:v0.2.17` instead of `ghcr.io/stacklok/toolhive/catalog:v0.2.17`)
2. **Given** no custom registry is specified, **When** the developer builds any container image, **Then** the image uses the production default registry (`ghcr.io/stacklok/...`)
3. **Given** a custom registry is specified for only the catalog image, **When** building bundle and index images, **Then** those images use their respective default registries (only catalog uses custom value)

---

### User Story 2 - Override Organization/Repository Path (Priority: P1)

A developer needs to change the organization and repository path within the registry to match their personal account or team namespace, enabling image storage in repositories they control.

**Why this priority**: Equally critical as registry override - developers need both registry and namespace control to push images to locations they have write access to.

**Independent Test**: Can be fully tested by building an image with custom organization path (e.g., `quay.io/myteam/my-operator-catalog:v0.2.17`) and verifying the full path matches the override instead of the default `stacklok/toolhive` path.

**Acceptance Scenarios**:

1. **Given** a developer wants to use their personal namespace, **When** they override the organization path for bundle image to `johndoe/toolhive-bundle`, **Then** the bundle image is built as `ghcr.io/johndoe/toolhive-bundle:v0.2.17`
2. **Given** custom registry and organization are both specified, **When** building the index image, **Then** both values are combined correctly (e.g., `quay.io/team/custom-index:v0.2.17`)
3. **Given** organization override contains slashes for nested paths, **When** building an image, **Then** the full nested path is preserved (e.g., `ghcr.io/org/subteam/project/image:tag`)

---

### User Story 3 - Override Container Image Name (Priority: P2)

A tester wants to use descriptive image names that clarify the purpose or test scenario, making it easier to identify different test builds in their registry.

**Why this priority**: Improves development workflow but is not strictly required - developers can work with default names. Helpful for organizing multiple parallel test builds.

**Independent Test**: Can be fully tested by specifying a custom image name (e.g., `toolhive-operator-catalog-experimental`) and verifying the built image uses this name instead of the default.

**Acceptance Scenarios**:

1. **Given** a tester wants descriptive names, **When** they override the catalog image name to `toolhive-operator-catalog-dev`, **Then** the catalog image is built as `ghcr.io/stacklok/toolhive-operator-catalog-dev:v0.2.17`
2. **Given** custom names for all three images (catalog, bundle, index), **When** building all images, **Then** each uses its respective custom name
3. **Given** a custom name contains hyphens and underscores, **When** building the image, **Then** the name is preserved exactly as specified

---

### User Story 4 - Override Container Image Tag (Priority: P2)

A developer wants to use custom version tags to distinguish between different development iterations or feature branches, enabling parallel testing of multiple versions.

**Why this priority**: Useful for parallel development but not critical - developers can work with default tags. Becomes more important as teams grow and multiple branches are tested simultaneously.

**Independent Test**: Can be fully tested by building an image with a custom tag (e.g., `feature-auth-v2`) and verifying the tag appears in the final image name.

**Acceptance Scenarios**:

1. **Given** a developer is working on a feature branch, **When** they override the tag to `feature-new-api`, **Then** the image is built with tag `feature-new-api` instead of `v0.2.17`
2. **Given** custom tags for catalog, bundle, and index images, **When** building all images, **Then** each image uses its respective custom tag
3. **Given** a tag contains semantic version format with metadata (e.g., `v1.0.0-rc1+build.123`), **When** building the image, **Then** the full tag format is preserved

---

### User Story 5 - Mix Default and Custom Values (Priority: P3)

A developer wants to override only specific components (e.g., just the registry) while keeping other components at their defaults, providing flexibility without requiring full specification of every component.

**Why this priority**: Convenience feature that reduces configuration burden. Nice to have but not essential - developers can specify full paths if needed.

**Independent Test**: Can be fully tested by overriding only the registry for catalog image while leaving organization, name, and tag at defaults, then verifying only the registry component changed.

**Acceptance Scenarios**:

1. **Given** only registry is overridden to `quay.io`, **When** building catalog image, **Then** the image is `quay.io/stacklok/toolhive/catalog:v0.2.17` (default org/name/tag preserved)
2. **Given** only tag is overridden to `latest`, **When** building bundle image, **Then** the image is `ghcr.io/stacklok/toolhive/bundle:latest` (default registry/org/name preserved)
3. **Given** registry and tag are overridden but organization and name use defaults, **When** building index image, **Then** both overrides and defaults are correctly combined

---

### Edge Cases

- What happens when a developer specifies an invalid registry URL format (e.g., missing protocol, invalid characters)?
- How does the system handle empty string overrides (should they be treated as "use default" or as an error)?
- What happens when the container image full path exceeds maximum length constraints for container registries?
- How does the system handle special characters in custom names that may be invalid for container image naming conventions?
- What happens when a developer tries to use a tag that conflicts with an existing image in their registry?
- How are trailing slashes in registry or organization paths handled (e.g., `quay.io/` vs `quay.io`)?
- What happens if custom values are provided via environment variables and command-line arguments simultaneously (which takes precedence)?

## Requirements

### Functional Requirements

- **FR-001**: System MUST allow developers to override the container registry for catalog images independently from bundle and index images
- **FR-002**: System MUST allow developers to override the container registry for bundle images independently from catalog and index images
- **FR-003**: System MUST allow developers to override the container registry for index images independently from catalog and bundle images
- **FR-004**: System MUST allow developers to override the organization/repository path for each of the three image types (catalog, bundle, index) independently
- **FR-005**: System MUST allow developers to override the container image name for each of the three image types independently
- **FR-006**: System MUST allow developers to override the container image tag for each of the three image types independently
- **FR-007**: System MUST use production defaults when no custom values are specified for any image component
- **FR-008**: System MUST preserve exactly these production defaults when not overridden:
  - Catalog: `ghcr.io/stacklok/toolhive/catalog:v0.2.17`
  - Bundle: `ghcr.io/stacklok/toolhive/bundle:v0.2.17`
  - Index: `ghcr.io/stacklok/toolhive/index-olmv0:v0.2.17`
- **FR-009**: System MUST support partial overrides where only specific components (registry, organization, name, or tag) are customized while others use defaults
- **FR-010**: System MUST correctly combine custom and default values to construct valid container image references (format: `registry/organization/name:tag`)
- **FR-011**: System MUST maintain separate override capabilities for all three image types without cross-contamination (catalog overrides don't affect bundle/index)
- **FR-012**: Build system MUST use the resolved image names (custom or default) when tagging, pushing, and referencing images in all build targets

### Key Entities

- **Container Image Reference**: Comprises four components - registry (e.g., `ghcr.io`), organization/path (e.g., `stacklok/toolhive`), image name (e.g., `catalog`), and tag (e.g., `v0.2.17`). Each component can be independently overridden.
- **Image Type**: Three distinct types - OLMv1 Catalog, OLMv0 Bundle, and OLMv0 Index - each with independent configuration and defaults.
- **Override Configuration**: User-provided values that replace default components for specific image types, applied at build time without modifying source files.

## Success Criteria

### Measurable Outcomes

- **SC-001**: Developers can build catalog images to their personal registry by specifying a single override value, completing the build in the same time as default builds
- **SC-002**: All three image types (catalog, bundle, index) can be built with completely custom naming (registry, organization, name, tag) without modifying Makefile source code
- **SC-003**: 100% of existing Makefile targets continue to work with default values when no overrides are specified (zero regression)
- **SC-004**: Developers can override only the registry component while preserving all other defaults, verified by inspecting final image names match expected pattern
- **SC-005**: Build system correctly handles all combinations of custom and default values for all three image types (27 test combinations: 3 images × 9 component scenarios)

## Constraints

- Overrides must not modify the Makefile source file itself (configuration via environment variables or command-line arguments only)
- Custom values must conform to container image naming conventions and registry requirements
- The override mechanism must be backward compatible with existing Makefile targets and workflows
- Production defaults must remain easily discoverable and documented within the Makefile

## Dependencies

- Existing Makefile structure and variables (BUNDLE_IMG, INDEX_OLMV0_IMG) defined in specification 004
- Container build tooling (podman/docker) must support custom image naming
- OLM catalog and bundle build processes must accept variable image names
- Existing build targets (catalog-build, bundle-build, index-olmv0-build) from specifications 001, 002, and 004

## Assumptions

- Developers have write access to their specified custom registries
- Container registries follow standard naming conventions (registry/organization/name:tag format)
- Developers understand container image naming constraints (character limits, allowed characters)
- Override mechanism will use standard Makefile variable override patterns (environment variables or command-line arguments)
- Default values represent current production configuration and should remain unchanged unless production requirements change
