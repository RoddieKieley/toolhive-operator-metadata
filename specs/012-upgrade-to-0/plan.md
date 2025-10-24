# Implementation Plan: Upgrade ToolHive Operator to v0.4.2

**Branch**: `012-upgrade-to-0` | **Date**: 2025-10-24 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/012-upgrade-to-0/spec.md`

## Summary

This implementation upgrades the ToolHive Operator metadata project from v0.3.11 to v0.4.2. The upgrade involves systematically updating version references across all project files, integrating the new MCPGroup custom resource definition (CRD), and ensuring all OLM catalog metadata reflects the v0.4.2 release. The technical approach follows the project's established pattern of maintaining downloaded upstream manifests, applying OpenShift-specific patches via kustomize, and generating validated OLM bundles and catalogs.

## Technical Context

**Language/Version**: YAML/Kustomize (manifest-based project, no programming language)
**Primary Dependencies**:
- kustomize (manifest composition)
- operator-sdk v1.x with go.kubebuilder.io/v4 plugin (bundle validation)
- opm (catalog generation and validation)
- yq (YAML manipulation)

**Storage**: File-based (YAML manifests, no database)
**Testing**:
- kustomize build validation (config/default, config/base)
- operator-sdk bundle validate (using go.kubebuilder.io/v4 plugin per constitution)
- opm validate (catalog validation)

**Target Platform**: Kubernetes/OpenShift operator deployment via OLM
**Project Type**: Kubernetes operator metadata (manifest-based configuration project)
**Performance Goals**: Instant build times for manifests (<5 seconds for kustomize/bundle/catalog)
**Constraints**:
- Must maintain kustomize build compatibility (constitution principle I)
- CRDs must remain unmodified from upstream (constitution principle III)
- Must support both config/default and config/base overlays
- Bundle validation must use go.kubebuilder.io/v4 plugin (constitution governance)

**Scale/Scope**:
- 6 CRDs (adding 1 new MCPGroup CRD)
- 20+ files containing version references
- 2 kustomize overlays (default + base)
- 3 OLM artifacts (bundle, catalog, index)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### ✅ Principle I - Manifest Integrity (NON-NEGOTIABLE)
**Status**: COMPLIANT
- This feature updates version numbers and adds a new CRD but does not modify kustomize structure
- Both `kustomize build config/default` and `kustomize build config/base` will continue to work
- The MCPGroup CRD follows the same pattern as existing CRDs (added to config/crd/bases/, referenced in kustomization.yaml)

### ✅ Principle II - Kustomize-Based Customization
**Status**: COMPLIANT
- No direct manifest modifications - all changes follow kustomize patterns
- The MCPGroup CRD is added as a base resource, not modified
- Version updates in downloaded manifests follow the established pattern (copy from upstream, patch via yq in Makefile)

### ✅ Principle III - CRD Immutability (NON-NEGOTIABLE)
**Status**: COMPLIANT
- The MCPGroup CRD will be downloaded directly from upstream v0.4.2 source without modification
- All 6 CRDs (including the new MCPGroup) remain unchanged from upstream definitions
- This upgrade follows the same pattern as the v0.3.11 upgrade (spec 011) which successfully maintained CRD immutability

### ✅ Principle IV - OpenShift Compatibility
**Status**: COMPLIANT
- No changes to the config/base vs config/default separation
- Existing OpenShift patches (security contexts, resource limits) will be verified to work with v0.4.2 manifests
- The config/default overlay remains OpenShift-agnostic

### ✅ Principle V - Namespace Awareness
**Status**: COMPLIANT
- No namespace changes required for this version upgrade
- config/default continues to use toolhive-operator-system
- config/base continues to target opendatahub

### ✅ Principle VI - OLM Catalog Multi-Bundle Support
**Status**: COMPLIANT
- The catalog structure remains unchanged: 1 olm.package, 1 olm.channel, 1 olm.bundle (for v0.4.2)
- Future upgrades may add additional olm.bundle entries for v0.3.11 to support rollback, but this is out of scope for this feature

### ✅ Governance - Operator SDK Plugin Policy
**Status**: COMPLIANT
- All operator-sdk commands in the Makefile already use --plugins go.kubebuilder.io/v4
- Bundle validation target (bundle-validate-sdk) explicitly specifies the v4 plugin
- No changes to operator-sdk usage patterns required

**Constitution Compliance Result**: ✅ ALL GATES PASSED - Proceed to Phase 0

## Project Structure

### Documentation (this feature)

```
specs/012-upgrade-to-0/
├── spec.md              # Feature specification (created by /speckit.specify)
├── plan.md              # This file (created by /speckit.plan)
├── research.md          # Phase 0: Research findings on v0.4.2 changes
├── data-model.md        # Phase 1: Entity model (minimal - just version tags and file locations)
├── quickstart.md        # Phase 1: Developer guide for performing version upgrades
├── contracts/           # Phase 1: Validation contracts (kustomize builds, bundle validation)
├── checklists/          # Created by /speckit.specify
│   └── requirements.md  # Specification quality checklist (✅ PASSED)
└── tasks.md             # Phase 2: NOT created by /speckit.plan - created by /speckit.tasks
```

### Source Code (repository root)

```
# Existing project structure (no new directories needed)
.
├── Makefile                    # Version variable updates (CATALOG_TAG, BUNDLE_TAG, INDEX_TAG)
├── config/
│   ├── base/
│   │   └── params.env          # Image version updates (toolhive-operator-image, toolhive-proxy-image)
│   ├── crd/
│   │   ├── bases/
│   │   │   ├── toolhive.stacklok.dev_mcpexternalauthconfigs.yaml
│   │   │   ├── toolhive.stacklok.dev_mcpgroups.yaml  # NEW - Downloaded from v0.4.2
│   │   │   ├── toolhive.stacklok.dev_mcpregistries.yaml
│   │   │   ├── toolhive.stacklok.dev_mcpremoteproxies.yaml
│   │   │   ├── toolhive.stacklok.dev_mcpservers.yaml
│   │   │   └── toolhive.stacklok.dev_mcptoolconfigs.yaml
│   │   └── kustomization.yaml  # Add MCPGroup CRD reference
│   ├── manager/
│   │   └── manager.yaml        # Operator and proxyrunner image tag updates
│   └── rbac/
│       └── role.yaml           # Add mcpgroups RBAC permissions
├── downloaded/
│   └── toolhive-operator/
│       ├── 0.3.11/             # Existing v0.3.11 manifests (preserved for reference)
│       └── 0.4.2/              # NEW - v0.4.2 manifests (CSV + 6 CRDs)
│           ├── toolhive-operator.clusterserviceversion.yaml  # Updated with MCPGroup
│           ├── mcpexternalauthconfigs.crd.yaml
│           ├── mcpgroups.crd.yaml                             # NEW
│           ├── mcpregistries.crd.yaml
│           ├── mcpremoteproxies.crd.yaml
│           ├── mcpservers.crd.yaml
│           └── mcptoolconfigs.crd.yaml
├── examples/
│   ├── catalogsource-olmv0.yaml  # Update image tags to v0.4.2
│   ├── catalogsource-olmv1.yaml  # Update image tags to v0.4.2
│   └── README.md                 # Update version references
├── README.md                     # Update version references
├── VALIDATION.md                 # Update version references
└── Containerfile.bundle          # Update version in comments

# Generated artifacts (updated during build)
bundle/
├── manifests/
│   ├── mcpexternalauthconfigs.crd.yaml
│   ├── mcpgroups.crd.yaml        # NEW - Included in bundle
│   ├── mcpregistries.crd.yaml
│   ├── mcpremoteproxies.crd.yaml
│   ├── mcpservers.crd.yaml
│   ├── mcptoolconfigs.crd.yaml
│   └── toolhive-operator.clusterserviceversion.yaml  # v0.4.2, declares MCPGroup ownership
└── metadata/
    └── annotations.yaml

catalog/
└── toolhive-operator/
    └── catalog.yaml              # 7 olm.bundle.object entries (6 CRDs + 1 CSV)
```

**Structure Decision**: This is a manifest-based metadata project with no source code. All changes are YAML file updates following the established kustomize pattern. The project structure remains unchanged - we're adding one new CRD file and updating version strings across existing files.

## Complexity Tracking

*No constitution violations - this section not needed.*

---

## Phase 0: Research & Decision Log

### Research Tasks

1. **Verify v0.4.2 Manifest Availability**
   - **Question**: Are complete v0.4.2 manifests (CSV + all 6 CRDs) available for download from upstream?
   - **Method**: Check GitHub release artifacts or generate from upstream Helm charts
   - **Output**: Document the source URL or generation method for v0.4.2 manifests

2. **Analyze v0.4.2 Changes**
   - **Question**: What changed between v0.3.11 and v0.4.2 that affects this project?
   - **Method**: Review release notes, commit log, and compare v0.3.11 vs v0.4.2 CSV structure
   - **Output**: List of changes beyond the MCPGroup CRD (e.g., new RBAC requirements, env vars, patches needed)

3. **MCPGroup CRD Integration Pattern**
   - **Question**: Does MCPGroup follow the same integration pattern as the 5 existing CRDs?
   - **Method**: Compare MCPGroup YAML structure to existing CRDs (group, version, scope, status fields)
   - **Output**: Confirmation that MCPGroup can be added using the same kustomization pattern

4. **Patch Compatibility**
   - **Question**: Are the existing OpenShift patches still applicable to v0.4.2 CSV?
   - **Method**: Test yq eval commands from Makefile against v0.4.2 CSV structure
   - **Output**: List of patches that work as-is vs. patches needing adjustment

5. **RBAC Permission Scope**
   - **Question**: What RBAC permissions does MCPGroup require (beyond standard CRUD)?
   - **Method**: Review MCPGroup CRD spec for controller requirements and finalizers
   - **Output**: Complete list of RBAC rules for mcpgroups, mcpgroups/status, mcpgroups/finalizers

### Research Output Location

`specs/012-upgrade-to-0/research.md` (generated during /speckit.plan Phase 0 execution)

---

## Phase 1: Design Artifacts

### Data Model

**Entity**: Version Reference Location
- **Attributes**: file_path, line_number, current_value (v0.3.11), new_value (v0.4.2), update_method (sed/yq/manual)
- **Purpose**: Track all locations requiring version updates to ensure completeness

**Entity**: MCPGroup CRD Metadata
- **Attributes**: source_url, destination_path, kustomization_entry, csv_owned_entry, rbac_rules
- **Purpose**: Document all integration points for the new CRD

**Output**: `specs/012-upgrade-to-0/data-model.md`

### Contracts

**Contract 1**: Kustomize Build Validation
- **Pre-condition**: All version references updated, MCPGroup CRD added
- **Test**: `kustomize build config/default` and `kustomize build config/base` both succeed
- **Post-condition**: Valid Kubernetes YAML output with v0.4.2 images and 6 CRDs

**Contract 2**: Bundle Validation
- **Pre-condition**: Bundle generated from updated manifests
- **Test**: `operator-sdk --plugins go.kubebuilder.io/v4 bundle validate ./bundle`
- **Post-condition**: No errors, 6 CRD files present, CSV declares MCPGroup ownership

**Contract 3**: Catalog Validation
- **Pre-condition**: Catalog generated with embedded bundle
- **Test**: `opm validate catalog/` and parse catalog.yaml for 7 olm.bundle.object entries
- **Post-condition**: Valid catalog with correct version tags and all CRDs

**Output**: `specs/012-upgrade-to-0/contracts/` directory with YAML validation schemas

### Developer Quickstart

**Topic**: How to Perform a ToolHive Operator Version Upgrade
- **Prerequisites**: Access to upstream v0.4.2 release, yq, kustomize, operator-sdk, opm
- **Step-by-step**:
  1. Download/generate v0.4.2 manifests → downloaded/toolhive-operator/0.4.2/
  2. Update version variables in Makefile
  3. Update image references in config/
  4. Add new CRDs (if any) to config/crd/bases/ and kustomization
  5. Update CSV with new CRD ownership and RBAC
  6. Update ClusterRole in config/rbac/
  7. Update documentation files
  8. Rebuild and validate bundle/catalog
  9. Test deployment
- **Common Pitfalls**: Forgetting to update params.env, missing RBAC subresources, operator-sdk plugin not specified

**Output**: `specs/012-upgrade-to-0/quickstart.md`

---

## Phase 2: Task Generation (Not in /speckit.plan)

**Note**: This phase is handled by the `/speckit.tasks` command, which:
1. Reads this plan.md and the spec.md
2. Generates dependency-ordered tasks in `tasks.md`
3. Each task maps to specific file updates with acceptance criteria

**Expected Task Categories** (for reference):
- **P1 Tasks**: Version variable updates (Makefile, params.env, manager.yaml)
- **P1 Tasks**: Download v0.4.2 manifests
- **P2 Tasks**: MCPGroup CRD integration (download, kustomization, bundle)
- **P3 Tasks**: CSV updates (ownership, RBAC, description)
- **P3 Tasks**: ClusterRole RBAC updates
- **P4 Tasks**: Documentation updates (README, examples, VALIDATION)
- **P5 Tasks**: Validation and testing (bundle-validate, catalog-validate, kustomize-validate)

---

## Post-Design Constitution Re-Check

*Re-evaluate after Phase 1 artifacts are generated*

| Principle | Pre-Design Status | Post-Design Status | Changes |
|-----------|-------------------|-------------------|---------|
| I. Manifest Integrity | ✅ PASS | ✅ PASS | No kustomize structure changes |
| II. Kustomize Customization | ✅ PASS | ✅ PASS | MCPGroup follows existing CRD pattern |
| III. CRD Immutability | ✅ PASS | ✅ PASS | All CRDs downloaded unmodified from upstream |
| IV. OpenShift Compatibility | ✅ PASS | ✅ PASS | No overlay structure changes |
| V. Namespace Awareness | ✅ PASS | ✅ PASS | No namespace changes |
| VI. OLM Multi-Bundle | ✅ PASS | ✅ PASS | Single bundle for v0.4.2 maintained |
| Operator SDK Plugin | ✅ PASS | ✅ PASS | Continues using go.kubebuilder.io/v4 |

**Final Compliance**: ✅ ALL PRINCIPLES MAINTAINED

---

## Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| v0.4.2 manifests unavailable or incomplete | Low | High | Document manual generation from Helm charts if needed |
| CSV patches incompatible with v0.4.2 | Low | Medium | Test patches early in Phase 0 research, adjust if needed |
| MCPGroup requires unique RBAC beyond standard | Low | Low | Research CRD thoroughly, compare with similar CRDs |
| Version reference missed in update | Medium | Medium | Generate comprehensive file list, use grep for verification |
| Bundle/catalog validation fails | Low | High | Follow established pattern from v0.3.11 upgrade (spec 011) |

---

## Success Metrics

Measured against specification success criteria:

- **SC-001**: All version references → Grep for "v0.3.11" returns 0 results, "v0.4.2" in 20+ files
- **SC-002**: Bundle with 6 CRDs → `ls bundle/manifests/*.crd.yaml | wc -l` = 6
- **SC-003**: Catalog with 7 objects → `yq eval '.properties[] | select(.type == "olm.bundle.object")' catalog.yaml | wc -l` = 7 (updated count)
- **SC-004**: Bundle validation → `make bundle-validate-sdk` exits 0
- **SC-005**: Catalog deploys → Manual test in OpenShift cluster
- **SC-006**: 6 CRDs available → `kubectl get crds | grep toolhive.stacklok.dev | wc -l` = 6
- **SC-007**: MCPGroup creation → `kubectl apply -f test-mcpgroup.yaml` succeeds
- **SC-008**: v0.4.2 images running → `kubectl describe pod -l app.kubernetes.io/name=toolhive-operator | grep Image:` shows v0.4.2
- **SC-009**: No RBAC errors → `kubectl logs deployment/toolhive-operator` shows no "forbidden" errors
- **SC-010**: First-attempt success → All validation commands pass without iteration

---

## Next Steps

After this plan is approved:

1. **Run `/speckit.plan`** (this command) to generate Phase 0 and Phase 1 artifacts:
   - research.md (all unknowns resolved)
   - data-model.md (version references and CRD integration points)
   - contracts/ (validation test definitions)
   - quickstart.md (upgrade procedure guide)

2. **Run `/speckit.tasks`** to generate implementation tasks:
   - Dependency-ordered task list in tasks.md
   - Each task with clear acceptance criteria and file targets

3. **Run `/speckit.implement`** to execute the tasks:
   - Automated file updates where possible
   - Manual verification checkpoints
   - Validation at each stage

4. **Manual verification**:
   - Deploy to test OpenShift cluster
   - Create sample MCPGroup resource
   - Verify operator logs show no errors
   - Confirm all 6 CRDs available via kubectl

**Estimated Effort**: 4-6 hours (research: 1h, implementation: 2-3h, testing: 1-2h)
