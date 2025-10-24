# Feature Specification: Upgrade ToolHive Operator to v0.4.2

**Feature Branch**: `012-upgrade-to-0`
**Created**: 2025-10-24
**Status**: Draft
**Input**: User description: "Upgrade to 0-4-2. This project has been building out its functionality utilizing the tagged toolhive-operator container image version v0.2.17 and was just upgraded to v0.3.11 via specification 011. Now there is a newer version of the ToolHive Operator available, v0.4.2, the source for which is located at https://github.com/stacklok/toolhive/tree/v0.4.2. As a part of v0.4.2 a new custom resource defintion is included at https://github.com/stacklok/toolhive/tree/v0.4.2/deploy/charts/operator-crds/crds named toolhive.stacklok.dev_mcpgroups.yaml. The project needs to be updated to include the latest ToolHive Operator and proxyrunner versions, v0.4.2, and as well include the new MCPGroups custom resource definition or CRD. Be sure to check the git commit log between the v0.3.11 and v0.4.2 tags to identify any potential changes that impact this project but were not mentioned."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Core Version Upgrade (Priority: P1)

As an operator maintainer, I need to update all container image references and version tags from v0.3.11 to v0.4.2 so that the project deploys the latest stable ToolHive Operator release with all recent bug fixes and improvements.

**Why this priority**: This is the foundation - without updating the version references, none of the other v0.4.2 features (including the new MCPGroup CRD) will be available. All subsequent work depends on this being completed first.

**Independent Test**: Can be fully tested by building the bundle and catalog, deploying to a test cluster, and verifying the operator pod runs with v0.4.2 images. Delivers immediate value by providing access to all v0.4.2 improvements.

**Acceptance Scenarios**:

1. **Given** the Makefile contains v0.3.11 version tags, **When** I update the default version variables, **Then** CATALOG_TAG, BUNDLE_TAG, and INDEX_TAG all default to v0.4.2
2. **Given** the manager deployment uses v0.3.11 images, **When** I update the container image references, **Then** both operator and proxyrunner images reference v0.4.2
3. **Given** the bundle CSV uses v0.3.11, **When** I update the ClusterServiceVersion version field, **Then** the CSV name becomes toolhive-operator.v0.4.2
4. **Given** the downloaded operator manifests are for v0.3.11, **When** I fetch the v0.4.2 manifests, **Then** the downloaded directory contains v0.4.2 manifests

---

### User Story 2 - Add MCPGroup CRD Support (Priority: P2)

As an operator user, I need the MCPGroup custom resource definition available in the cluster so that I can organize and manage related MCP servers as logical groups with unified status tracking.

**Why this priority**: While important for advanced use cases, the operator can function without MCPGroup CRD - it's a new feature in v0.4.2 that enhances server organization but isn't required for basic operation. Users currently managing servers individually can continue to do so.

**Independent Test**: Can be fully tested by deploying only the CRD, creating a sample MCPGroup resource, and verifying it's accepted by the API server with proper status tracking. Delivers value to users who want to organize servers into logical groups.

**Acceptance Scenarios**:

1. **Given** I have downloaded the MCPGroup CRD from v0.4.2 source, **When** I add it to config/crd/bases/, **Then** the CRD file is present alongside the existing 5 CRDs
2. **Given** the CRD kustomization lists 5 CRDs, **When** I add the MCPGroup CRD reference, **Then** the kustomization.yaml includes all 6 CRDs in alphabetical order
3. **Given** the bundle contains 5 CRDs, **When** I rebuild the bundle after adding MCPGroup, **Then** the bundle manifests directory contains 6 CRD files
4. **Given** the catalog contains 5 CRD objects, **When** I rebuild the catalog after adding MCPGroup, **Then** the catalog contains 6 olm.bundle.object entries for CRDs

---

### User Story 3 - Update CSV with MCPGroup Ownership (Priority: P3)

As an OLM catalog consumer, I need the ClusterServiceVersion to declare ownership of the MCPGroup CRD so that the operator's managed resources are properly documented and the OLM understands the full scope of custom resources.

**Why this priority**: This is metadata and documentation - while important for OLM compliance and clarity, the operator and CRD will function without the CSV ownership declaration. This is about proper packaging and discoverability rather than core functionality.

**Independent Test**: Can be fully tested by validating the bundle with operator-sdk and checking that no CRD warnings are generated. Delivers value by ensuring OLM catalog metadata is complete and accurate.

**Acceptance Scenarios**:

1. **Given** the CSV lists 5 owned CRDs, **When** I add MCPGroup to the owned CRDs section, **Then** the CSV spec.customresourcedefinitions.owned array contains 6 entries
2. **Given** the CSV RBAC rules cover 5 CRDs, **When** I add mcpgroups to the RBAC permissions, **Then** cluster permissions include mcpgroups, mcpgroups/finalizers, and mcpgroups/status
3. **Given** the CSV description mentions 5 resource types, **When** I update the description, **Then** the description includes MCPGroup with a brief explanation
4. **Given** the bundle is built with updated CSV, **When** I run operator-sdk bundle validate, **Then** no warnings about missing CRD ownership appear

---

### User Story 4 - Update RBAC for MCPGroup (Priority: P3)

As a cluster administrator, I need the operator's ClusterRole to include permissions for MCPGroup resources so that the operator can manage these resources without permission errors.

**Why this priority**: While technically part of the MCPGroup feature, RBAC can be updated independently and the impact is isolated to just this one resource type. The operator will generate clear permission errors if this is missed, making it easy to identify and fix.

**Independent Test**: Can be fully tested by deploying the operator and attempting to create an MCPGroup resource - the operator logs will show whether it has the necessary permissions. Delivers value by preventing permission-related failures.

**Acceptance Scenarios**:

1. **Given** the ClusterRole lists 5 toolhive.stacklok.dev resources, **When** I add mcpgroups to the resources list, **Then** the role includes mcpgroups with full CRUD verbs
2. **Given** the operator needs to update MCPGroup status, **When** I verify the RBAC rules, **Then** mcpgroups/status subresource has get, patch, and update verbs
3. **Given** the operator uses finalizers on resources, **When** I verify the RBAC rules, **Then** mcpgroups/finalizers subresource has update verb
4. **Given** the updated RBAC is deployed, **When** the operator attempts to manage an MCPGroup, **Then** no permission denied errors appear in the operator logs

---

### Edge Cases

- What happens when the downloaded v0.4.2 manifests are not available or the download fails?
- How does the system handle version mismatches between the operator image and the CRDs in the bundle?
- What happens if a user attempts to use MCPGroup resources before the CRD is installed in the cluster?
- How are existing v0.3.11 deployments affected when the catalog is updated to v0.4.2?
- What happens if only some files are updated to v0.4.2 while others remain at v0.3.11?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: All Makefile version variables (CATALOG_TAG, BUNDLE_TAG, INDEX_TAG) MUST default to v0.4.2
- **FR-002**: All container image references to ghcr.io/stacklok/toolhive/operator MUST use the v0.4.2 tag
- **FR-003**: All container image references to ghcr.io/stacklok/toolhive/proxyrunner MUST use the v0.4.2 tag
- **FR-004**: The project MUST include the toolhive.stacklok.dev_mcpgroups.yaml CRD file from the v0.4.2 release
- **FR-005**: The CRD kustomization file MUST list all 6 CRDs including the new MCPGroup CRD
- **FR-006**: The bundle MUST contain all 6 CRD manifests when generated
- **FR-007**: The catalog MUST contain 6 CRD objects plus 1 CSV object (7 total olm.bundle.object entries) when generated
- **FR-008**: The ClusterServiceVersion MUST declare ownership of all 6 CRDs including MCPGroup
- **FR-009**: The ClusterServiceVersion MUST include RBAC cluster permissions for mcpgroups, mcpgroups/finalizers, and mcpgroups/status
- **FR-010**: The ClusterRole in config/rbac/role.yaml MUST include permissions for mcpgroups resources with all subresources
- **FR-011**: The downloaded operator manifests directory MUST be updated to v0.4.2 (located at downloaded/toolhive-operator/0.4.2/)
- **FR-012**: The ClusterServiceVersion version field MUST be updated to 0.4.2
- **FR-013**: The ClusterServiceVersion metadata.name MUST be updated to toolhive-operator.v0.4.2
- **FR-014**: The catalog schema olm.channel entries MUST reference toolhive-operator.v0.4.2
- **FR-015**: Example YAML files MUST be updated to reference v0.4.2 image tags where applicable
- **FR-016**: The params.env file in config/base/ MUST use v0.4.2 for both operator and proxyrunner images
- **FR-017**: Documentation files (README.md, examples/README.md, VALIDATION.md) MUST be updated to reference v0.4.2 where version-specific instructions exist
- **FR-018**: The CSV description MUST be updated to mention the MCPGroup resource type

### Key Entities

- **Version Tag**: Represents the semantic version string (v0.4.2) used consistently across all files and configurations
- **MCPGroup CRD**: A custom resource definition that enables grouping and organized management of MCP server instances with unified status tracking
- **Container Image Reference**: The fully qualified image path including registry, repository, and tag (e.g., ghcr.io/stacklok/toolhive/operator:v0.4.2)
- **ClusterServiceVersion (CSV)**: The OLM manifest that declares operator metadata, owned CRDs, and RBAC requirements - must be updated with v0.4.2 information and MCPGroup ownership

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: All version references in the project successfully change from v0.3.11 to v0.4.2 (verifiable by searching all files)
- **SC-002**: The bundle build process completes without errors and produces a bundle containing 6 CRD files (verifiable by listing bundle/manifests/)
- **SC-003**: The catalog build process completes without errors and produces a catalog with 7 olm.bundle.object entries (verifiable by parsing catalog YAML)
- **SC-004**: Operator-sdk bundle validation passes with no errors and at most informational warnings
- **SC-005**: The catalog deploys successfully to an OpenShift cluster and shows the ToolHive Operator v0.4.2 in the OperatorHub
- **SC-006**: All 6 CRDs become available in the cluster after installing the operator from the updated catalog (verifiable via kubectl get crds)
- **SC-007**: Users can create MCPGroup custom resources without validation errors after the operator is deployed
- **SC-008**: The operator pod runs with v0.4.2 images for both operator and proxyrunner containers (verifiable via kubectl describe pod)
- **SC-009**: The operator logs show no RBAC permission errors when managing any of the 6 resource types including MCPGroup
- **SC-010**: The project builds and validates successfully on the first attempt after all updates are complete (no iteration required)

## Assumptions

- The v0.4.2 release is stable and production-ready (based on it being tagged and released on GitHub)
- The MCPGroup CRD follows the same patterns and conventions as the existing 5 CRDs in the project
- No breaking changes exist in v0.4.2 that would require migration of existing resources or configurations
- The operator container images for v0.4.2 are available in the ghcr.io/stacklok/toolhive registry
- The project's current structure (using downloaded manifests from upstream) remains valid for v0.4.2
- The CSV patches applied in the project (OpenShift security contexts, leader election RBAC) are still applicable to v0.4.2
- Existing bundle and catalog build processes work without modification for v0.4.2 content
- The release notes for v0.4.2 (insecure HTTP OIDC for development, MCPGroup documentation) do not introduce breaking changes to this metadata project
- The quay.io development registry structure remains unchanged for the v0.4.2 images

## Scope

### In Scope

- Updating all version tags from v0.3.11 to v0.4.2 across the entire project
- Adding the MCPGroup CRD to the project's CRD collection
- Updating the ClusterServiceVersion to declare MCPGroup ownership and include RBAC permissions
- Updating the ClusterRole to grant permissions for MCPGroup resources
- Downloading or creating v0.4.2 manifests in the downloaded/toolhive-operator/0.4.2/ directory
- Updating documentation files that contain version-specific references
- Rebuilding and validating the bundle and catalog with v0.4.2 content
- Verifying all 6 CRDs (including MCPGroup) are included in both bundle and catalog

### Out of Scope

- Making functional changes beyond version updates and adding MCPGroup support
- Modifying operator behavior or configuration beyond version updates
- Updating to versions beyond v0.4.2 (e.g., v0.5.0 or later)
- Testing or validating the MCPGroup functionality itself (only ensuring the CRD is properly included)
- Migrating existing deployed instances from v0.3.11 to v0.4.2
- Creating new example MCPGroup resources or usage documentation
- Performance testing or benchmarking v0.4.2 vs v0.3.11
- Implementing the insecure HTTP OIDC feature mentioned in v0.4.2 release notes (development-only feature)
- Modifying the icon, branding, or visual elements
- Updating the bundle channel strategy or upgrade paths
