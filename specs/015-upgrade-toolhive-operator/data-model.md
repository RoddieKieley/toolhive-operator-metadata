# Data Model: ToolHive Operator CRD Schema Comparison

**Feature**: Upgrade ToolHive Operator to v0.6.11
**Date**: 2025-12-04
**Purpose**: Document CRD schema changes from v0.4.2 to v0.6.11

## Overview

This document compares the Custom Resource Definition (CRD) schemas between ToolHive Operator v0.4.2 (current) and v0.6.11 (target). It identifies new CRDs, field additions, schema changes, and backward compatibility considerations.

The upgrade represents a **major feature release** with significant schema enhancements, particularly the introduction of Virtual MCP Server capabilities and enhanced authentication/authorization features.

**CRD Helm Chart Version**: toolhive-operator-crds-0.0.74
**Operator Version**: v0.6.11
**API Group**: toolhive.stacklok.dev
**API Version**: v1alpha1 (all CRDs)

---

## CRD Inventory

| CRD Name | Status in v0.4.2 | Status in v0.6.11 | Action Required |
|----------|------------------|-------------------|-----------------|
| MCPRegistry | Exists | Updated | UPDATE schema |
| MCPServer | Exists | Updated | UPDATE schema |
| MCPExternalAuthConfig | Exists (post-v0.4.2) | Exists | VERIFY schema |
| MCPGroup | Exists (post-v0.4.2) | Exists | VERIFY schema |
| MCPRemoteProxy | Exists (post-v0.4.2) | Exists | UPDATE schema |
| MCPToolConfig | Exists (post-v0.4.2) | Exists | VERIFY schema |
| VirtualMCPServer | **Does not exist** | **NEW** | **ADD CRD** |
| VirtualMCPCompositeToolDefinition | **Does not exist** | **NEW** | **ADD CRD** |

**Summary**:
- **2 new CRDs** to add
- **2 major CRDs** to update (MCPRegistry, MCPServer)
- **4 CRDs** to verify (likely post-v0.4.2 additions)

---

## Detailed CRD Schemas

### 1. MCPRegistry

**API Group**: toolhive.stacklok.dev
**Version**: v1alpha1
**Kind**: MCPRegistry
**Scope**: Namespaced

#### Purpose
Manages registries of MCP servers, supporting multiple registry sources including API endpoints, Git repositories, ConfigMaps, and now PersistentVolumeClaims.

#### Schema Changes v0.4.2 → v0.6.11

**NEW Fields**:

1. **`spec.registries[].pvcRef`** - PersistentVolumeClaim reference
   - **Type**: Object
   - **Purpose**: Support PVC as registry source for offline/airgapped environments
   - **Required**: No (mutually exclusive with apiEndpoint, configMapRef, gitRepository)
   - **Schema**:
     ```yaml
     pvcRef:
       name: string        # PVC name (required)
       mountPath: string   # Optional mount path
     ```
   - **Use Case**: Store registry data in persistent volumes for disconnected environments

2. **`spec.registries[].syncPolicy`** - Synchronization policy
   - **Type**: Object
   - **Purpose**: Control automatic sync intervals for registry data
   - **Required**: No
   - **Schema**:
     ```yaml
     syncPolicy:
       interval: string    # Duration (e.g., "5m", "1h")
     ```
   - **Use Case**: Automatic periodic registry updates

3. **`spec.registries[].filter`** - Registry filtering
   - **Type**: Object
   - **Purpose**: Name/tag inclusion/exclusion filters for selective registry syncing
   - **Required**: No
   - **Schema**:
     ```yaml
     filter:
       include: []string   # Patterns to include
       exclude: []string   # Patterns to exclude
     ```
   - **Use Case**: Reduce registry size by filtering unwanted tools/servers

4. **`spec.registries[].format`** - Registry format
   - **Type**: String (enum)
   - **Purpose**: Specify registry data format
   - **Required**: No
   - **Values**: `toolhive` | `upstream`
   - **Default**: `toolhive`
   - **Use Case**: Support for different registry schema formats

**Existing Fields (Unchanged)**:
- `spec.registries[].name` (string, required, unique)
- `spec.registries[].apiEndpoint` (object, optional)
- `spec.registries[].configMapRef` (object, optional)
- `spec.registries[].gitRepository` (object, optional)

**Validation Rules**:
- Minimum 1 registry required in `spec.registries` array
- Registry sources are mutually exclusive (only one of: apiEndpoint, configMapRef, gitRepository, pvcRef)
- Registry names must be unique within the MCPRegistry resource
- Source selection validation enforced at admission time

**Backward Compatibility**:
- **Status**: FULLY BACKWARD COMPATIBLE
- Existing v0.4.2 MCPRegistry resources will validate successfully under v0.6.11 schema
- All new fields are optional
- No breaking changes to existing source types
- **Migration**: No action required for existing resources; new features are opt-in

**Example Migration**:
```yaml
# v0.4.2 (still valid in v0.6.11)
apiVersion: toolhive.stacklok.dev/v1alpha1
kind: MCPRegistry
metadata:
  name: my-registry
spec:
  registries:
    - name: default
      gitRepository:
        url: https://github.com/example/registry.git

# v0.6.11 (with new features)
apiVersion: toolhive.stacklok.dev/v1alpha1
kind: MCPRegistry
metadata:
  name: my-registry
spec:
  registries:
    - name: default
      pvcRef:
        name: registry-data-pvc
      syncPolicy:
        interval: "15m"
      filter:
        include: ["filesystem-*", "git-*"]
        exclude: ["*-experimental"]
      format: toolhive
```

---

### 2. MCPServer

**API Group**: toolhive.stacklok.dev
**Version**: v1alpha1
**Kind**: MCPServer
**Scope**: Namespaced

#### Purpose
Manages individual MCP server instances, including configuration, authentication, authorization, and runtime behavior.

#### Schema Changes v0.4.2 → v0.6.11

**NEW Fields**:

1. **`spec.authzConfig`** - Authorization policy configuration
   - **Type**: Object
   - **Purpose**: Define fine-grained authorization policies for MCP server access
   - **Required**: No
   - **Schema**:
     ```yaml
     authzConfig:
       policies: []object    # Array of authorization policies
       defaultAction: string # "allow" | "deny"
     ```
   - **Use Case**: Implement RBAC-style access control for MCP tools/resources

2. **`spec.oidcConfig`** - OIDC authentication configuration
   - **Type**: Object
   - **Purpose**: Configure OpenID Connect authentication for client access
   - **Required**: No
   - **Schema**:
     ```yaml
     oidcConfig:
       type: string          # "kubernetes" | "configMap" | "inline"
       # Type-specific fields based on selection
     ```
   - **Types**:
     - **kubernetes**: Use Kubernetes service account tokens
     - **configMap**: Reference OIDC config from ConfigMap
     - **inline**: Inline OIDC provider configuration
   - **Use Case**: Secure MCP server endpoints with industry-standard OIDC auth
   - **Enhancement**: Expanded from v0.5.0 with environment variable and SecretKeyRef support

3. **`spec.permissionProfile`** - Permission profile definitions
   - **Type**: Object
   - **Purpose**: Define allowed operations and resource access patterns
   - **Required**: No
   - **Schema**:
     ```yaml
     permissionProfile:
       allowedTools: []string       # Tool whitelist
       allowedResources: []string   # Resource patterns
     ```
   - **Use Case**: Implement least-privilege access for MCP servers

4. **`spec.proxyPort`** - Proxy runner exposure port
   - **Type**: Integer
   - **Purpose**: Customize the port on which the proxy runner listens
   - **Required**: No
   - **Default**: 8080
   - **Validation**: Range 1-65535
   - **Use Case**: Avoid port conflicts in multi-server deployments

5. **`spec.telemetry`** - Observability configuration
   - **Type**: Object
   - **Purpose**: Enable metrics, tracing, and logging for MCP server operations
   - **Required**: No
   - **Schema**:
     ```yaml
     telemetry:
       metrics:
         enabled: boolean
         prometheus: object
       tracing:
         enabled: boolean
         openTelemetry: object
     ```
   - **Use Case**: Integrate with OpenTelemetry/Prometheus for observability

6. **`spec.transport`** - Transport method
   - **Type**: String (enum)
   - **Purpose**: Select MCP protocol transport mechanism
   - **Required**: No
   - **Values**: `stdio` | `streamable-http` | `sse`
   - **Default**: `streamable-http` (changed from `sse` in v0.6.0)
   - **Breaking Change**: Default transport changed in v0.6.0
   - **Use Case**: Match client transport requirements

**ENHANCED Fields**:

7. **`spec.env`** - Environment variable support
   - **Status**: Enhanced with more capabilities
   - **Purpose**: Pass environment variables to MCP server container
   - **Enhancements**: Support for SecretKeyRef, ConfigMapKeyRef, fieldRef

8. **`spec.resources`** - CPU/memory resource requirements
   - **Status**: Enhanced schema
   - **Purpose**: Define resource requests and limits
   - **Schema**: Standard Kubernetes ResourceRequirements

**Existing Fields (Unchanged)**:
- `spec.name` (string, required)
- `spec.image` (string, required)
- `spec.command` (array of strings, optional)
- `spec.args` (array of strings, optional)
- `spec.registryRef` (object, optional)

**Validation Rules**:
- `proxyPort`: Must be in range 1-65535
- `transport`: Must be one of: stdio, streamable-http, sse
- `oidcConfig.type`: Must be one of: kubernetes, configMap, inline
- OIDC config requires type-specific mandatory fields based on selected type

**Backward Compatibility**:
- **Status**: MOSTLY BACKWARD COMPATIBLE with one breaking change
- **Breaking Change**: Default transport changed from `sse` to `streamable-http` in v0.6.0
  - **Impact**: Servers that relied on default SSE transport must explicitly set `transport: sse`
  - **Mitigation**: Add explicit `transport` field to existing MCPServer resources before upgrade
- All new fields are optional with sensible defaults
- Existing required fields unchanged
- **Migration**: Review and explicitly set `transport` field if relying on SSE default

**Example Migration**:
```yaml
# v0.4.2 (requires transport update)
apiVersion: toolhive.stacklok.dev/v1alpha1
kind: MCPServer
metadata:
  name: my-mcp-server
spec:
  image: ghcr.io/example/my-mcp:v1
  # Implicit transport: sse (v0.4.2 default)

# v0.6.11 (explicit transport for backward compat)
apiVersion: toolhive.stacklok.dev/v1alpha1
kind: MCPServer
metadata:
  name: my-mcp-server
spec:
  image: ghcr.io/example/my-mcp:v1
  transport: sse  # Explicit to maintain v0.4.2 behavior
  proxyPort: 8080
  oidcConfig:
    type: kubernetes
  permissionProfile:
    allowedTools: ["read_file", "list_directory"]
  telemetry:
    metrics:
      enabled: true
      prometheus:
        port: 9090
```

---

### 3. MCPExternalAuthConfig

**API Group**: toolhive.stacklok.dev
**Version**: v1alpha1
**Kind**: MCPExternalAuthConfig
**Scope**: Namespaced
**Short Names**: extauth, mcpextauth

#### Purpose
Configures external authentication mechanisms for MCP servers, supporting token exchange and header injection patterns.

#### Status in v0.4.2
Likely added post-v0.4.2. Exists in current repository.

#### Schema (v0.6.11)

**Required Fields**:
- **`spec.type`**: Authentication type
  - **Type**: String (enum)
  - **Values**: `tokenExchange` | `headerInjection`
  - **Required**: Yes

**Configuration Schemas**:

1. **Token Exchange** (`type: tokenExchange`):
   ```yaml
   spec:
     type: tokenExchange
     tokenExchange:
       audience: string            # Required: Target audience
       tokenUrl: string            # Required: Token endpoint URL
       clientId: string            # Optional: OAuth client ID
       clientSecretRef:            # Optional: Secret reference
         name: string
         key: string
       scopes: []string            # Optional: OAuth scopes
       subjectTokenType: string    # Optional: Token type
   ```

2. **Header Injection** (`type: headerInjection`):
   ```yaml
   spec:
     type: headerInjection
     headerInjection:
       headerName: string          # Required: Header name
       valueSecretRef:             # Required: Secret containing value
         name: string
         key: string
   ```

**Status Fields**:
- `status.configHash`: Hash of current configuration
- `status.referencingServers`: List of MCPServers using this auth config
- `status.observedGeneration`: Last observed generation number

**Validation Rules**:
- Type-specific required fields must be present based on selected type
- Secret references must exist in same namespace
- Token URLs must be valid HTTP/HTTPS URLs

**Backward Compatibility**:
- **Status**: VERIFY REQUIRED (post-v0.4.2 addition)
- If this CRD exists in v0.4.2 environment, verify schema matches v0.6.11
- Likely fully compatible as it's a newer addition

**Use Cases**:
- **Token Exchange**: OAuth 2.0 token exchange for service-to-service auth
- **Header Injection**: API key or bearer token injection for external APIs

---

### 4. MCPGroup

**API Group**: toolhive.stacklok.dev
**Version**: v1alpha1
**Kind**: MCPGroup
**Scope**: Namespaced

#### Purpose
Logical grouping mechanism for organizing MCP resources (servers, registries) for management and access control.

#### Status in v0.4.2
Likely added post-v0.4.2. Exists in current repository. Used by VirtualMCPServer for backend discovery.

#### Schema (v0.6.11)

**Spec Fields**:
- **`spec.description`**: Optional human-readable description
  - **Type**: String
  - **Required**: No

**Status Fields**:
- **`status.phase`**: Current phase of the group
  - **Type**: String (enum)
  - **Values**: `Ready` | `Pending` | `Failed`
- **`status.conditions`**: Standard Kubernetes condition array
  - **Type**: Array of Condition objects
  - **Fields**: type, status, lastTransitionTime, reason, message

**Backward Compatibility**:
- **Status**: VERIFY REQUIRED (post-v0.4.2 addition)
- Minimal schema - unlikely to have breaking changes
- **Enhancement**: v0.6.0 introduced "CRD-based group storage for Kubernetes"

**Use Cases**:
- Organize related MCP servers into logical groups
- Backend selection for VirtualMCPServer (via `groupRef`)
- Namespace-based multi-tenancy

**Example**:
```yaml
apiVersion: toolhive.stacklok.dev/v1alpha1
kind: MCPGroup
metadata:
  name: development-tools
  namespace: dev-team
spec:
  description: "MCP servers for development team workflows"
status:
  phase: Ready
  conditions:
    - type: Ready
      status: "True"
      lastTransitionTime: "2025-12-04T10:00:00Z"
      reason: GroupReady
      message: "Group is ready for use"
```

---

### 5. MCPRemoteProxy

**API Group**: toolhive.stacklok.dev
**Version**: v1alpha1
**Kind**: MCPRemoteProxy
**Scope**: Namespaced

#### Purpose
Proxies connections to remote MCP servers, enabling secure access to externally-hosted MCP services with authentication and authorization.

#### Status in v0.4.2
Likely added post-v0.4.2. Exists in current repository.

#### Schema (v0.6.11)

**Required Fields**:
- **`spec.remoteURL`**: URL of remote MCP server
  - **Type**: String
  - **Format**: Must start with `http://` or `https://`
  - **Required**: Yes
  - **Validation**: URL format validation

- **`spec.oidcConfig`**: OIDC authentication configuration
  - **Type**: Object
  - **Required**: Yes
  - **Schema**: Same as MCPServer.oidcConfig

**Optional Fields**:
- **`spec.port`**: Proxy listening port
  - **Type**: Integer
  - **Range**: 1-65535
  - **Default**: 8080

- **`spec.transport`**: Transport protocol
  - **Type**: String (enum)
  - **Values**: `sse` | `streamable-http`
  - **Default**: `streamable-http`

- **`spec.authzConfig`**: Authorization configuration
  - **Type**: Object
  - **Purpose**: Access control policies

- **`spec.auditLog`**: Audit logging configuration
  - **Type**: Object
  - **Purpose**: Enable request/response logging

- **`spec.externalAuthConfig`**: External authentication reference
  - **Type**: Object
  - **Purpose**: Reference to MCPExternalAuthConfig for upstream auth

- **`spec.telemetry`**: Observability configuration
  - **Type**: Object
  - **Fields**:
    - OpenTelemetry configuration
    - Prometheus metrics

**Status Fields**:
- **`status.phase`**: Current phase
  - **Values**: `Pending` | `Ready` | `Failed` | `Terminating`
- **`status.conditions`**: Condition array

**Enhancements in v0.6.11**:
- Enhanced authentication monitoring for remote workloads (v0.6.0)
- Ping checks for remote workloads (v0.6.11)
- ExternalAuthConfig discovery (v0.6.11)
- Increased readiness probe initial delay to 15 seconds (v0.5.0)

**Backward Compatibility**:
- **Status**: UPDATE REQUIRED
- Schema enhancements in v0.6.x for authentication and monitoring
- Existing resources should remain compatible
- New features are additive

**Use Cases**:
- Access cloud-hosted MCP services
- Bridge on-premises and cloud MCP servers
- Centralized authentication/authorization for remote MCPs
- Multi-region MCP deployments

---

### 6. MCPToolConfig

**API Group**: toolhive.stacklok.dev
**Version**: v1alpha1
**Kind**: MCPToolConfig
**Scope**: Namespaced

#### Purpose
Configures tool filtering and override policies for MCP servers, enabling fine-grained control over tool availability and behavior.

#### Status in v0.4.2
Likely added post-v0.4.2. Exists in current repository.

#### Schema (v0.6.11)

**Spec Fields**:

- **`spec.toolsFilter`**: Tool allowlist
  - **Type**: Array of strings
  - **Required**: No
  - **Purpose**: Whitelist of allowed tool names
  - **Behavior**: If set, only listed tools are exposed

- **`spec.toolsOverride`**: Tool configuration overrides
  - **Type**: Map (string → object)
  - **Required**: No
  - **Purpose**: Rename tools or modify tool configurations
  - **Schema**:
    ```yaml
    toolsOverride:
      original_tool_name:
        newName: string           # Rename the tool
        description: string       # Override description
        schema: object            # Override JSON schema
    ```

**Status Fields**:
- `status.referencingServers`: List of MCPServers using this config
- `status.configHash`: Configuration hash for change detection
- `status.observedGeneration`: Last observed generation

**Constraints**:
- **Namespace-scoped**: Cannot reference MCPToolConfig across namespaces
- References must be in same namespace as MCPServer

**Backward Compatibility**:
- **Status**: VERIFY REQUIRED (post-v0.4.2 addition)
- Minimal schema - unlikely to have breaking changes
- Opt-in feature - no impact if not used

**Use Cases**:
- Restrict tool access for security (e.g., disable file deletion)
- Rename tools for consistency across environments
- Override tool schemas for custom validation
- Multi-tenancy: Different tool policies per namespace

**Example**:
```yaml
apiVersion: toolhive.stacklok.dev/v1alpha1
kind: MCPToolConfig
metadata:
  name: restricted-filesystem
  namespace: production
spec:
  toolsFilter:
    - read_file
    - list_directory
    # delete_file intentionally omitted
  toolsOverride:
    read_file:
      newName: safe_read_file
      description: "Read-only file access with audit logging"
```

---

### 7. VirtualMCPServer (NEW)

**API Group**: toolhive.stacklok.dev
**Version**: v1alpha1
**Kind**: VirtualMCPServer
**Scope**: Namespaced
**Short Names**: vmcp, virtualmcp

#### Purpose
Manages virtual MCP servers that aggregate multiple backend MCP servers into a unified interface, enabling tool composition, load balancing, and advanced workflows.

#### Status in v0.4.2
**Does not exist** - New in v0.6.0

#### Schema (v0.6.11)

**Required Fields**:

- **`spec.groupRef`**: Reference to MCPGroup
  - **Type**: Object
  - **Required**: Yes
  - **Schema**:
    ```yaml
    groupRef:
      name: string    # MCPGroup name in same namespace
    ```
  - **Purpose**: Discover backend MCP servers from group membership

- **`spec.incomingAuth`**: Client authentication configuration
  - **Type**: Object
  - **Required**: Yes
  - **Purpose**: Configure how clients authenticate to the virtual MCP server
  - **Schema**: OIDC configuration (same pattern as MCPServer)

**Optional Fields**:

- **`spec.aggregation`**: Tool conflict resolution
  - **Type**: Object
  - **Purpose**: Define how to handle duplicate tools from multiple backends
  - **Schema**:
    ```yaml
    aggregation:
      conflictResolution: string  # "first" | "merge" | "error"
      toolPriority: []string      # Ordered backend preference
    ```

- **`spec.compositeToolRefs`**: References to composite tool definitions
  - **Type**: Array of object references
  - **Purpose**: Include VirtualMCPCompositeToolDefinition resources
  - **Schema**:
    ```yaml
    compositeToolRefs:
      - name: string              # VirtualMCPCompositeToolDefinition name
        namespace: string         # Optional, defaults to vmcp namespace
    ```

- **`spec.compositeTools`**: Inline composite tool definitions
  - **Type**: Array of objects
  - **Purpose**: Define workflows inline without separate CRD
  - **Schema**: Same as VirtualMCPCompositeToolDefinition spec

- **`spec.outgoingAuth`**: Backend authentication configuration
  - **Type**: Object
  - **Purpose**: Configure authentication to backend MCP servers
  - **Note**: v0.6.11 added ExternalAuthConfig discovery

- **`spec.operational`**: Operational configuration
  - **Type**: Object
  - **Schema**:
    ```yaml
    operational:
      timeout: string             # Request timeout (e.g., "30s")
      maxConcurrentRequests: int  # Backend concurrency limit
      failurePolicy: string       # "failFast" | "bestEffort"
    ```

- **`spec.podTemplateSpec`**: Pod customization
  - **Type**: PodTemplateSpec
  - **Purpose**: Customize the vmcp pod (resources, nodeSelector, etc.)

- **`spec.serviceType`**: Kubernetes Service type
  - **Type**: String (enum)
  - **Values**: `ClusterIP` | `NodePort` | `LoadBalancer`
  - **Default**: `ClusterIP`

**Status Fields**:

- **`status.phase`**: Current phase
  - **Type**: String (enum)
  - **Values**: `Pending` | `Ready` | `Degraded` | `Failed`

- **`status.backendDiscovery`**: Backend server status
  - **Type**: Object
  - **Schema**:
    ```yaml
    backendDiscovery:
      discoveredServers: int      # Number of backends found
      healthyServers: int         # Number of healthy backends
      backends:
        - name: string
          status: string          # "Healthy" | "Unhealthy"
          lastCheck: timestamp
    ```

- **`status.conditions`**: Condition array

**Managed Resources**:
- **Deployment**: Runs vmcp container (image: ghcr.io/stacklok/toolhive/vmcp:v0.6.11)
- **Service**: Exposes virtual MCP endpoint
- **ConfigMap**: Backend server configuration
- **Optional**: Gateway API resources (HTTPRoute, Gateway) for advanced routing

**Key Relationships**:
- **References**: MCPGroup (backend discovery)
- **References**: VirtualMCPCompositeToolDefinition (workflow composition)
- **Manages**: vmcp pods and services
- **Discovers**: MCPServer instances via groupRef

**Validation Rules**:
- `groupRef.name` must reference existing MCPGroup in same namespace
- At least one backend server must be discovered from group
- Composite tool references must exist and be valid
- Service type must be valid Kubernetes Service type

**RBAC Requirements**:
The operator needs new permissions for VirtualMCPServer management:
```yaml
- apiGroups: ["toolhive.stacklok.dev"]
  resources: ["virtualmcpservers"]
  verbs: ["create", "delete", "get", "list", "patch", "update", "watch"]
- apiGroups: ["toolhive.stacklok.dev"]
  resources: ["virtualmcpservers/finalizers"]
  verbs: ["update"]
- apiGroups: ["toolhive.stacklok.dev"]
  resources: ["virtualmcpservers/status"]
  verbs: ["get", "patch", "update"]
```

**Use Cases**:
- Aggregate multiple MCP servers into single endpoint
- Create composite workflows across multiple tools/servers
- Implement high-availability MCP services with failover
- Centralized authentication/authorization for multiple backends
- Tool orchestration and chaining

**Example**:
```yaml
apiVersion: toolhive.stacklok.dev/v1alpha1
kind: VirtualMCPServer
metadata:
  name: unified-devtools
  namespace: development
spec:
  groupRef:
    name: development-tools  # MCPGroup with backend servers
  incomingAuth:
    type: kubernetes
  outgoingAuth:
    type: serviceAccount
  aggregation:
    conflictResolution: first
    toolPriority:
      - filesystem-server
      - git-server
  compositeToolRefs:
    - name: git-commit-workflow
  operational:
    timeout: "60s"
    maxConcurrentRequests: 10
    failurePolicy: bestEffort
  serviceType: ClusterIP
status:
  phase: Ready
  backendDiscovery:
    discoveredServers: 3
    healthyServers: 3
    backends:
      - name: filesystem-server
        status: Healthy
        lastCheck: "2025-12-04T10:15:00Z"
      - name: git-server
        status: Healthy
        lastCheck: "2025-12-04T10:15:00Z"
      - name: slack-server
        status: Healthy
        lastCheck: "2025-12-04T10:15:00Z"
```

---

### 8. VirtualMCPCompositeToolDefinition (NEW)

**API Group**: toolhive.stacklok.dev
**Version**: v1alpha1
**Kind**: VirtualMCPCompositeToolDefinition
**Scope**: Namespaced

#### Purpose
Defines workflow compositions of MCP tools, enabling multi-step workflows with conditional logic, parameter passing, and structured outputs.

#### Status in v0.4.2
**Does not exist** - New in v0.6.0

#### Schema (v0.6.11)

**Required Fields**:

- **`spec.name`**: Composite tool name
  - **Type**: String
  - **Required**: Yes
  - **Length**: 1-64 characters
  - **Pattern**: `^[a-z0-9]([a-z0-9_-]*[a-z0-9])?$`
  - **Purpose**: Lowercase alphanumeric tool identifier

- **`spec.description`**: Human-readable description
  - **Type**: String
  - **Required**: Yes
  - **Purpose**: Explain the workflow purpose and behavior

- **`spec.steps`**: Workflow steps
  - **Type**: Array of objects
  - **Required**: Yes (minimum 1 step)
  - **Schema**:
    ```yaml
    steps:
      - id: string                # Required: Unique step identifier
        type: string              # Required: "tool" | "elicitation"
        tool: string              # Required if type=tool: Backend tool name
        arguments: object         # Optional: Input arguments (JSON)
        condition: string         # Optional: Conditional execution (expression)
        outputMapping: object     # Optional: Map output to workflow variables
    ```

**Optional Fields**:

- **`spec.parameters`**: Input parameter schema
  - **Type**: Object (JSON Schema)
  - **Purpose**: Define and validate workflow inputs
  - **Schema**:
    ```yaml
    parameters:
      type: object
      properties:
        param_name:
          type: string
          description: string
      required: []string
    ```

- **`spec.output`**: Structured output schema
  - **Type**: Object (JSON Schema)
  - **Purpose**: Define workflow output structure
  - **Added**: v0.6.10 (Output Schema Support to CompositeToolSpec)
  - **Schema**:
    ```yaml
    output:
      type: object
      properties:
        result_field:
          type: string
      required: []string
    ```

- **`spec.failureMode`**: Failure handling strategy
  - **Type**: String (enum)
  - **Values**: `abort` | `continue`
  - **Default**: `abort`
  - **Purpose**: Control workflow behavior on step failure

- **`spec.timeout`**: Workflow timeout
  - **Type**: String (duration)
  - **Default**: 30 minutes
  - **Pattern**: Duration with units (ms, s, m, h)
  - **Examples**: "30s", "5m", "1h"

**Status Fields**:

- **`status.validationStatus`**: Validation state
  - **Type**: String (enum)
  - **Values**: `Valid` | `Invalid` | `Pending`

- **`status.referencingVirtualServers`**: VirtualMCPServers using this definition
  - **Type**: Array of strings

- **`status.conditions`**: Condition array

- **`status.validationErrors`**: Validation error messages
  - **Type**: Array of strings
  - **Purpose**: Report schema validation failures

**Step Types**:

1. **Tool Step** (`type: tool`):
   - Executes a backend MCP tool
   - Requires `tool` field with backend tool name
   - Supports argument templating with previous step outputs
   - Output captured for subsequent steps

2. **Elicitation Step** (`type: elicitation`):
   - Prompts user for input during workflow execution
   - Used for interactive workflows
   - Output becomes available as variable for subsequent steps

**Validation Rules**:
- Tool name must match pattern: `^[a-z0-9]([a-z0-9_-]*[a-z0-9])?$`
- Tool name length: 1-64 characters
- Steps array must have at least one step
- Each step must have unique `id`
- Step type must be "tool" or "elicitation"
- Tool steps must reference valid backend tools
- Parameter and output schemas must be valid JSON Schema
- Timeout must be valid duration string

**RBAC Requirements**:
```yaml
- apiGroups: ["toolhive.stacklok.dev"]
  resources: ["virtualmcpcompositetooldefinitions"]
  verbs: ["create", "delete", "get", "list", "patch", "update", "watch"]
- apiGroups: ["toolhive.stacklok.dev"]
  resources: ["virtualmcpcompositetooldefinitions/finalizers"]
  verbs: ["update"]
- apiGroups: ["toolhive.stacklok.dev"]
  resources: ["virtualmcpcompositetooldefinitions/status"]
  verbs: ["get", "patch", "update"]
```

**Use Cases**:
- Multi-step git workflows (clone → analyze → commit → push)
- CI/CD pipelines (build → test → deploy)
- Data processing workflows (extract → transform → load)
- Interactive approval workflows with elicitation
- Complex tool orchestration with conditional logic

**Example**:
```yaml
apiVersion: toolhive.stacklok.dev/v1alpha1
kind: VirtualMCPCompositeToolDefinition
metadata:
  name: git-commit-workflow
  namespace: development
spec:
  name: git-commit-workflow
  description: "Automated git commit workflow with validation"
  parameters:
    type: object
    properties:
      repository_path:
        type: string
        description: "Path to git repository"
      commit_message:
        type: string
        description: "Commit message"
    required:
      - repository_path
      - commit_message
  steps:
    - id: check-status
      type: tool
      tool: git_status
      arguments:
        path: "{{ .parameters.repository_path }}"

    - id: stage-changes
      type: tool
      tool: git_add
      arguments:
        path: "{{ .parameters.repository_path }}"
        files: ["."]
      condition: "{{ .steps.check-status.output.has_changes }}"

    - id: commit
      type: tool
      tool: git_commit
      arguments:
        path: "{{ .parameters.repository_path }}"
        message: "{{ .parameters.commit_message }}"
      condition: "{{ .steps.stage-changes.output.success }}"

    - id: confirm-push
      type: elicitation
      arguments:
        prompt: "Push changes to remote? (yes/no)"
      condition: "{{ .steps.commit.output.success }}"

    - id: push
      type: tool
      tool: git_push
      arguments:
        path: "{{ .parameters.repository_path }}"
      condition: "{{ eq .steps.confirm-push.output.response 'yes' }}"
  output:
    type: object
    properties:
      commit_sha:
        type: string
      pushed:
        type: boolean
  failureMode: abort
  timeout: "5m"
status:
  validationStatus: Valid
  referencingVirtualServers:
    - unified-devtools
  conditions:
    - type: Valid
      status: "True"
      lastTransitionTime: "2025-12-04T10:00:00Z"
```

---

## Validation Rules Summary

### Cross-CRD Validation

1. **Namespace References**:
   - MCPToolConfig: Cannot reference across namespaces
   - VirtualMCPServer groupRef: Must be in same namespace
   - VirtualMCPCompositeToolDefinition refs: Support cross-namespace references

2. **Resource Existence**:
   - MCPServer registryRef must reference existing MCPRegistry
   - VirtualMCPServer groupRef must reference existing MCPGroup
   - MCPExternalAuthConfig secretRefs must exist in same namespace

3. **Mutual Exclusivity**:
   - MCPRegistry source types: Only one of (apiEndpoint, configMapRef, gitRepository, pvcRef)
   - Authentication config types: Only one authentication method per resource

### Field-Level Validation

1. **Port Numbers**: Range 1-65535 for all port fields
2. **URLs**: Must be valid HTTP/HTTPS for remote endpoints
3. **Enums**: Strict validation on enumerated values (transport, phase, etc.)
4. **Patterns**: Regex validation for tool names, durations
5. **JSON Schema**: Parameters and output schemas must be valid JSON Schema

---

## Migration Considerations

### Breaking Changes

1. **MCPServer Transport Default** (v0.6.0):
   - **Change**: Default transport changed from `sse` to `streamable-http`
   - **Impact**: Existing MCPServers relying on SSE default will break
   - **Action Required**: Add explicit `transport: sse` to all existing MCPServer manifests before upgrade
   - **Risk Level**: HIGH

2. **Authentication API Refactoring** (v0.6.0):
   - **Change**: Removed GetClaimsFromContext backward compatibility helper
   - **Impact**: Custom authentication integrations may break
   - **Action Required**: Review custom auth implementations
   - **Risk Level**: MEDIUM (only affects custom integrations)

3. **OAuth Secret Management** (v0.6.0):
   - **Change**: Moved to new package structure
   - **Impact**: Custom OAuth implementations need updates
   - **Action Required**: Review OAuth configurations
   - **Risk Level**: LOW (operator-internal change)

### Optional New Features

1. **MCPRegistry PVC Support**:
   - Opt-in feature for airgapped/offline scenarios
   - No migration required for existing registries
   - Enable by adding `pvcRef` to registry entries

2. **VirtualMCPServer**:
   - Entirely new feature - no migration needed
   - Opt-in for advanced use cases
   - Requires creating new MCPGroup and VirtualMCPServer resources

3. **Enhanced Authentication**:
   - New OIDC, authz, and permission features are optional
   - Existing servers work without these configurations
   - Incrementally adopt for security hardening

4. **Telemetry**:
   - Observability features are opt-in
   - Add `telemetry` configuration as needed
   - No impact on existing servers

### Default Value Changes

| Field | v0.4.2 Default | v0.6.11 Default | Impact |
|-------|----------------|-----------------|--------|
| MCPServer.transport | sse | streamable-http | BREAKING |
| MCPServer.proxyPort | 8080 | 8080 | No change |
| MCPRemoteProxy.transport | sse | streamable-http | BREAKING |
| VirtualMCPCompositeToolDefinition.failureMode | N/A | abort | New CRD |
| VirtualMCPCompositeToolDefinition.timeout | N/A | 30m | New CRD |

### Pre-Upgrade Checklist

- [ ] **Audit all MCPServer resources** for implicit SSE transport dependency
- [ ] **Add explicit `transport: sse`** to MCPServer manifests if needed
- [ ] **Review MCPRemoteProxy resources** for transport defaults
- [ ] **Backup all CRD instances** before upgrade
- [ ] **Test CRD schema updates** in non-production environment
- [ ] **Verify RBAC permissions** include new VirtualMCP resources
- [ ] **Update operator RBAC** with Gateway API permissions
- [ ] **Plan VirtualMCP adoption** (optional, post-upgrade)

### Post-Upgrade Validation

- [ ] **Verify existing MCPServer instances reconcile** without errors
- [ ] **Check MCPRegistry resources** continue syncing
- [ ] **Validate MCPRemoteProxy connections** to remote servers
- [ ] **Test new CRD installations** (VirtualMCPServer, VirtualMCPCompositeToolDefinition)
- [ ] **Monitor operator logs** for deprecation warnings
- [ ] **Verify metrics/telemetry** if enabled

---

## Summary

### Data Model Evolution

The v0.4.2 → v0.6.11 upgrade represents a **major evolution** of the ToolHive Operator data model:

**Quantitative Changes**:
- **2 new CRDs** (VirtualMCPServer, VirtualMCPCompositeToolDefinition)
- **10+ new fields** in MCPServer (authz, oidc, telemetry, etc.)
- **4+ new fields** in MCPRegistry (pvcRef, syncPolicy, filter, format)
- **1 breaking change** (transport default)

**Qualitative Changes**:
- **Virtual MCP Server Capability**: Major new feature for server aggregation and workflow orchestration
- **Enhanced Security**: Comprehensive authentication (OIDC) and authorization (authz, permissionProfile)
- **Observability**: Telemetry support for metrics and tracing
- **Operational Flexibility**: PVC support, sync policies, filtering
- **Workflow Engine**: Composite tool definitions for multi-step workflows

### Backward Compatibility Assessment

**Overall**: **90% Backward Compatible** with one critical breaking change

**Compatible**:
- Existing MCPRegistry resources (all new fields optional)
- MCPExternalAuthConfig, MCPGroup, MCPToolConfig (minimal changes)
- RBAC structure (additive changes only)
- Namespace and deployment model

**Breaking**:
- MCPServer/MCPRemoteProxy transport default (requires explicit configuration)

**New/Optional**:
- VirtualMCPServer (new capability, opt-in)
- VirtualMCPCompositeToolDefinition (new capability, opt-in)
- Enhanced auth/authz features (opt-in)
- Telemetry (opt-in)

### Recommended Upgrade Strategy

1. **Phase 1 - Preparation**:
   - Audit and update MCPServer manifests with explicit `transport` field
   - Backup all CRD instances
   - Review release notes for v0.5.0, v0.6.0, v0.6.10, v0.6.11

2. **Phase 2 - CRD Updates**:
   - Update 6 existing CRDs to v0.6.11 schemas
   - Add 2 new CRDs (VirtualMCP)
   - Validate schema compatibility

3. **Phase 3 - RBAC Updates**:
   - Add VirtualMCP permissions to ClusterRole
   - Add Gateway API permissions
   - Create registry-api service account (if needed)

4. **Phase 4 - Operator Upgrade**:
   - Deploy operator v0.6.11
   - Update environment variables
   - Monitor reconciliation of existing resources

5. **Phase 5 - Feature Adoption** (Post-Upgrade):
   - Gradually adopt new security features (OIDC, authz)
   - Evaluate VirtualMCP use cases
   - Enable telemetry for observability

### Risk Assessment

**Low Risk**:
- MCPRegistry updates (all additive)
- New CRD additions (isolated)
- RBAC enhancements (additive)

**Medium Risk**:
- MCPServer schema enhancements (extensive but optional)
- Authentication refactoring (affects custom integrations)

**High Risk**:
- Transport default change (requires explicit migration)

**Mitigation**:
- Thorough testing in non-production environment
- Phased rollout with validation gates
- Rollback plan with CRD backups
- Monitor operator logs for deprecation warnings

---

## References

- Research Document: `/wip/src/github.com/RHEcosystemAppEng/toolhive-operator-metadata/specs/015-upgrade-toolhive-operator/research.md`
- Upstream Repository: https://github.com/stacklok/toolhive
- CRD Helm Chart v0.0.74: https://github.com/stacklok/toolhive/tree/toolhive-operator-crds-0.0.74/deploy/charts/operator-crds
- Operator Helm Chart v0.5.9: https://github.com/stacklok/toolhive/tree/toolhive-operator-0.5.8/deploy/charts/operator
- Release v0.6.11: https://github.com/stacklok/toolhive/releases/tag/v0.6.11
- Release v0.6.0: https://github.com/stacklok/toolhive/releases/tag/v0.6.0
