# Makefile Targets Contract

This document defines the interface contract for scorecard-related Makefile targets.

## Target: scorecard-test

**Purpose**: Run scorecard validation tests against the generated bundle

**Prerequisites**:
- Bundle must exist (`make bundle` completed)
- operator-sdk must be installed
- Kubernetes cluster must be accessible
- kubectl/oc must be configured

**Command**:
```makefile
make scorecard-test
```

**Behavior**:
1. Checks for scorecard prerequisites (operator-sdk, cluster access)
2. Executes `operator-sdk scorecard bundle/` with text output
3. Displays test results to stdout
4. Returns exit code 0 if all tests pass, 1 if any fail

**Output Format** (text):
```
Image:      quay.io/operator-framework/scorecard-test:v1.41.0
Entrypoint: [scorecard-test basic-check-spec]
Labels:
	"suite":"basic"
	"test":"basic-check-spec-test"
Results:
	Name: basic-check-spec
	State: pass

[Additional tests...]
```

**Exit Codes**:
- `0`: All tests passed
- `1`: One or more tests failed OR prerequisites missing OR cluster unreachable

**Error Handling**:
- Missing operator-sdk: Prints installation instructions, exits 1
- Cluster unreachable: Prints cluster setup instructions, exits 1
- Bundle not found: Prints "Run 'make bundle' first", exits 1
- Test failures: Prints test results, exits 1

---

## Target: scorecard-test-json

**Purpose**: Run scorecard tests with JSON output for CI/CD integration

**Prerequisites**: Same as scorecard-test

**Command**:
```makefile
make scorecard-test-json
```

**Behavior**:
1. Same as scorecard-test but with `-o json` flag
2. Outputs JSON to stdout
3. Returns exit code 0 if all tests pass, 1 if any fail

**Output Format** (JSON):
```json
{
  "apiVersion": "scorecard.operatorframework.io/v1alpha3",
  "kind": "TestList",
  "items": [
    {
      "kind": "Test",
      "apiVersion": "scorecard.operatorframework.io/v1alpha3",
      "spec": {
        "image": "quay.io/operator-framework/scorecard-test:v1.41.0",
        "entrypoint": ["scorecard-test", "basic-check-spec"],
        "labels": {
          "suite": "basic",
          "test": "basic-check-spec-test"
        }
      },
      "status": {
        "results": [
          {
            "name": "basic-check-spec",
            "state": "pass",
            "log": "..."
          }
        ]
      }
    }
  ]
}
```

---

## Target: scorecard-test-suite

**Purpose**: Run specific test suite (basic or olm)

**Prerequisites**: Same as scorecard-test

**Command**:
```makefile
make scorecard-test-suite SUITE=basic
make scorecard-test-suite SUITE=olm
```

**Parameters**:
- `SUITE`: Test suite selector (basic, olm)

**Behavior**:
1. Validates SUITE parameter is provided
2. Executes scorecard with `--selector=suite=$(SUITE)` flag
3. Returns exit code based on selected suite results

**Example Usage**:
```bash
# Run only basic suite tests
make scorecard-test-suite SUITE=basic

# Run only OLM suite tests
make scorecard-test-suite SUITE=olm
```

---

## Target: check-scorecard-deps

**Purpose**: Verify scorecard prerequisites are installed and configured

**Prerequisites**: None

**Command**:
```makefile
make check-scorecard-deps
```

**Behavior**:
1. Checks operator-sdk command exists
2. Checks kubectl/oc command exists
3. Verifies cluster connectivity (`kubectl cluster-info`)
4. Prints status for each check
5. Returns exit code 0 if all checks pass, 1 if any fail

**Output** (success):
```
Checking scorecard dependencies...
  ✓ operator-sdk found (version: v1.41.0)
  ✓ kubectl found (version: v1.31.0)
  ✓ Cluster accessible (kubernetes.default.svc.cluster.local)
✅ All scorecard dependencies present
```

**Output** (failure):
```
Checking scorecard dependencies...
  ✗ operator-sdk not found
    Install: https://sdk.operatorframework.io/docs/installation/
  ✓ kubectl found (version: v1.31.0)
  ✗ Cluster not accessible
    Setup kind: kind create cluster
    Or minikube: minikube start
❌ Missing scorecard dependencies
```

---

## Target: validate-all (updated)

**Purpose**: Run all validation checks including scorecard

**Prerequisites**: All validation tool prerequisites

**Command**:
```makefile
make validate-all
```

**Behavior**:
1. Runs constitution-check (CRD immutability, kustomize builds)
2. Runs kustomize-validate
3. Runs bundle-validate (static validation)
4. Runs bundle-validate-sdk
5. Runs catalog-validate
6. Runs scorecard-test (dynamic validation - NEW)
7. Prints summary of all validations

**Output**:
```
Running constitutional checks...
✅ Constitution compliance: PASSED

Validating kustomize builds...
✅ Kustomize validation: PASSED

Validating bundle structure...
✅ Bundle validation: PASSED

Validating catalog structure...
✅ Catalog validation: PASSED

Running scorecard tests...
✅ Scorecard tests: PASSED (6/6 tests)

=========================================
✅ All validations passed
=========================================
```

**Exit Code**:
- `0`: All validations passed
- `1`: One or more validations failed

**Behavior on Failure**:
- Stops at first failing validation
- Prints which validation failed
- Returns exit code 1

---

## Integration Contract

### Dependency Order

```
make bundle
    ↓
make check-scorecard-deps (optional, for debugging)
    ↓
make scorecard-test (or scorecard-test-json)
    ↓
make catalog (if tests pass)
    ↓
make validate-all (comprehensive validation)
```

### Parameter Passing

| Parameter | Target | Description | Example |
|-----------|--------|-------------|---------|
| `SUITE` | scorecard-test-suite | Test suite selector | `SUITE=basic` |
| None | scorecard-test | Runs all tests | - |
| None | scorecard-test-json | JSON output format | - |

### Environment Variables

| Variable | Purpose | Default | Example |
|----------|---------|---------|---------|
| `KUBECONFIG` | Specify kubeconfig path | `~/.kube/config` | `KUBECONFIG=/path/to/config` |
| `SCORECARD_NAMESPACE` | Namespace for test Pods | default | `SCORECARD_NAMESPACE=scorecard-tests` |

---

## Error Messages Contract

### Missing operator-sdk

```
❌ Error: operator-sdk not found

Scorecard requires operator-sdk to be installed.

Install operator-sdk:
  https://sdk.operatorframework.io/docs/installation/

Verify installation:
  operator-sdk version
```

### Cluster unreachable

```
❌ Error: Cannot access Kubernetes cluster

Scorecard requires a configured Kubernetes cluster.

Setup local cluster:
  kind create cluster          # Using kind
  minikube start              # Using minikube

Verify cluster access:
  kubectl cluster-info
  kubectl get nodes
```

### Bundle not found

```
❌ Error: Bundle directory not found at ./bundle

Run 'make bundle' to generate the bundle first.

Example:
  make bundle
  make scorecard-test
```

### Test failures

```
❌ Scorecard tests failed (2/6 tests failed)

Failed tests:
  - olm-spec-descriptors-test: Missing spec descriptors for CRD fields
  - olm-status-descriptors-test: Missing status descriptors for CRD fields

See test output above for details.

Troubleshooting:
  - Review ClusterServiceVersion spec/status descriptors
  - See https://olm.operatorframework.io/docs/advanced-tasks/adding-descriptors/
```

---

## Performance Contract

| Operation | Target Time | Measurement Point |
|-----------|-------------|-------------------|
| check-scorecard-deps | < 5 seconds | Command completion |
| scorecard-test (first run) | < 3 minutes | Image pull + test execution |
| scorecard-test (cached) | < 2 minutes | Test execution only |
| scorecard-test-suite SUITE=basic | < 30 seconds | Single test execution |
| scorecard-test-suite SUITE=olm | < 2 minutes | OLM suite (5 tests) execution |

---

## Success Criteria

A Makefile target implementation is considered complete when:

1. ✅ Target can be invoked via `make <target-name>`
2. ✅ Help text appears in `make help` output
3. ✅ Prerequisites are checked before execution
4. ✅ Clear error messages for all failure modes
5. ✅ Exit code correctly reflects success (0) or failure (1)
6. ✅ Output format matches this contract
7. ✅ Performance targets are met
8. ✅ Integration with validate-all works correctly

---

## Notes

- All scorecard targets are optional for users without cluster access
- Static validation (bundle-validate) should always work without cluster
- JSON output format is intended for CI/CD parsing, not human reading
- Suite-specific targets enable faster iteration during development
- Dependency check target helps debug environment setup issues
