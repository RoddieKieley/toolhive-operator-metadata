# Research: Scorecard Testing Implementation

**Feature**: Add Scorecard Tests (010-add-scorecard-tests)
**Date**: 2025-10-21
**Purpose**: Document technical decisions and research findings for implementing Operator SDK Scorecard validation

## Overview

Scorecard is a static validation tool within the Operator SDK that executes tests against operator bundles to ensure OLM compliance and operator best practices. Unlike `operator-sdk bundle validate` which performs static checks, scorecard runs dynamic tests in Kubernetes Pods.

## Key Technical Decisions

### Decision 1: Bundle Directory vs Container Image Testing

**Decision**: Use bundle directory testing (`operator-sdk scorecard ./bundle`) as the primary approach

**Rationale**:
- Faster iteration during development (no image build required)
- Aligns with existing `make bundle` workflow
- Reduces dependencies (no container registry needed for testing)
- Bundle images are only needed for actual deployment, not validation

**Alternatives Considered**:
- Bundle container image testing: Rejected due to slower iteration (requires building and potentially pushing images before testing)
- Both approaches: Overly complex for metadata-only repository

**Implementation Impact**: Makefile target will reference local bundle directory

---

### Decision 2: Scorecard Test Image Version

**Decision**: Use `quay.io/operator-framework/scorecard-test:v1.41.0`

**Rationale**:
- Matches recent operator-sdk releases (v1.41.x series)
- Stable and widely tested in operator-framework ecosystem
- Contains all standard basic and OLM test suites
- Red Hat UBI9-based image (enterprise-friendly)

**Alternatives Considered**:
- Latest tag: Rejected due to unpredictability and potential breaking changes
- Older versions (v1.35.x): Rejected as unnecessarily outdated
- Hardcoded version in config: Selected (with documentation for version updates)

**Implementation Impact**: Configuration file will reference specific version; README will document version update process

---

### Decision 3: Test Suite Selection

**Decision**: Enable both basic and OLM test suites in default configuration

**Rationale**:
- Basic suite validates CRD spec blocks (fundamental requirement)
- OLM suite validates bundle structure, CSV descriptors, and OLM compliance
- Both are essential for successful OLM deployment
- Total test count is manageable (6 tests total)

**Tests Included**:

**Basic Suite (1 test)**:
- `basic-check-spec-test`: Validates all Custom Resources have spec blocks

**OLM Suite (5 tests)**:
- `olm-bundle-validation-test`: Validates bundle manifests format
- `olm-crds-have-validation-test`: Verifies CRD validation sections exist
- `olm-crds-have-resources-test`: Ensures CSV lists CRD resources
- `olm-spec-descriptors-test`: Verifies CR spec field descriptors in CSV
- `olm-status-descriptors-test`: Verifies CR status field descriptors in CSV

**Alternatives Considered**:
- Only basic suite: Rejected as insufficient for OLM deployment confidence
- Custom tests: Out of scope per spec (phase 1 uses only built-in tests)

**Implementation Impact**: Configuration file will define all 6 tests; Makefile will support selective execution via `--selector` flag

---

### Decision 4: Cluster Requirement Strategy

**Decision**: Document requirement for Kubernetes cluster access; provide instructions for local kind/minikube setup

**Rationale**:
- Scorecard has no "offline" mode (requires cluster for Pod execution)
- Local clusters (kind, minikube) are lightweight and sufficient for testing
- Most operator developers already have cluster access
- Documentation reduces friction for new contributors

**Alternatives Considered**:
- Mock cluster environment: Not technically feasible (scorecard uses real Kubernetes API)
- Skip scorecard in environments without clusters: Rejected as defeats purpose of validation
- CI-only execution: Rejected as prevents local validation during development

**Implementation Impact**: README will include kind/minikube setup instructions; Makefile target will check for cluster access and provide helpful error message

---

### Decision 5: Configuration File Location and Management

**Decision**: Store scorecard configuration template in `config/scorecard/` and copy to `bundle/tests/scorecard/` during bundle generation

**Rationale**:
- Aligns with existing kustomize pattern (base configs in config/, rendered output in bundle/)
- Configuration persists across `make bundle` runs
- Enables version control of configuration separate from generated bundle
- Follows operator-sdk convention for scorecard config management

**Alternatives Considered**:
- Store directly in bundle/: Rejected as bundle/ is git-ignored (generated content)
- Manual config management: Rejected as error-prone and doesn't align with existing workflow

**Implementation Impact**: Create `config/scorecard/` directory with `kustomization.yaml` and `config.yaml` template; Makefile bundle target copies to bundle during generation

---

### Decision 6: Makefile Integration Approach

**Decision**: Create dedicated `scorecard-test` target and integrate into `validate-all` target

**Rationale**:
- Follows existing pattern (bundle-validate, catalog-validate, constitution-check)
- Allows selective execution during development
- Integrates into comprehensive validation workflow
- Clear naming convention (`*-test` suffix indicates test execution)

**Target Design**:
```makefile
.PHONY: scorecard-test
scorecard-test: bundle ## Run scorecard tests against bundle
	@echo "Running scorecard tests..."
	@operator-sdk scorecard bundle/ -o text
```

**Alternatives Considered**:
- Inline in bundle target: Rejected as makes bundle generation slow and couples concerns
- Separate manual script: Rejected as inconsistent with existing Makefile-based workflow
- Always run on validate-all: Selected (part of comprehensive validation)

**Implementation Impact**: New Makefile target; documentation for usage; integration with validate-all

---

### Decision 7: Output Format Strategy

**Decision**: Use text format for interactive use; provide JSON output option for CI/CD integration

**Rationale**:
- Text format is human-readable for development
- JSON format enables programmatic parsing in CI/CD pipelines
- Both formats supported via `--output` flag
- No need for XUnit format in current workflow

**Implementation Impact**: Default target uses text; document `-o json` flag for CI use

---

### Decision 8: Test Execution Parallelization

**Decision**: Enable parallel test execution in scorecard configuration (`parallel: true`)

**Rationale**:
- Scorecard tests are independent and isolated
- Parallel execution reduces total test time (6 tests run concurrently vs sequentially)
- No shared state between basic and OLM tests
- Scorecard handles Pod lifecycle and cleanup for parallel tests

**Alternatives Considered**:
- Sequential execution: Rejected as unnecessarily slow (tests are isolated)
- Conditional parallelization: Overly complex for metadata-only testing

**Implementation Impact**: Configuration file will set `parallel: true` in stage definition

---

### Decision 9: Error Handling and Prerequisites

**Decision**: Makefile target checks for operator-sdk installation and cluster connectivity; provides actionable error messages

**Rationale**:
- Clear prerequisites reduce debugging time for contributors
- Early failure is better than cryptic scorecard errors
- Aligns with existing pattern in icon validation (check-icon-deps target)

**Prerequisite Checks**:
1. operator-sdk command exists
2. kubectl/oc command exists
3. Cluster is reachable (kubectl cluster-info)

**Implementation Impact**: Helper target `check-scorecard-deps` similar to `check-icon-deps`

---

### Decision 10: Storage Configuration

**Decision**: Use default empty mountPath storage configuration (`mountPath: {}`)

**Rationale**:
- Standard scorecard test images don't require custom storage paths
- Bundle is automatically mounted at `/bundle` by scorecard
- Empty configuration works for all built-in tests
- Custom paths only needed for custom test images (out of scope)

**Storage Configuration**:
```yaml
storage:
  spec:
    mountPath: {}
```

**Alternatives Considered**:
- Explicit /bundle path: Rejected as redundant (scorecard default)
- Omit storage field: Rejected as configuration schema expects it

**Implementation Impact**: Minimal storage config in scorecard YAML

---

## Technical Constraints

### Kubernetes Cluster Requirement

**Constraint**: Scorecard requires access to a configured Kubernetes cluster

**Impact**:
- Local development requires kind/minikube/k3s or access to remote cluster
- CI/CD pipelines must provision clusters (GitHub Actions kind, GitLab Kubernetes executor)
- Cannot run in pure offline environments

**Mitigation**: Documentation provides cluster setup instructions; Makefile checks for cluster access

---

### Network Dependency

**Constraint**: Test container images must be pulled from quay.io/operator-framework

**Impact**:
- First run requires internet access to pull images
- Air-gapped environments need image mirroring
- Network failures prevent test execution

**Mitigation**: Document image caching; provide instructions for air-gapped scenarios

---

### Test Execution Time

**Constraint**: Scorecard tests run in Kubernetes Pods, introducing overhead

**Impact**:
- Slower than pure static validation (bundle validate)
- Each test requires Pod creation, execution, and cleanup
- Parallel execution helps but still slower than static checks

**Measurement**: Target 2 minutes for complete test suite (6 tests in parallel)

**Mitigation**: Use parallel execution; run selectively during development (`--selector=suite=basic`)

---

## Integration Points

### Existing Validation Workflow

**Current Validation Targets**:
- `kustomize-validate`: Validates kustomize builds succeed
- `bundle-validate`: Validates bundle structure (operator-sdk bundle validate)
- `bundle-validate-sdk`: SDK-based bundle validation
- `catalog-validate`: Validates FBC catalog (opm validate)
- `constitution-check`: Verifies constitutional compliance
- `validate-all`: Runs all validation checks

**Scorecard Integration**:
- Adds `scorecard-test` to validation suite
- Integrates into `validate-all` as final dynamic validation step
- Complements existing static validation (bundle-validate)

**Workflow**:
```
make bundle          # Generate bundle
make bundle-validate # Static validation (fast, no cluster)
make scorecard-test  # Dynamic validation (slow, requires cluster)
make catalog         # Generate catalog
make validate-all    # Comprehensive validation (includes scorecard)
```

---

### Constitution Compliance

**Relevant Principles**:

✅ **I. Manifest Integrity**: Scorecard validates manifests but doesn't modify them
✅ **II. Kustomize-Based Customization**: Config stored in config/scorecard/, copied during bundle generation
✅ **III. CRD Immutability**: Scorecard validates CRDs but doesn't modify them
✅ **IV. OpenShift Compatibility**: Scorecard tests apply to OpenShift-specific bundle in config/base
✅ **V. Namespace Awareness**: Scorecard tests run in configurable namespace

**No Constitutional Violations**: Scorecard testing is purely validation, doesn't modify manifests or violate principles

---

## Performance Targets

Based on research and operator-framework examples:

| Metric | Target | Measurement |
|--------|--------|-------------|
| Total test execution time | < 2 minutes | Time from scorecard invocation to completion (6 tests in parallel) |
| Individual test time | < 30 seconds | Per-test execution time |
| Configuration file size | < 5 KB | YAML file size |
| Test image pull time (first run) | < 1 minute | Time to pull quay.io test image (~50 MB) |
| Test image pull time (cached) | < 1 second | Subsequent runs with cached image |

---

## Tooling Versions

| Tool | Minimum Version | Recommended | Purpose |
|------|----------------|-------------|---------|
| operator-sdk | v1.30.0+ | v1.41.0+ | Scorecard command |
| Kubernetes | v1.21+ | v1.31+ | Cluster for test execution |
| kubectl | v1.21+ | v1.31+ | Cluster access verification |
| kind | v0.20.0+ | v0.24.0+ | Local cluster (optional) |
| minikube | v1.30.0+ | v1.34.0+ | Local cluster (optional) |

**Version Alignment**: Scorecard test image version should match operator-sdk major.minor version

---

## File Paths and Locations

| File/Directory | Purpose | Version Controlled |
|----------------|---------|-------------------|
| `config/scorecard/config.yaml` | Scorecard configuration template | Yes |
| `config/scorecard/kustomization.yaml` | Kustomize integration for scorecard | Yes |
| `bundle/tests/scorecard/config.yaml` | Generated scorecard config in bundle | No (generated) |
| `bundle/metadata/annotations.yaml` | Bundle annotations (includes scorecard refs) | No (generated) |
| `Makefile` | Build and test targets | Yes |
| `README.md` | Documentation and usage instructions | Yes |

---

## Risk Mitigations

### Risk: Cluster unavailable during development

**Mitigation**:
- Document local cluster setup (kind/minikube)
- Provide cluster health check in Makefile
- Make scorecard-test optional for rapid iteration
- Static validation (bundle-validate) works without cluster

---

### Risk: Test image version incompatibility

**Mitigation**:
- Pin specific test image version in config
- Document version update process
- Test against current toolhive bundle before committing
- Include version in comments

---

### Risk: Test failures on valid bundles

**Mitigation**:
- Understand each test's validation criteria
- Document expected test results
- Provide troubleshooting guide for common failures
- Support selective test execution for debugging

---

### Risk: Network failures preventing test execution

**Mitigation**:
- Document offline/air-gapped scenarios
- Provide image caching instructions
- Graceful failure with actionable error messages
- Separate static validation from dynamic testing

---

## Reference Documentation

- [Operator SDK Scorecard](https://sdk.operatorframework.io/docs/testing-operators/scorecard/)
- [Scorecard Configuration](https://sdk.operatorframework.io/docs/testing-operators/scorecard/#config-file)
- [Scorecard Test Images](https://quay.io/repository/operator-framework/scorecard-test)
- [OLM Bundle Validation](https://olm.operatorframework.io/docs/tasks/creating-operator-bundle/)
- [operator-framework/api](https://github.com/operator-framework/api/blob/master/pkg/validation/validation.go)

---

## Conclusion

All technical unknowns have been resolved through research of official Operator SDK documentation and operator-framework source code. The implementation approach uses:

- **Standard scorecard configuration**: v1alpha3 API with basic and OLM test suites
- **Established test images**: quay.io/operator-framework/scorecard-test:v1.41.0
- **Makefile integration**: Follows existing validation target patterns
- **Kustomize workflow**: Config template in config/scorecard/, rendered to bundle/
- **Local cluster support**: kind/minikube for development, any cluster for CI/CD

No [NEEDS CLARIFICATION] markers remain. Ready to proceed to Phase 1 (Design & Contracts).
