# Research: OpenShift Security Context Requirements

**Feature**: Fix Security Context for OpenShift Compatibility
**Date**: 2025-10-16
**Status**: Complete

## Overview

This research document captures the findings for fixing security context violations in the ToolHive Operator deployment manifests to comply with OpenShift's restricted-v2 security policy.

## Research Areas

### 1. OpenShift Restricted-v2 Security Policy Requirements

**Decision**: Remove hardcoded `runAsUser: 1000` and rely on OpenShift dynamic UID assignment

**Rationale**:
- OpenShift's restricted-v2 Security Context Constraint (SCC) enforces MustRunAsRange strategy for runAsUser
- This means pods MUST NOT specify a hardcoded UID; OpenShift assigns UIDs dynamically from the namespace's UID range
- Specifying `runAsUser: 1000` violates this constraint and causes pod startup failure
- The operator container must be compatible with running as an arbitrary UID (standard for OpenShift-ready containers)

**Key Requirements Identified**:
- `runAsNonRoot: true` MUST be set at both pod and container level
- `runAsUser` field MUST be absent (not set) or explicitly removed in container securityContext
- `seccompProfile.type: RuntimeDefault` MUST be set at pod level
- `allowPrivilegeEscalation: false` MUST be set at container level
- `readOnlyRootFilesystem: true` MUST be set at container level
- `capabilities.drop: [ALL]` MUST be set at container level

**References**:
- OpenShift documentation on Pod Security Standards
- Example from toolhive Helm chart values-openshift.yaml (lines 43-56)
- Upstream Kubebuilder default security context in manager.yaml

**Alternatives Considered**:
- **Alternative 1**: Create custom SCC with relaxed runAsUser constraints
  - **Rejected**: Violates security best practices and requires cluster-admin privileges for SCC creation
  - Adds operational complexity for OpenShift administrators
  - Not portable across OpenShift clusters with different security policies

- **Alternative 2**: Modify upstream manager.yaml directly
  - **Rejected**: Violates Constitution Principle II (Kustomize-Based Customization)
  - Makes future upstream updates difficult to merge
  - Loses traceability of what was changed and why

- **Alternative 3**: Use strategic merge patch instead of JSON patch
  - **Rejected**: Strategic merge cannot remove fields (like runAsUser), only add/replace
  - JSON patch with "remove" operation is the appropriate kustomize tool for field removal

### 2. Kustomize JSON Patch Best Practices for Security Context

**Decision**: Use JSON patch operations in `config/base/openshift_sec_patches.yaml`

**Rationale**:
- Kustomize JSON patches allow precise removal of specific fields (runAsUser)
- Current file already uses JSON patch format for adding seccompProfile and removing runAsUser
- Extends existing pattern without introducing new patch mechanisms
- Clear diff visibility showing exactly what changed from upstream

**Implementation Pattern**:
```yaml
# Remove operation for runAsUser
- op: remove
  path: /spec/template/spec/containers/0/securityContext/runAsUser

# Add operation for missing pod-level settings
- op: add
  path: /spec/template/spec/securityContext/runAsNonRoot
  value: true

# Replace operation for existing container settings (if needed)
- op: replace
  path: /spec/template/spec/containers/0/securityContext/allowPrivilegeEscalation
  value: false
```

**Alternatives Considered**:
- **Alternative 1**: Use kustomize strategic merge patch
  - **Rejected**: Cannot remove fields, only add/replace
  - Less precise than JSON patch for security context modifications

- **Alternative 2**: Create entirely new manager.yaml in config/base
  - **Rejected**: Duplicates upstream content
  - Harder to track when upstream changes (no clear diff)
  - Violates DRY principle

### 3. Pod vs Container Security Context Hierarchy

**Decision**: Set `runAsNonRoot: true` at both pod and container levels

**Rationale**:
- Container-level settings override pod-level settings when both are present
- Setting at both levels ensures consistency and explicit intent
- Matches pattern from working OpenShift Helm chart reference
- Provides defense-in-depth: if container setting is accidentally removed, pod-level remains

**Key Findings**:
- `seccompProfile` is a pod-level setting (applies to all containers)
- `runAsNonRoot` can be set at both pod and container level (container overrides pod if different)
- `allowPrivilegeEscalation`, `readOnlyRootFilesystem`, `capabilities` are container-only settings
- `runAsUser` (when present) can be set at either level but MUST be omitted for OpenShift restricted-v2

**Reference Architecture**:
```
Pod Security Context:
  runAsNonRoot: true
  seccompProfile:
    type: RuntimeDefault

Container Security Context:
  runAsNonRoot: true
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop:
    - ALL
  # runAsUser: MUST BE ABSENT
```

### 4. Current State Analysis

**Current Configuration** (config/base/openshift_sec_patches.yaml):
```yaml
- op: add
  path: /spec/template/spec/securityContext/seccompProfile
  value:
    type: RuntimeDefault

- op: remove
  path: /spec/template/spec/containers/0/securityContext/runAsUser
```

**Current Configuration** (config/manager/manager.yaml - upstream):
```yaml
spec:
  template:
    spec:
      securityContext:
        runAsNonRoot: true
      containers:
      - name: manager
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop:
            - ALL
          readOnlyRootFilesystem: true
          runAsNonRoot: true
          runAsUser: 1000  # THIS CAUSES THE VIOLATION
```

**Gap Analysis**:
- ✅ Pod-level `runAsNonRoot: true` already present in upstream
- ✅ Pod-level `seccompProfile` added by existing patch
- ✅ Container-level `allowPrivilegeEscalation: false` already present
- ✅ Container-level `capabilities.drop: [ALL]` already present
- ✅ Container-level `readOnlyRootFilesystem: true` already present
- ✅ Container-level `runAsNonRoot: true` already present
- ❌ Container-level `runAsUser: 1000` being removed by patch BUT...

**Issue Found**: The existing patch removes runAsUser, which should be sufficient. Need to verify the patch is actually being applied during kustomize build.

**Hypothesis**: Either:
1. The patch path is incorrect (array index changed)
2. The patch is not included in kustomization.yaml
3. The patch is being applied but then overridden by another patch
4. The catalog build is not picking up the latest manifests

### 5. Validation Strategy

**Decision**: Multi-layer validation approach

**Validation Steps**:
1. **Kustomize Build Validation**:
   - Run `kustomize build config/base` and verify runAsUser is absent in output
   - Run `kustomize build config/default` to ensure base config remains valid
   - Parse YAML output to programmatically verify security context fields

2. **Catalog Build Validation**:
   - Rebuild OLM catalog after manifest changes
   - Verify catalog renders without errors
   - Check bundle metadata includes updated manifests

3. **OpenShift Deployment Test**:
   - Deploy operator via OperatorHub
   - Verify pod enters Running state
   - Check pod events for security violations
   - Inspect pod spec to confirm applied security context

**Success Criteria**:
- `kustomize build config/base` succeeds without errors
- Output YAML has no `runAsUser` field in container securityContext
- Pod starts successfully in OpenShift with restricted-v2 SCC
- No security violation errors in pod events

## Summary of Findings

| Topic | Decision | Key Insight |
|-------|----------|-------------|
| runAsUser removal | Remove field entirely | OpenShift assigns UIDs dynamically; hardcoded values violate restricted-v2 |
| Patch mechanism | JSON patch operations | Precise field removal capability required |
| Security context hierarchy | Set at both pod & container | Defense-in-depth, explicit intent |
| Current patch status | Verify application | Patch exists but need to confirm it's being applied correctly |
| Validation | Multi-layer approach | Build-time + runtime validation required |

## Open Questions Resolved

**Q1**: Should we set runAsUser to a different value instead of removing it?
**A1**: No. OpenShift restricted-v2 SCC requires dynamic UID assignment. The field must be absent.

**Q2**: Do we need a custom SCC?
**A2**: No. The restricted-v2 SCC (default) is sufficient when security context is properly configured.

**Q3**: Will this break standard Kubernetes deployments?
**A3**: No. These security settings are compatible with standard Kubernetes. The changes make the deployment more secure across all platforms.

**Q4**: Should changes go in config/default or config/base?
**A4**: config/base per Constitution Principle IV - OpenShift-specific patches belong in the OpenShift overlay.

## Next Steps

1. Verify existing patch in openshift_sec_patches.yaml is correctly referenced in kustomization.yaml
2. Test `kustomize build config/base` output to confirm runAsUser is absent
3. If patch is not working, debug patch path and operation
4. Proceed to Phase 1 design artifacts (data-model, contracts, quickstart)
