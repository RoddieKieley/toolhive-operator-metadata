# Implementation Plan: Upgrade ToolHive Operator to v0.6.11

**Branch**: `015-upgrade-toolhive-operator` | **Date**: 2025-12-04 | **Spec**: [spec.md](spec.md)

## Summary

Upgrade ToolHive Operator metadata from v0.4.2 to v0.6.11 by synchronizing Custom Resource Definitions (CRDs), operator and operand container images, RBAC permissions, and configuration with upstream helm charts at toolhive-operator-0.5.8 and toolhive-operator-crds-0.0.74. The upgrade introduces the new vmcp operand for VirtualMCPServer functionality while maintaining backward compatibility with both OLMv0 (legacy OpenShift 4.15-4.18) and OLMv1 (modern OpenShift 4.19+) deployment formats.

**Technical Approach**: Extract configuration from upstream helm charts, update Makefile variables, synchronize CRDs, update ClusterServiceVersion (CSV) with new images and RBAC permissions, regenerate bundles and catalogs, and validate using operator-sdk and opm tools.

## Technical Context

**Language/Version**: YAML (Kubernetes manifests), Makefile (build orchestration), Kustomize v5.0+
**Primary Dependencies**:
- operator-sdk v1.41.0+ (bundle generation and validation)
- opm v1.49.0+ (catalog generation and validation)
- kustomize v5.0+ (manifest customization)
- yq v4+ (YAML processing in Makefile)
- Upstream helm charts: toolhive-operator-0.5.8, toolhive-operator-crds-0.0.74

**Storage**: Git repository (source of truth for manifests), ghcr.io (container image registry)
**Testing**:
- operator-sdk scorecard (bundle validation)
- opm validate (catalog validation)
- kustomize build (manifest integrity)
- Manual test cluster deployment (upgrade path validation)

**Target Platform**: OpenShift 4.15-4.18 (OLMv0 SQLite index), OpenShift 4.19+ (OLMv1 File-Based Catalog), Kubernetes 1.25+
**Project Type**: Kubernetes Operator Metadata (manifest repository)
**Performance Goals**:
- Bundle generation: < 2 minutes
- Catalog generation: < 1 minute
- Operator installation: < 5 minutes
- Upgrade completion: < 10 minutes

**Constraints**:
- MUST maintain constitutional compliance (manifest integrity, CRD immutability, kustomize-based customization)
- MUST NOT modify CRD content (sync from upstream only)
- MUST use helm charts as definitive source of truth
- MUST support both OLMv0 and OLMv1 formats
- MUST pass operator-sdk scorecard validation
- MUST preserve OpenShift compatibility (config/base overlay)

**Scale/Scope**:
- 2 CRD files to sync (mcpregistries, mcpservers) plus any new CRDs from v0.6.11
- 3 container images to update (operator, vmcp, proxyrunner)
- 1 ClusterServiceVersion to update
- 1 Makefile with ~20 version variables
- ~7 minor releases worth of changes (v0.4.2 → v0.6.11)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Constitutional Compliance Analysis

✅ **Principle I: Manifest Integrity**
- Status: COMPLIANT
- All manifest changes will be validated with `kustomize build config/base` and `kustomize build config/default`
- Upgrade process includes validation step before commit

✅ **Principle II: Kustomize-Based Customization**
- Status: COMPLIANT
- CRD updates via direct file replacement (permitted for sync from upstream)
- Image version updates via `config/base/params.env` kustomize replacements
- RBAC updates via CSV patches in kustomize overlay

✅ **Principle III: CRD Immutability**
- Status: COMPLIANT - CRITICAL FOR THIS UPGRADE
- CRDs sourced from toolhive-operator-crds-0.0.74 helm chart
- No modifications to CRD schemas, only version sync
- CRDs copied from upstream, not modified locally

✅ **Principle IV: OpenShift Compatibility**
- Status: COMPLIANT
- OpenShift-specific configurations remain in `config/base`
- `config/default` remains OpenShift-agnostic
- Image version changes applied to both overlays via kustomize replacements

✅ **Principle V: Namespace Awareness**
- Status: COMPLIANT
- No namespace changes required
- Existing namespace configurations (`toolhive-operator-system` and `opendatahub`) remain intact

✅ **Principle VI: OLM Catalog Multi-Bundle Support**
- Status: COMPLIANT
- Catalog structure supports multiple bundle versions
- Upgrade adds v0.6.11 bundle alongside v0.4.2 (if maintaining upgrade path)
- OR replaces v0.4.2 with v0.6.11 (if single-version catalog)

✅ **Principle VII: Scorecard Quality Assurance**
- Status: COMPLIANT
- `operator-sdk scorecard bundle/` validation required before completion
- Success criteria SC-005 explicitly requires scorecard tests to pass

✅ **Principle VIII: GitHub Actions Actor Lowercase**
- Status: COMPLIANT (not applicable to this upgrade)
- GitHub Actions workflows already compliant from specification 014
- No workflow modifications required for this upgrade

**Operator SDK Plugin Policy**:
- Status: COMPLIANT
- All operator-sdk commands in Makefile already specify `--plugins=go.kubebuilder.io/v4`

**GATE STATUS**: ✅ **PASS** - All constitutional principles compliant. No violations requiring justification.

## Project Structure

### Documentation (this feature)

```
specs/015-upgrade-toolhive-operator/
├── spec.md              # Feature specification (completed)
├── checklists/
│   └── requirements.md  # Spec quality checklist (completed)
├── plan.md              # This file
├── research.md          # Phase 0 output (helm chart analysis)
├── data-model.md        # Phase 1 output (CRD entity comparison v0.4.2 → v0.6.11)
├── quickstart.md        # Phase 1 output (upgrade procedure guide)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created yet)
```

### Source Code (repository root)

```
# Existing structure - files TO BE MODIFIED

config/
├── crd/
│   ├── bases/
│   │   ├── toolhive.stacklok.dev_mcpregistries.yaml    # [UPDATE] from toolhive-operator-crds-0.0.74
│   │   └── toolhive.stacklok.dev_mcpservers.yaml       # [UPDATE] from toolhive-operator-crds-0.0.74
│   │   └── [POTENTIALLY NEW CRDs]                       # [ADD] if present in toolhive-operator-crds-0.0.74
│   └── kustomization.yaml                               # [UPDATE] if new CRDs added
│
├── base/
│   ├── params.env                                       # [UPDATE] image versions
│   ├── kustomization.yaml                               # [REVIEW] no changes expected
│   ├── openshift_env_var_patch.yaml                     # [UPDATE] TOOLHIVE_RUNNER_IMAGE version
│   └── [other patches]                                  # [REVIEW] verify compatibility
│
├── default/
│   └── kustomization.yaml                               # [REVIEW] no changes expected
│
├── manager/
│   └── manager.yaml                                     # [UPDATE] via kustomize (image versions)
│
└── rbac/
    ├── role.yaml                                        # [UPDATE] new permissions from helm chart
    ├── cluster_role.yaml                                # [UPDATE] new permissions from helm chart
    └── kustomization.yaml                               # [REVIEW] verify resource list

bundle/
├── manifests/
│   ├── toolhive-operator.clusterserviceversion.yaml    # [REGENERATE] via make bundle
│   ├── toolhive.stacklok.dev_mcpregistries.yaml        # [REGENERATE] via make bundle
│   └── toolhive.stacklok.dev_mcpservers.yaml           # [REGENERATE] via make bundle
└── metadata/
    └── annotations.yaml                                 # [UPDATE] version annotations

catalog/
└── toolhive-operator/
    └── catalog.yaml                                     # [REGENERATE] via make catalog

Makefile                                                 # [UPDATE] VERSION, image tags, helm chart references
```

**Structure Decision**: This is a manifest metadata repository following Kubebuilder structure. All changes are updates to existing files or regeneration of derived artifacts (bundle, catalog). No new source code directories required.

## Complexity Tracking

*No constitutional violations - this section not applicable*

## Phase 0: Research

### Research Status

**Objective**: Identify all configuration changes between v0.4.2 and v0.6.11 by analyzing helm charts and git commit log.

### Research Tasks

1. **Helm Chart Analysis - CRDs**
   - Download toolhive-operator-crds-0.0.74 helm chart
   - Extract CRD files from chart
   - Compare with current CRDs in `config/crd/bases/`
   - Document: new CRDs, field additions, schema changes, API version changes

2. **Helm Chart Analysis - Operator Configuration**
   - Download toolhive-operator-0.5.8 helm chart
   - Extract operator deployment configuration
   - Document: container images, resource limits, security contexts, environment variables, ports

3. **Helm Chart Analysis - RBAC**
   - Extract ClusterRole and Role permissions from toolhive-operator-0.5.8
   - Compare with current permissions in `config/rbac/`
   - Document: new API groups, new resources, new verbs, leader election permissions

4. **Git Commit Log Analysis**
   - Clone https://github.com/stacklok/toolhive
   - Run: `git log --oneline v0.4.2..toolhive-operator-0.5.8`
   - Identify commits affecting: CRDs, RBAC, operand images, configuration
   - Document undocumented changes not in release notes

5. **Version Mapping**
   - Confirm: operator image tag for v0.6.11
   - Confirm: vmcp image tag for v0.6.11
   - Confirm: proxyrunner image tag for v0.6.11
   - Document: any version mismatches or special tagging schemes

**Output**: [research.md](research.md) with detailed findings from each research task

### Research Execution Plan

Use Task tool with subagent_type='general-purpose' to:
1. Fetch helm charts from GitHub releases/tags
2. Extract and parse YAML files
3. Compare configurations
4. Analyze git commit log
5. Consolidate findings into research.md

## Phase 1: Design & Contracts

**Prerequisites**: `research.md` complete with helm chart analysis

### Design Artifacts

#### 1. Data Model (data-model.md)

**Content**: Entity comparison table for CRD changes v0.4.2 → v0.6.11

- **MCPRegistry CRD**:
  - v0.4.2 schema fields
  - v0.6.11 schema fields (from toolhive-operator-crds-0.0.74)
  - New fields: PVC source configuration, Kubernetes source type
  - Changed fields: (from research)
  - Removed fields: (from research)

- **MCPServer CRD**:
  - v0.4.2 schema fields
  - v0.6.11 schema fields
  - Field changes (from research)

- **VirtualMCPServer CRD** (NEW in v0.6.x):
  - Full schema documentation
  - Required fields
  - Relationship to vmcp operand

- **CompositeToolSpec CRD**:
  - v0.4.2 schema (if exists)
  - v0.6.11 schema with Output Schema Support
  - Field changes (from research)

- **Validation Rules**:
  - Backward compatibility assessment
  - Breaking changes identified
  - Migration considerations

**Output**: [data-model.md](data-model.md)

#### 2. API Contracts (contracts/)

**Not applicable** - This is a Kubernetes operator metadata upgrade. There are no REST/GraphQL APIs to define. The "API" is the Kubernetes CRD schema, which is documented in data-model.md.

**Decision**: Skip contracts/ directory - CRD schemas serve as the API contract.

#### 3. Quickstart Guide (quickstart.md)

**Content**: Step-by-step upgrade procedure for developers

- **Prerequisites**:
  - Tools required (operator-sdk, opm, kustomize, yq)
  - Access requirements (ghcr.io, upstream git repo)

- **Upgrade Procedure**:
  1. Update Makefile variables (VERSION, image tags, helm chart references)
  2. Sync CRDs from toolhive-operator-crds-0.0.74
  3. Update RBAC permissions from toolhive-operator-0.5.8
  4. Update image references in `config/base/params.env`
  5. Update environment variables (TOOLHIVE_RUNNER_IMAGE)
  6. Regenerate bundle: `make bundle`
  7. Validate bundle: `operator-sdk scorecard bundle/`
  8. Regenerate catalog: `make catalog`
  9. Validate catalog: `make catalog-validate`
  10. Test upgrade path in test cluster

- **Validation Checklist**:
  - [ ] `kustomize build config/base` succeeds
  - [ ] `kustomize build config/default` succeeds
  - [ ] `operator-sdk scorecard bundle/` passes
  - [ ] `make catalog-validate` passes
  - [ ] Test cluster upgrade succeeds

- **Troubleshooting**:
  - CRD validation errors
  - RBAC permission errors
  - Image pull errors
  - Scorecard test failures

**Output**: [quickstart.md](quickstart.md)

## Phase 2: Task Planning

**Deferred to `/speckit.tasks` command** - This section will generate the detailed task breakdown.

**Expected Task Categories**:
1. **Research Phase**: Helm chart analysis, git commit log analysis
2. **Makefile Updates**: Version variables, image tags
3. **CRD Synchronization**: Download and copy CRDs from upstream
4. **RBAC Updates**: Permissions from helm chart to config/rbac/
5. **Image Reference Updates**: params.env, environment variables
6. **Bundle Regeneration**: make bundle, validation
7. **Catalog Regeneration**: make catalog, validation
8. **Testing**: Upgrade path validation, scorecard tests

## Post-Design Constitution Check

*Re-evaluate after Phase 1 artifacts are generated*

### Constitution Compliance Re-Verification

**Phase 1 Changes**:
- research.md created (documentation only)
- data-model.md created (CRD schema comparison, read-only analysis)
- quickstart.md created (documentation only)

✅ **Constitutional compliance remains COMPLIANT** - No manifest changes in Phase 1, only documentation and analysis artifacts.

**Phase 2 Preview (Implementation Tasks)**:
- CRD file replacements: ✅ COMPLIANT (Principle III allows sync from upstream)
- RBAC updates: ✅ COMPLIANT (via kustomize patches or direct config/rbac/ updates)
- Image updates: ✅ COMPLIANT (via params.env kustomize replacements)
- Bundle/catalog regeneration: ✅ COMPLIANT (derived artifacts from manifests)

**Compliance Status**: ✅ **COMPLIANT** - All planned implementation tasks align with constitutional principles

## Next Steps

1. ✅ **Phase 0 Setup Complete**: Plan template populated, constitution verified
2. ✅ **Phase 0 Research Complete**: Generated research.md with helm chart and git log analysis
3. ✅ **Phase 1 Design Complete**: Generated data-model.md, quickstart.md
4. ✅ **Agent Context Updated**: CLAUDE.md updated with new technologies
5. ⏭️ **Phase 2 Tasks**: Run `/speckit.tasks` to generate actionable task breakdown

**Planning Phase Complete** - All design artifacts generated and validated against constitutional principles.

**Suggested Next Command**: `/speckit.tasks`
