# Tasks: Upgrade ToolHive Operator to v0.6.11

**Feature Branch**: `015-upgrade-toolhive-operator`
**Date**: 2025-12-04
**Estimated Time**: 2-4 hours (excluding testing)

## Task Overview

This task breakdown implements the ToolHive Operator v0.6.11 upgrade following the specification, plan, research, data model, and quickstart guide. Tasks are organized by implementation phases, with each user story clearly marked and parallelizable tasks identified.

**Legend**:
- `[P]` - Task can be executed in parallel with other [P] tasks in the same phase
- `[US1]`, `[US2]`, etc. - Indicates which user story this task implements
- `[Validation]` - Validation checkpoint task

---

## Phase 1: Setup and Preparation

**Duration**: 15 minutes

### Task 1.1: Verify Development Environment [P]
**User Story**: N/A (Setup)
**Priority**: Critical
**File Impact**: None

```bash
# Verify all required tools are installed
operator-sdk version  # Require v1.41.0+
opm version          # Require v1.49.0+
kustomize version    # Require v5.0+
yq --version         # Require v4+
git --version
jq --version
podman --version     # or docker --version
```

**Acceptance Criteria**:
- All tools installed and meet minimum version requirements
- No missing dependencies

---

### Task 1.2: Setup Feature Branch [P]
**User Story**: N/A (Setup)
**Priority**: Critical
**File Impact**: None

```bash
cd /wip/src/github.com/RHEcosystemAppEng/toolhive-operator-metadata

# Ensure main branch is up-to-date
git checkout main
git pull origin main

# Create feature branch (if not exists)
git checkout -b 015-upgrade-toolhive-operator

# Verify branch
git status
```

**Acceptance Criteria**:
- On feature branch `015-upgrade-toolhive-operator`
- Working directory is clean
- No uncommitted changes

---

### Task 1.3: Create Backup of Current Configuration [P]
**User Story**: N/A (Setup)
**Priority**: High
**File Impact**: None (creates backup outside repo)

```bash
# Create backup directory
mkdir -p /tmp/toolhive-v0.4.2-backup-$(date +%Y%m%d-%H%M%S)
BACKUP_DIR=/tmp/toolhive-v0.4.2-backup-$(date +%Y%m%d-%H%M%S)

# Backup critical files
cp -r config/ "$BACKUP_DIR/"
cp Makefile "$BACKUP_DIR/"
cp -r bundle/ "$BACKUP_DIR/" 2>/dev/null || true
cp -r catalog/ "$BACKUP_DIR/" 2>/dev/null || true

# Record current state
git log --oneline -5 > "$BACKUP_DIR/git-log.txt"
git diff > "$BACKUP_DIR/git-diff.txt"

echo "Backup created at: $BACKUP_DIR"
```

**Acceptance Criteria**:
- Backup directory created with timestamp
- All configuration files backed up
- Git state recorded

---

## Phase 2: Foundational Tasks (CRD Download and Analysis)

**Duration**: 20 minutes

### Task 2.1: Download Upstream ToolHive Repository
**User Story**: US1, US2
**Priority**: P1
**File Impact**: None (temporary directory)

```bash
# Create temporary directory for upstream repository
mkdir -p /tmp/toolhive-upgrade
cd /tmp/toolhive-upgrade

# Clone upstream ToolHive repository
git clone https://github.com/stacklok/toolhive.git
cd toolhive

# Record cloned commit
git log --oneline -1
```

**Acceptance Criteria**:
- Upstream repository cloned successfully
- Repository accessible at /tmp/toolhive-upgrade/toolhive

---

### Task 2.2: Checkout CRD Helm Chart Tag
**User Story**: US2
**Priority**: P1
**File Impact**: None (temporary directory)

```bash
cd /tmp/toolhive-upgrade/toolhive

# Checkout the CRD helm chart tag for v0.6.11
git checkout toolhive-operator-crds-0.0.74

# Verify tag
git describe --tags
# Expected output: toolhive-operator-crds-0.0.74

# Navigate to CRD directory
cd deploy/charts/operator-crds/crds

# List available CRDs
ls -lh *.yaml
```

**Acceptance Criteria**:
- On tag `toolhive-operator-crds-0.0.74`
- CRD directory contains 8 YAML files
- New CRDs visible: `virtualmcpservers.yaml`, `virtualmcpcompositetooldefinitions.yaml`

**Expected CRD Files**:
1. toolhive.stacklok.dev_mcpexternalauthconfigs.yaml
2. toolhive.stacklok.dev_mcpgroups.yaml
3. toolhive.stacklok.dev_mcpregistries.yaml
4. toolhive.stacklok.dev_mcpremoteproxies.yaml
5. toolhive.stacklok.dev_mcpservers.yaml
6. toolhive.stacklok.dev_mcptoolconfigs.yaml
7. toolhive.stacklok.dev_virtualmcpcompositetooldefinitions.yaml (NEW)
8. toolhive.stacklok.dev_virtualmcpservers.yaml (NEW)

---

### Task 2.3: Checkout Operator Helm Chart Tag
**User Story**: US1, US4, US5
**Priority**: P1
**File Impact**: None (temporary directory)

```bash
cd /tmp/toolhive-upgrade/toolhive

# Checkout the operator helm chart tag for v0.6.11
git checkout toolhive-operator-0.5.8

# Verify tag
git describe --tags
# Expected output: toolhive-operator-0.5.8

# Navigate to operator helm chart directory
cd deploy/charts/operator

# List chart files
ls -lh
```

**Acceptance Criteria**:
- On tag `toolhive-operator-0.5.8`
- Helm chart files present (Chart.yaml, values.yaml, templates/)
- Can access RBAC templates and deployment configuration

---

### Task 2.4: Analyze Helm Chart Configuration [P]
**User Story**: US1, US3, US4, US5
**Priority**: P1
**File Impact**: None (analysis only)

```bash
cd /tmp/toolhive-upgrade/toolhive/deploy/charts/operator

# Extract image references
echo "=== Operator Images ==="
yq eval '.image.repository' values.yaml
yq eval '.image.tag' values.yaml

# Extract vmcp image (NEW)
echo "=== VMCP Image (NEW) ==="
yq eval '.operator.vmcpImage' values.yaml

# Extract proxyrunner image
echo "=== ProxyRunner Image ==="
yq eval '.operator.toolhiveRunnerImage' values.yaml

# Extract environment variables
echo "=== Environment Variables ==="
yq eval '.operator.env' values.yaml

# Extract resource specifications
echo "=== Resource Specifications ==="
yq eval '.resources' values.yaml

# Extract RBAC permissions
echo "=== RBAC ClusterRole ==="
ls -lh templates/clusterrole.yaml
```

**Acceptance Criteria**:
- Image references identified for operator, vmcp, proxyrunner
- Environment variables documented
- RBAC template accessible

**Expected Findings** (from research.md):
- operator: ghcr.io/stacklok/toolhive/operator:v0.6.11
- vmcp: ghcr.io/stacklok/toolhive/vmcp:v0.6.11 (NEW)
- proxyrunner: ghcr.io/stacklok/toolhive/proxyrunner:v0.6.11
- New env vars: TOOLHIVE_VMCP_IMAGE, TOOLHIVE_USE_CONFIGMAP, GOMEMLIMIT, GOGC

---

## Phase 3: User Story 1 - Update Core Operator Version to v0.6.11

**Duration**: 15 minutes
**Priority**: P1

### Task 3.1: Update Makefile VERSION Variable [US1]
**User Story**: US1
**Priority**: P1
**File Impact**: `/wip/src/github.com/RHEcosystemAppEng/toolhive-operator-metadata/Makefile`

**Edit Makefile** (line ~38-42):

Change:
```makefile
OPERATOR_TAG ?= v0.4.2
```

To:
```makefile
OPERATOR_TAG ?= v0.6.11
```

**Also update catalog, bundle, and index tags**:

Change:
```makefile
CATALOG_TAG ?= v0.4.2
BUNDLE_TAG ?= v0.4.2
INDEX_TAG ?= v0.4.2
```

To:
```makefile
CATALOG_TAG ?= v0.6.11
BUNDLE_TAG ?= v0.6.11
INDEX_TAG ?= v0.6.11
```

**Acceptance Criteria**:
- OPERATOR_TAG = v0.6.11
- CATALOG_TAG = v0.6.11
- BUNDLE_TAG = v0.6.11
- INDEX_TAG = v0.6.11
- No syntax errors in Makefile

**Validation Command**:
```bash
grep "v0.6.11" Makefile | wc -l
# Expected: 4 or more occurrences
```

---

### Task 3.2: Update params.env with v0.6.11 Operator Image [US1]
**User Story**: US1
**Priority**: P1
**File Impact**: `/wip/src/github.com/RHEcosystemAppEng/toolhive-operator-metadata/config/base/params.env`

**Edit config/base/params.env**:

Change:
```bash
toolhive-operator-image2=ghcr.io/stacklok/toolhive/operator:v0.4.2
toolhive-operator-image=ghcr.io/stacklok/toolhive/operator:v0.4.2
```

To:
```bash
toolhive-operator-image2=ghcr.io/stacklok/toolhive/operator:v0.6.11
toolhive-operator-image=ghcr.io/stacklok/toolhive/operator:v0.6.11
```

**Acceptance Criteria**:
- Both operator image references use v0.6.11 tag
- No syntax errors in params.env

**Validation Command**:
```bash
grep "operator:v0.6.11" config/base/params.env
# Expected: 2 lines
```

---

### Task 3.3: Validate Operator Version Updates [US1] [Validation]
**User Story**: US1
**Priority**: P1
**File Impact**: None (validation only)

```bash
# Verify version consistency
echo "=== Version Check ==="
grep -n "v0.6.11" Makefile
grep -n "v0.6.11" config/base/params.env

# Build manifests to verify operator image
kustomize build config/base | grep "image:.*operator:v0.6.11"
kustomize build config/default | grep "image:.*operator:v0.6.11"
```

**Acceptance Criteria**:
- Makefile shows v0.6.11 in all version variables
- params.env shows v0.6.11 for operator images
- Kustomize builds successfully reference operator:v0.6.11

---

## Phase 4: User Story 2 - Update Custom Resource Definitions

**Duration**: 20 minutes
**Priority**: P1

### Task 4.1: Copy All 8 CRDs from Upstream [US2]
**User Story**: US2
**Priority**: P1
**File Impact**: `/wip/src/github.com/RHEcosystemAppEng/toolhive-operator-metadata/config/crd/bases/*.yaml` (8 files)

```bash
cd /wip/src/github.com/RHEcosystemAppEng/toolhive-operator-metadata

# Copy ALL 8 CRDs (6 updates + 2 new)
cp /tmp/toolhive-upgrade/toolhive/deploy/charts/operator-crds/crds/toolhive.stacklok.dev_*.yaml \
   config/crd/bases/

# Verify all files copied
ls -lh config/crd/bases/
# Should show 8 CRD files with recent timestamps
```

**Files Updated** (6 existing):
1. config/crd/bases/toolhive.stacklok.dev_mcpexternalauthconfigs.yaml
2. config/crd/bases/toolhive.stacklok.dev_mcpgroups.yaml
3. config/crd/bases/toolhive.stacklok.dev_mcpregistries.yaml
4. config/crd/bases/toolhive.stacklok.dev_mcpremoteproxies.yaml
5. config/crd/bases/toolhive.stacklok.dev_mcpservers.yaml
6. config/crd/bases/toolhive.stacklok.dev_mcptoolconfigs.yaml

**Files Added** (2 new):
7. config/crd/bases/toolhive.stacklok.dev_virtualmcpcompositetooldefinitions.yaml
8. config/crd/bases/toolhive.stacklok.dev_virtualmcpservers.yaml

**Acceptance Criteria**:
- 8 CRD files present in config/crd/bases/
- All files have recent modification timestamps
- New VirtualMCP CRDs present

**Validation Command**:
```bash
ls -1 config/crd/bases/*.yaml | wc -l
# Expected: 8
```

---

### Task 4.2: Update CRD Kustomization to Include New CRDs [US2]
**User Story**: US2
**Priority**: P1
**File Impact**: `/wip/src/github.com/RHEcosystemAppEng/toolhive-operator-metadata/config/crd/kustomization.yaml`

**Edit config/crd/kustomization.yaml**:

Add the 2 new CRD resources:

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

**Acceptance Criteria**:
- Kustomization lists all 8 CRD files
- YAML syntax is valid
- No duplicate entries

**Validation Command**:
```bash
yq eval '.resources | length' config/crd/kustomization.yaml
# Expected: 8
```

---

### Task 4.3: Validate CRD YAML Syntax [US2] [Validation]
**User Story**: US2
**Priority**: P1
**File Impact**: None (validation only)

```bash
# Validate YAML syntax for all CRDs
for crd in config/crd/bases/*.yaml; do
  echo "Validating $crd..."
  yq eval '.' "$crd" > /dev/null || echo "ERROR in $crd"
done

# Count CRDs
echo "Total CRDs: $(ls -1 config/crd/bases/*.yaml | wc -l)"
# Expected: 8

# Check for the new CRDs specifically
echo "Checking for new VirtualMCP CRDs..."
ls -lh config/crd/bases/toolhive.stacklok.dev_virtualmcpservers.yaml
ls -lh config/crd/bases/toolhive.stacklok.dev_virtualmcpcompositetooldefinitions.yaml
```

**Acceptance Criteria**:
- All 8 CRDs have valid YAML syntax
- No parsing errors
- New VirtualMCP CRDs present and valid

---

### Task 4.4: Validate Kustomize Build with Updated CRDs [US2] [Validation]
**User Story**: US2
**Priority**: P1
**File Impact**: None (validation only)

```bash
# Validate kustomize build includes all CRDs
kustomize build config/crd > /tmp/crd-manifests.yaml

# Count CRDs in output
echo "CRDs in kustomize output:"
grep -c "kind: CustomResourceDefinition" /tmp/crd-manifests.yaml
# Expected: 8

# Check for specific new CRDs
echo "Checking for VirtualMCPServer CRD..."
grep "virtualmcpservers.toolhive.stacklok.dev" /tmp/crd-manifests.yaml && echo "✅ Found"

echo "Checking for VirtualMCPCompositeToolDefinition CRD..."
grep "virtualmcpcompositetooldefinitions.toolhive.stacklok.dev" /tmp/crd-manifests.yaml && echo "✅ Found"
```

**Acceptance Criteria**:
- Kustomize build succeeds without errors
- Output contains exactly 8 CRDs
- New VirtualMCP CRDs present in output

---

## Phase 5: User Story 3 - Add vmcp Operand Image References

**Duration**: 15 minutes
**Priority**: P2

### Task 5.1: Add vmcp Image to params.env [US3]
**User Story**: US3
**Priority**: P2
**File Impact**: `/wip/src/github.com/RHEcosystemAppEng/toolhive-operator-metadata/config/base/params.env`

**Edit config/base/params.env**:

Add new line:
```bash
toolhive-vmcp-image=ghcr.io/stacklok/toolhive/vmcp:v0.6.11
```

**Final params.env content**:
```bash
toolhive-operator-image2=ghcr.io/stacklok/toolhive/operator:v0.6.11
toolhive-operator-image=ghcr.io/stacklok/toolhive/operator:v0.6.11
toolhive-proxy-image=ghcr.io/stacklok/toolhive/proxyrunner:v0.6.11
toolhive-vmcp-image=ghcr.io/stacklok/toolhive/vmcp:v0.6.11
```

**Acceptance Criteria**:
- vmcp image reference added with v0.6.11 tag
- No syntax errors in params.env

**Validation Command**:
```bash
grep "vmcp:v0.6.11" config/base/params.env
# Expected: 1 line
```

---

### Task 5.2: Create Manager Environment Variable Patch for config/base [US3]
**User Story**: US3
**Priority**: P2
**File Impact**: `/wip/src/github.com/RHEcosystemAppEng/toolhive-operator-metadata/config/base/manager_env_patch.yaml` (NEW)

**Create config/base/manager_env_patch.yaml**:

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

**Acceptance Criteria**:
- New file created at config/base/manager_env_patch.yaml
- YAML syntax is valid
- Contains all 4 new environment variables

**Validation Command**:
```bash
yq eval '.spec.template.spec.containers[0].env[] | select(.name == "TOOLHIVE_VMCP_IMAGE")' config/base/manager_env_patch.yaml
# Expected: Output showing TOOLHIVE_VMCP_IMAGE env var
```

---

### Task 5.3: Update config/base Kustomization to Include Manager Env Patch [US3]
**User Story**: US3
**Priority**: P2
**File Impact**: `/wip/src/github.com/RHEcosystemAppEng/toolhive-operator-metadata/config/base/kustomization.yaml`

**Edit config/base/kustomization.yaml**:

Add `manager_env_patch.yaml` to the `patchesStrategicMerge` section:

```yaml
# config/base/kustomization.yaml
# ... existing content ...

patchesStrategicMerge:
- remove-namespace.yaml
- openshift_env_var_patch.yaml
- openshift_sec_patches.yaml
- openshift_res_utilization.yaml
- manager_env_patch.yaml  # NEW - Add this line
```

**Acceptance Criteria**:
- manager_env_patch.yaml listed in patchesStrategicMerge
- YAML syntax valid
- No duplicate entries

**Validation Command**:
```bash
yq eval '.patchesStrategicMerge[]' config/base/kustomization.yaml | grep manager_env_patch.yaml
# Expected: manager_env_patch.yaml
```

---

### Task 5.4: Create Manager Environment Variable Patch for config/default [US3]
**User Story**: US3
**Priority**: P2
**File Impact**: `/wip/src/github.com/RHEcosystemAppEng/toolhive-operator-metadata/config/default/manager_env_patch.yaml` (NEW)

**Create config/default/manager_env_patch.yaml**:

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

**Acceptance Criteria**:
- New file created at config/default/manager_env_patch.yaml
- YAML syntax is valid
- Contains all 4 new environment variables

---

### Task 5.5: Update config/default Kustomization to Include Manager Env Patch [US3]
**User Story**: US3
**Priority**: P2
**File Impact**: `/wip/src/github.com/RHEcosystemAppEng/toolhive-operator-metadata/config/default/kustomization.yaml`

**Edit config/default/kustomization.yaml**:

Add `manager_env_patch.yaml` to the `patchesStrategicMerge` section:

```yaml
# config/default/kustomization.yaml
# ... existing content ...

patchesStrategicMerge:
- manager_env_patch.yaml  # Add this line (or append to existing list)
```

**Acceptance Criteria**:
- manager_env_patch.yaml listed in patchesStrategicMerge
- YAML syntax valid

**Validation Command**:
```bash
yq eval '.patchesStrategicMerge[]' config/default/kustomization.yaml | grep manager_env_patch.yaml
# Expected: manager_env_patch.yaml
```

---

### Task 5.6: Validate vmcp Image and Environment Variables [US3] [Validation]
**User Story**: US3
**Priority**: P2
**File Impact**: None (validation only)

```bash
# Validate config/base includes vmcp image environment variable
echo "=== Checking config/base for vmcp env var ==="
kustomize build config/base | grep -A 5 "TOOLHIVE_VMCP_IMAGE"

# Validate config/default includes vmcp image environment variable
echo "=== Checking config/default for vmcp env var ==="
kustomize build config/default | grep -A 5 "TOOLHIVE_VMCP_IMAGE"

# Check all 4 new environment variables
echo "=== Checking all new environment variables ==="
kustomize build config/base | grep -E "(TOOLHIVE_VMCP_IMAGE|TOOLHIVE_USE_CONFIGMAP|GOMEMLIMIT|GOGC)"

# Count environment variables
echo "=== Environment variable count ==="
kustomize build config/base | grep -c "name: TOOLHIVE"
```

**Acceptance Criteria**:
- TOOLHIVE_VMCP_IMAGE environment variable present with v0.6.11 image
- TOOLHIVE_USE_CONFIGMAP=true present
- GOMEMLIMIT=150MiB present
- GOGC=75 present
- Both config/base and config/default builds include new env vars

---

## Phase 6: User Story 4 - Update RBAC Permissions

**Duration**: 20 minutes
**Priority**: P2

### Task 6.1: Update ClusterRole with VirtualMCPServer Permissions [US4]
**User Story**: US4
**Priority**: P2
**File Impact**: `/wip/src/github.com/RHEcosystemAppEng/toolhive-operator-metadata/config/rbac/role.yaml`

**Edit config/rbac/role.yaml**:

Add the following RBAC rules after the existing toolhive.stacklok.dev rules:

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
```

**Acceptance Criteria**:
- 3 new rules added for VirtualMCPServer (main resource, finalizers, status)
- YAML syntax valid
- All required verbs present

**Validation Command**:
```bash
yq eval '.rules[] | select(.resources[] == "virtualmcpservers")' config/rbac/role.yaml
# Expected: Output showing virtualmcpservers rule
```

---

### Task 6.2: Update ClusterRole with VirtualMCPCompositeToolDefinition Permissions [US4]
**User Story**: US4
**Priority**: P2
**File Impact**: `/wip/src/github.com/RHEcosystemAppEng/toolhive-operator-metadata/config/rbac/role.yaml`

**Edit config/rbac/role.yaml**:

Add the following RBAC rules:

```yaml
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
```

**Acceptance Criteria**:
- 3 new rules added for VirtualMCPCompositeToolDefinition
- YAML syntax valid
- All required verbs present

**Validation Command**:
```bash
yq eval '.rules[] | select(.resources[] == "virtualmcpcompositetooldefinitions")' config/rbac/role.yaml
# Expected: Output showing virtualmcpcompositetooldefinitions rule
```

---

### Task 6.3: Update ClusterRole with Gateway API Permissions [US4]
**User Story**: US4
**Priority**: P2
**File Impact**: `/wip/src/github.com/RHEcosystemAppEng/toolhive-operator-metadata/config/rbac/role.yaml`

**Edit config/rbac/role.yaml**:

Add the following RBAC rules:

```yaml
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

**Acceptance Criteria**:
- Gateway API rule added with gateways and httproutes resources
- YAML syntax valid
- All required verbs present

**Validation Command**:
```bash
yq eval '.rules[] | select(.apiGroups[] == "gateway.networking.k8s.io")' config/rbac/role.yaml
# Expected: Output showing Gateway API rule
```

---

### Task 6.4: Validate RBAC Updates [US4] [Validation]
**User Story**: US4
**Priority**: P2
**File Impact**: None (validation only)

```bash
# Validate YAML syntax
yq eval '.' config/rbac/role.yaml > /dev/null && echo "✅ RBAC YAML valid"

# Count the number of rules for toolhive.stacklok.dev
echo "=== ToolHive API rules count ==="
yq eval '.rules[] | select(.apiGroups[] == "toolhive.stacklok.dev") | .resources[]' config/rbac/role.yaml | wc -l

# Check for VirtualMCP permissions
echo "=== Checking VirtualMCPServer permissions ==="
yq eval '.rules[] | select(.resources[] == "virtualmcpservers")' config/rbac/role.yaml && echo "✅ Found"

echo "=== Checking VirtualMCPCompositeToolDefinition permissions ==="
yq eval '.rules[] | select(.resources[] == "virtualmcpcompositetooldefinitions")' config/rbac/role.yaml && echo "✅ Found"

# Check for Gateway API permissions
echo "=== Checking Gateway API permissions ==="
yq eval '.rules[] | select(.apiGroups[] == "gateway.networking.k8s.io") | .resources' config/rbac/role.yaml && echo "✅ Found"
```

**Acceptance Criteria**:
- RBAC YAML is valid
- VirtualMCPServer permissions present (3 rules)
- VirtualMCPCompositeToolDefinition permissions present (3 rules)
- Gateway API permissions present (1 rule with 2 resources)

---

## Phase 7: User Story 5 - Update proxyrunner Image Reference

**Duration**: 10 minutes
**Priority**: P3

### Task 7.1: Update params.env with v0.6.11 ProxyRunner Image [US5]
**User Story**: US5
**Priority**: P3
**File Impact**: `/wip/src/github.com/RHEcosystemAppEng/toolhive-operator-metadata/config/base/params.env`

**Edit config/base/params.env**:

Change:
```bash
toolhive-proxy-image=ghcr.io/stacklok/toolhive/proxyrunner:v0.4.2
```

To:
```bash
toolhive-proxy-image=ghcr.io/stacklok/toolhive/proxyrunner:v0.6.11
```

**Acceptance Criteria**:
- ProxyRunner image uses v0.6.11 tag
- No syntax errors in params.env

**Validation Command**:
```bash
grep "proxyrunner:v0.6.11" config/base/params.env
# Expected: 1 line
```

---

### Task 7.2: Validate ProxyRunner Image Updates [US5] [Validation]
**User Story**: US5
**Priority**: P3
**File Impact**: None (validation only)

```bash
# Verify proxyrunner image in kustomize output
echo "=== Checking for proxyrunner v0.6.11 ==="
kustomize build config/base | grep "proxyrunner:v0.6.11"

# Verify all three images are v0.6.11
echo "=== All v0.6.11 images ==="
kustomize build config/base | grep -E "image:.*v0.6.11|value:.*v0.6.11"
```

**Acceptance Criteria**:
- ProxyRunner image reference uses v0.6.11
- All three images (operator, vmcp, proxyrunner) use v0.6.11

---

## Phase 8: Validation and Testing

**Duration**: 30 minutes
**Priority**: Critical

### Task 8.1: Validate Kustomize Builds [Validation]
**User Story**: All
**Priority**: Critical
**File Impact**: None (validation only)

```bash
# Validate config/default builds correctly
echo "=== Testing config/default ==="
kustomize build config/default > /tmp/default-manifests.yaml
echo "✅ config/default build succeeded"

# Validate config/base builds correctly
echo "=== Testing config/base ==="
kustomize build config/base > /tmp/base-manifests.yaml
echo "✅ config/base build succeeded"

# Check for image references in output
echo "=== Checking image references in config/base ==="
grep -E "image:.*v0.6.11" /tmp/base-manifests.yaml || echo "⚠️ Warning: v0.6.11 images not found"

# Verify all 8 CRDs are present
echo "=== Verifying CRD count ==="
CRD_COUNT=$(grep -c "kind: CustomResourceDefinition" /tmp/base-manifests.yaml)
echo "CRD count: $CRD_COUNT"
# Expected: 8

# Check for VirtualMCP CRDs specifically
echo "=== Checking for new VirtualMCP CRDs ==="
grep "virtualmcpservers.toolhive.stacklok.dev" /tmp/base-manifests.yaml && echo "✅ VirtualMCPServer CRD found"
grep "virtualmcpcompositetooldefinitions.toolhive.stacklok.dev" /tmp/base-manifests.yaml && echo "✅ VirtualMCPCompositeToolDefinition CRD found"

# Verify new environment variables
echo "=== Checking for new environment variables ==="
grep "TOOLHIVE_VMCP_IMAGE" /tmp/base-manifests.yaml && echo "✅ TOOLHIVE_VMCP_IMAGE found"
grep "TOOLHIVE_USE_CONFIGMAP" /tmp/base-manifests.yaml && echo "✅ TOOLHIVE_USE_CONFIGMAP found"
grep "GOMEMLIMIT" /tmp/base-manifests.yaml && echo "✅ GOMEMLIMIT found"
grep "GOGC" /tmp/base-manifests.yaml && echo "✅ GOGC found"
```

**Acceptance Criteria**:
- config/default builds successfully
- config/base builds successfully
- All 8 CRDs present in output
- All v0.6.11 images present
- All 4 new environment variables present

---

### Task 8.2: Clean Previous Build Artifacts [P]
**User Story**: All
**Priority**: Critical
**File Impact**: Removes `/wip/src/github.com/RHEcosystemAppEng/toolhive-operator-metadata/bundle/` and `/wip/src/github.com/RHEcosystemAppEng/toolhive-operator-metadata/catalog/`

```bash
cd /wip/src/github.com/RHEcosystemAppEng/toolhive-operator-metadata

# Clean old bundle and catalog
make clean

# Verify cleaned
ls -lh bundle/ catalog/ 2>/dev/null || echo "✅ Cleaned successfully"
```

**Acceptance Criteria**:
- bundle/ directory removed or emptied
- catalog/ directory removed or emptied
- No stale artifacts from v0.4.2

---

### Task 8.3: Generate OLM Bundle [Validation]
**User Story**: All
**Priority**: Critical
**File Impact**: Regenerates `/wip/src/github.com/RHEcosystemAppEng/toolhive-operator-metadata/bundle/`

```bash
# Generate new bundle with v0.6.11
make bundle

# Verify bundle generation
echo "=== Checking bundle contents ==="
ls -lh bundle/manifests/

# Count CRDs in bundle
echo "=== CRDs in bundle ==="
CRD_COUNT=$(ls -1 bundle/manifests/toolhive.stacklok.dev_*.yaml | wc -l)
echo "CRD count: $CRD_COUNT"
# Expected: 8

# Check CSV metadata
echo "=== CSV version ==="
yq eval '.spec.version' bundle/manifests/toolhive-operator.clusterserviceversion.yaml

# Check CSV name
echo "=== CSV name ==="
yq eval '.metadata.name' bundle/manifests/toolhive-operator.clusterserviceversion.yaml
# Expected: toolhive-operator.v0.6.11

# Check for all CRDs in CSV
echo "=== CRDs listed in CSV ==="
yq eval '.spec.customresourcedefinitions.owned[].name' bundle/manifests/toolhive-operator.clusterserviceversion.yaml

# Check related images
echo "=== Related images in CSV ==="
yq eval '.spec.relatedImages[].image' bundle/manifests/toolhive-operator.clusterserviceversion.yaml | sort -u
```

**Acceptance Criteria**:
- Bundle generated successfully
- 8 CRD files present in bundle/manifests/
- CSV version is 0.6.11 (not v0.6.11 - OLM uses semver without 'v' prefix)
- CSV name is toolhive-operator.v0.6.11
- All 8 CRDs listed in CSV customresourcedefinitions.owned
- Related images include operator:v0.6.11, vmcp:v0.6.11, proxyrunner:v0.6.11

---

### Task 8.4: Validate Bundle with operator-sdk [Validation]
**User Story**: All
**Priority**: Critical
**File Impact**: None (validation only)

```bash
# Validate with operator-sdk
make bundle-validate-sdk

# Expected output should include:
# ✅ All validation tests passed
```

**Acceptance Criteria**:
- operator-sdk bundle validation passes
- No validation errors
- No critical warnings

---

### Task 8.5: Generate File-Based Catalog [Validation]
**User Story**: All
**Priority**: Critical
**File Impact**: Regenerates `/wip/src/github.com/RHEcosystemAppEng/toolhive-operator-metadata/catalog/`

```bash
# Generate FBC catalog
make catalog

# Verify catalog generation
echo "=== Checking catalog contents ==="
ls -lh catalog/toolhive-operator/

# Check catalog file size (should be >900KB based on past experience)
du -h catalog/toolhive-operator/catalog.yaml

# Check catalog metadata
echo "=== Catalog packages ==="
yq eval 'select(.schema == "olm.package")' catalog/toolhive-operator/catalog.yaml

echo "=== Catalog channels ==="
yq eval 'select(.schema == "olm.channel")' catalog/toolhive-operator/catalog.yaml

echo "=== Catalog bundles ==="
yq eval 'select(.schema == "olm.bundle") | .name' catalog/toolhive-operator/catalog.yaml
```

**Acceptance Criteria**:
- Catalog generated successfully
- catalog.yaml file size >900KB
- Catalog contains olm.package schema
- Catalog contains olm.channel schema
- Catalog contains olm.bundle schema with v0.6.11 bundle

---

### Task 8.6: Validate Catalog [Validation]
**User Story**: All
**Priority**: Critical
**File Impact**: None (validation only)

```bash
# Validate catalog structure
make catalog-validate

# Expected output:
# ✅ Catalog validation passed
```

**Acceptance Criteria**:
- Catalog validation passes with no errors
- No critical warnings

---

### Task 8.7: Version Consistency Validation [Validation]
**User Story**: All
**Priority**: Critical
**File Impact**: None (validation only)

```bash
echo "=== Checking version consistency ==="

# Check Makefile
echo "Makefile versions:"
grep "v0.6.11" Makefile && echo "✅ Makefile versions updated"

# Check params.env
echo "params.env versions:"
grep "v0.6.11" config/base/params.env && echo "✅ params.env versions updated"

# Check bundle CSV version
echo "Bundle CSV version:"
yq eval '.spec.version' bundle/manifests/toolhive-operator.clusterserviceversion.yaml
# Expected: 0.6.11 (semver without 'v')

# Check bundle metadata name
echo "Bundle CSV name:"
yq eval '.metadata.name' bundle/manifests/toolhive-operator.clusterserviceversion.yaml
# Expected: toolhive-operator.v0.6.11

# Check bundle annotations
echo "Bundle annotations:"
yq eval '.annotations."operators.operatorframework.io.bundle.package.v1"' bundle/metadata/annotations.yaml
# Expected: toolhive-operator

# Validate all image references are v0.6.11
echo "=== All image references should be v0.6.11 ==="
kustomize build config/base | grep -E "image:.*ghcr.io/stacklok/toolhive" | sort -u
```

**Acceptance Criteria**:
- All version references use v0.6.11 (or 0.6.11 for semver)
- No v0.4.2 references remain
- All image tags are v0.6.11

---

### Task 8.8: RBAC Completeness Validation [Validation]
**User Story**: US4
**Priority**: P2
**File Impact**: None (validation only)

```bash
echo "=== RBAC Completeness Check ==="

# Check VirtualMCPServer permissions
echo "VirtualMCPServer permissions:"
yq eval '.rules[] | select(.resources[] == "virtualmcpservers") | .verbs' config/rbac/role.yaml
# Expected: create, delete, get, list, patch, update, watch

echo "VirtualMCPServer finalizers:"
yq eval '.rules[] | select(.resources[] == "virtualmcpservers/finalizers") | .verbs' config/rbac/role.yaml
# Expected: update

echo "VirtualMCPServer status:"
yq eval '.rules[] | select(.resources[] == "virtualmcpservers/status") | .verbs' config/rbac/role.yaml
# Expected: get, patch, update

# Check VirtualMCPCompositeToolDefinition permissions
echo "VirtualMCPCompositeToolDefinition permissions:"
yq eval '.rules[] | select(.resources[] == "virtualmcpcompositetooldefinitions") | .verbs' config/rbac/role.yaml
# Expected: create, delete, get, list, patch, update, watch

# Check Gateway API permissions
echo "Gateway API permissions:"
yq eval '.rules[] | select(.apiGroups[] == "gateway.networking.k8s.io") | .resources' config/rbac/role.yaml
# Expected: gateways, httproutes

# Verify permissions are in CSV
echo "=== CSV RBAC Check ==="
yq eval '.spec.install.spec.clusterPermissions[0].rules | length' bundle/manifests/toolhive-operator.clusterserviceversion.yaml
# Expected: Number of rules (should be significant, 20+)
```

**Acceptance Criteria**:
- All VirtualMCP permissions present in ClusterRole
- Gateway API permissions present
- CSV includes all permissions in clusterPermissions section

---

## Phase 9: Polish and Documentation

**Duration**: 20 minutes
**Priority**: Medium

### Task 9.1: Verify Git Changes [Validation]
**User Story**: All
**Priority**: Medium
**File Impact**: None (validation only)

```bash
cd /wip/src/github.com/RHEcosystemAppEng/toolhive-operator-metadata

# Check git status
git status

# Review changed files
echo "=== Modified files ==="
git diff --name-only

# Check for untracked files
echo "=== Untracked files ==="
git ls-files --others --exclude-standard
```

**Acceptance Criteria**:
- All expected files modified (Makefile, params.env, CRDs, RBAC, patches, kustomizations)
- Bundle and catalog directories regenerated
- No unexpected changes

**Expected Modified Files**:
- Makefile
- config/base/params.env
- config/base/kustomization.yaml
- config/default/kustomization.yaml
- config/crd/kustomization.yaml
- config/rbac/role.yaml
- config/crd/bases/*.yaml (8 files)
- config/base/manager_env_patch.yaml (new)
- config/default/manager_env_patch.yaml (new)
- bundle/ (regenerated)
- catalog/ (regenerated)

---

### Task 9.2: Stage All Changes for Commit [P]
**User Story**: All
**Priority**: Medium
**File Impact**: None (git staging only)

```bash
# Stage all configuration changes
git add config/

# Stage Makefile
git add Makefile

# Stage bundle and catalog
git add bundle/ catalog/

# Review staged changes
git status

# Review diff summary
git diff --staged --stat
```

**Acceptance Criteria**:
- All modified files staged
- Bundle and catalog staged
- No unwanted files staged (e.g., temporary files, backups)

---

### Task 9.3: Create Comprehensive Commit Message [P]
**User Story**: All
**Priority**: Medium
**File Impact**: Git commit

```bash
# Commit with descriptive message
git commit -m "Upgrade ToolHive Operator from v0.4.2 to v0.6.11

## Summary

Upgrade ToolHive Operator metadata to v0.6.11, introducing VirtualMCPServer
functionality, enhanced authentication/authorization, and updated operand images.

## Changes by User Story

### US1: Update Core Operator Version to v0.6.11
- Updated Makefile version variables (OPERATOR_TAG, CATALOG_TAG, BUNDLE_TAG, INDEX_TAG)
- Updated operator image in config/base/params.env to v0.6.11
- Updated related image references in CSV

### US2: Update Custom Resource Definitions
- Updated 6 existing CRDs to v0.6.11 schemas:
  - MCPRegistry (added PVC support, sync policy, filtering)
  - MCPServer (added authz, OIDC, telemetry, transport config)
  - MCPExternalAuthConfig
  - MCPGroup
  - MCPRemoteProxy
  - MCPToolConfig
- Added 2 new CRDs:
  - VirtualMCPServer (new capability)
  - VirtualMCPCompositeToolDefinition (workflow orchestration)
- Updated config/crd/kustomization.yaml to include new CRDs

### US3: Add vmcp Operand Image References
- Added vmcp image to config/base/params.env (v0.6.11)
- Created config/base/manager_env_patch.yaml with new environment variables:
  - TOOLHIVE_VMCP_IMAGE=ghcr.io/stacklok/toolhive/vmcp:v0.6.11
  - TOOLHIVE_USE_CONFIGMAP=true
  - GOMEMLIMIT=150MiB
  - GOGC=75
- Created config/default/manager_env_patch.yaml with same env vars
- Updated kustomizations to include manager_env_patch.yaml

### US4: Update RBAC Permissions
- Added VirtualMCPServer permissions to config/rbac/role.yaml
- Added VirtualMCPCompositeToolDefinition permissions
- Added Gateway API permissions (gateways, httproutes)
- All permissions include finalizers and status subresources

### US5: Update proxyrunner Image Reference
- Updated proxyrunner image in config/base/params.env to v0.6.11

## Validation

- [x] Kustomize builds pass (config/default, config/base)
- [x] All 8 CRDs present in manifests
- [x] Bundle validation passes (operator-sdk)
- [x] Catalog validation passes (opm)
- [x] All image references updated to v0.6.11
- [x] RBAC includes VirtualMCP and Gateway API permissions
- [x] CSV version is 0.6.11
- [x] CSV lists all 8 CRDs in customresourcedefinitions.owned
- [x] Related images include operator, vmcp, proxyrunner at v0.6.11

## Breaking Changes

Default MCPServer transport changed from \`sse\` to \`streamable-http\`.
Existing resources relying on default will need explicit \`transport: sse\`.

## References

- Spec: specs/015-upgrade-toolhive-operator/spec.md
- Plan: specs/015-upgrade-toolhive-operator/plan.md
- Research: specs/015-upgrade-toolhive-operator/research.md
- Data Model: specs/015-upgrade-toolhive-operator/data-model.md
- Quickstart: specs/015-upgrade-toolhive-operator/quickstart.md
- Upstream Release: https://github.com/stacklok/toolhive/releases/tag/v0.6.11
- CRD Chart: https://github.com/stacklok/toolhive/tree/toolhive-operator-crds-0.0.74
- Operator Chart: https://github.com/stacklok/toolhive/tree/toolhive-operator-0.5.8

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"

# Verify commit
git log --oneline -1
```

**Acceptance Criteria**:
- Commit created with comprehensive message
- Message includes all user stories
- Message includes validation checklist
- Message includes breaking changes notice
- Message includes references to spec documents
- Message includes Claude Code attribution

---

### Task 9.4: Prepare Pull Request [P]
**User Story**: All
**Priority**: Medium
**File Impact**: None (PR preparation)

**Pull Request Title**:
```
Upgrade ToolHive Operator to v0.6.11
```

**Pull Request Body**:
```markdown
## Summary

This PR upgrades the ToolHive Operator metadata from v0.4.2 to v0.6.11, introducing VirtualMCPServer functionality, enhanced authentication/authorization features, and updated operand images.

## Changes

### Custom Resource Definitions
- **Updated 6 existing CRDs** to v0.6.11 schemas (MCPRegistry, MCPServer, MCPExternalAuthConfig, MCPGroup, MCPRemoteProxy, MCPToolConfig)
- **Added 2 new CRDs**: VirtualMCPServer, VirtualMCPCompositeToolDefinition

### Container Images
- **Operator**: ghcr.io/stacklok/toolhive/operator:v0.6.11 (updated from v0.4.2)
- **VMCP**: ghcr.io/stacklok/toolhive/vmcp:v0.6.11 (NEW operand)
- **ProxyRunner**: ghcr.io/stacklok/toolhive/proxyrunner:v0.6.11 (updated from v0.4.2)

### RBAC Permissions
- Added permissions for VirtualMCPServer resources
- Added permissions for VirtualMCPCompositeToolDefinition resources
- Added Gateway API permissions (gateways, httproutes)

### Environment Variables
- **TOOLHIVE_VMCP_IMAGE**: ghcr.io/stacklok/toolhive/vmcp:v0.6.11 (NEW)
- **TOOLHIVE_USE_CONFIGMAP**: true (NEW)
- **GOMEMLIMIT**: 150MiB (NEW)
- **GOGC**: 75 (NEW)

### Configuration Updates
- Updated Makefile version variables to v0.6.11
- Updated config/base/params.env with all v0.6.11 images
- Created manager_env_patch.yaml for config/base and config/default
- Updated kustomizations to include new patches
- Regenerated OLM bundle and File-Based Catalog

## Validation

- [x] Kustomize builds pass (config/default, config/base)
- [x] All 8 CRDs present in bundle
- [x] Bundle validation passes (operator-sdk)
- [x] Catalog validation passes (opm)
- [x] All image references updated to v0.6.11
- [x] RBAC includes VirtualMCP and Gateway API permissions
- [x] CSV version is 0.6.11
- [x] CSV lists all 8 CRDs in customresourcedefinitions.owned
- [x] Related images include operator:v0.6.11, vmcp:v0.6.11, proxyrunner:v0.6.11

## Breaking Changes

⚠️ **Default MCPServer transport changed from `sse` to `streamable-http`** in v0.6.0.

**Impact**: Existing MCPServer resources that rely on the default transport will break.

**Mitigation**: Add explicit `transport: sse` to existing MCPServer manifests before upgrade if SSE transport is required.

## New Features Introduced

### VirtualMCPServer
- Aggregate multiple backend MCP servers into single endpoint
- Composite tool workflows across multiple servers
- High-availability with failover
- Centralized authentication/authorization

### Enhanced MCPRegistry
- PVC support for airgapped/offline environments
- Sync policy for automatic periodic updates
- Filtering for selective registry syncing

### Enhanced MCPServer
- OIDC authentication configuration
- Authorization policies
- Permission profiles
- Telemetry/observability support

## Testing

### Pre-merge Testing
- All kustomize builds successful
- Bundle and catalog validation passed
- Version consistency verified

### Post-merge Testing Plan
- [ ] Deploy to test cluster
- [ ] Verify CRDs install successfully
- [ ] Create test VirtualMCPServer resource
- [ ] Verify existing MCPServer/MCPRegistry resources reconcile
- [ ] Test upgrade path from v0.4.2
- [ ] Monitor operator logs for errors

## References

- **Specification**: [specs/015-upgrade-toolhive-operator/spec.md](/wip/src/github.com/RHEcosystemAppEng/toolhive-operator-metadata/specs/015-upgrade-toolhive-operator/spec.md)
- **Implementation Plan**: [specs/015-upgrade-toolhive-operator/plan.md](/wip/src/github.com/RHEcosystemAppEng/toolhive-operator-metadata/specs/015-upgrade-toolhive-operator/plan.md)
- **Research Analysis**: [specs/015-upgrade-toolhive-operator/research.md](/wip/src/github.com/RHEcosystemAppEng/toolhive-operator-metadata/specs/015-upgrade-toolhive-operator/research.md)
- **Data Model Comparison**: [specs/015-upgrade-toolhive-operator/data-model.md](/wip/src/github.com/RHEcosystemAppEng/toolhive-operator-metadata/specs/015-upgrade-toolhive-operator/data-model.md)
- **Quickstart Guide**: [specs/015-upgrade-toolhive-operator/quickstart.md](/wip/src/github.com/RHEcosystemAppEng/toolhive-operator-metadata/specs/015-upgrade-toolhive-operator/quickstart.md)
- **Upstream Release v0.6.11**: https://github.com/stacklok/toolhive/releases/tag/v0.6.11
- **CRD Helm Chart**: https://github.com/stacklok/toolhive/tree/toolhive-operator-crds-0.0.74
- **Operator Helm Chart**: https://github.com/stacklok/toolhive/tree/toolhive-operator-0.5.8

## Rollback Plan

If issues arise post-merge:

1. Restore CRDs from v0.4.2: `git checkout main -- config/crd/bases/`
2. Restore RBAC: `git checkout main -- config/rbac/role.yaml`
3. Restore Makefile: `git checkout main -- Makefile`
4. Restore params.env: `git checkout main -- config/base/params.env`
5. Remove manager_env_patch.yaml files
6. Regenerate bundle and catalog: `make clean && make bundle && make catalog`

---

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

**Acceptance Criteria**:
- Pull request title is clear and concise
- PR body includes comprehensive summary
- All changes documented by category
- Breaking changes highlighted
- Validation checklist included
- Testing plan outlined
- References to all specification documents
- Rollback plan documented

---

## Phase 10: Optional Test Cluster Validation

**Duration**: 30-60 minutes (if test cluster available)
**Priority**: Optional (Recommended)

### Task 10.1: Deploy CRDs to Test Cluster [Optional]
**User Story**: US2
**Priority**: Optional
**File Impact**: None (test cluster only)

```bash
# Apply just the CRDs to test cluster
kustomize build config/crd | kubectl apply -f -

# Verify CRDs installed
kubectl get crds | grep toolhive.stacklok.dev

# Expected: 8 CRDs including virtualmcpservers and virtualmcpcompositetooldefinitions

# Check CRD details
kubectl get crd virtualmcpservers.toolhive.stacklok.dev -o yaml
kubectl get crd virtualmcpcompositetooldefinitions.toolhive.stacklok.dev -o yaml
```

**Acceptance Criteria**:
- All 8 CRDs install successfully
- No CRD schema validation errors
- New VirtualMCP CRDs present

---

### Task 10.2: Create Test VirtualMCPServer Resource [Optional]
**User Story**: US2, US3
**Priority**: Optional
**File Impact**: None (test cluster only)

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

# Describe resource
kubectl describe virtualmcpserver test-vmcp -n default

# Cleanup test resource
kubectl delete virtualmcpserver test-vmcp -n default
```

**Acceptance Criteria**:
- VirtualMCPServer resource creates successfully
- No schema validation errors
- Resource can be retrieved and described
- Resource can be deleted cleanly

---

### Task 10.3: Deploy Full Operator to Test Namespace [Optional]
**User Story**: All
**Priority**: Optional
**File Impact**: None (test cluster only)

```bash
# Create test namespace
kubectl create namespace toolhive-test

# Deploy operator to test namespace
kustomize build config/default | kubectl apply -n toolhive-test -f -

# Check operator pod
kubectl get pods -n toolhive-test -w

# Wait for operator pod to be running
kubectl wait --for=condition=Ready pod -l control-plane=controller-manager -n toolhive-test --timeout=300s

# Check operator logs for version and errors
kubectl logs -n toolhive-test -l control-plane=controller-manager --tail=100

# Look for:
# - Version indicators (v0.6.11)
# - Successful controller start messages
# - No RBAC permission errors
# - Environment variable loading (TOOLHIVE_VMCP_IMAGE, etc.)

# Check operator environment variables
kubectl exec -n toolhive-test deployment/toolhive-operator-controller-manager -- env | grep TOOLHIVE

# Cleanup
kubectl delete namespace toolhive-test
```

**Acceptance Criteria**:
- Operator pod starts successfully
- No crash loops or restart errors
- Logs show v0.6.11 indicators
- No RBAC permission errors
- Environment variables correctly set

---

## Summary of Tasks by Phase

### Phase Breakdown

| Phase | Duration | Tasks | Critical? |
|-------|----------|-------|-----------|
| Phase 1: Setup | 15 min | 3 tasks | Yes |
| Phase 2: Foundational | 20 min | 4 tasks | Yes |
| Phase 3: US1 - Operator Version | 15 min | 3 tasks | Yes (P1) |
| Phase 4: US2 - CRDs | 20 min | 4 tasks | Yes (P1) |
| Phase 5: US3 - vmcp Image | 15 min | 6 tasks | Yes (P2) |
| Phase 6: US4 - RBAC | 20 min | 4 tasks | Yes (P2) |
| Phase 7: US5 - ProxyRunner | 10 min | 2 tasks | Yes (P3) |
| Phase 8: Validation | 30 min | 8 tasks | Yes |
| Phase 9: Polish | 20 min | 4 tasks | Yes |
| Phase 10: Test Cluster | 30-60 min | 3 tasks | Optional |
| **TOTAL** | **2-4 hours** | **41 tasks** | - |

### Task Distribution by User Story

| User Story | Tasks | Priority |
|------------|-------|----------|
| US1: Update Core Operator Version | 3 | P1 |
| US2: Update CRDs | 4 | P1 |
| US3: Add vmcp Operand | 6 | P2 |
| US4: Update RBAC | 4 | P2 |
| US5: Update ProxyRunner | 2 | P3 |
| Setup | 3 | Critical |
| Foundational | 4 | Critical |
| Validation | 8 | Critical |
| Polish | 4 | Medium |
| Test Cluster (Optional) | 3 | Optional |

### Parallel Execution Opportunities

Tasks marked [P] can be executed in parallel within their phase:

**Phase 1 (Setup)**: All 3 tasks can run in parallel
**Phase 2 (Foundational)**: Task 2.4 can run in parallel with 2.1-2.3

### Critical Path

1. **Setup** (Phase 1) → **Foundational** (Phase 2) → **User Stories** (Phases 3-7) → **Validation** (Phase 8) → **Polish** (Phase 9)
2. User Story phases can be executed in order (US1 → US2 → US3 → US4 → US5) or in priority order if preferred
3. Test Cluster validation (Phase 10) is optional but recommended before creating PR

### Validation Checkpoints

Each user story phase includes a validation task to verify completion before proceeding:

- **Checkpoint 1**: After US1 - Operator version verified (Task 3.3)
- **Checkpoint 2**: After US2 - CRDs validated (Tasks 4.3, 4.4)
- **Checkpoint 3**: After US3 - vmcp image validated (Task 5.6)
- **Checkpoint 4**: After US4 - RBAC validated (Task 6.4)
- **Checkpoint 5**: After US5 - ProxyRunner validated (Task 7.2)
- **Final Checkpoint**: Phase 8 - Complete system validation

### Success Criteria

All tasks in Phases 1-9 must be completed successfully. Phase 10 is optional but highly recommended for confidence in the upgrade.

**Final Deliverable**:
- Git commit with all changes
- Bundle and catalog validated
- Pull request prepared with comprehensive documentation
- (Optional) Test cluster validation passed

---

## Troubleshooting Reference

### Common Issues by Phase

#### Phase 2: Foundational
- **Issue**: Upstream repository clone fails
  - **Solution**: Check network connectivity, verify GitHub access

- **Issue**: CRD tag not found
  - **Solution**: Verify tag name is `toolhive-operator-crds-0.0.74` (not `v0.0.74`)

#### Phase 4: CRDs
- **Issue**: CRD copy fails
  - **Solution**: Verify source path `/tmp/toolhive-upgrade/toolhive/deploy/charts/operator-crds/crds/`

- **Issue**: Kustomize build fails after CRD update
  - **Solution**: Check kustomization.yaml lists all 8 CRDs, verify CRD YAML syntax

#### Phase 5: vmcp Image
- **Issue**: Environment variables not appearing in kustomize output
  - **Solution**: Verify manager_env_patch.yaml is listed in patchesStrategicMerge in kustomization.yaml

#### Phase 6: RBAC
- **Issue**: YAML syntax error in role.yaml
  - **Solution**: Verify indentation is correct, use `yq eval '.' config/rbac/role.yaml` to check

#### Phase 8: Validation
- **Issue**: Bundle validation fails
  - **Solution**: Regenerate bundle after fixing issues: `make clean && make bundle`

- **Issue**: CRD count mismatch
  - **Solution**: Verify config/crd/kustomization.yaml lists all 8 CRDs

### Rollback Procedure

If you need to rollback to v0.4.2 during upgrade:

```bash
# 1. Restore all config files from main branch
git checkout main -- config/ Makefile

# 2. Remove new patch files
rm -f config/base/manager_env_patch.yaml
rm -f config/default/manager_env_patch.yaml

# 3. Clean and regenerate
make clean
make bundle
make catalog

# 4. Validate rollback
make kustomize-validate
make bundle-validate-sdk
make catalog-validate
```

---

## Appendix: File Modification Summary

### Files Created (NEW)
1. `/wip/src/github.com/RHEcosystemAppEng/toolhive-operator-metadata/config/base/manager_env_patch.yaml`
2. `/wip/src/github.com/RHEcosystemAppEng/toolhive-operator-metadata/config/default/manager_env_patch.yaml`
3. `/wip/src/github.com/RHEcosystemAppEng/toolhive-operator-metadata/config/crd/bases/toolhive.stacklok.dev_virtualmcpservers.yaml`
4. `/wip/src/github.com/RHEcosystemAppEng/toolhive-operator-metadata/config/crd/bases/toolhive.stacklok.dev_virtualmcpcompositetooldefinitions.yaml`

### Files Modified (UPDATED)
1. `/wip/src/github.com/RHEcosystemAppEng/toolhive-operator-metadata/Makefile`
2. `/wip/src/github.com/RHEcosystemAppEng/toolhive-operator-metadata/config/base/params.env`
3. `/wip/src/github.com/RHEcosystemAppEng/toolhive-operator-metadata/config/base/kustomization.yaml`
4. `/wip/src/github.com/RHEcosystemAppEng/toolhive-operator-metadata/config/default/kustomization.yaml`
5. `/wip/src/github.com/RHEcosystemAppEng/toolhive-operator-metadata/config/crd/kustomization.yaml`
6. `/wip/src/github.com/RHEcosystemAppEng/toolhive-operator-metadata/config/rbac/role.yaml`
7. `/wip/src/github.com/RHEcosystemAppEng/toolhive-operator-metadata/config/crd/bases/toolhive.stacklok.dev_mcpexternalauthconfigs.yaml`
8. `/wip/src/github.com/RHEcosystemAppEng/toolhive-operator-metadata/config/crd/bases/toolhive.stacklok.dev_mcpgroups.yaml`
9. `/wip/src/github.com/RHEcosystemAppEng/toolhive-operator-metadata/config/crd/bases/toolhive.stacklok.dev_mcpregistries.yaml`
10. `/wip/src/github.com/RHEcosystemAppEng/toolhive-operator-metadata/config/crd/bases/toolhive.stacklok.dev_mcpremoteproxies.yaml`
11. `/wip/src/github.com/RHEcosystemAppEng/toolhive-operator-metadata/config/crd/bases/toolhive.stacklok.dev_mcpservers.yaml`
12. `/wip/src/github.com/RHEcosystemAppEng/toolhive-operator-metadata/config/crd/bases/toolhive.stacklok.dev_mcptoolconfigs.yaml`

### Directories Regenerated
1. `/wip/src/github.com/RHEcosystemAppEng/toolhive-operator-metadata/bundle/`
2. `/wip/src/github.com/RHEcosystemAppEng/toolhive-operator-metadata/catalog/`

**Total Files Created**: 4
**Total Files Modified**: 12
**Total Directories Regenerated**: 2

---

**End of Tasks Document**
