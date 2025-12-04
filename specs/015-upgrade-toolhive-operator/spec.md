# Feature Specification: Upgrade ToolHive Operator to v0.6.11

**Feature Branch**: `015-upgrade-toolhive-operator`
**Created**: 2025-11-24
**Status**: Draft
**Input**: User description: "Upgrade v0.6.11. This project has been building out its functionality utilizing the tagged toolhive-operator container image version v0.3.11 and was just upgraded to v0.4.2 via specification 012. Now there is a newer version of the ToolHive Operator available, v0.6.11, the source for which is located at https://github.com/stacklok/toolhive/tree/v0.6.11. Associated with this newer version of the ToolHive Operator, v0.6.11, is a helm chart utilized to install the required custom resource definitions. This corresponding version of custom resource definitions, that is crds, is tagged and made available separately as tag toolhive-operator-crds-0.0.74 at https://github.com/stacklok/toolhive/tree/toolhive-operator-crds-0.0.74/deploy/charts/operator-crds. Associated with this newer version of the ToolHive Operator, v0.6.11, is a helm chart utilized to install the v0.6.11 operator itself and this helm chart is versioned and tagged separately with the corresponding version being toolhive-operator-0.5.8 available at https://github.com/stacklok/toolhive/tree/toolhive-operator-0.5.8/deploy/charts/operator. Since the upgrade to v0.4.2, which was previously reflected in this project there have been a number of important changes in the in between releases that are summarized on the releases page at https://github.com/stacklok/toolhive/releases. These changes include updated crds, new crds, a new operand container image for vmcp referenced in the operator helm chart as well as new RBAC permissions. This project needs to be updated to include the latest v0.6.11 ToolHive Operator aligned operand versions, the updated and new crds, and any other associated configuration changes referenced by the working helm charts from the toolhive-operator-0.5.8 and toolhive-operator-crds-0.0.74 tags referenced previously. Be sure to check the git commit log between the v0.4.2 tag and toolhive-operator-0.5.8 tag as the toolhive-operator-0.5.8 tag has the helm charts updated and contains a fix on top of the v0.6.11 tag. Use this git commit log check to identify any potential changes that impact this project but were not mentioned here or in the release notes."

## Overview

This specification defines the requirements for upgrading the ToolHive Operator metadata from v0.4.2 to v0.6.11. The upgrade encompasses updating Custom Resource Definitions (CRDs), operator container images, operand images (including the new vmcp component), RBAC permissions, and configuration files to align with the official helm charts from toolhive-operator-0.5.8 and toolhive-operator-crds-0.0.74.

The upgrade ensures that users deploying the ToolHive Operator through OLM catalogs receive the latest features, bug fixes, and security updates while maintaining compatibility with both modern OpenShift (4.19+) and legacy (4.15-4.18) environments.

## User Scenarios & Testing

### User Story 1 - Update Core Operator Version (Priority: P1)

As an OpenShift cluster administrator, I need the operator metadata to reference ToolHive Operator v0.6.11 so that when I deploy the operator through OLM, I receive the latest stable version with all accumulated bug fixes and security patches since v0.4.2.

**Why this priority**: This is the foundational change that enables all other updates. Without updating the core operator version, none of the new features, CRDs, or operand images can be utilized.

**Independent Test**: Can be fully tested by deploying the updated catalog to a test cluster, installing the operator through OperatorHub, and verifying the operator pod runs with v0.6.11 images. Delivers immediate value through access to bug fixes and security updates from releases v0.5.0 through v0.6.11.

**Acceptance Scenarios**:

1. **Given** an OpenShift cluster with the updated catalog installed, **When** an administrator browses OperatorHub for ToolHive Operator, **Then** version v0.6.11 is displayed as the available version
2. **Given** an administrator installs ToolHive Operator v0.6.11 from OperatorHub, **When** the installation completes, **Then** the operator pod runs the ghcr.io/stacklok/toolhive/operator:v0.6.11 image
3. **Given** the operator pod is running, **When** checking the operator logs or version endpoint, **Then** the version reports as v0.6.11
4. **Given** an existing v0.4.2 installation, **When** upgrading to v0.6.11 through OLM, **Then** the upgrade completes successfully without data loss or service interruption

---

### User Story 2 - Update Custom Resource Definitions (Priority: P1)

As a developer deploying MCP servers, I need access to the latest CRD schemas from toolhive-operator-crds-0.0.74 so that I can utilize new features like PVC source in MCPRegistry, Output Schema Support in CompositeToolSpec, and Kubernetes source type for registry servers.

**Why this priority**: CRD updates are critical as they define the API contract. Without updated CRDs, users cannot access new functionality introduced in intermediate releases, and existing resources may not validate correctly.

**Independent Test**: Can be fully tested by applying the updated CRDs to a test cluster, creating sample resources using new fields (e.g., MCPRegistry with PVC source), and verifying they are accepted and processed correctly. Delivers value by unlocking new capabilities without requiring operator deployment.

**Acceptance Scenarios**:

1. **Given** the updated CRDs are applied to a cluster, **When** creating an MCPRegistry resource with PVC source configuration, **Then** the resource is accepted and validates successfully
2. **Given** the updated CRDs are installed, **When** listing available API versions for toolhive.stacklok.dev resources, **Then** all new and updated resource types from v0.6.11 are present
3. **Given** existing v0.4.2 custom resources, **When** upgrading CRDs to v0.6.11, **Then** existing resources remain valid and functional
4. **Given** a CompositeToolSpec resource, **When** defining Output Schema Support fields, **Then** the schema validation accepts the new fields

---

### User Story 3 - Add vmcp Operand Image References (Priority: P2)

As an operator maintainer, I need the operator metadata to reference the new vmcp operand image (ghcr.io/stacklok/toolhive/vmcp:v0.6.11) so that VirtualMCPServer resources can be deployed correctly when users create them.

**Why this priority**: This enables new functionality (VirtualMCPServer) introduced in v0.6.x releases. While critical for users needing this feature, it's secondary to ensuring the base operator and CRDs are updated correctly.

**Independent Test**: Can be fully tested by deploying the operator, creating a VirtualMCPServer resource, and verifying that the correct vmcp:v0.6.11 image is pulled and the workload starts successfully. Delivers value by enabling virtual MCP server deployments.

**Acceptance Scenarios**:

1. **Given** the updated operator is installed, **When** a user creates a VirtualMCPServer resource, **Then** the operator deploys a vmcp container using the ghcr.io/stacklok/toolhive/vmcp:v0.6.11 image
2. **Given** a deployed VirtualMCPServer, **When** checking the running pods, **Then** the vmcp container is present and running
3. **Given** the operator CSV, **When** examining related images metadata, **Then** vmcp:v0.6.11 is listed as a related image
4. **Given** ExternalAuthConfig resources, **When** referenced by a VirtualMCPServer, **Then** the vmcp operand correctly discovers and applies the auth configuration

---

### User Story 4 - Update RBAC Permissions (Priority: P2)

As a cluster administrator, I need the operator's RBAC permissions updated to match the helm chart from toolhive-operator-0.5.8 so that the operator can properly manage new resources like MCPRegistry API server resources and function with expanded capabilities.

**Why this priority**: Missing RBAC permissions can prevent the operator from functioning correctly, but this is a dependency of the new features rather than a standalone capability. It's tested as part of feature verification.

**Independent Test**: Can be fully tested by deploying the operator with updated RBAC, creating resources that require the new permissions (e.g., MCPRegistry with API server), and verifying the operator can manage them without permission errors. Delivers value by preventing runtime authorization failures.

**Acceptance Scenarios**:

1. **Given** the updated operator with new RBAC permissions, **When** creating MCPRegistry resources that spawn API server components, **Then** the operator successfully creates all required Kubernetes resources without permission errors
2. **Given** leader election is enabled, **When** multiple operator replicas are running, **Then** leader election functions correctly using the updated configmaps, leases, and events permissions
3. **Given** the operator is managing resources across allowed namespaces, **When** resources are created or modified, **Then** all operations complete successfully within the RBAC scope
4. **Given** the ClusterServiceVersion RBAC section, **When** comparing to toolhive-operator-0.5.8 helm chart, **Then** all required permissions are present

---

### User Story 5 - Update proxyrunner Image Reference (Priority: P3)

As an operator maintainer, I need the proxyrunner image reference updated to ghcr.io/stacklok/toolhive/proxyrunner:v0.6.11 so that MCP server proxy components use the latest version aligned with the operator.

**Why this priority**: While important for consistency and accessing bug fixes in the proxy runner, this is less critical than the core operator, CRDs, and new operands. Can be updated last without breaking core functionality.

**Independent Test**: Can be fully tested by creating an MCPServer resource that uses the proxy runner, verifying the correct v0.6.11 image is deployed, and confirming proxy functionality works correctly. Delivers value through bug fixes and consistency with the operator version.

**Acceptance Scenarios**:

1. **Given** the updated operator, **When** deploying an MCPServer that requires a proxy runner, **Then** the ghcr.io/stacklok/toolhive/proxyrunner:v0.6.11 image is used
2. **Given** an MCP server with proxy runner, **When** clients connect through the proxy, **Then** connections are established successfully using the v0.6.11 proxy runner
3. **Given** environment variables in the operator deployment, **When** checking the TOOLHIVE_RUNNER_IMAGE variable, **Then** it references proxyrunner:v0.6.11

---

### Edge Cases

- What happens when upgrading from v0.4.2 to v0.6.11 if users have created custom resources using v0.4.2 CRDs that contain fields removed or changed in v0.6.11?
- How does the system handle v0.4.2 installations that are still running when the v0.6.11 catalog becomes available?
- What happens if the vmcp operand image cannot be pulled due to network or registry issues?
- How does the upgrade handle cases where intermediate versions (v0.5.x, v0.6.0-v0.6.10) introduced breaking changes?
- What happens when namespace-scoped RBAC is configured but resources require cluster-scoped permissions?
- How does the system handle rollback scenarios if v0.6.11 introduces regressions?

## Requirements

### Functional Requirements

- **FR-001**: All CRD files MUST be updated to match toolhive-operator-crds-0.0.74, including new CRDs, updated API versions, and new fields
- **FR-002**: The operator container image reference MUST be updated to ghcr.io/stacklok/toolhive/operator:v0.6.11
- **FR-003**: The vmcp operand container image reference MUST be added/updated to ghcr.io/stacklok/toolhive/vmcp:v0.6.11
- **FR-004**: The proxyrunner container image reference MUST be updated to ghcr.io/stacklok/toolhive/proxyrunner:v0.6.11
- **FR-005**: RBAC permissions in the ClusterServiceVersion MUST be updated to match the helm chart from toolhive-operator-0.5.8, including permissions for MCPRegistry API server resources
- **FR-006**: The operator version in all metadata files (Makefile, CSV, annotations) MUST be updated to v0.6.11
- **FR-007**: Related images section in the CSV MUST include all operand images (operator, vmcp, proxyrunner) with v0.6.11 tags
- **FR-008**: All image references in environment variables (e.g., TOOLHIVE_RUNNER_IMAGE) MUST use v0.6.11 tags
- **FR-009**: The upgrade MUST maintain backward compatibility with resources created under v0.4.2 where CRD schemas allow
- **FR-010**: Generated bundles and catalogs MUST validate successfully with operator-sdk and opm tools
- **FR-011**: Security context configurations from the helm chart (runAsNonRoot, drop all capabilities, readOnlyRootFilesystem) MUST be reflected in the CSV
- **FR-012**: Resource requests and limits from the helm chart (CPU: 500m, Memory: 128Mi) MUST be applied to the operator deployment
- **FR-013**: Health check and metrics port configurations (8081 for health, 8080 for metrics) MUST match the helm chart
- **FR-014**: Leader election RBAC permissions (configmaps, leases, events) MUST be included in the CSV permissions section
- **FR-015**: The CSV MUST support both OLMv0 (bundle + index) and OLMv1 (File-Based Catalog) deployment formats

### Key Entities

- **ToolHive Operator v0.6.11**: The main operator component managing MCP server lifecycle, referenced as ghcr.io/stacklok/toolhive/operator:v0.6.11
- **Custom Resource Definitions**: Kubernetes API extensions defining MCPServer, MCPRegistry, VirtualMCPServer, CompositeToolSpec, and other ToolHive resource types, sourced from toolhive-operator-crds-0.0.74
- **vmcp Operand**: Virtual MCP server component deployed by the operator when VirtualMCPServer resources are created, using image ghcr.io/stacklok/toolhive/vmcp:v0.6.11
- **proxyrunner Operand**: Proxy component for MCP servers, using image ghcr.io/stacklok/toolhive/proxyrunner:v0.6.11
- **ClusterServiceVersion (CSV)**: OLM metadata describing the operator's capabilities, permissions, and deployment configuration
- **Helm Charts**: Source of truth for configuration (toolhive-operator-0.5.8 for operator, toolhive-operator-crds-0.0.74 for CRDs)

## Success Criteria

### Measurable Outcomes

- **SC-001**: Operators deployed from the updated catalog run with all three v0.6.11 images (operator, vmcp, proxyrunner) within 5 minutes of installation
- **SC-002**: All CRDs from toolhive-operator-crds-0.0.74 validate successfully and can be applied to Kubernetes clusters version 1.25 or higher
- **SC-003**: The operator successfully manages at least one instance each of MCPServer, MCPRegistry, and VirtualMCPServer resources using new v0.6.11 features
- **SC-004**: Catalog validation with opm completes with zero errors for both OLMv1 File-Based Catalog and OLMv0 index formats
- **SC-005**: Bundle validation with operator-sdk completes with zero errors and scorecard tests pass
- **SC-006**: Upgrade from v0.4.2 to v0.6.11 in a test cluster completes in under 10 minutes with zero resource recreation or data loss
- **SC-007**: The operator functions correctly with both cluster-scoped and namespace-scoped RBAC configurations as defined in the helm chart
- **SC-008**: All configuration parameters from toolhive-operator-0.5.8 helm chart (replicas, resources, security contexts, ports) are accurately reflected in the generated CSV

## Scope

### In Scope

- Updating all CRD files to match toolhive-operator-crds-0.0.74
- Updating operator container image reference to v0.6.11
- Adding/updating vmcp operand image reference to v0.6.11
- Updating proxyrunner image reference to v0.6.11
- Updating RBAC permissions to match toolhive-operator-0.5.8 helm chart
- Updating version references in Makefile, CSV, and metadata files
- Ensuring catalog and bundle validation passes with updated content
- Verifying compatibility with OLMv0 (legacy OpenShift 4.15-4.18) and OLMv1 (modern OpenShift 4.19+)
- Analyzing git commit log between v0.4.2 and toolhive-operator-0.5.8 for undocumented changes
- Testing upgrade path from v0.4.2 to v0.6.11

### Out of Scope

- Modifying the project's constitution or build workflow processes
- Changing the GitHub Actions workflows (unless directly impacted by version updates)
- Adding new custom icons or branding elements
- Implementing features from v0.7.0 or later versions
- Backporting v0.6.11 features to v0.4.2 for compatibility
- Creating migration scripts for resources that may have breaking changes (users are responsible for adapting their resource definitions)
- Supporting Kubernetes versions older than 1.25 (as per helm chart prerequisites)

## Dependencies

- ToolHive upstream repository at https://github.com/stacklok/toolhive
- Helm charts at toolhive-operator-0.5.8 and toolhive-operator-crds-0.0.74 tags
- Access to ghcr.io/stacklok/toolhive container registry for pulling operator and operand images
- operator-sdk tool for bundle generation and validation
- opm tool for catalog generation and validation
- Git access to analyze commit differences between v0.4.2 and toolhive-operator-0.5.8

## Assumptions

- The helm charts at toolhive-operator-0.5.8 and toolhive-operator-crds-0.0.74 are the definitive source of truth for v0.6.11 configuration
- The project's existing Makefile-based build process for generating bundles and catalogs remains unchanged
- CRD schema changes between v0.4.2 and v0.6.11 maintain backward compatibility for existing resources unless explicitly noted in release notes
- The vmcp operand is required for VirtualMCPServer functionality and was not present in v0.4.2
- RBAC permissions from the helm chart are comprehensive and sufficient for all operator functionality
- The project continues to support both OLMv0 and OLMv1 deployment formats
- Container images are publicly accessible at ghcr.io and do not require authentication
- The toolhive-operator-0.5.8 tag contains fixes on top of v0.6.11 that should be incorporated

## Risks

- **Backward Compatibility**: CRD schema changes may break existing resources created under v0.4.2, requiring manual intervention during upgrades
- **Dependency on Upstream**: Reliance on specific helm chart tags means any corrections or updates to those tags require re-synchronization
- **RBAC Gaps**: Missing RBAC permissions discovered after deployment could prevent operator functionality until corrected
- **Image Availability**: If ghcr.io experiences outages or images are removed, deployment and upgrades will fail
- **Undocumented Changes**: Commit log analysis between v0.4.2 and toolhive-operator-0.5.8 may reveal undocumented changes that impact this project

## Notes

This upgrade represents a significant version jump (v0.4.2 → v0.6.11) spanning approximately 7 minor releases. Thorough testing of the upgrade path is essential to ensure stability. Special attention should be paid to the commit differences between v0.4.2 and toolhive-operator-0.5.8 as instructed to catch any changes not covered in formal release notes.

The introduction of the vmcp operand and associated VirtualMCPServer functionality represents new capabilities that were not present in v0.4.2, requiring careful integration of related RBAC permissions and container image references.
