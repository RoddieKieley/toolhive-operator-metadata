# Implementation Plan: Fix Security Context for OpenShift Compatibility

**Branch**: `008-fix-security-context` | **Date**: 2025-10-16 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/008-fix-security-context/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Fix security context configuration in ToolHive Operator manifests to comply with OpenShift restricted-v2 security policy. The operator pod currently fails to start due to hardcoded `runAsUser: 1000` which violates OpenShift security constraints. Solution involves removing hardcoded user ID and ensuring proper pod/container security context settings that allow OpenShift to dynamically assign UIDs while maintaining security compliance.

## Technical Context

**Language/Version**: YAML manifests (Kubernetes 1.24+, OpenShift 4.12+)
**Primary Dependencies**: Kustomize 5.0+, OLM (Operator Lifecycle Manager)
**Storage**: N/A (manifest metadata repository)
**Testing**: Kustomize build validation, OpenShift deployment testing
**Target Platform**: OpenShift 4.12+ (Kubernetes with restricted-v2 security policy)
**Project Type**: Kubernetes manifest repository with kustomize overlays
**Performance Goals**: Pod startup within 60 seconds
**Constraints**: OpenShift restricted-v2 security policy compliance, no hardcoded UIDs, read-only root filesystem support
**Scale/Scope**: Single operator deployment per namespace, ~10 manifest files affected

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Pre-Design Check (Before Phase 0)

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Manifest Integrity | ✅ PASS | Changes will be validated with `kustomize build config/base` and `kustomize build config/default` |
| II. Kustomize-Based Customization | ✅ PASS | Security context fixes will use JSON patches in `config/base/openshift_sec_patches.yaml` |
| III. CRD Immutability | ✅ PASS | No CRD modifications required - only deployment manifest changes |
| IV. OpenShift Compatibility | ✅ PASS | Changes isolated to `config/base` overlay, `config/default` remains agnostic |
| V. Namespace Awareness | ✅ PASS | No namespace changes required |
| VI. OLM Catalog Multi-Bundle | ✅ PASS | Catalog rebuild will maintain multi-bundle structure |

**Result**: All constitutional principles satisfied. Proceed to Phase 0.

### Post-Design Check (After Phase 1)

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Manifest Integrity | ✅ PASS | Validation commands defined in contracts/ and quickstart.md confirm both builds succeed |
| II. Kustomize-Based Customization | ✅ PASS | Design uses JSON patches in openshift_sec_patches.yaml per research.md findings |
| III. CRD Immutability | ✅ PASS | No CRD changes in design - only Deployment manifest patches |
| IV. OpenShift Compatibility | ✅ PASS | All changes isolated to config/base per data-model.md and contracts/ |
| V. Namespace Awareness | ✅ PASS | No namespace changes in design |
| VI. OLM Catalog Multi-Bundle | ✅ PASS | Quickstart.md includes catalog rebuild without structural changes |

**Result**: All constitutional principles satisfied. Design is compliant. Proceed to Phase 2 (/speckit.tasks).

## Project Structure

### Documentation (this feature)

```
specs/[###-feature]/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```
config/
├── base/                           # OpenShift overlay (PRIMARY MODIFICATION TARGET)
│   ├── kustomization.yaml          # Includes openshift_sec_patches.yaml
│   ├── openshift_sec_patches.yaml  # JSON patches for security context (TO BE MODIFIED)
│   ├── openshift_env_var_patch.yaml
│   ├── openshift_res_utilization.yaml
│   ├── params.env
│   └── remove-namespace.yaml
├── default/                        # Base Kubebuilder configuration
│   └── kustomization.yaml
├── manager/                        # Manager deployment (REFERENCED BY PATCHES)
│   └── manager.yaml                # Current manifest with runAsUser: 1000
├── crd/                            # CRDs (NO CHANGES)
├── rbac/                           # RBAC resources (NO CHANGES)
├── prometheus/                     # Metrics (NO CHANGES)
└── network-policy/                 # Network policies (NO CHANGES)

catalogs/                           # OLM catalog (REBUILD AFTER FIX)
└── toolhive-catalog/
    └── index.yaml                  # File-based catalog definition
```

**Structure Decision**: This is a manifest-only repository using kustomize overlays. All security context fixes will be implemented as JSON patches in `config/base/openshift_sec_patches.yaml` following Constitution Principle II (Kustomize-Based Customization). No source code changes required - only manifest patches.

## Complexity Tracking

*No constitutional violations. This section is not applicable.*
