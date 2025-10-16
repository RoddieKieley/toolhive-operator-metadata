# Quickstart: Fix Security Context for OpenShift Compatibility

**Feature**: Fix Security Context for OpenShift Compatibility
**Date**: 2025-10-16
**Audience**: Developers implementing the security context fix

## Problem Statement

The ToolHive Operator pod fails to start in OpenShift due to security context violation:
- Current issue: `runAsUser: 1000` violates OpenShift restricted-v2 SCC
- Impact: Operator cannot be installed via OperatorHub
- Root cause: Hardcoded UID conflicts with OpenShift's dynamic UID assignment

## Solution Overview

Modify kustomize patches to ensure security context complies with OpenShift restricted-v2 requirements:
1. Verify existing patch removes `runAsUser` field
2. Confirm all required security context fields are present
3. Test manifest build and OpenShift deployment
4. Rebuild OLM catalog with fixed manifests

## Prerequisites

Before starting implementation:

- [ ] OpenShift 4.12+ cluster access for testing
- [ ] `kustomize` CLI installed (v5.0+)
- [ ] `kubectl` or `oc` CLI for deployment testing
- [ ] `yq` (YAML processor) for output validation
- [ ] `opm` CLI for catalog operations
- [ ] Repository cloned and on branch `008-fix-security-context`

## Implementation Steps

### Step 1: Verify Current Patch Configuration

**Goal**: Confirm existing patches and identify gaps

```bash
# Check current patch file
cat config/base/openshift_sec_patches.yaml

# Verify patch is referenced in kustomization
grep -A 10 "patchesJson6902\|patches:" config/base/kustomization.yaml

# Build and inspect output
kustomize build config/base > /tmp/output.yaml

# Check if runAsUser is present (should be absent)
yq '.spec.template.spec.containers[0].securityContext.runAsUser' /tmp/output.yaml
# Expected: null

# Check if seccompProfile is present
yq '.spec.template.spec.securityContext.seccompProfile' /tmp/output.yaml
# Expected: {type: RuntimeDefault}
```

**Success Criteria**:
- Patch file exists at `config/base/openshift_sec_patches.yaml`
- Patch removes `runAsUser` from container security context
- Patch adds `seccompProfile` to pod security context
- Build succeeds without errors
- Output has no `runAsUser` field in container security context

### Step 2: Validate Against Security Context Schema

**Goal**: Ensure all required fields are present in build output

```bash
# Run all validation checks from contracts/security-context-schema.yaml

# Critical validations
echo "=== CRITICAL VALIDATIONS ==="

# 1. runAsUser must be absent at container level
echo -n "runAsUser absent: "
if [ "$(yq '.spec.template.spec.containers[0].securityContext | has("runAsUser")' /tmp/output.yaml)" = "false" ]; then
  echo "✅ PASS"
else
  echo "❌ FAIL"
fi

# 2. runAsNonRoot must be true at pod level
echo -n "Pod runAsNonRoot: "
if [ "$(yq '.spec.template.spec.securityContext.runAsNonRoot' /tmp/output.yaml)" = "true" ]; then
  echo "✅ PASS"
else
  echo "❌ FAIL"
fi

# 3. runAsNonRoot must be true at container level
echo -n "Container runAsNonRoot: "
if [ "$(yq '.spec.template.spec.containers[0].securityContext.runAsNonRoot' /tmp/output.yaml)" = "true" ]; then
  echo "✅ PASS"
else
  echo "❌ FAIL"
fi

# 4. seccompProfile must be RuntimeDefault
echo -n "seccompProfile: "
if [ "$(yq '.spec.template.spec.securityContext.seccompProfile.type' /tmp/output.yaml)" = "RuntimeDefault" ]; then
  echo "✅ PASS"
else
  echo "❌ FAIL"
fi

# 5. allowPrivilegeEscalation must be false
echo -n "allowPrivilegeEscalation: "
if [ "$(yq '.spec.template.spec.containers[0].securityContext.allowPrivilegeEscalation' /tmp/output.yaml)" = "false" ]; then
  echo "✅ PASS"
else
  echo "❌ FAIL"
fi

# 6. readOnlyRootFilesystem must be true
echo -n "readOnlyRootFilesystem: "
if [ "$(yq '.spec.template.spec.containers[0].securityContext.readOnlyRootFilesystem' /tmp/output.yaml)" = "true" ]; then
  echo "✅ PASS"
else
  echo "❌ FAIL"
fi

# 7. capabilities must drop ALL
echo -n "capabilities drop ALL: "
if yq '.spec.template.spec.containers[0].securityContext.capabilities.drop | contains(["ALL"])' /tmp/output.yaml | grep -q "true"; then
  echo "✅ PASS"
else
  echo "❌ FAIL"
fi
```

**Success Criteria**: All validations show ✅ PASS

### Step 3: Test Kustomize Builds

**Goal**: Verify both base and default overlays build successfully

```bash
# Build base (OpenShift) configuration
echo "Building config/base..."
kustomize build config/base > /tmp/base-output.yaml
if [ $? -eq 0 ]; then
  echo "✅ Base build succeeded"
else
  echo "❌ Base build failed"
  exit 1
fi

# Build default configuration
echo "Building config/default..."
kustomize build config/default > /tmp/default-output.yaml
if [ $? -eq 0 ]; then
  echo "✅ Default build succeeded"
else
  echo "❌ Default build failed"
  exit 1
fi

# Verify default config still has runAsUser: 1000 (not patched)
echo -n "Default config runAsUser (should be 1000): "
yq '.spec.template.spec.containers[0].securityContext.runAsUser' /tmp/default-output.yaml

# Verify base config has no runAsUser (patched)
echo -n "Base config runAsUser (should be null): "
yq '.spec.template.spec.containers[0].securityContext.runAsUser' /tmp/base-output.yaml
```

**Success Criteria**:
- Both builds succeed without errors
- Base config has `runAsUser` removed
- Default config retains original `runAsUser: 1000` (shows patch is targeted correctly)

### Step 4: Deploy and Test in OpenShift

**Goal**: Verify operator pod starts successfully in OpenShift

```bash
# Ensure you're connected to OpenShift cluster
oc whoami
oc project opendatahub || oc new-project opendatahub

# Apply manifests
echo "Deploying to OpenShift..."
oc apply -k config/base

# Wait for deployment to create pod
echo "Waiting for pod creation..."
sleep 5

# Wait for pod to be ready (max 120 seconds)
echo "Waiting for pod to be ready..."
oc wait --for=condition=Ready pod -l control-plane=controller-manager --timeout=120s

if [ $? -eq 0 ]; then
  echo "✅ Pod is ready"
else
  echo "❌ Pod failed to become ready"
  echo "Checking pod events..."
  oc describe pod -l control-plane=controller-manager
  exit 1
fi

# Check for security violations in events
echo "Checking for security violations..."
VIOLATIONS=$(oc describe pod -l control-plane=controller-manager | grep -i "security\|violation\|forbidden" || true)
if [ -z "$VIOLATIONS" ]; then
  echo "✅ No security violations found"
else
  echo "❌ Security violations detected:"
  echo "$VIOLATIONS"
  exit 1
fi

# Verify assigned UID
echo "Checking assigned UID..."
ASSIGNED_UID=$(oc get pod -l control-plane=controller-manager -o jsonpath='{.items[0].status.containerStatuses[0].user.uid}' 2>/dev/null || echo "not available")
echo "Assigned UID: $ASSIGNED_UID"
if [ "$ASSIGNED_UID" != "1000" ]; then
  echo "✅ UID dynamically assigned (not hardcoded 1000)"
else
  echo "⚠️  UID is 1000 (check if OpenShift range includes this)"
fi

# Check pod logs for startup errors
echo "Checking pod logs..."
oc logs -l control-plane=controller-manager --tail=20
```

**Success Criteria**:
- Pod enters Running state
- Pod condition Ready is True
- No security violation events
- UID is dynamically assigned by OpenShift
- Operator logs show successful startup

### Step 5: Rebuild OLM Catalog

**Goal**: Update catalog with fixed manifests for OperatorHub distribution

```bash
# Navigate to catalog directory
cd catalogs/toolhive-catalog

# Rebuild catalog with updated manifests
# (Exact command depends on catalog build process)
# Example using opm:
opm validate .

# If using a Makefile or script:
# make catalog-build
# OR
# ./build-catalog.sh

# Verify catalog builds successfully
echo "Catalog validation complete"
```

**Success Criteria**:
- Catalog builds without validation errors
- Updated operator bundle includes fixed manifests
- Catalog can be deployed to cluster

### Step 6: End-to-End Verification via OperatorHub

**Goal**: Verify complete installation flow through OperatorHub

```bash
# Clean up previous deployment
oc delete -k config/base
oc delete project opendatahub
oc new-project opendatahub

# Deploy updated catalog to cluster
# (Command depends on your catalog deployment method)
# Example:
# oc apply -f catalog-source.yaml

# Wait for catalog source to be ready
# oc wait --for=condition=Ready catalogsource/toolhive-catalog --timeout=300s

# Install operator via OperatorHub UI or CLI
# Via CLI example:
# oc apply -f subscription.yaml

# Monitor operator installation
oc get csv -n opendatahub -w

# Verify operator pod starts
oc wait --for=condition=Ready pod -l control-plane=controller-manager -n opendatahub --timeout=180s

# Final verification
echo "✅ Operator installed successfully via OperatorHub"
```

**Success Criteria**:
- Catalog source appears in OperatorHub
- Operator installation succeeds
- Operator pod starts without security violations
- Operator is functional (can create MCPServer/MCPRegistry resources)

## Troubleshooting

### Issue: runAsUser still present in output

**Symptom**: `yq` shows runAsUser value in build output

**Diagnosis**:
```bash
# Check if patch is referenced
grep openshift_sec_patches.yaml config/base/kustomization.yaml

# Verify patch syntax
kustomize build config/base --enable-alpha-plugins
```

**Solution**:
- Ensure patch file is listed in `patchesJson6902` or `patches` section
- Verify target matches: `kind: Deployment`, `name: controller-manager`
- Check JSON path: `/spec/template/spec/containers/0/securityContext/runAsUser`
- Container index may have changed if upstream added containers

### Issue: Pod fails with "container has runAsNonRoot and image will run as root"

**Symptom**: Pod events show runAsNonRoot violation

**Diagnosis**:
```bash
# Check container image user
podman inspect ghcr.io/stacklok/toolhive/operator:v0.2.17 | jq '.[0].Config.User'
```

**Solution**:
- Upstream container image must support running as non-root
- Check if image has USER directive set to non-root
- May require upstream fix if image expects root

### Issue: Pod fails with "error creating fsGroup directory"

**Symptom**: Pod can't start due to volume permission issues

**Diagnosis**:
```bash
# Check volumes and fsGroup
oc get pod -l control-plane=controller-manager -o yaml | yq '.spec.securityContext'
```

**Solution**:
- Add `fsGroup` to pod security context if volumes are used
- Ensure volumes support fsGroup (some volume types don't)

### Issue: Kustomize build fails with "path not found"

**Symptom**: `kustomize build` errors on patch application

**Diagnosis**:
```bash
# Validate patch paths against source
kustomize build config/manager
yq '.spec.template.spec.containers' config/manager/manager.yaml
```

**Solution**:
- Verify container index in path (containers/0 or containers/1)
- Check if upstream changed deployment structure
- Use `op: test` before `op: remove` for conditional removal

## Quick Reference

### Key Files Modified
- `config/base/openshift_sec_patches.yaml` - JSON patches (verify/modify)
- `config/base/kustomization.yaml` - Patch references (verify inclusion)

### Key Commands
```bash
# Build and validate
kustomize build config/base | yq '.spec.template.spec.containers[0].securityContext.runAsUser'

# Deploy to OpenShift
oc apply -k config/base

# Check pod status
oc get pod -l control-plane=controller-manager
oc describe pod -l control-plane=controller-manager

# View logs
oc logs -l control-plane=controller-manager
```

### Expected Security Context (Final State)
```yaml
Pod securityContext:
  runAsNonRoot: true
  seccompProfile:
    type: RuntimeDefault

Container securityContext:
  runAsNonRoot: true
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop: [ALL]
  # runAsUser: ABSENT
```

## Next Steps After Successful Implementation

1. Create pull request with changes
2. Update CHANGELOG.md or release notes
3. Tag new operator version
4. Publish updated catalog to registry
5. Test installation on fresh OpenShift cluster
6. Document OpenShift compatibility in README

## References

- [Feature Specification](spec.md)
- [Implementation Plan](plan.md)
- [Research Findings](research.md)
- [Data Model](data-model.md)
- [Contracts](contracts/)
- [OpenShift SCC Documentation](https://docs.openshift.com/container-platform/latest/authentication/managing-security-context-constraints.html)
- [Kustomize JSON Patches](https://kubectl.docs.kubernetes.io/references/kustomize/kustomization/patchesjson6902/)
