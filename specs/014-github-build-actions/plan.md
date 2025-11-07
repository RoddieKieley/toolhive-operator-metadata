# Implementation Plan: GitHub Actions Build Workflows

**Branch**: `014-github-build-actions` | **Date**: 2025-11-06 | **Spec**: [spec.md](spec.md)

## Summary

Create three GitHub Actions workflows to automate building and publishing OLM container images (bundle, index, catalog) to GitHub Container Registry (ghcr.io) with manual trigger capability and repository-based naming. Each workflow uses the repository's own ghcr.io namespace, enabling both upstream and fork development.

**Technical Approach**: Create workflow YAML files in `.github/workflows/` that leverage existing Makefile targets, use GitHub's built-in authentication, and dynamically construct image URLs based on repository context.

## Technical Context

**Language/Version**: YAML (GitHub Actions workflow syntax v2)
**Primary Dependencies**:
- GitHub Actions (built-in platform)
- Docker/Podman (available in ubuntu-latest runners)
- Make (available in ubuntu-latest runners)
- yq v4+ (required for bundle generation)
- opm v1.35.0+ (Operator Package Manager)
- operator-sdk v1.41.0+ (for bundle validation)

**Storage**: GitHub Container Registry (ghcr.io)
**Authentication**: GitHub built-in `GITHUB_TOKEN` with `packages: write` permission
**Testing**: Manual workflow triggers via GitHub Actions web UI

**Target Platform**: GitHub Actions ubuntu-latest runners
**Project Type**: Infrastructure/CI-CD (GitHub Actions workflows)
**Performance Goals**:
- Bundle workflow: < 3 minutes
- Catalog workflow: < 4 minutes
- Index workflow: < 5 minutes (includes permissive bundle pull/create)

**Constraints**:
- Must use repository-based naming: `ghcr.io/{owner}/{repo}/{type}`
- Must support both upstream and fork repositories
- Must use existing Makefile targets (no duplicate logic)
- Must validate artifacts before pushing
- Constitutional compliance not directly applicable (no manifest changes)

**Scale/Scope**:
- 3 workflow files (bundle.yml, index.yml, catalog.yml)
- Each workflow ~80-120 lines
- Manual triggers only (no automatic git tag triggers yet)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Constitutional Compliance Analysis

✅ **Not Applicable**: GitHub Actions workflows do not modify Kubernetes manifests, CRDs, or kustomize structure. Constitutional principles apply to repository content, not CI/CD automation.

**Rationale**:
- Workflows build artifacts FROM existing manifests (no modification)
- Use existing `make bundle/catalog/index` targets
- Do not touch `config/`, `config/crd/`, or kustomize files
- Publishing to ghcr.io is external to repository content

**GATE STATUS**: ✅ **PASS** - Constitutional compliance not required for CI/CD workflows

## Project Structure

### Documentation (this feature)

```
specs/014-github-build-actions/
├── spec.md              # Feature specification (completed)
├── checklists/
│   └── requirements.md  # Spec quality checklist (completed)
├── plan.md              # This file
├── quickstart.md        # Phase 1 output (workflow usage guide)
└── tasks.md             # Phase 2 output (/speckit.tasks - NOT created yet)
```

### Source Code (repository root)

```
.github/workflows/          # [NEW DIRECTORY]
├── build-bundle.yml       # [CREATE] Bundle image build workflow
├── build-index.yml        # [CREATE] Index image build workflow (OLMv0)
└── build-catalog.yml      # [CREATE] Catalog image build workflow (OLMv1)
```

**Structure Decision**: GitHub Actions requires workflows in `.github/workflows/` directory. Each workflow is independent and manually triggered.

## Complexity Tracking

*No constitutional violations - this section not applicable*

## Phase 0: Research

### Research Status

**Minimal research required** - GitHub Actions and ghcr.io integration is well-documented:

1. **GitHub Actions workflow_dispatch**: Standard trigger type for manual workflows
2. **GITHUB_TOKEN authentication**: Built-in secret with automatic ghcr.io access
3. **Repository context variables**: `github.repository`, `github.repository_owner` provide dynamic naming
4. **Docker login action**: Standard `docker/login-action@v3` for ghcr.io
5. **Image build and push**: Standard Docker commands compatible with existing Containerfiles

**Key Decisions** (no research.md needed):
- Use `workflow_dispatch` trigger (manual only)
- Use `docker/login-action@v3` for authentication
- Use `docker/build-push-action@v5` for building and pushing
- Extract version from Makefile using shell commands
- Image names: `ghcr.io/${{ github.repository }}/{bundle|index|catalog}`

**Decision**: Skip research.md generation - all technical approaches are industry-standard patterns.

## Phase 1: Design & Contracts

### Design Artifacts

#### 1. Data Model (data-model.md)

**Not applicable** - Workflows don't involve persistent data entities. They process ephemeral build artifacts.

**Decision**: Skip data-model.md - no data to model.

#### 2. API Contracts (contracts/)

**Not applicable** - GitHub Actions workflows don't expose APIs. They consume GitHub's workflow API.

**Decision**: Skip contracts/ directory - no APIs to define.

#### 3. Quickstart Guide (quickstart.md)

**Required** - Document how to use the workflows for developers.

**Contents**:
- How to manually trigger each workflow
- Where to find published images
- How to verify successful builds
- Troubleshooting common issues

## Phase 2: Task Planning

**Deferred to `/speckit.tasks` command** - This section will generate the detailed task breakdown.

**Expected Task Categories**:
1. **Workflow Creation**: Create three `.github/workflows/` YAML files
2. **Bundle Workflow** (P1): Build and push bundle image
3. **Index Workflow** (P2): Build and push OLMv0 index image
4. **Catalog Workflow** (P3): Build and push OLMv1 catalog image
5. **Testing**: Manually trigger each workflow and verify
6. **Documentation**: Update quickstart with usage instructions

## Post-Design Constitution Check

*Re-evaluate after Phase 1 artifacts are generated*

### Constitution Compliance Re-Verification

**Phase 1 Changes**: Quickstart guide created (documentation only)

✅ **Constitutional compliance remains not applicable** - No manifest changes, no CRD changes, no kustomize modifications.

**Compliance Status**: ✅ **N/A** - CI/CD workflows outside constitutional scope

## Next Steps

1. ✅ **Phase 0 Complete**: Research not required (standard GitHub Actions patterns)
2. ⏭️ **Phase 1 In Progress**: Generate quickstart.md
3. ⏸️ **Phase 2 Pending**: Run `/speckit.tasks` after Phase 1 complete

**Current Action**: Generate quickstart.md with workflow usage instructions.