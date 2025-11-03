# Implementation Plan: Repository Rehoming

**Branch**: `013-rehome-repos-the` | **Date**: 2025-11-03 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/013-rehome-repos-the/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Update all repository location references from the old location to `https://github.com/stacklok/toolhive-operator-metadata` and all container image references to production destinations under `ghcr.io/stacklok/toolhive/` (operator-bundle, operator-catalog, operator-index). This enables production deployment with correct image URLs and ensures documentation points users to the current repository location.

**Technical Approach**: Systematic replacement of URL patterns across Makefile variables, documentation files, and scripts, followed by validation that generated OLM artifacts contain only production image references.

## Technical Context

**Language/Version**: Bash (Makefile, shell scripts), YAML (Kustomize, OLM manifests), Markdown (documentation)
**Primary Dependencies**:
- Kustomize v5.0.0+ (manifest customization)
- operator-sdk v1.41.0+ with go.kubebuilder.io/v4 plugin (bundle/scorecard)
- yq (YAML processing in scripts)
- Podman (container image builds)

**Storage**: File-based (git repository, local filesystem for generated artifacts)
**Testing**:
- Makefile targets (kustomize-validate, bundle-validate, catalog-validate)
- operator-sdk scorecard (6 tests for bundle quality)
- Version consistency verification script

**Target Platform**: Linux development environment, OpenShift/Kubernetes production deployment
**Project Type**: Infrastructure/Tooling (Kubernetes operator metadata repository)
**Performance Goals**: N/A (configuration changes, not runtime performance)
**Constraints**:
- Must maintain constitutional compliance (all 7 principles)
- All kustomize builds must succeed after changes
- All scorecard tests must pass
- No CRD modifications allowed
- Version consistency must be maintained

**Scale/Scope**:
- 3 primary image destinations (bundle, catalog, index)
- ~10-15 files requiring updates (Makefile, documentation, scripts)
- Multiple generated artifacts (bundle/, catalog/, downloaded/)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Constitutional Compliance Analysis

✅ **Principle I (Manifest Integrity)**: Configuration changes only - no manifest modifications. Kustomize builds will continue to work.

✅ **Principle II (Kustomize-Based Customization)**: No kustomize changes required. Image URL changes are in Makefile variables that feed into kustomize via params.env.

✅ **Principle III (CRD Immutability)**: No CRD modifications - this feature only updates URLs.

✅ **Principle IV (OpenShift Compatibility)**: No changes to OpenShift-specific patches. Image URLs are agnostic to deployment target.

✅ **Principle V (Namespace Awareness)**: No namespace changes - purely URL updates.

✅ **Principle VI (OLM Catalog Multi-Bundle Support)**: Catalog structure unchanged, only image references updated.

✅ **Principle VII (Scorecard Quality Assurance)**: All scorecard tests must continue to pass after URL changes. Image URL changes should not affect scorecard results.

**Compliance Verification Requirements** (Constitution §124-133):
1. ✅ Version consistency - script already exists, must pass after changes
2. ✅ `kustomize build config/base` - must succeed
3. ✅ `kustomize build config/default` - must succeed
4. ✅ CRD files unchanged - no CRD modifications planned
5. ✅ Patches documented - no new patches
6. ✅ Namespace placement - unchanged
7. ✅ OLM catalog valid - must remain valid with new image URLs
8. ✅ operator-sdk plugin - no operator-sdk command changes
9. ✅ Scorecard passes - all 6 tests must pass

**GATE STATUS**: ✅ **PASS** - No constitutional violations. This is a straightforward configuration update that maintains all principles.

## Project Structure

### Documentation (this feature)

```
specs/013-rehome-repos-the/
├── spec.md              # Feature specification (completed)
├── checklists/
│   └── requirements.md  # Spec quality checklist (completed)
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (not needed - no unknowns)
├── data-model.md        # Phase 1 output (not applicable - no data entities)
├── quickstart.md        # Phase 1 output (usage guide)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created yet)
```

### Source Code (repository root)

```
toolhive-operator-metadata/
├── Makefile                          # [UPDATE] Image URL variables
├── README.md                         # [UPDATE] Repository references, image examples
├── CLAUDE.md                         # [UPDATE] Repository location
├── VALIDATION.md                     # [UPDATE] Image references in examples
├── config/
│   ├── base/
│   │   └── params.env                # [UPDATE] Image base URLs
│   ├── default/
│   │   └── [no changes]
│   ├── manager/
│   │   └── manager.yaml              # [VERIFY] No hardcoded URLs (should use kustomize vars)
│   └── [other configs - no changes]
├── scripts/
│   ├── generate-csv-from-kustomize.sh # [UPDATE] Bundle image references in CSV template
│   └── verify-version-consistency.sh  # [ENHANCE] Add image base URL validation
└── [generated directories - regenerated with new URLs]
    ├── bundle/
    ├── catalog/
    └── downloaded/
```

**Structure Decision**: This is an infrastructure/tooling repository with configuration files and build scripts. No source code structure changes needed - only updates to configuration values (URLs) in existing files.

## Complexity Tracking

*No constitutional violations - this section not applicable*

## Phase 0: Research

### Research Status

**No research required** - All technical details are explicitly specified:

1. **Old repository location**: Implicit (whatever exists currently in files)
2. **New repository location**: `https://github.com/stacklok/toolhive-operator-metadata` (specified)
3. **New bundle image**: `ghcr.io/stacklok/toolhive/operator-bundle` (specified)
4. **New catalog image**: `ghcr.io/stacklok/toolhive/operator-catalog` (specified)
5. **New index image**: `ghcr.io/stacklok/toolhive/operator-index` (specified)

All unknowns are resolved. The feature is a straightforward find-and-replace operation with validation.

**Decision**: Skip research.md generation - proceed directly to Phase 1.

## Phase 1: Design & Contracts

### Design Artifacts

#### 1. Data Model (data-model.md)

**Not applicable** - This feature does not involve data entities, APIs, or state management. It is a configuration update only.

**Decision**: Skip data-model.md - no data entities to model.

#### 2. API Contracts (contracts/)

**Not applicable** - This feature does not involve API design, endpoints, or service contracts. It updates configuration files only.

**Decision**: Skip contracts/ directory - no APIs to define.

#### 3. Quickstart Guide (quickstart.md)

**Required** - Document the URL update process and validation steps for developers.

**Contents**:
- Files that require updates
- Search patterns for finding old URLs
- Validation commands to verify changes
- Build verification steps

## Phase 2: Task Planning

**Deferred to `/speckit.tasks` command** - This section will generate the detailed task breakdown with dependencies and acceptance criteria.

**Expected Task Categories**:
1. **Configuration Updates**: Makefile, params.env, scripts
2. **Documentation Updates**: README.md, CLAUDE.md, VALIDATION.md
3. **Validation Enhancement**: Update verify-version-consistency.sh
4. **Build Verification**: Run olm-all and verify artifacts
5. **Constitutional Compliance**: Run all compliance checks

## Post-Design Constitution Check

*Re-evaluate after Phase 1 artifacts are generated*

### Constitution Compliance Re-Verification

**Phase 1 Changes**: Quickstart guide created (documentation only)

✅ **All principles remain satisfied** - No manifest changes, no CRD changes, no structural changes. Only configuration values (URLs) updated.

**Compliance Status**: ✅ **PASS** - Ready for task generation phase.

## Next Steps

1. ✅ **Phase 0 Complete**: Research not required (all details specified)
2. ⏭️ **Phase 1 In Progress**: Generate quickstart.md
3. ⏸️ **Phase 2 Pending**: Run `/speckit.tasks` after Phase 1 complete

**Current Action**: Generate quickstart.md with URL update procedures and validation steps.