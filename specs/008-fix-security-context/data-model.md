# Data Model: Security Context Configuration

**Feature**: Fix Security Context for OpenShift Compatibility
**Date**: 2025-10-16
**Status**: Complete

## Overview

This feature involves modifying Kubernetes manifest configurations rather than application data models. The "entities" in this context are Kubernetes resource specifications and kustomize patch definitions.

## Entity Definitions

### 1. Pod Security Context

**Description**: Pod-level security settings that apply to all containers in a pod. Defined in the Deployment spec at `spec.template.spec.securityContext`.

**Attributes**:
- `runAsNonRoot` (boolean, required): Must be `true` - ensures pod cannot run as root user
- `seccompProfile.type` (string, required): Must be `RuntimeDefault` - enables default seccomp profile
- `runAsUser` (integer, MUST BE ABSENT): If present, causes OpenShift restricted-v2 violation

**Validation Rules**:
- `runAsNonRoot` MUST be explicitly set to `true`
- `seccompProfile.type` MUST be set to `RuntimeDefault`
- `runAsUser` field MUST NOT be present at pod level

**Relationships**:
- Parent: Deployment.spec.template.spec
- Applies to: All containers in the pod template

**State Transitions**: N/A (static configuration)

**Example**:
```yaml
securityContext:
  runAsNonRoot: true
  seccompProfile:
    type: RuntimeDefault
```

### 2. Container Security Context

**Description**: Container-level security settings that can override pod-level settings. Defined in the Deployment spec at `spec.template.spec.containers[].securityContext`.

**Attributes**:
- `runAsNonRoot` (boolean, required): Must be `true` - reinforces pod-level setting
- `allowPrivilegeEscalation` (boolean, required): Must be `false` - prevents privilege escalation
- `readOnlyRootFilesystem` (boolean, required): Must be `true` - makes root filesystem read-only
- `capabilities.drop` (array of strings, required): Must include `["ALL"]` - drops all Linux capabilities
- `runAsUser` (integer, MUST BE ABSENT): If present, causes OpenShift restricted-v2 violation

**Validation Rules**:
- `runAsNonRoot` MUST be `true`
- `allowPrivilegeEscalation` MUST be `false`
- `readOnlyRootFilesystem` MUST be `true`
- `capabilities.drop` MUST include `ALL`
- `runAsUser` field MUST NOT be present

**Relationships**:
- Parent: Deployment.spec.template.spec.containers[0] (manager container)
- Overrides: Pod-level securityContext for this container
- Constrained by: OpenShift Security Context Constraint (restricted-v2)

**State Transitions**: N/A (static configuration)

**Example**:
```yaml
securityContext:
  runAsNonRoot: true
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop:
    - ALL
```

### 3. Kustomize JSON Patch

**Description**: A kustomize patch operation that modifies Kubernetes manifests during build. Defined in `config/base/openshift_sec_patches.yaml`.

**Attributes**:
- `op` (string, required): Operation type - one of `add`, `remove`, `replace`, `test`
- `path` (string, required): JSON Pointer path to the field being modified
- `value` (any, conditional): Value to add/replace - required for `add` and `replace` operations

**Validation Rules**:
- `op` MUST be one of the allowed operation types
- `path` MUST be a valid JSON Pointer referencing an existing or parent path in the target manifest
- For `remove` operations: `value` MUST be absent
- For `add` operations: parent path MUST exist
- For `replace` operations: target path MUST exist

**Relationships**:
- Target: Deployment manifest in config/manager/manager.yaml
- Applied by: kustomize build process
- Included via: config/base/kustomization.yaml patchesJson6902 directive

**Patch Operations for This Feature**:

1. **Add seccompProfile** (already exists):
   - `op: add`
   - `path: /spec/template/spec/securityContext/seccompProfile`
   - `value: {type: RuntimeDefault}`

2. **Remove runAsUser** (already exists):
   - `op: remove`
   - `path: /spec/template/spec/containers/0/securityContext/runAsUser`

**Example**:
```yaml
- op: add
  path: /spec/template/spec/securityContext/seccompProfile
  value:
    type: RuntimeDefault

- op: remove
  path: /spec/template/spec/containers/0/securityContext/runAsUser
```

### 4. Kustomization Configuration

**Description**: The kustomize configuration file that orchestrates manifest builds and patch application.

**Attributes**:
- `resources` (array of strings): Base resources to include
- `patchesJson6902` (array of objects): JSON patch definitions
- `namespace` (string): Target namespace for resources
- `namePrefix` (string): Prefix for resource names

**Validation Rules**:
- All referenced patch files MUST exist
- All patch targets MUST exist in resources
- Patch paths MUST be valid for their target resources

**Relationships**:
- References: config/manager/manager.yaml (via resources or bases)
- Includes: openshift_sec_patches.yaml (via patchesJson6902)
- Builds to: Final Kubernetes manifests for OpenShift deployment

**Example**:
```yaml
patchesJson6902:
- target:
    group: apps
    version: v1
    kind: Deployment
    name: controller-manager
  path: openshift_sec_patches.yaml
```

## Data Flow

```
config/manager/manager.yaml (upstream base manifest with runAsUser: 1000)
    ↓
kustomize build process
    ↓
Apply patches from config/base/openshift_sec_patches.yaml
    ↓
Output manifest with:
  - seccompProfile added
  - runAsUser removed
    ↓
OLM bundle creation
    ↓
Catalog build
    ↓
OpenShift deployment via OperatorHub
    ↓
Pod starts with OpenShift-assigned UID
```

## Field Dependencies

| Field | Depends On | Reason |
|-------|-----------|--------|
| securityContext.seccompProfile | Pod security context exists | Must add to existing securityContext block |
| containers[0].securityContext fields | Container definition exists | Security context nested under container |
| JSON patch path | Target field structure | Path must match actual manifest structure |

## Constraints

### OpenShift Restricted-v2 SCC Constraints

The following constraints are enforced by OpenShift's restricted-v2 Security Context Constraint:

| Field | Constraint | Enforcement |
|-------|-----------|-------------|
| runAsUser | MustRunAsRange | Must be absent; OpenShift assigns from namespace UID range |
| runAsNonRoot | MustRunAsNonRoot | Must be true |
| seccompProfile | RuntimeDefault | Must be RuntimeDefault or Localhost |
| allowPrivilegeEscalation | false | Must be false |
| capabilities | Drop ALL | Must drop all capabilities |
| readOnlyRootFilesystem | true (recommended) | Should be true for security |

### Kustomize Patch Constraints

- Patch operations execute in order defined in the file
- Remove operations fail if path doesn't exist (unless using `op: test` first)
- Add operations fail if parent path doesn't exist
- Array indices are zero-based and must reference existing elements

## Configuration Schema

### Complete Security Context Configuration

**Pod Level** (`spec.template.spec.securityContext`):
```yaml
runAsNonRoot: true
seccompProfile:
  type: RuntimeDefault
```

**Container Level** (`spec.template.spec.containers[0].securityContext`):
```yaml
runAsNonRoot: true
allowPrivilegeEscalation: false
readOnlyRootFilesystem: true
capabilities:
  drop:
  - ALL
```

**Fields MUST NOT Include**:
- `runAsUser` (at either pod or container level)
- `runAsGroup` (optional, but if present must align with OpenShift's dynamic assignment)

## Notes

- This is a configuration-only feature with no runtime data model
- No database schemas or API models are involved
- The "data" being modeled is Kubernetes manifest structure
- Changes are declarative and applied at deployment time
- No application code changes required
