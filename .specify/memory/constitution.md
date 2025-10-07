<!--
  Sync Impact Report
  ==================
  Version Change: [none] → 1.0.0 (initial constitution)

  Modified Principles: N/A (initial version)

  Added Sections:
  - I. Manifest Integrity (non-negotiable)
  - II. Kustomize-Based Customization
  - III. CRD Immutability (non-negotiable)
  - IV. OpenShift Compatibility
  - V. Namespace Awareness
  - Kustomize Build Standards
  - OpenDataHub Integration Requirements
  - Governance

  Removed Sections: N/A (initial version)

  Templates Requiring Updates:
  ✅ plan-template.md - reviewed, constitution check section aligns
  ✅ spec-template.md - reviewed, no conflicts
  ✅ tasks-template.md - reviewed, no conflicts
  ✅ agent-file-template.md - reviewed, no conflicts
  ✅ checklist-template.md - reviewed, no conflicts

  Follow-up TODOs: None
-->

# Toolhive Operator Metadata Constitution

## Core Principles

### I. Manifest Integrity (NON-NEGOTIABLE)

All changes to Kubernetes/OpenShift manifests MUST preserve the ability to build valid manifests using kustomize. Before any modification is committed, `kustomize build config/base` and `kustomize build config/default` MUST execute successfully without errors.

**Rationale**: This repository serves as a metadata source for the OpenDataHub operator integration. Broken manifests prevent deployment and integration, breaking downstream consumers. The dual-build requirement ensures both the base OpenShift configuration and default Kubebuilder configuration remain valid.

### II. Kustomize-Based Customization

All manifest customization MUST be performed using kustomize overlays, patches, and replacements. Direct modification of base manifests from upstream sources is prohibited unless explicitly required for permanent divergence.

**Rationale**: Kustomize-based customization enables:
- Clear separation between upstream (Kubebuilder) and OpenShift-specific changes
- Maintainable upgrade paths when upstream releases new versions
- Transparent diff visibility showing what was changed and why
- Reusable patterns across similar deployments

### III. CRD Immutability (NON-NEGOTIABLE)

Custom Resource Definitions (CRDs) for MCPRegistry and MCPServer MUST NOT be modified in this repository. CRDs are defined and maintained in the upstream Toolhive operator source and must remain unchanged.

**Rationale**: CRDs define the API contract for the operator. Modifying them breaks compatibility with the upstream operator controller implementation and creates version skew that prevents successful operation. CRD changes must originate from the upstream Toolhive operator project.

### IV. OpenShift Compatibility

All OpenShift-specific customizations (security contexts, resource limits, environment variables) MUST be isolated in the `config/base` overlay and applied via patches. The `config/default` base MUST remain OpenShift-agnostic.

**Rationale**: This separation maintains compatibility with both standard Kubernetes deployments (via `config/default`) and OpenShift deployments (via `config/base`), enabling the operator to support multiple deployment targets without duplication.

### V. Namespace Awareness

Manifests MUST explicitly handle namespace placement. The `config/default` overlay uses the `toolhive-operator-system` namespace, while `config/base` targets `opendatahub` for OpenDataHub integration. Any new namespace-scoped resources MUST be consistent with their overlay's target namespace.

**Rationale**: Namespace mismatches cause deployment failures and access control issues. Explicit namespace handling ensures resources deploy to the correct namespaces for their intended integration contexts.

## Kustomize Build Standards

All kustomize manifests MUST:
- Use explicit file references (no wildcard includes that might capture unintended files)
- Document patches with comments explaining what is patched and why
- Use strategic merge patches for structured additions (environment variables, volumes)
- Use JSON patches for precise removals or replacements (security contexts, namespaces)
- Validate outputs using `kustomize build` before committing

ConfigMap-based variable substitution MUST:
- Centralize image references in `config/base/params.env`
- Use kustomize replacements to propagate values to both container images and environment variables
- Document variable purpose and expected format in comments

## OpenDataHub Integration Requirements

When adding manifests for OpenDataHub integration, developers MUST:
- Ensure all resources deploy to the `opendatahub` namespace
- Apply OpenShift security context constraints compatible with restricted SCC
- Remove or patch any hard-coded namespaces from upstream manifests
- Test with `kustomize build config/base` to verify OpenShift compatibility
- Document integration-specific patches in `config/base/kustomization.yaml`

## Governance

**Constitution Authority**: This constitution supersedes ad-hoc development practices. When conflicts arise between convenience and constitutional principles, principles take precedence unless explicitly amended.

**Amendment Process**: Amendments require:
1. Documented justification explaining why current principles are insufficient
2. Review confirming no alternative approach satisfies the requirement
3. Update to this constitution with version bump
4. Migration plan if existing manifests require changes

**Compliance Verification**: All pull requests MUST verify:
1. `kustomize build config/base` succeeds
2. `kustomize build config/default` succeeds
3. CRD files remain unchanged (hash/diff check)
4. New patches are documented
5. Namespace placement is correct for the overlay

**Version**: 1.0.0 | **Ratified**: 2025-10-07 | **Last Amended**: 2025-10-07
