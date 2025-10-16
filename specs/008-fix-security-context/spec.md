# Feature Specification: Fix Security Context for OpenShift Compatibility

**Feature Branch**: `008-fix-security-context`
**Created**: 2025-10-16
**Status**: Draft
**Input**: User description: "Fix security context. The File Based Catalog operates correctly and allows for the instllation of the ToolHive Operator. However the ToolHive Operator does not complete installtion successfully as the Operator Pod fails to start. It fails to start with an error about the runAsUser being incorrectly set to a value of 1000 which violates the restricted-v2 security policy. We need the pod security policies set as per the documentation at https://docs.redhat.com/en/documentation/openshift_container_platform/4.19/html/authentication_and_authorization/managing-pod-security-policies so that the ToolHive Operator Pod can start successfully in the OpenShift environment which is more restrictive than most other kubernetes distributions. Example podSecurityContext values that operate successfully in OpenShift are at: https://github.com/RoddieKieley/toolhive/blob/main/deploy/charts/operator/values-openshift.yaml#L43-L46. Example containerSecurityContext values that operate successfully in OpenShift are at: https://github.com/RoddieKieley/toolhive/blob/main/deploy/charts/operator/values-openshift.yaml#L49-L56 The ToolHive Operator MUST successfully start once installed by the File Based Catalog as utilized through OperatorHub inside OpenShift. To do so requires correctly set pod and container security context constraints for OpenShift."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Successful Operator Pod Startup in OpenShift (Priority: P1)

An OpenShift cluster administrator installs the ToolHive Operator through OperatorHub using the File Based Catalog. After installation completes, the operator pod starts successfully and becomes ready without security policy violations.

**Why this priority**: This is the critical path for operator installation. Without the operator pod running, no ToolHive functionality is available. This represents the minimum viable product.

**Independent Test**: Install operator via OperatorHub in OpenShift cluster, verify pod enters Running state with all containers ready, and confirm no security context violation errors in pod events or logs.

**Acceptance Scenarios**:

1. **Given** an OpenShift cluster with restricted-v2 security policy enforced, **When** administrator installs ToolHive Operator from OperatorHub, **Then** the operator pod starts successfully with status Running and ready condition true
2. **Given** the operator pod is running, **When** administrator checks pod events and logs, **Then** no security context violation errors appear related to runAsUser or other security settings
3. **Given** an OpenShift cluster with default namespace security policies, **When** the operator pod is deployed, **Then** the pod respects the dynamically assigned UID range without hardcoded user IDs

---

### User Story 2 - Verification Across OpenShift Versions (Priority: P2)

An OpenShift cluster administrator needs to verify the ToolHive Operator works across different OpenShift versions that enforce restricted security policies.

**Why this priority**: Ensures compatibility and prevents regression across supported OpenShift versions. This extends the core functionality to broader deployment scenarios.

**Independent Test**: Deploy operator to OpenShift 4.12, 4.13, and 4.14+ clusters, verify successful pod startup on each version.

**Acceptance Scenarios**:

1. **Given** OpenShift clusters running versions 4.12 or newer, **When** ToolHive Operator is installed, **Then** the operator pod starts successfully on all tested versions
2. **Given** different OpenShift versions with varying security context implementations, **When** the operator deploys, **Then** security context settings remain compatible across versions

---

### User Story 3 - Catalog Build and Installation Flow (Priority: P3)

A development team rebuilds the File Based Catalog after security context fixes and validates the complete installation flow from catalog build to operator functionality.

**Why this priority**: Validates the end-to-end process including catalog regeneration. This ensures the fix is properly packaged and distributed.

**Independent Test**: Rebuild catalog with updated manifests, push to registry, install via OperatorHub, verify operator becomes operational.

**Acceptance Scenarios**:

1. **Given** updated operator manifests with corrected security context, **When** File Based Catalog is rebuilt, **Then** catalog build completes successfully with no validation errors
2. **Given** a fresh catalog deployment, **When** operator is installed through OperatorHub, **Then** installation succeeds and operator pod runs without security violations

---

### Edge Cases

- What happens when the operator is deployed to a namespace with custom security context constraints that are more restrictive than restricted-v2?
- How does the system handle upgrades from previous operator versions that had incorrect security context settings?
- What happens if OpenShift dynamically assigns a UID that conflicts with file system permissions required by the operator?
- How does the operator behave when deployed to standard Kubernetes clusters that don't enforce OpenShift's security policies?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Operator pod MUST NOT specify a hardcoded runAsUser value in container security context
- **FR-002**: Operator pod MUST set runAsNonRoot to true in both pod and container security contexts
- **FR-003**: Operator pod MUST include seccompProfile with type RuntimeDefault in pod security context
- **FR-004**: Operator container MUST set allowPrivilegeEscalation to false
- **FR-005**: Operator container MUST set readOnlyRootFilesystem to true
- **FR-006**: Operator container MUST drop ALL capabilities
- **FR-007**: Operator manifests MUST comply with OpenShift restricted-v2 security policy requirements
- **FR-008**: File Based Catalog MUST validate successfully when built with updated security context settings
- **FR-009**: Operator MUST start successfully when installed through OperatorHub in OpenShift environments
- **FR-010**: Security context patches MUST apply correctly during kustomize manifest build process

### Key Entities

- **Pod Security Context**: Pod-level security settings including runAsNonRoot and seccompProfile that apply to all containers
- **Container Security Context**: Container-level security settings including allowPrivilegeEscalation, readOnlyRootFilesystem, runAsNonRoot, runAsUser (when unset), and capabilities
- **Security Context Constraint**: OpenShift policy (restricted-v2) that defines allowed security context values for pods

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: ToolHive Operator pod starts successfully within 60 seconds when installed via OperatorHub in OpenShift environments with restricted-v2 policy
- **SC-002**: Zero security context violation errors appear in pod events or logs during operator deployment
- **SC-003**: Operator installation succeeds on 100% of tested OpenShift versions (4.12+) enforcing restricted security policies
- **SC-004**: File Based Catalog builds complete successfully with zero validation errors related to security context
- **SC-005**: Operator maintains full functionality (can manage MCPRegistry and MCPServer resources) while running under restricted security context

## Assumptions

- OpenShift environments are configured with default restricted-v2 security policy
- The operator container image is compatible with running as an arbitrary non-root user ID
- The operator application code does not require write access to the container root filesystem (supports readOnlyRootFilesystem)
- Kustomize overlay patches in config/base are the appropriate location for OpenShift-specific security context modifications
- The operator does not require elevated Linux capabilities beyond those available in restricted mode

## Dependencies

- Operator container image must support running with arbitrary UID (OpenShift assigns UIDs dynamically)
- Operator application must handle read-only root filesystem (write operations must use mounted volumes or temporary directories)
- Kustomize build tooling must be available to apply security context patches correctly

## Scope

**In Scope**:
- Updating pod security context in operator deployment manifests
- Updating container security context in operator deployment manifests
- Modifying OpenShift-specific kustomize patches for security context
- Validating security context settings comply with restricted-v2 policy
- Testing operator pod startup in OpenShift environments

**Out of Scope**:
- Modifications to operator application code or container image
- Changes to security context for MCP server pods managed by the operator
- Implementation of custom Security Context Constraints (SCC)
- Support for security policies stricter than restricted-v2
- Backporting fixes to previous operator versions already released
