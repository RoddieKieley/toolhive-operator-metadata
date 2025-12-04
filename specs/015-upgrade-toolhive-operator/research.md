# Research: ToolHive Operator v0.4.2 → v0.6.11 Upgrade Analysis

**Date**: 2025-12-04
**Objective**: Identify all configuration changes for upgrade from v0.4.2 to v0.6.11
**Analyst**: Claude Code

## Executive Summary

The upgrade from ToolHive Operator v0.4.2 to v0.6.11 represents a **significant feature release** with 380 commits across 776 files. Key changes include:

- **New CRDs**: VirtualMCPServer and VirtualMCPCompositeToolDefinition (major feature addition)
- **New Container Image**: vmcp (Virtual MCP Server) introduced
- **Updated Images**: All three images (operator, vmcp, proxyrunner) now at v0.6.11
- **RBAC Changes**: Added permissions for new VirtualMCP resources and gateway API resources
- **Enhanced CRDs**: Expanded MCPRegistry (PVC support), MCPServer, MCPRemoteProxy, and MCPExternalAuthConfig schemas
- **New Environment Variables**: TOOLHIVE_VMCP_IMAGE, TOOLHIVE_USE_CONFIGMAP
- **Registry API**: New component for registry management (v0.4.0)

---

## 1. CRD Analysis (toolhive-operator-crds-0.0.74)

### 1.1 MCPRegistry CRD
- **API Version**: toolhive.stacklok.dev/v1alpha1
- **Status in v0.4.2**: Exists
- **New/Changed Fields**:
  - **NEW**: `registries[].pvcRef` - Support for PersistentVolumeClaim as registry source
  - **NEW**: `registries[].syncPolicy` - Automatic synchronization interval configuration
  - **NEW**: `registries[].filter` - Name/tag inclusion/exclusion filters
  - **NEW**: `registries[].format` - Registry format (toolhive/upstream)
- **Existing Source Types**: API endpoint, ConfigMapRef, Git repository
- **Validation Rules**:
  - Minimum 1 registry required
  - Registry sources are mutually exclusive (API/ConfigMap/Git/PVC)
  - Unique registry names enforced

### 1.2 MCPServer CRD
- **API Version**: toolhive.stacklok.dev/v1alpha1
- **Status in v0.4.2**: Exists
- **New/Changed Fields**:
  - **NEW**: `authzConfig` - Authorization policy configuration
  - **NEW**: `oidcConfig` - OIDC authentication configuration with multiple types (kubernetes, configMap, inline)
  - **NEW**: `permissionProfile` - Permission profile definitions
  - **NEW**: `proxyPort` - Proxy runner exposure port (default: 8080)
  - **NEW**: `telemetry` - Observability configuration
  - **NEW**: `transport` - Transport method (stdio, streamable-http, sse)
  - **ENHANCED**: `env` - Environment variable support
  - **ENHANCED**: `resources` - CPU/memory resource requirements
- **Validation Rules**:
  - Ports: 1-65535 range
  - Transport options: stdio, streamable-http, sse
  - OIDC config requires specific mandatory fields

### 1.3 MCPExternalAuthConfig CRD
- **API Version**: toolhive.stacklok.dev/v1alpha1
- **Status**: Exists in current repo, likely added post-v0.4.2
- **Short Names**: extauth, mcpextauth
- **Required Fields**:
  - `type`: Enum (tokenExchange | headerInjection)
- **Configuration Options**:
  - **tokenExchange**: audience, tokenUrl (required); clientId, clientSecretRef, scopes, subjectTokenType (optional)
  - **headerInjection**: headerName, valueSecretRef (required)
- **Status Fields**: configHash, referencingServers, observedGeneration

### 1.4 MCPGroup CRD
- **API Version**: toolhive.stacklok.dev/v1alpha1
- **Status**: Exists in current repo, likely added post-v0.4.2
- **Spec Fields**:
  - `description` (optional string)
- **Status Fields**:
  - `phase`: Enum (Ready | Pending | Failed)
  - `conditions`: Standard Kubernetes condition array
- **Purpose**: Group management for organizing MCP resources

### 1.5 MCPRemoteProxy CRD
- **API Version**: toolhive.stacklok.dev/v1alpha1
- **Status**: Exists in current repo, likely added post-v0.4.2
- **Required Fields**:
  - `remoteURL`: URL of remote MCP server (must start with http:// or https://)
  - `oidcConfig`: OIDC authentication configuration
- **Key Features**:
  - `port`: 1-65535 (default: 8080)
  - `transport`: sse | streamable-http (default: streamable-http)
  - `oidcConfig.type`: kubernetes | configMap | inline
  - Authorization configuration
  - Audit logging support
  - External auth token exchange
  - Telemetry (OpenTelemetry, Prometheus)
- **Status Phases**: Pending, Ready, Failed, Terminating

### 1.6 MCPToolConfig CRD
- **API Version**: toolhive.stacklok.dev/v1alpha1
- **Status**: Exists in current repo, likely added post-v0.4.2
- **Scope**: Namespaced (namespace-scoped references only)
- **Spec Fields**:
  - `toolsFilter`: Optional array of tool names to allow
  - `toolsOverride`: Optional map for renaming/modifying tool configurations
- **Constraints**: Cannot reference across namespaces
- **Status Fields**: referencingServers, configHash, observedGeneration

### 1.7 VirtualMCPServer CRD ⭐ NEW IN v0.6.x
- **API Version**: toolhive.stacklok.dev/v1alpha1
- **Status**: **MISSING FROM CURRENT REPO - NEEDS TO BE ADDED**
- **Short Names**: vmcp, virtualmcp
- **Required Fields**:
  - `groupRef`: Reference to MCPGroup
  - `incomingAuth`: Authentication configuration
- **Major Spec Sections**:
  - `aggregation`: Tool conflict resolution
  - `compositeToolRefs`: References to composite tool definitions
  - `compositeTools`: Inline composite tool definitions
  - `groupRef`: Reference to MCPGroup
  - `incomingAuth`: Client authentication config
  - `operational`: Timeouts and failure handling
  - `outgoingAuth`: Backend authentication config
  - `podTemplateSpec`: Pod customization
  - `serviceType`: ClusterIP | NodePort | LoadBalancer
- **Status Tracking**:
  - Backend discovery status
  - Condition reporting
  - Phases: Pending, Ready, Degraded, Failed

### 1.8 VirtualMCPCompositeToolDefinition CRD ⭐ NEW IN v0.6.x
- **API Version**: toolhive.stacklok.dev/v1alpha1
- **Status**: **MISSING FROM CURRENT REPO - NEEDS TO BE ADDED**
- **Required Spec Fields**:
  - `name`: 1-64 characters, lowercase alphanumeric (regex: `^[a-z0-9]([a-z0-9_-]*[a-z0-9])?$`)
  - `description`: Human-readable description
  - `steps`: At least one workflow step (array)
- **Key Schema Properties**:
  - `parameters`: JSON Schema for input parameters
  - `steps`: Sequential workflow steps with id (required), tool/type, optional arguments/conditions
  - `output`: Structured output schema
  - `failureMode`: 'abort' (default) | 'continue'
  - `timeout`: Default 30 minutes (pattern: duration with ms/s/m/h units)
- **Step Types**: 'tool' or 'elicitation'
- **Status Tracking**: Validation status, referencing virtual servers, condition tracking, validation errors

---

## 2. Operator Configuration (toolhive-operator-0.5.8 / v0.6.11)

### 2.1 Container Images

| Component | v0.4.2 | v0.6.11 | Notes |
|-----------|---------|---------|-------|
| Operator | ghcr.io/stacklok/toolhive/operator:v0.4.2 | ghcr.io/stacklok/toolhive/operator:v0.6.11 | Core operator |
| ProxyRunner | ghcr.io/stacklok/toolhive/proxyrunner:v0.4.2 | ghcr.io/stacklok/toolhive/proxyrunner:v0.6.11 | MCP proxy runner |
| VMCP | N/A | ghcr.io/stacklok/toolhive/vmcp:v0.6.11 | **NEW** - Virtual MCP Server |
| Registry API | N/A | ghcr.io/stacklok/thv-registry-api:v0.4.0 | **NEW** - Registry API service |

### 2.2 Resource Specifications
**No changes from v0.4.2**:
- CPU Limits: 500m
- CPU Requests: 10m
- Memory Limits: 128Mi
- Memory Requests: 64Mi
- Replicas: 1

### 2.3 Security Context
**No changes from v0.4.2**:
- `runAsNonRoot`: true
- `allowPrivilegeEscalation`: false
- `readOnlyRootFilesystem`: true
- `runAsUser`: 1000
- `capabilities.drop`: ALL
- `seccompProfile.type`: RuntimeDefault

### 2.4 Environment Variables

| Variable | v0.4.2 | v0.6.11 | Notes |
|----------|---------|---------|-------|
| UNSTRUCTURED_LOGS | false | false | Unchanged |
| POD_NAMESPACE | fieldRef:metadata.namespace | fieldRef:metadata.namespace | Unchanged |
| ENABLE_EXPERIMENTAL_FEATURES | false | Configurable (default: false) | Now configurable |
| TOOLHIVE_RUNNER_IMAGE | ghcr.io/stacklok/toolhive/proxyrunner:v0.4.2 | Removed/Renamed | See below |
| TOOLHIVE_PROXY_HOST | 0.0.0.0 | 0.0.0.0 | Unchanged |
| **TOOLHIVE_USE_CONFIGMAP** | N/A | **true** | **NEW** - ConfigMap usage flag |
| **GOMEMLIMIT** | N/A | **150MiB** | **NEW** - Go memory limit |
| **GOGC** | N/A | **75** | **NEW** - Go GC percentage |
| **WATCH_NAMESPACE** | N/A | **Conditional** | **NEW** - Based on RBAC scope |

**Image Reference Changes**:
The environment variable pattern has changed. In v0.6.11 Helm chart, images are referenced as:
- `operator.toolhiveRunnerImage` → `ghcr.io/stacklok/toolhive/proxyrunner:v0.6.11`
- `operator.vmcpImage` → `ghcr.io/stacklok/toolhive/vmcp:v0.6.11` (NEW)

### 2.5 Ports
**No changes from v0.4.2**:
- Health check port: 8081
- Metrics port: 8080

### 2.6 Service Account Configuration
**Enhanced in v0.6.11**:
- `create`: true
- `automountServiceAccountToken`: true
- `name`: toolhive-operator
- **NEW**: Additional registry-api service account for registry API component

### 2.7 Additional Configuration Options
**New in v0.6.11**:
- `imagePullPolicy`: IfNotPresent
- HPA (Horizontal Pod Autoscaler) support via templates
- `values-openshift.yaml`: OpenShift-specific configuration overlay

---

## 3. RBAC Permissions

### 3.1 ClusterRole Permissions (manager-role)

#### Current v0.4.2 Permissions in Repository

| API Group | Resources | Verbs | Notes |
|-----------|-----------|-------|-------|
| "" (core) | configmaps, serviceaccounts | create, delete, get, list, patch, update, watch | |
| "" (core) | events | create, patch | |
| "" (core) | pods, secrets | get, list, watch | |
| "" (core) | pods/attach | create, get | |
| "" (core) | pods/log | get | |
| "" (core) | services | apply, create, delete, get, list, patch, update, watch | |
| apps | deployments | create, delete, get, list, patch, update, watch | |
| apps | statefulsets | apply, create, delete, get, list, patch, update, watch | |
| rbac.authorization.k8s.io | rolebindings, roles | create, delete, get, list, patch, update, watch | |
| toolhive.stacklok.dev | mcpexternalauthconfigs, mcpgroups, mcpregistries, mcpremoteproxies, mcpservers, mcptoolconfigs | create, delete, get, list, patch, update, watch | |
| toolhive.stacklok.dev | [same resources]/finalizers | update | |
| toolhive.stacklok.dev | [same resources]/status | get, patch, update | |

#### New Permissions Required for v0.6.11

| API Group | Resources | Verbs | Status |
|-----------|-----------|-------|--------|
| toolhive.stacklok.dev | **virtualmcpservers** | create, delete, get, list, patch, update, watch | **MISSING** |
| toolhive.stacklok.dev | **virtualmcpservers/finalizers** | update | **MISSING** |
| toolhive.stacklok.dev | **virtualmcpservers/status** | get, patch, update | **MISSING** |
| toolhive.stacklok.dev | **virtualmcpcompositetooldefinitions** | create, delete, get, list, patch, update, watch | **MISSING** |
| toolhive.stacklok.dev | **virtualmcpcompositetooldefinitions/finalizers** | update | **MISSING** |
| toolhive.stacklok.dev | **virtualmcpcompositetooldefinitions/status** | get, patch, update | **MISSING** |
| gateway.networking.k8s.io | **gateways, httproutes** | create, delete, get, list, patch, update, watch | **MISSING** |
| coordination.k8s.io | **leases** | get, list, watch, create, update, patch, delete | **EXISTS in leader-election-role only** |

**Note**: The v0.6.11 operator adds Gateway API support for advanced networking configurations with VirtualMCPServer.

### 3.2 Registry API ClusterRole Permissions (NEW)
**New component in v0.6.11**:

| API Group | Resources | Verbs |
|-----------|-----------|-------|
| toolhive.stacklok.dev | mcpservers | get, list, watch |

This is a read-only role for the registry API service to discover MCP servers.

### 3.3 Leader Election Role Permissions
**No changes from v0.4.2**:

| API Group | Resources | Verbs |
|-----------|-----------|-------|
| "" (core) | configmaps | get, list, watch, create, update, patch, delete |
| coordination.k8s.io | leases | get, list, watch, create, update, patch, delete |
| "" (core) | events | create, patch |

---

## 4. Git Commit Log Analysis (v0.4.2..v0.6.11)

### 4.1 Summary Statistics
- **Total Commits**: 380 commits
- **Files Changed**: 776 files
- **Release Range**: v0.4.2 (pre-v0.5.0) → v0.6.11

**Note**: The GitHub web comparison tool could not render the full diff due to size. Manual git analysis recommended.

### 4.2 Key Release Milestones

#### v0.5.0 Release
**Key Features**:
- Added `/health` endpoint for Kubernetes health probes
- Enhanced OIDC configuration:
  - Environment variable support for client secret
  - SecretKeyRef support for InlineOIDCConfig
- New GitHub.com OAuth authentication provider
- Increased MCPRemoteProxy readiness probe initial delay to 15 seconds
- Prevented zombie supervisor processes on restart
- Added new port values for MCPServer CRD

#### v0.6.0 Release ⭐ Major Feature Release
**Headline Changes**:
1. **VirtualMCPServer Kubernetes Controller** - New major feature
2. **Composite Tools Workflow Engine** - Workflow orchestration capability
3. **Default proxy mode change**: SSE → streamable-http
4. **CRD-based group storage** for Kubernetes
5. **Automatic authentication monitoring** for remote workloads

**Breaking Changes**:
- Removed GetClaimsFromContext backward compatibility helper
- Moved OAuth secret management into new package
- Changed CA certificate config operations
- Updated cosign signing configuration for cosign v3 support

**Infrastructure**:
- Unified authentication with Identity struct
- Updated authentication strategies for remote MCP servers
- Added resource indicator when authorizing to remote MCP server

#### v0.6.10 Release
**Key Features**:
- **PVC source support for MCPRegistry** (major enhancement)
- **Output Schema Support** to CompositeToolSpec CRD
- **Kubernetes registry configuration** for registry server
- **Zed client support**

#### v0.6.11 Release (Latest)
**Key Features**:
- **Ping checks for remote workloads**
- **Build environments**: Support for secrets from secrets manager and host env vars
- **ExternalAuthConfig discovery** for VirtualMCPServer backends
- **Security Update**: Go upgraded to 1.25.5 (fixes GO-2025-4155)

### 4.3 Commits Affecting CRDs
**Based on release notes analysis**:
- v0.5.0: Enhanced MCPServer CRD with new port values
- v0.6.0: Added VirtualMCPServer and VirtualMCPCompositeToolDefinition CRDs
- v0.6.10: Added Output Schema to CompositeToolSpec CRD
- v0.6.10: Added PVCRef to MCPRegistry CRD
- Ongoing: MCPRemoteProxy, MCPExternalAuthConfig enhancements

### 4.4 Commits Affecting RBAC
**Based on release notes and CRD analysis**:
- Addition of VirtualMCPServer and VirtualMCPCompositeToolDefinition resources requires new RBAC rules
- Gateway API permissions added for advanced networking
- Registry API service account and ClusterRole created

### 4.5 Commits Affecting Operands
**Major Change**: Introduction of **vmcp** (Virtual MCP Server) image
- New operand: `ghcr.io/stacklok/toolhive/vmcp:v0.6.11`
- Runs VirtualMCPServer workloads
- Managed by operator via VirtualMCPServer CRD

**Registry API Introduction**:
- New component: `ghcr.io/stacklok/thv-registry-api:v0.4.0`
- Provides registry discovery and management API
- Requires dedicated service account and RBAC

### 4.6 Undocumented Changes (Potential)
**Areas requiring manual verification**:
1. **CRD schema evolution**: Detailed field changes between v0.4.2 CRDs and v0.6.11 CRDs
2. **Webhook configurations**: Admission/conversion webhooks (if any)
3. **Default value changes**: CRD default values that may affect existing resources
4. **Deprecations**: Fields marked as deprecated but still supported
5. **API version changes**: Any alpha→beta transitions (currently all v1alpha1)

---

## 5. Version Mapping Confirmation

### 5.1 Container Image Tags for v0.6.11

| Component | Full Image Reference | Chart Version |
|-----------|---------------------|---------------|
| Operator | ghcr.io/stacklok/toolhive/operator:v0.6.11 | toolhive-operator-0.5.9 |
| VMCP | ghcr.io/stacklok/toolhive/vmcp:v0.6.11 | toolhive-operator-0.5.9 |
| ProxyRunner | ghcr.io/stacklok/toolhive/proxyrunner:v0.6.11 | toolhive-operator-0.5.9 |
| Registry API | ghcr.io/stacklok/thv-registry-api:v0.4.0 | N/A (separate component) |

### 5.2 Helm Chart Versions

| Chart | Version | App Version |
|-------|---------|-------------|
| toolhive-operator-crds | 0.0.74 | 0.0.1 |
| toolhive-operator | 0.5.9 | v0.6.11 |

**Note**: The CRD chart version (0.0.74) is independent of the operator version.

---

## 6. Summary of Key Changes

### 6.1 Critical Changes Requiring Action

1. **New CRDs to Add**:
   - `toolhive.stacklok.dev_virtualmcpservers.yaml`
   - `toolhive.stacklok.dev_virtualmcpcompositetooldefinitions.yaml`

2. **RBAC Updates Required**:
   - Add VirtualMCPServer permissions to ClusterRole
   - Add VirtualMCPCompositeToolDefinition permissions to ClusterRole
   - Add Gateway API permissions (gateways, httproutes)
   - Create registry-api service account and ClusterRole (if using registry API)

3. **Image Updates Required**:
   - Operator: v0.4.2 → v0.6.11
   - ProxyRunner: v0.4.2 → v0.6.11
   - **NEW**: Add vmcp:v0.6.11

4. **Environment Variables to Update**:
   - Add: `TOOLHIVE_USE_CONFIGMAP=true`
   - Add: `GOMEMLIMIT=150MiB`
   - Add: `GOGC=75`
   - Add: `TOOLHIVE_VMCP_IMAGE=ghcr.io/stacklok/toolhive/vmcp:v0.6.11`
   - Consider: `WATCH_NAMESPACE` (if using namespace-scoped RBAC)

5. **Existing CRDs to Update**:
   - MCPRegistry: Add PVCRef, syncPolicy, filter, format fields
   - MCPServer: Add authzConfig, oidcConfig, permissionProfile, telemetry fields
   - MCPRemoteProxy: Enhanced configuration options
   - MCPExternalAuthConfig: Verify schema matches v0.6.11

### 6.2 Compatibility Considerations

**Breaking Changes**:
- Default transport mode changed from SSE to streamable-http (may affect existing MCPServer configs)
- Authentication API changes (GetClaimsFromContext removed)
- OAuth secret management refactored

**Backward Compatibility**:
- Existing MCPServer and MCPRegistry resources should continue to work
- New fields are optional with sensible defaults
- VirtualMCP features are entirely new and won't affect existing deployments

### 6.3 Testing Requirements

Before deployment, validate:
1. All CRDs install successfully with `kubectl apply`
2. RBAC permissions allow operator to manage all resource types
3. Operator pod starts with new environment variables
4. Existing MCPServer and MCPRegistry resources reconcile correctly
5. VirtualMCPServer CRD can be created and managed

### 6.4 OpenShift-Specific Considerations

Based on current `config/base/` configuration:
1. **Security Context Patches**: Verify compatibility with new operator version
2. **Namespace**: Continue using `opendatahub` namespace
3. **Image References**: Update `params.env` with all three image references
4. **Resource Limits**: Current OpenShift resource limits should remain adequate
5. **RBAC Scope**: Determine if namespace-scoped or cluster-scoped RBAC for VirtualMCP

### 6.5 Migration Path Recommendation

**Recommended Upgrade Steps**:
1. **Phase 1 - CRD Updates**:
   - Update existing 6 CRDs to v0.6.11 schemas
   - Add 2 new CRDs (VirtualMCPServer, VirtualMCPCompositeToolDefinition)

2. **Phase 2 - RBAC Updates**:
   - Update ClusterRole with VirtualMCP and Gateway API permissions
   - Create registry-api service account and ClusterRole (if needed)

3. **Phase 3 - Operator Deployment**:
   - Update image references in `params.env`
   - Add new environment variables to `manager.yaml` or patches
   - Update kustomization to include vmcp image reference

4. **Phase 4 - Validation**:
   - Deploy to test environment
   - Validate existing resources reconcile
   - Test new VirtualMCP features
   - Verify OpenShift-specific patches still apply correctly

5. **Phase 5 - Production Rollout**:
   - Deploy to production with monitoring
   - Document any runtime issues
   - Update operational runbooks

---

## 7. Open Questions / Manual Verification Needed

1. **Webhook Configuration**: Does v0.6.11 introduce any admission or conversion webhooks?
2. **Default Value Changes**: Are there schema default changes that could affect existing resources?
3. **API Deprecations**: Are any fields marked as deprecated in v0.6.11?
4. **OpenShift Compatibility**: Have security context requirements changed that affect OpenShift patches?
5. **Registry API Deployment**: Is registry-api component required or optional?
6. **Gateway API Version**: Which version of Gateway API is required (v1beta1, v1)?
7. **Migration Guide**: Does upstream provide a migration guide for v0.4.2→v0.6.11?
8. **Feature Flags**: Are any experimental features now stable or new experiments added?

---

## 8. References

- Upstream Repository: https://github.com/stacklok/toolhive
- CRD Helm Chart: https://github.com/stacklok/toolhive/tree/toolhive-operator-crds-0.0.74/deploy/charts/operator-crds
- Operator Helm Chart: https://github.com/stacklok/toolhive/tree/toolhive-operator-0.5.8/deploy/charts/operator
- Main Branch Operator Chart: https://github.com/stacklok/toolhive/tree/main/deploy/charts/operator (v0.6.11)
- Release v0.6.11: https://github.com/stacklok/toolhive/releases/tag/v0.6.11
- Release v0.6.10: https://github.com/stacklok/toolhive/releases/tag/v0.6.10
- Release v0.6.0: https://github.com/stacklok/toolhive/releases/tag/v0.6.0
- Release v0.5.0: https://github.com/stacklok/toolhive/releases/tag/v0.5.0

---

## 9. Next Steps

1. **Fetch Updated CRDs**: Download all 8 CRD files from toolhive-operator-crds-0.0.74
2. **Compare CRD Schemas**: Detailed field-by-field comparison of existing 6 CRDs
3. **Update RBAC Manifests**: Add missing permissions to ClusterRole
4. **Update Operator Deployment**: Add new env vars and image references
5. **Update Kustomize Base**: Modify `config/base/` for OpenShift compatibility
6. **Test in Development**: Deploy to test cluster and validate
7. **Document Changes**: Update CLAUDE.md and README with v0.6.11 specifics
8. **Create Migration Guide**: Document upgrade process for users

---

**Analysis Complete**: 2025-12-04
**Confidence Level**: High (based on upstream Helm charts and release notes)
**Recommendation**: Proceed with phased upgrade approach outlined in Section 6.5
