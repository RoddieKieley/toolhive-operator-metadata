# Implementation Plan: Executable Catalog Image

**Branch**: `006-executable-catalog-image` | **Date**: 2025-10-15 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/006-executable-catalog-image/spec.md`

## Summary

Transform the current metadata-only OLMv1 File-Based Catalog container image into an executable image that runs the operator-framework registry-server when deployed to Kubernetes/OpenShift clusters. This enables the catalog to function as a running service that OLM can query for operator metadata, following the multi-stage build pattern demonstrated in the ActiveMQ Artemis operator reference implementation.

## Technical Context

**Language/Version**: Containerfile (OCI specification), GNU Make 3.81+
**Primary Dependencies**:
- operator-framework opm base image (quay.io/operator-framework/opm:latest)
- Container build tool (podman or docker)
- opm CLI tool for validation

**Storage**: File-based catalog metadata (YAML files in catalog/toolhive-operator/)
**Testing**:
- `opm validate` for catalog schema validation
- `kustomize build` for manifest integrity
- Container inspection and local execution tests
- Kubernetes/OpenShift deployment validation

**Target Platform**: Kubernetes 1.23+ / OpenShift 4.12+
**Project Type**: Container image build configuration (Containerfile modification)
**Performance Goals**:
- Catalog pod startup time < 10 seconds (SC-001)
- Registry-server query response time < 500ms (SC-002)

**Constraints**:
- Must preserve existing OLM labels and catalog metadata structure (FR-004, FR-005)
- Must use operator-framework opm tooling (no custom registry implementations)
- Must remain compatible with both podman and docker build tools
- Must not modify catalog.yaml content (constraints section)

**Scale/Scope**:
- Single Containerfile modification (Containerfile.catalog)
- Existing catalog metadata (~53 lines in catalog.yaml)
- Multi-stage build with builder and runtime stages
- Pre-caching optimization for improved startup performance

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Gate I: Manifest Integrity (NON-NEGOTIABLE)

**Status**: ✅ PASS

**Analysis**: This feature modifies only the `Containerfile.catalog` container image build configuration. It does not modify any Kubernetes/OpenShift manifest files in `config/base/` or `config/default/`. The existing kustomize builds will remain unaffected.

**Verification Plan**:
- Run `kustomize build config/base` before and after changes
- Run `kustomize build config/default` before and after changes
- Both must succeed with identical output (no manifest changes)

### Gate II: Kustomize-Based Customization

**Status**: ✅ PASS (N/A)

**Analysis**: This feature does not involve kustomize customization. The Containerfile.catalog is a container image build specification, not a Kubernetes manifest. Kustomize is not used for container image builds.

### Gate III: CRD Immutability (NON-NEGOTIABLE)

**Status**: ✅ PASS

**Analysis**: This feature does not modify CRDs. The catalog image contains references to CRDs defined in the bundle metadata but does not modify the CRD definitions themselves. CRDs remain unchanged in `config/crd/`.

**Verification Plan**:
- Hash check on all files in `config/crd/bases/` before and after
- Hashes must be identical (no CRD modifications)

### Gate IV: OpenShift Compatibility

**Status**: ✅ PASS

**Analysis**: The executable catalog image will be deployable to both Kubernetes and OpenShift clusters (FR-008). The multi-stage build uses the standard opm base image which is compatible with both platforms. No OpenShift-specific patches are needed for the catalog image itself.

**Note**: While the catalog image must be deployable to OpenShift, the image build process itself is platform-agnostic. OpenShift compatibility is achieved through the opm base image's existing OpenShift support.

### Gate V: Namespace Awareness

**Status**: ✅ PASS (N/A)

**Analysis**: This feature modifies the catalog container image build process, not Kubernetes manifests. Namespace placement for the CatalogSource resource that references this image is handled separately in cluster deployment configurations, not in this repository.

**Constitution Compliance Summary**: All applicable gates pass. This feature has no constitutional violations and requires no complexity justification.

## Project Structure

### Documentation (this feature)

```
specs/006-executable-catalog-image/
├── spec.md              # Feature specification (already created)
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (to be generated)
├── data-model.md        # Phase 1 output (to be generated)
├── quickstart.md        # Phase 1 output (to be generated)
├── contracts/           # Phase 1 output (to be generated)
│   └── containerfile-structure.md  # Multi-stage build contract
└── checklists/
    └── requirements.md  # Spec quality checklist (already created)
```

### Source Code (repository root)

```
# Existing structure - modified files marked with [MODIFIED]
/
├── Containerfile.catalog              [MODIFIED - primary change]
├── Makefile                           [POSSIBLY MODIFIED - validation targets]
├── catalog/
│   └── toolhive-operator/
│       └── catalog.yaml               [UNCHANGED - preserved as-is]
├── config/
│   ├── base/                          [UNCHANGED - no manifest changes]
│   ├── default/                       [UNCHANGED - no manifest changes]
│   └── crd/                           [UNCHANGED - CRD immutability]
└── specs/
    └── 006-executable-catalog-image/  [NEW - this feature's documentation]
```

**Structure Decision**: This is a focused feature modifying a single container image build file (Containerfile.catalog). The project follows a single-project structure with kustomize-based manifest management. The catalog image build is independent of the kustomize workflow but must preserve compatibility with the metadata structure expected by OLM.

## Phase 0: Research & Decision Log

**Objective**: Research the multi-stage build pattern from the reference implementation and resolve technical approach for integrating the registry-server into the catalog image.

### Research Tasks

1. **Multi-stage Containerfile Pattern Analysis**
   - Analyze the ActiveMQ Artemis catalog.Dockerfile reference implementation
   - Document the builder stage configuration (cache pre-population)
   - Document the runtime stage configuration (entrypoint, CMD, copied artifacts)
   - Identify differences between the reference and current Containerfile.catalog

2. **OPM Base Image Investigation**
   - Verify the opm base image (quay.io/operator-framework/opm:latest) contents
   - Confirm presence of /bin/opm binary and /bin/grpc_health_probe
   - Document the registry-server command-line interface (serve subcommand)
   - Investigate cache-dir parameter usage and pre-caching benefits

3. **Catalog Metadata Structure Validation**
   - Verify the current catalog metadata location and structure
   - Confirm compatibility with /configs directory convention
   - Validate that existing labels align with OLM expectations
   - Document the catalog directory structure (toolhive-operator subdirectory vs. flat structure)

4. **Build and Validation Workflow**
   - Document the current catalog-build Make target behavior
   - Identify validation steps needed for executable catalog images
   - Define local testing approach for registry-server functionality
   - Plan Kubernetes/OpenShift deployment validation steps

**Output**: `research.md` with findings and decisions for each research task

## Phase 1: Design Artifacts

**Prerequisites**: `research.md` complete with multi-stage build pattern documented

### Artifacts to Generate

1. **data-model.md** - Container Image Structure
   - Document the layer structure of the executable catalog image
   - Define the builder stage outputs (cache files, configs)
   - Define the runtime stage contents (binaries, configs, cache)
   - Specify file paths and permissions

2. **contracts/containerfile-structure.md** - Multi-stage Build Contract
   - Define the builder stage specification (FROM, RUN, outputs)
   - Define the runtime stage specification (FROM, COPY, ENTRYPOINT, CMD)
   - Specify label requirements (preserve existing OLM labels)
   - Document the cache pre-population contract

3. **quickstart.md** - Developer Usage Guide
   - How to build the executable catalog image
   - How to validate the image locally (container inspection, test run)
   - How to test the registry-server locally (port mapping, queries)
   - How to deploy the catalog to a Kubernetes/OpenShift cluster

### Agent Context Update

After generating design artifacts, run:
```bash
.specify/scripts/bash/update-agent-context.sh claude
```

This updates `.specify/memory/claude.md` with:
- Containerfile multi-stage build patterns
- OPM registry-server configuration
- Catalog image validation approaches
- Local testing workflows

## Phase 2: Task Generation (Not Performed by /speckit.plan)

**Note**: Task breakdown is created by the `/speckit.tasks` command, not by this planning phase. The tasks will be organized by user story priority and will include:

- Setup tasks (backup, research validation)
- Foundation tasks (Containerfile.catalog rewrite with multi-stage build)
- User Story 1 tasks (deploy and validate executable catalog in cluster)
- User Story 2 tasks (local validation workflow)
- User Story 3 tasks (backward compatibility verification)
- User Story 4 tasks (cache pre-population optimization)
- Documentation and validation tasks

## Post-Planning Constitution Re-check

**To be performed after Phase 1 design artifacts are generated**

Constitution gates will be re-verified to ensure:
- No manifest files were modified during design phase (Gate I)
- No CRDs were touched (Gate III)
- Design maintains OpenShift compatibility (Gate IV)

**Expected Result**: All gates remain PASS status. If any gate fails during design, implementation must be revised before proceeding to `/speckit.tasks`.
