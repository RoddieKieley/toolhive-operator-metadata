# Quickstart: Upgrading ToolHive Operator to v0.6.11

**Feature**: Upgrade ToolHive Operator v0.4.2 → v0.6.11
**Date**: 2025-12-04
**Estimated Time**: 2-4 hours (excluding testing)

## Overview

This guide provides step-by-step instructions for upgrading the ToolHive Operator metadata from v0.4.2 to v0.6.11. The upgrade introduces VirtualMCPServer functionality, enhanced CRDs, and updated operand images.

**Upgrade Scope**:
- 2 new CRDs to add (VirtualMCPServer, VirtualMCPCompositeToolDefinition)
- 6 existing CRDs to update (MCPRegistry, MCPServer, MCPExternalAuthConfig, MCPGroup, MCPRemoteProxy, MCPToolConfig)
- 3 container images to update (operator: v0.6.11, vmcp: v0.6.11, proxyrunner: v0.6.11)
- RBAC permissions to expand (VirtualMCP resources, Gateway API)
- Environment variables to add (TOOLHIVE_VMCP_IMAGE, TOOLHIVE_USE_CONFIGMAP, GOMEMLIMIT, GOGC)
- Bundle and catalog regeneration

**Breaking Change**: Default MCPServer transport changed from `sse` to `streamable-http` in v0.6.0. Existing MCPServer resources that rely on the default will need explicit `transport: sse` added before upgrade.

## Prerequisites

### Tools Required

| Tool | Minimum Version | Purpose | Installation |
|------|----------------|---------|--------------|
| operator-sdk | v1.41.0+ | Bundle generation/validation | https://sdk.operatorframework.io/docs/installation/ |
| opm | v1.49.0+ | Catalog generation/validation | https://github.com/operator-framework/operator-registry/releases |
| kustomize | v5.0+ | Manifest customization | https://kubectl.docs.kubernetes.io/installation/kustomize/ |
| yq | v4+ | YAML processing | https://github.com/mikefarah/yq#install |
| git | Any recent | Source control | (system package manager) |
| jq | Any recent | JSON processing | (system package manager) |
| podman or docker | Any recent | Container operations | (system package manager) |

**Verify tool installation**:

```bash
# Check all required tools
operator-sdk version
opm version
kustomize version
yq --version
git --version
jq --version
podman --version  # or docker --version
```

### Access Requirements

- [ ] Read access to https://github.com/stacklok/toolhive
- [ ] Write access to toolhive-operator-metadata repository
- [ ] Access to ghcr.io container registry (for testing images)
- [ ] OpenShift/Kubernetes test cluster (for validation)

### Pre-Upgrade Checklist

- [ ] Current branch is clean (`git status`)
- [ ] On feature branch `015-upgrade-toolhive-operator` (or create it)
- [ ] Latest changes pulled from upstream
- [ ] Backup of current configuration taken
- [ ] Test cluster available for validation

**Setup feature branch**:

```bash
cd /wip/src/github.com/RHEcosystemAppEng/toolhive-operator-metadata

# Ensure you're on main and up-to-date
git checkout main
git pull origin main

# Create and checkout feature branch
git checkout -b 015-upgrade-toolhive-operator

# Verify branch
git status
```

## Upgrade Procedure

### Phase 1: CRD Updates

#### Step 1.1: Download New CRDs from Upstream

```bash
# Create temporary directory for upstream repository
mkdir -p /tmp/toolhive-upgrade
cd /tmp/toolhive-upgrade

# Clone upstream ToolHive repository
git clone https://github.com/stacklok/toolhive.git
cd toolhive

# Checkout the CRD helm chart tag for v0.6.11
git checkout toolhive-operator-crds-0.0.74

# Verify you're on the correct tag
git describe --tags
# Expected output: toolhive-operator-crds-0.0.74

# Navigate to CRD directory
cd deploy/charts/operator-crds/crds

# List available CRDs
ls -lh *.yaml
```

**Expected CRD files**:
- toolhive.stacklok.dev_mcpexternalauthconfigs.yaml
- toolhive.stacklok.dev_mcpgroups.yaml
- toolhive.stacklok.dev_mcpregistries.yaml
- toolhive.stacklok.dev_mcpremoteproxies.yaml
- toolhive.stacklok.dev_mcpservers.yaml
- toolhive.stacklok.dev_mcptoolconfigs.yaml
- toolhive.stacklok.dev_virtualmcpcompositetooldefinitions.yaml (NEW)
- toolhive.stacklok.dev_virtualmcpservers.yaml (NEW)

#### Step 1.2: Copy All CRDs to Your Repository

```bash
# Navigate to your toolhive-operator-metadata repo
cd /wip/src/github.com/RHEcosystemAppEng/toolhive-operator-metadata

# Copy ALL 8 CRDs (6 updates + 2 new)
cp /tmp/toolhive-upgrade/toolhive/deploy/charts/operator-crds/crds/toolhive.stacklok.dev_*.yaml \
   config/crd/bases/

# Verify all files copied
ls -lh config/crd/bases/
# Should show 8 CRD files with recent timestamps
```

#### Step 1.3: Update CRD Kustomization

Edit the CRD kustomization file to include the new CRDs:

```bash
# Edit the kustomization file
vi config/crd/kustomization.yaml
```

**Update to include all 8 CRDs**:

```yaml
# config/crd/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- bases/toolhive.stacklok.dev_mcpexternalauthconfigs.yaml
- bases/toolhive.stacklok.dev_mcpgroups.yaml
- bases/toolhive.stacklok.dev_mcpregistries.yaml
- bases/toolhive.stacklok.dev_mcpremoteproxies.yaml
- bases/toolhive.stacklok.dev_mcpservers.yaml
- bases/toolhive.stacklok.dev_mcptoolconfigs.yaml
- bases/toolhive.stacklok.dev_virtualmcpcompositetooldefinitions.yaml  # NEW
- bases/toolhive.stacklok.dev_virtualmcpservers.yaml                    # NEW
```

#### Step 1.4: Validate CRD Updates

```bash
# Validate YAML syntax
for crd in config/crd/bases/*.yaml; do
  echo "Validating $crd..."
  yq eval '.' "$crd" > /dev/null || echo "ERROR in $crd"
done

# Count CRDs
echo "Total CRDs: $(ls -1 config/crd/bases/*.yaml | wc -l)"
# Expected: 8

# Check for the new CRDs specifically
ls -lh config/crd/bases/toolhive.stacklok.dev_virtualmcpservers.yaml
ls -lh config/crd/bases/toolhive.stacklok.dev_virtualmcpcompositetooldefinitions.yaml
```

### Phase 2: RBAC Updates

#### Step 2.1: Update ClusterRole with New Permissions

Edit the ClusterRole to add permissions for the new VirtualMCP resources and Gateway API:

```bash
# Edit the ClusterRole
vi config/rbac/role.yaml
```

**Add the following rules to the ClusterRole** (append after existing toolhive.stacklok.dev rules):

```yaml
# VirtualMCPServer permissions (NEW)
- apiGroups:
  - toolhive.stacklok.dev
  resources:
  - virtualmcpservers
  verbs:
  - create
  - delete
  - get
  - list
  - patch
  - update
  - watch
- apiGroups:
  - toolhive.stacklok.dev
  resources:
  - virtualmcpservers/finalizers
  verbs:
  - update
- apiGroups:
  - toolhive.stacklok.dev
  resources:
  - virtualmcpservers/status
  verbs:
  - get
  - patch
  - update

# VirtualMCPCompositeToolDefinition permissions (NEW)
- apiGroups:
  - toolhive.stacklok.dev
  resources:
  - virtualmcpcompositetooldefinitions
  verbs:
  - create
  - delete
  - get
  - list
  - patch
  - update
  - watch
- apiGroups:
  - toolhive.stacklok.dev
  resources:
  - virtualmcpcompositetooldefinitions/finalizers
  verbs:
  - update
- apiGroups:
  - toolhive.stacklok.dev
  resources:
  - virtualmcpcompositetooldefinitions/status
  verbs:
  - get
  - patch
  - update

# Gateway API permissions (NEW - for advanced networking)
- apiGroups:
  - gateway.networking.k8s.io
  resources:
  - gateways
  - httproutes
  verbs:
  - create
  - delete
  - get
  - list
  - patch
  - update
  - watch
```

#### Step 2.2: Validate RBAC Updates

```bash
# Validate YAML syntax
yq eval '.' config/rbac/role.yaml > /dev/null && echo "✅ RBAC YAML valid"

# Count the number of rules for toolhive.stacklok.dev
echo "ToolHive API rules:"
yq eval '.rules[] | select(.apiGroups[] == "toolhive.stacklok.dev") | .resources' config/rbac/role.yaml

# Check for Gateway API permissions
echo "Gateway API rules:"
yq eval '.rules[] | select(.apiGroups[] == "gateway.networking.k8s.io") | .resources' config/rbac/role.yaml
```

### Phase 3: Image and Configuration Updates

#### Step 3.1: Update Makefile Version Variables

```bash
# Edit Makefile
vi Makefile
```

**Update the following variables** (around lines 38-42):

```makefile
# Change from:
OPERATOR_TAG ?= v0.4.2

# To:
OPERATOR_TAG ?= v0.6.11
```

**Also update catalog/bundle/index tags**:

```makefile
# Change catalog tag (around line 12):
CATALOG_TAG ?= v0.6.11

# Change bundle tag (around line 21):
BUNDLE_TAG ?= v0.6.11

# Change index tag (around line 30):
INDEX_TAG ?= v0.6.11
```

#### Step 3.2: Update params.env with New Images

```bash
# Edit params.env
vi config/base/params.env
```

**Update to v0.6.11 and add vmcp image**:

```bash
# config/base/params.env
toolhive-operator-image2=ghcr.io/stacklok/toolhive/operator:v0.6.11
toolhive-operator-image=ghcr.io/stacklok/toolhive/operator:v0.6.11
toolhive-proxy-image=ghcr.io/stacklok/toolhive/proxyrunner:v0.6.11
toolhive-vmcp-image=ghcr.io/stacklok/toolhive/vmcp:v0.6.11
```

#### Step 3.3: Update Manager Deployment with New Environment Variables

Create a new patch file for the additional environment variables:

```bash
# Create new environment variable patch
vi config/base/manager_env_patch.yaml
```

**Add the following content**:

```yaml
# config/base/manager_env_patch.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: controller-manager
  namespace: system
spec:
  template:
    spec:
      containers:
      - name: manager
        env:
        # Existing env vars (unchanged)
        - name: UNSTRUCTURED_LOGS
          value: "false"
        - name: POD_NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
        - name: TOOLHIVE_PROXY_HOST
          value: "0.0.0.0"

        # NEW: VMCP image reference
        - name: TOOLHIVE_VMCP_IMAGE
          value: ghcr.io/stacklok/toolhive/vmcp:v0.6.11

        # NEW: ConfigMap usage flag
        - name: TOOLHIVE_USE_CONFIGMAP
          value: "true"

        # NEW: Go runtime optimization
        - name: GOMEMLIMIT
          value: "150MiB"

        # NEW: Go garbage collection tuning
        - name: GOGC
          value: "75"
```

**Update kustomization to include the patch**:

```bash
# Edit base kustomization
vi config/base/kustomization.yaml
```

**Add the patch to the patchesStrategicMerge section**:

```yaml
# config/base/kustomization.yaml
# ... existing content ...

patchesStrategicMerge:
- remove-namespace.yaml
- openshift_env_var_patch.yaml
- openshift_sec_patches.yaml
- openshift_res_utilization.yaml
- manager_env_patch.yaml  # NEW
```

#### Step 3.4: Update Default Configuration

The default configuration also needs environment variable updates:

```bash
# Check if config/default has manager patches
ls -lh config/default/
```

If `config/default/manager_config.yaml` exists, update it with the same environment variables. Otherwise, create a patch:

```bash
# Create default env patch
vi config/default/manager_env_patch.yaml
```

**Add similar environment variables**:

```yaml
# config/default/manager_env_patch.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: controller-manager
  namespace: system
spec:
  template:
    spec:
      containers:
      - name: manager
        env:
        - name: TOOLHIVE_VMCP_IMAGE
          value: ghcr.io/stacklok/toolhive/vmcp:v0.6.11
        - name: TOOLHIVE_USE_CONFIGMAP
          value: "true"
        - name: GOMEMLIMIT
          value: "150MiB"
        - name: GOGC
          value: "75"
```

**Update config/default/kustomization.yaml**:

```bash
vi config/default/kustomization.yaml
```

**Add the patch**:

```yaml
# config/default/kustomization.yaml
# ... existing content ...

patchesStrategicMerge:
- manager_env_patch.yaml  # Add this line
```

### Phase 4: Validate Manifest Builds

#### Step 4.1: Validate Kustomize Builds

```bash
# Validate config/default builds correctly
echo "Testing config/default..."
kustomize build config/default > /tmp/default-manifests.yaml
echo "✅ config/default build succeeded"

# Validate config/base builds correctly
echo "Testing config/base..."
kustomize build config/base > /tmp/base-manifests.yaml
echo "✅ config/base build succeeded"

# Check for image references in output
echo "Checking image references in config/base..."
grep -E "image:.*v0.6.11" /tmp/base-manifests.yaml || echo "⚠️ Warning: v0.6.11 images not found"

# Verify all 8 CRDs are present
echo "Verifying CRD count..."
grep -c "kind: CustomResourceDefinition" /tmp/base-manifests.yaml
# Expected: 8

# Check for VirtualMCP CRDs specifically
echo "Checking for new VirtualMCP CRDs..."
grep "virtualmcpservers.toolhive.stacklok.dev" /tmp/base-manifests.yaml && echo "✅ VirtualMCPServer CRD found"
grep "virtualmcpcompositetooldefinitions.toolhive.stacklok.dev" /tmp/base-manifests.yaml && echo "✅ VirtualMCPCompositeToolDefinition CRD found"

# Verify new environment variables
echo "Checking for new environment variables..."
grep "TOOLHIVE_VMCP_IMAGE" /tmp/base-manifests.yaml && echo "✅ TOOLHIVE_VMCP_IMAGE found"
grep "TOOLHIVE_USE_CONFIGMAP" /tmp/base-manifests.yaml && echo "✅ TOOLHIVE_USE_CONFIGMAP found"
grep "GOMEMLIMIT" /tmp/base-manifests.yaml && echo "✅ GOMEMLIMIT found"
grep "GOGC" /tmp/base-manifests.yaml && echo "✅ GOGC found"
```

#### Step 4.2: Run Makefile Validation

```bash
# Run kustomize validation target
make kustomize-validate
```

### Phase 5: Bundle and Catalog Regeneration

#### Step 5.1: Clean Previous Artifacts

```bash
# Clean old bundle and catalog
make clean

# Verify cleaned
ls -lh bundle/ catalog/ 2>/dev/null || echo "✅ Cleaned successfully"
```

#### Step 5.2: Generate Bundle

```bash
# Generate new bundle with v0.6.11
make bundle

# Verify bundle generation
echo "Checking bundle contents..."
ls -lh bundle/manifests/

# Count CRDs in bundle
echo "CRDs in bundle:"
ls -1 bundle/manifests/toolhive.stacklok.dev_*.yaml | wc -l
# Expected: 8

# Check CSV metadata
echo "CSV version:"
yq eval '.spec.version' bundle/manifests/toolhive-operator.clusterserviceversion.yaml

# Check for all CRDs in CSV
echo "CRDs listed in CSV:"
yq eval '.spec.customresourcedefinitions.owned[].name' bundle/manifests/toolhive-operator.clusterserviceversion.yaml
```

#### Step 5.3: Validate Bundle

```bash
# Validate with operator-sdk
make bundle-validate-sdk

# Expected output should include:
# ✅ All validation tests passed
```

#### Step 5.4: Generate Catalog

```bash
# Generate FBC catalog
make catalog

# Verify catalog generation
echo "Checking catalog contents..."
ls -lh catalog/toolhive-operator/

# Validate catalog structure
make catalog-validate

# Check catalog metadata
echo "Catalog packages:"
yq eval 'select(.schema == "olm.package")' catalog/toolhive-operator/catalog.yaml

echo "Catalog channels:"
yq eval 'select(.schema == "olm.channel")' catalog/toolhive-operator/catalog.yaml
```

#### Step 5.5: Build Catalog Image (Optional)

```bash
# Build catalog image
make catalog-build

# Validate executable catalog image
make catalog-validate-executable

# Expected output:
# ✅ All validation checks passed - catalog image is executable
```

### Phase 6: Comprehensive Validation

#### Step 6.1: Version Consistency Check

```bash
# Verify all version references are v0.6.11
echo "Checking version consistency..."

# Check Makefile
grep "v0.6.11" Makefile && echo "✅ Makefile versions updated"

# Check params.env
grep "v0.6.11" config/base/params.env && echo "✅ params.env versions updated"

# Check bundle CSV
yq eval '.spec.version' bundle/manifests/toolhive-operator.clusterserviceversion.yaml

# Check bundle metadata
yq eval '.metadata.name' bundle/manifests/toolhive-operator.clusterserviceversion.yaml
# Expected: toolhive-operator.v0.6.11
```

#### Step 6.2: RBAC Validation

```bash
# Verify VirtualMCP permissions in ClusterRole
echo "Checking RBAC for VirtualMCP resources..."

yq eval '.rules[] | select(.resources[] == "virtualmcpservers")' config/rbac/role.yaml && \
  echo "✅ VirtualMCPServer permissions found"

yq eval '.rules[] | select(.resources[] == "virtualmcpcompositetooldefinitions")' config/rbac/role.yaml && \
  echo "✅ VirtualMCPCompositeToolDefinition permissions found"

yq eval '.rules[] | select(.apiGroups[] == "gateway.networking.k8s.io")' config/rbac/role.yaml && \
  echo "✅ Gateway API permissions found"
```

#### Step 6.3: Image Reference Validation

```bash
# Validate all image references in generated manifests
echo "Validating image references..."

kustomize build config/base | grep -E "image:.*ghcr.io/stacklok/toolhive" | sort -u

# Expected images:
# - ghcr.io/stacklok/toolhive/operator:v0.6.11
# - ghcr.io/stacklok/toolhive/proxyrunner:v0.6.11
# - ghcr.io/stacklok/toolhive/vmcp:v0.6.11 (in env var)
```

#### Step 6.4: CSV Validation

```bash
# Check CSV has all required fields
echo "Validating CSV..."

# Check owned CRDs
echo "Owned CRDs in CSV:"
yq eval '.spec.customresourcedefinitions.owned[] | .name + " (version: " + .version + ")"' \
  bundle/manifests/toolhive-operator.clusterserviceversion.yaml

# Should list all 8 CRDs:
# - mcpexternalauthconfigs.toolhive.stacklok.dev
# - mcpgroups.toolhive.stacklok.dev
# - mcpregistries.toolhive.stacklok.dev
# - mcpremoteproxies.toolhive.stacklok.dev
# - mcpservers.toolhive.stacklok.dev
# - mcptoolconfigs.toolhive.stacklok.dev
# - virtualmcpcompositetooldefinitions.toolhive.stacklok.dev
# - virtualmcpservers.toolhive.stacklok.dev

# Check related images
echo "Related images in CSV:"
yq eval '.spec.relatedImages[].image' bundle/manifests/toolhive-operator.clusterserviceversion.yaml | sort -u

# Check install permissions
echo "ClusterRole rules count:"
yq eval '.spec.install.spec.clusterPermissions[0].rules | length' bundle/manifests/toolhive-operator.clusterserviceversion.yaml
```

### Phase 7: Test Cluster Validation (Optional but Recommended)

If you have access to a test Kubernetes/OpenShift cluster:

#### Step 7.1: Deploy CRDs Only

```bash
# Apply just the CRDs to test cluster
kustomize build config/crd | kubectl apply -f -

# Verify CRDs installed
kubectl get crds | grep toolhive.stacklok.dev

# Expected: 8 CRDs including virtualmcpservers and virtualmcpcompositetooldefinitions
```

#### Step 7.2: Create Test VirtualMCPServer Resource

```bash
# Create a test VirtualMCPServer to validate CRD schema
cat <<EOF | kubectl apply -f -
apiVersion: toolhive.stacklok.dev/v1alpha1
kind: VirtualMCPServer
metadata:
  name: test-vmcp
  namespace: default
spec:
  groupRef:
    name: test-group
  incomingAuth:
    type: kubernetes
  serviceType: ClusterIP
EOF

# Check if resource was created
kubectl get virtualmcpservers -n default

# Cleanup test resource
kubectl delete virtualmcpserver test-vmcp -n default
```

#### Step 7.3: Deploy Full Operator (Advanced)

```bash
# Deploy operator to test namespace
kubectl create namespace toolhive-test
kustomize build config/default | kubectl apply -n toolhive-test -f -

# Check operator pod
kubectl get pods -n toolhive-test

# Check operator logs for version
kubectl logs -n toolhive-test -l control-plane=controller-manager

# Look for version indicators and check for errors

# Cleanup
kubectl delete namespace toolhive-test
```

## Validation Checklist

### Manifest Validation
- [ ] `kustomize build config/base` succeeds without errors
- [ ] `kustomize build config/default` succeeds without errors
- [ ] No YAML syntax errors in any manifest files
- [ ] All image references use v0.6.11 tags
- [ ] All 8 CRDs present in kustomize output
- [ ] New environment variables (TOOLHIVE_VMCP_IMAGE, TOOLHIVE_USE_CONFIGMAP, GOMEMLIMIT, GOGC) present

### RBAC Validation
- [ ] ClusterRole includes VirtualMCPServer permissions (create, delete, get, list, patch, update, watch)
- [ ] ClusterRole includes VirtualMCPCompositeToolDefinition permissions
- [ ] ClusterRole includes Gateway API permissions (gateways, httproutes)
- [ ] ClusterRole includes finalizer and status permissions for new CRDs

### Bundle Validation
- [ ] `make bundle` completes successfully
- [ ] `make bundle-validate-sdk` passes all checks
- [ ] CSV version is v0.6.11
- [ ] CSV contains all 8 CRDs in `spec.customresourcedefinitions.owned`
- [ ] CSV related images section includes operator:v0.6.11, vmcp:v0.6.11, proxyrunner:v0.6.11
- [ ] Bundle metadata annotations are correct
- [ ] Scorecard tests pass (optional): `make scorecard-test`

### Catalog Validation
- [ ] `make catalog` completes successfully
- [ ] `make catalog-validate` passes
- [ ] Catalog size is reasonable (>900KB expected)
- [ ] Catalog contains olm.package, olm.channel, olm.bundle schemas
- [ ] `make catalog-build` succeeds (if building image)
- [ ] `make catalog-validate-executable` passes (if building image)

### Runtime Validation (Test Cluster - Optional)
- [ ] CRDs install successfully to cluster
- [ ] Can create VirtualMCPServer test resource
- [ ] Can create VirtualMCPCompositeToolDefinition test resource
- [ ] Operator pod starts successfully
- [ ] Operator logs show v0.6.11 version
- [ ] No RBAC permission errors in operator logs
- [ ] Existing MCPServer/MCPRegistry resources reconcile (if applicable)

## Troubleshooting

### Common Issues

#### Issue: CRD validation fails with schema errors

**Symptoms**:
```
Error: error validating data: ValidationError(CustomResourceDefinition)
```

**Solution**:
1. Ensure you downloaded CRDs from the correct tag: `toolhive-operator-crds-0.0.74`
2. Check for merge conflicts if CRDs were manually edited
3. Verify YAML syntax: `yq eval '.' config/crd/bases/toolhive.stacklok.dev_*.yaml`
4. Re-download CRDs from upstream if corrupted

#### Issue: operator-sdk bundle validate fails

**Symptoms**:
```
Error: Value <some-field>: Invalid value
```

**Solution**:
1. Check CSV has all required fields: `yq eval '.spec' bundle/manifests/toolhive-operator.clusterserviceversion.yaml`
2. Verify all CRDs are listed in `spec.customresourcedefinitions.owned`
3. Ensure version format is correct: `0.6.11` (not `v0.6.11` in CSV version field)
4. Check bundle metadata annotations are complete

#### Issue: Kustomize build fails with "resource not found"

**Symptoms**:
```
Error: unable to find one or more resources
```

**Solution**:
1. Verify all CRD files exist: `ls -lh config/crd/bases/`
2. Check `config/crd/kustomization.yaml` lists all 8 CRDs
3. Ensure no typos in CRD filenames
4. Verify kustomization resources paths are correct

#### Issue: RBAC permission denied errors in operator logs

**Symptoms**:
```
Error: "virtualmcpservers.toolhive.stacklok.dev" is forbidden:
User "system:serviceaccount:..." cannot create resource "virtualmcpservers"
```

**Solution**:
1. Verify ClusterRole includes VirtualMCP permissions
2. Check RoleBinding/ClusterRoleBinding exists
3. Confirm service account is correctly bound to ClusterRole
4. Apply updated RBAC: `kubectl apply -f config/rbac/role.yaml`

#### Issue: Image pull failures for v0.6.11 images

**Symptoms**:
```
Failed to pull image "ghcr.io/stacklok/toolhive/vmcp:v0.6.11":
image not found
```

**Solution**:
1. Verify images exist on ghcr.io:
   ```bash
   podman pull ghcr.io/stacklok/toolhive/operator:v0.6.11
   podman pull ghcr.io/stacklok/toolhive/vmcp:v0.6.11
   podman pull ghcr.io/stacklok/toolhive/proxyrunner:v0.6.11
   ```
2. Check for typos in image references
3. Ensure image pull secrets configured (if registry is private)

#### Issue: Catalog validation fails with "invalid schema"

**Symptoms**:
```
Error: invalid FBC catalog: schema validation failed
```

**Solution**:
1. Regenerate catalog: `make clean && make catalog`
2. Verify opm version: `opm version` (should be v1.49.0+)
3. Check catalog YAML structure: `yq eval '.' catalog/toolhive-operator/catalog.yaml`
4. Ensure bundle was generated successfully before catalog

#### Issue: Environment variables not appearing in deployment

**Symptoms**:
Operator pod doesn't have TOOLHIVE_VMCP_IMAGE or other new env vars

**Solution**:
1. Verify patch file exists: `cat config/base/manager_env_patch.yaml`
2. Check kustomization includes patch: `grep manager_env_patch config/base/kustomization.yaml`
3. Rebuild manifests: `kustomize build config/base | grep -A 20 "env:"`
4. Ensure patch has correct namespace/name selectors

## Rollback Procedure

If the upgrade fails and you need to rollback:

### Rollback Steps

```bash
# 1. Restore CRDs to v0.4.2 versions
git checkout main -- config/crd/bases/

# 2. Restore RBAC to v0.4.2
git checkout main -- config/rbac/role.yaml

# 3. Restore Makefile
git checkout main -- Makefile

# 4. Restore params.env
git checkout main -- config/base/params.env

# 5. Remove new environment variable patch
rm -f config/base/manager_env_patch.yaml
rm -f config/default/manager_env_patch.yaml

# 6. Restore kustomization files
git checkout main -- config/base/kustomization.yaml
git checkout main -- config/default/kustomization.yaml
git checkout main -- config/crd/kustomization.yaml

# 7. Clean generated artifacts
make clean

# 8. Regenerate v0.4.2 bundle and catalog
make bundle
make catalog

# 9. Verify rollback
make kustomize-validate
make bundle-validate-sdk
make catalog-validate

# 10. If on test cluster, redeploy v0.4.2
kustomize build config/default | kubectl apply -f -
```

### Preserve Investigation Data

Before rollback, capture diagnostic information:

```bash
# Save failed manifests
mkdir -p /tmp/upgrade-rollback-$(date +%Y%m%d)
cp -r bundle/ /tmp/upgrade-rollback-$(date +%Y%m%d)/
cp -r catalog/ /tmp/upgrade-rollback-$(date +%Y%m%d)/
kustomize build config/base > /tmp/upgrade-rollback-$(date +%Y%m%d)/base-manifests.yaml

# Save operator logs if deployed
kubectl logs -n toolhive-operator-system -l control-plane=controller-manager \
  > /tmp/upgrade-rollback-$(date +%Y%m%d)/operator-logs.txt

# Save error messages
# Document what failed for future troubleshooting
```

## Next Steps

After successful upgrade validation:

### 1. Commit Changes

```bash
# Stage all changes
git add config/ Makefile bundle/ catalog/

# Review changes
git status
git diff --staged

# Commit with descriptive message
git commit -m "Upgrade ToolHive Operator from v0.4.2 to v0.6.11

- Update all 6 existing CRDs to v0.6.11 schemas
- Add 2 new CRDs: VirtualMCPServer, VirtualMCPCompositeToolDefinition
- Update container images: operator, vmcp, proxyrunner to v0.6.11
- Add RBAC permissions for VirtualMCP resources and Gateway API
- Add new environment variables: TOOLHIVE_VMCP_IMAGE, TOOLHIVE_USE_CONFIGMAP, GOMEMLIMIT, GOGC
- Update Makefile version to v0.6.11
- Regenerate bundle and catalog for OLM deployment

Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

### 2. Push to Remote Repository

```bash
# Push feature branch
git push origin 015-upgrade-toolhive-operator

# Verify push
git log --oneline -1
```

### 3. Create Pull Request

```bash
# Using GitHub CLI (if available)
gh pr create \
  --title "Upgrade ToolHive Operator to v0.6.11" \
  --body "$(cat <<'EOF'
## Summary

This PR upgrades the ToolHive Operator metadata from v0.4.2 to v0.6.11, introducing VirtualMCPServer functionality and enhanced CRDs.

### Changes

- **CRDs**: Updated 6 existing CRDs, added 2 new CRDs (VirtualMCPServer, VirtualMCPCompositeToolDefinition)
- **Images**: Updated to v0.6.11 (operator, vmcp, proxyrunner)
- **RBAC**: Added permissions for VirtualMCP resources and Gateway API
- **Environment Variables**: Added TOOLHIVE_VMCP_IMAGE, TOOLHIVE_USE_CONFIGMAP, GOMEMLIMIT, GOGC
- **Bundle/Catalog**: Regenerated for v0.6.11

### Validation

- [x] Kustomize builds pass (config/default, config/base)
- [x] Bundle validation passes (operator-sdk)
- [x] Catalog validation passes (opm)
- [x] All 8 CRDs present in bundle
- [x] RBAC includes VirtualMCP permissions
- [x] Image references updated to v0.6.11

### Breaking Changes

Default MCPServer transport changed from `sse` to `streamable-http`. Existing resources relying on default will need explicit `transport: sse` configuration.

### References

- Research: specs/015-upgrade-toolhive-operator/research.md
- Data Model: specs/015-upgrade-toolhive-operator/data-model.md
- Upstream Release: https://github.com/stacklok/toolhive/releases/tag/v0.6.11

Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"

# Or create PR manually on GitHub web interface
```

### 4. Update Documentation

```bash
# Update CLAUDE.md with v0.6.11 information
vi CLAUDE.md

# Update README.md if it references version numbers
vi README.md
```

### 5. Deploy to Staging Environment

```bash
# Build and push catalog image
make catalog-build
make catalog-push

# Deploy to staging OpenShift cluster
# (adjust namespace and catalog source as needed)

# Apply catalog source
cat <<EOF | kubectl apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: toolhive-operator-catalog
  namespace: olm
spec:
  sourceType: grpc
  image: ghcr.io/stacklok/toolhive-operator-metadata/catalog:v0.6.11
  displayName: ToolHive Operator Catalog
  publisher: StackLok
  updateStrategy:
    registryPoll:
      interval: 15m
EOF

# Monitor catalog source
kubectl get catalogsource -n olm -w

# Install operator via OperatorHub UI or Subscription
```

### 6. Monitor and Validate

```bash
# Check operator pod status
kubectl get pods -n opendatahub -l control-plane=controller-manager

# Check operator version in logs
kubectl logs -n opendatahub -l control-plane=controller-manager | grep -i version

# Verify CRDs are registered
kubectl get crds | grep toolhive.stacklok.dev

# Test creating a VirtualMCPServer resource
# (after creating required MCPGroup)
```

### 7. Production Deployment

After successful staging validation:

1. Tag the release:
   ```bash
   git tag -a v0.6.11 -m "ToolHive Operator v0.6.11 release"
   git push origin v0.6.11
   ```

2. Build and push production catalog image

3. Update production CatalogSource

4. Monitor production deployment

5. Update operational runbooks with v0.6.11 specifics

## References

- [Research Document](research.md) - Detailed upgrade analysis
- [Data Model Comparison](data-model.md) - CRD schema changes
- [Specification](spec.md) - Complete upgrade specification
- Upstream Repository: https://github.com/stacklok/toolhive
- Release Notes v0.6.11: https://github.com/stacklok/toolhive/releases/tag/v0.6.11
- Release Notes v0.6.0: https://github.com/stacklok/toolhive/releases/tag/v0.6.0 (VirtualMCP introduction)
- CRD Helm Chart: https://github.com/stacklok/toolhive/tree/toolhive-operator-crds-0.0.74
- Operator Helm Chart: https://github.com/stacklok/toolhive/tree/toolhive-operator-0.5.8

## Appendix

### Full List of Modified Files

```
config/crd/bases/toolhive.stacklok.dev_mcpexternalauthconfigs.yaml (updated)
config/crd/bases/toolhive.stacklok.dev_mcpgroups.yaml (updated)
config/crd/bases/toolhive.stacklok.dev_mcpregistries.yaml (updated)
config/crd/bases/toolhive.stacklok.dev_mcpremoteproxies.yaml (updated)
config/crd/bases/toolhive.stacklok.dev_mcpservers.yaml (updated)
config/crd/bases/toolhive.stacklok.dev_mcptoolconfigs.yaml (updated)
config/crd/bases/toolhive.stacklok.dev_virtualmcpcompositetooldefinitions.yaml (NEW)
config/crd/bases/toolhive.stacklok.dev_virtualmcpservers.yaml (NEW)
config/crd/kustomization.yaml (updated - added 2 new CRDs)
config/rbac/role.yaml (updated - added VirtualMCP and Gateway API permissions)
config/base/params.env (updated - v0.6.11 images + vmcp image)
config/base/manager_env_patch.yaml (NEW - environment variables)
config/base/kustomization.yaml (updated - added manager_env_patch.yaml)
config/default/manager_env_patch.yaml (NEW - environment variables)
config/default/kustomization.yaml (updated - added manager_env_patch.yaml)
Makefile (updated - version variables to v0.6.11)
bundle/ (regenerated)
catalog/ (regenerated)
```

### Container Image Manifest

| Component | v0.4.2 Image | v0.6.11 Image |
|-----------|--------------|---------------|
| Operator | ghcr.io/stacklok/toolhive/operator:v0.4.2 | ghcr.io/stacklok/toolhive/operator:v0.6.11 |
| ProxyRunner | ghcr.io/stacklok/toolhive/proxyrunner:v0.4.2 | ghcr.io/stacklok/toolhive/proxyrunner:v0.6.11 |
| VMCP | N/A | ghcr.io/stacklok/toolhive/vmcp:v0.6.11 (NEW) |

### Environment Variables Reference

| Variable | v0.4.2 | v0.6.11 | Purpose |
|----------|--------|---------|---------|
| UNSTRUCTURED_LOGS | false | false | Structured logging toggle |
| POD_NAMESPACE | fieldRef | fieldRef | Pod namespace detection |
| TOOLHIVE_PROXY_HOST | 0.0.0.0 | 0.0.0.0 | Proxy bind address |
| TOOLHIVE_VMCP_IMAGE | N/A | ghcr.io/stacklok/toolhive/vmcp:v0.6.11 | VMCP container image (NEW) |
| TOOLHIVE_USE_CONFIGMAP | N/A | true | ConfigMap usage flag (NEW) |
| GOMEMLIMIT | N/A | 150MiB | Go memory limit (NEW) |
| GOGC | N/A | 75 | Go GC percentage (NEW) |

### CRD Version Matrix

| CRD | API Version | Status | Short Names |
|-----|-------------|--------|-------------|
| MCPRegistry | v1alpha1 | Updated | - |
| MCPServer | v1alpha1 | Updated | - |
| MCPExternalAuthConfig | v1alpha1 | Updated | extauth, mcpextauth |
| MCPGroup | v1alpha1 | Updated | - |
| MCPRemoteProxy | v1alpha1 | Updated | - |
| MCPToolConfig | v1alpha1 | Updated | - |
| VirtualMCPServer | v1alpha1 | NEW | vmcp, virtualmcp |
| VirtualMCPCompositeToolDefinition | v1alpha1 | NEW | - |
