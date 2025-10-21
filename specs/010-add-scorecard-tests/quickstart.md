# Quick Start: Scorecard Testing

**Feature**: Add Scorecard Tests (010-add-scorecard-tests)
**Estimated time to first validation**: 15 minutes

## Prerequisites

Before you begin, ensure you have:

- ✅ operator-sdk CLI installed (v1.30.0+)
- ✅ kubectl or oc CLI installed
- ✅ Access to a Kubernetes cluster (kind, minikube, or remote)
- ✅ This repository cloned and bundle generated

## 5-Minute Setup

### Step 1: Install operator-sdk

**Linux/macOS**:
```bash
# Set version and architecture
export ARCH=$(case $(uname -m) in x86_64) echo -n amd64 ;; aarch64) echo -n arm64 ;; *) echo -n $(uname -m) ;; esac)
export OS=$(uname | awk '{print tolower($0)}')
export OPERATOR_SDK_VERSION=v1.41.0

# Download and install
curl -LO "https://github.com/operator-framework/operator-sdk/releases/download/${OPERATOR_SDK_VERSION}/operator-sdk_${OS}_${ARCH}"
chmod +x operator-sdk_${OS}_${ARCH}
sudo mv operator-sdk_${OS}_${ARCH} /usr/local/bin/operator-sdk

# Verify
operator-sdk version
```

**Alternative (Homebrew on macOS)**:
```bash
brew install operator-sdk
```

### Step 2: Setup Local Cluster (if needed)

**Option A: kind (Kubernetes in Docker)**:
```bash
# Install kind
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.24.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# Create cluster
kind create cluster --name scorecard-test

# Verify
kubectl cluster-info
```

**Option B: minikube**:
```bash
# Install minikube
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube

# Start cluster
minikube start

# Verify
kubectl cluster-info
```

### Step 3: Generate Bundle (if not already done)

```bash
cd toolhive-operator-metadata/
make bundle
```

Expected output:
```
Generating OLM bundle from downloaded operator files...
✅ Bundle generated successfully
```

### Step 4: Run Scorecard Tests

```bash
make scorecard-test
```

Expected output (first run may take 1-2 minutes to pull images):
```
Checking scorecard dependencies...
  ✓ operator-sdk found (version: v1.41.0)
  ✓ kubectl found
  ✓ Cluster accessible
Running scorecard tests...

Image:      quay.io/operator-framework/scorecard-test:v1.41.0
Entrypoint: [scorecard-test basic-check-spec]
Labels:
	"suite":"basic"
	"test":"basic-check-spec-test"
Results:
	Name: basic-check-spec
	State: pass

[... 5 more tests ...]

✅ All scorecard tests passed (6/6)
```

**Success!** You've run your first scorecard validation.

---

## Common Tasks

### Run Only Basic Tests

For faster iteration during development:

```bash
make scorecard-test-suite SUITE=basic
```

Expected execution time: ~30 seconds

### Run Only OLM Tests

```bash
make scorecard-test-suite SUITE=olm
```

Expected execution time: ~90 seconds

### Get JSON Output (for CI/CD)

```bash
make scorecard-test-json > scorecard-results.json
```

### Check Prerequisites

If scorecard fails, verify your environment:

```bash
make check-scorecard-deps
```

Expected output:
```
Checking scorecard dependencies...
  ✓ operator-sdk found (version: v1.41.0)
  ✓ kubectl found (version: v1.31.0)
  ✓ Cluster accessible (kubernetes.default.svc.cluster.local)
✅ All scorecard dependencies present
```

### Run All Validations

For comprehensive validation before committing:

```bash
make validate-all
```

This runs:
1. Constitution checks (CRD immutability, kustomize builds)
2. Bundle validation (static)
3. Catalog validation
4. Scorecard tests (dynamic)

---

## Troubleshooting

### Error: "operator-sdk not found"

**Solution**: Install operator-sdk (see Step 1 above)

**Verify**:
```bash
operator-sdk version
```

---

### Error: "Cannot access Kubernetes cluster"

**Solution**: Setup a local cluster (see Step 2 above)

**Verify**:
```bash
kubectl cluster-info
kubectl get nodes
```

**Check kubeconfig**:
```bash
echo $KUBECONFIG
kubectl config get-contexts
kubectl config use-context <your-context>
```

---

### Error: "Bundle directory not found"

**Solution**: Generate the bundle first

```bash
make bundle
```

---

### Error: "Test failed: olm-spec-descriptors-test"

**Meaning**: ClusterServiceVersion (CSV) is missing spec field descriptors

**Solution**: Check CSV for missing descriptors

```bash
# View CSV
cat bundle/manifests/toolhive-operator.clusterserviceversion.yaml

# Look for spec descriptors section
yq eval '.spec.customresourcedefinitions.owned[].specDescriptors' \
  bundle/manifests/toolhive-operator.clusterserviceversion.yaml
```

**Documentation**: [Adding Descriptors](https://olm.operatorframework.io/docs/advanced-tasks/adding-descriptors/)

---

### Error: "Image pull failed"

**Cause**: Network issue or registry unavailable

**Solution 1**: Retry (images may be temporarily unavailable)
```bash
make scorecard-test
```

**Solution 2**: Check network connectivity
```bash
curl -I https://quay.io/operator-framework/scorecard-test:v1.41.0
```

**Solution 3**: Pre-pull image
```bash
# For kind
docker pull quay.io/operator-framework/scorecard-test:v1.41.0
kind load docker-image quay.io/operator-framework/scorecard-test:v1.41.0 --name scorecard-test

# For minikube
minikube image load quay.io/operator-framework/scorecard-test:v1.41.0
```

---

### Slow Test Execution

**Cause**: First run pulls images (~50 MB)

**Solution**: Subsequent runs use cached images and complete in ~2 minutes

**Speed up development**:
```bash
# Run only the test you're fixing
make scorecard-test-suite SUITE=basic
```

---

## Integration with Development Workflow

### Typical Development Cycle

```bash
# 1. Make changes to operator metadata
vim config/base/openshift_sec_patches.yaml

# 2. Regenerate bundle
make bundle

# 3. Quick validation (no cluster needed)
make bundle-validate

# 4. Full validation (requires cluster)
make scorecard-test

# 5. If all tests pass, build catalog
make catalog

# 6. Comprehensive validation before committing
make validate-all
```

### Pre-Commit Checklist

Before committing changes:

- [ ] `make bundle` completes successfully
- [ ] `make bundle-validate` passes (static validation)
- [ ] `make scorecard-test` passes (dynamic validation)
- [ ] `make validate-all` passes (comprehensive validation)
- [ ] Test results documented in commit message (if failures fixed)

---

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Validate Operator Bundle

on: [push, pull_request]

jobs:
  scorecard:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Install operator-sdk
        run: |
          ARCH=amd64
          OS=linux
          VERSION=v1.41.0
          curl -LO "https://github.com/operator-framework/operator-sdk/releases/download/${VERSION}/operator-sdk_${OS}_${ARCH}"
          chmod +x operator-sdk_${OS}_${ARCH}
          sudo mv operator-sdk_${OS}_${ARCH} /usr/local/bin/operator-sdk

      - name: Setup kind
        uses: helm/kind-action@v1.5.0
        with:
          cluster_name: scorecard

      - name: Generate bundle
        run: make bundle

      - name: Run scorecard tests
        run: make scorecard-test-json > scorecard-results.json

      - name: Upload results
        if: always()
        uses: actions/upload-artifact@v3
        with:
          name: scorecard-results
          path: scorecard-results.json
```

---

## Next Steps

After successfully running scorecard tests:

1. **Fix any test failures**: Review test output for specific issues
2. **Understand test requirements**: See [OLM Documentation](https://olm.operatorframework.io/)
3. **Customize configuration**: Modify `config/scorecard/config.yaml` if needed
4. **Integrate into CI**: Add scorecard to your CI/CD pipeline
5. **Document results**: Update VALIDATION.md with test status

---

## Learning Resources

- [Operator SDK Scorecard Docs](https://sdk.operatorframework.io/docs/testing-operators/scorecard/)
- [OLM Bundle Spec](https://olm.operatorframework.io/docs/tasks/creating-operator-bundle/)
- [Writing Custom Scorecard Tests](https://sdk.operatorframework.io/docs/testing-operators/scorecard/custom-tests/)
- [CSV Descriptors Guide](https://olm.operatorframework.io/docs/advanced-tasks/adding-descriptors/)

---

## Summary

You've learned how to:

✅ Install operator-sdk and setup a test cluster
✅ Run scorecard validation tests
✅ Troubleshoot common issues
✅ Integrate scorecard into development workflow
✅ Prepare for CI/CD integration

**Time invested**: 15 minutes
**Value gained**: Automated bundle validation catching errors before deployment

For detailed implementation plans, see:
- [plan.md](plan.md) - Technical implementation plan
- [data-model.md](data-model.md) - Data structures and validation rules
- [contracts/](contracts/) - API contracts and schemas
