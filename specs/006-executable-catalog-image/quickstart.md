# Quickstart: Executable Catalog Image

**Feature**: 006-executable-catalog-image
**Audience**: Developers building and testing the Toolhive operator catalog
**Date**: 2025-10-15

---

## Overview

This quickstart guide shows how to build, validate, and test the executable OLMv1 File-Based Catalog image that runs the operator-framework registry-server when deployed to Kubernetes/OpenShift clusters.

---

## Prerequisites

**Required Tools**:
- Container build tool: `podman` or `docker`
- OLM tooling: `opm` CLI (for validation)
- gRPC testing: `grpcurl` (for API queries)
- Health checking: `grpc_health_probe` (for health validation)

**Verification**:
```bash
# Check tool versions
podman --version   # or docker --version
opm version
grpcurl --version
grpc_health_probe --version
```

**Optional for Cluster Testing**:
- Kubernetes/OpenShift cluster with OLM installed
- `kubectl` or `oc` CLI configured
- Container registry access (e.g., quay.io, ghcr.io)

---

## Quick Start: Build and Test Locally

### Step 1: Build the Catalog Image

```bash
# Navigate to repository root
cd /wip/src/github.com/RHEcosystemAppEng/toolhive-operator-metadata

# Build the executable catalog image
make catalog-build

# Or manually:
podman build -f Containerfile.catalog \
  -t ghcr.io/stacklok/toolhive/catalog:v0.2.17 .
```

**Expected Output**:
```
STEP 1/8: FROM quay.io/operator-framework/opm:latest AS builder
STEP 2/8: ADD catalog /configs
STEP 3/8: RUN ["/bin/opm", "serve", "/configs", "--cache-dir=/tmp/cache", "--cache-only"]
...cache generation logs...
STEP 4/8: FROM quay.io/operator-framework/opm:latest
STEP 5/8: COPY --from=builder /configs /configs
STEP 6/8: COPY --from=builder /tmp/cache /tmp/cache
STEP 7/8: LABEL operators.operatorframework.io.index.configs.v1=/configs
STEP 8/8: ENTRYPOINT ["/bin/opm"]
Successfully tagged ghcr.io/stacklok/toolhive/catalog:v0.2.17
```

### Step 2: Validate the Image

```bash
# Validate catalog structure with opm
opm validate ghcr.io/stacklok/toolhive/catalog:v0.2.17

# Inspect image contents
podman run --rm ghcr.io/stacklok/toolhive/catalog:v0.2.17 \
  ls -R /configs

# Expected: /configs/toolhive-operator/catalog.yaml

# Verify cache exists
podman run --rm ghcr.io/stacklok/toolhive/catalog:v0.2.17 \
  ls -la /tmp/cache

# Expected: Cache files from builder stage
```

### Step 3: Test Registry Server Locally

```bash
# Start the catalog server
podman run -d -p 50051:50051 \
  --name toolhive-catalog-test \
  ghcr.io/stacklok/toolhive/catalog:v0.2.17

# Check server logs
podman logs -f toolhive-catalog-test

# Expected: "serving registry" or similar ready message

# Test health check
grpc_health_probe -addr localhost:50051

# Expected output:
# status: SERVING

# Query available packages
grpcurl -plaintext localhost:50051 api.Registry/ListPackages

# Expected JSON response with toolhive-operator package

# Get package details
grpcurl -plaintext -d '{"name":"toolhive-operator"}' \
  localhost:50051 api.Registry/GetPackage

# Expected: Package metadata with fast channel and v0.2.17 bundle

# Cleanup
podman stop toolhive-catalog-test
podman rm toolhive-catalog-test
```

---

## Detailed Workflows

### Workflow 1: Development Iteration

**Use Case**: Making changes to catalog metadata and rebuilding

```bash
# 1. Edit catalog metadata
vi catalog/toolhive-operator/catalog.yaml

# 2. Validate changes before building
opm validate catalog/

# 3. Rebuild image (fast with layer caching)
make catalog-build

# 4. Test locally
podman run -d -p 50051:50051 --name test \
  ghcr.io/stacklok/toolhive/catalog:v0.2.17

# 5. Verify changes
grpcurl -plaintext localhost:50051 api.Registry/ListPackages

# 6. Cleanup
podman stop test && podman rm test
```

### Workflow 2: Custom Image Naming

**Use Case**: Building catalog image to personal registry for testing

```bash
# Build with custom registry and organization
make catalog-build \
  CATALOG_REGISTRY=quay.io \
  CATALOG_ORG=myuser \
  CATALOG_TAG=test

# Result: quay.io/myuser/catalog:test

# Test the custom-named image
podman run -d -p 50051:50051 --name test quay.io/myuser/catalog:test
grpcurl -plaintext localhost:50051 api.Registry/ListPackages
podman stop test && podman rm test

# Push to personal registry
make catalog-push \
  CATALOG_REGISTRY=quay.io \
  CATALOG_ORG=myuser \
  CATALOG_TAG=test
```

### Workflow 3: Deploy to OpenShift Cluster

**Use Case**: Testing executable catalog in live OpenShift cluster

```bash
# 1. Push catalog image to accessible registry
podman push ghcr.io/stacklok/toolhive/catalog:v0.2.17

# Or use custom registry
podman push quay.io/myuser/toolhive-catalog:test

# 2. Create CatalogSource resource
cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: toolhive-catalog
  namespace: openshift-marketplace
spec:
  sourceType: grpc
  image: ghcr.io/stacklok/toolhive/catalog:v0.2.17
  displayName: Toolhive Operator Catalog
  publisher: Stacklok
  updateStrategy:
    registryPoll:
      interval: 10m
EOF

# 3. Wait for catalog pod to start
oc get pods -n openshift-marketplace -w | grep toolhive-catalog

# Expected: Pod reaches Running state within 10 seconds

# 4. Check catalog pod logs
oc logs -n openshift-marketplace \
  $(oc get pods -n openshift-marketplace -l olm.catalogSource=toolhive-catalog -o name)

# Expected: "serving registry" message, no errors

# 5. Verify PackageManifest creation
oc get packagemanifest toolhive-operator -o yaml

# Expected: Package with fast channel, v0.2.17 bundle

# 6. Check OperatorHub UI
# Navigate to OperatorHub in OpenShift console
# Search for "Toolhive"
# Expected: Toolhive Operator appears in catalog

# 7. Cleanup (when done testing)
oc delete catalogsource toolhive-catalog -n openshift-marketplace
```

### Workflow 4: Debugging Failed Builds

**Use Case**: Troubleshooting catalog build issues

```bash
# 1. Validate catalog metadata first
opm validate catalog/

# If validation fails, fix YAML syntax errors

# 2. Build with verbose output
podman build -f Containerfile.catalog \
  -t test:debug \
  --no-cache .  # Force rebuild without layer cache

# 3. Inspect builder stage output
# Look for "cache only mode, exiting after cache generation"
# Check for validation errors in builder RUN step

# 4. Manually test cache generation
podman run --rm -v $(pwd)/catalog:/catalog:ro \
  quay.io/operator-framework/opm:latest \
  validate /catalog

# 5. If build succeeds but runtime fails, inspect image
podman run --rm -it test:debug /bin/sh
# Inside container:
ls -R /configs
ls -la /tmp/cache
/bin/opm serve /configs --cache-dir=/tmp/cache --debug
```

---

## Common Tasks

### Inspect Image Labels

```bash
podman inspect ghcr.io/stacklok/toolhive/catalog:v0.2.17 | \
  jq -r '.[0].Config.Labels'

# Verify all 7 labels are present:
# - operators.operatorframework.io.index.configs.v1
# - org.opencontainers.image.title
# - org.opencontainers.image.description
# - org.opencontainers.image.vendor
# - org.opencontainers.image.source
# - org.opencontainers.image.version
# - org.opencontainers.image.licenses
```

### Check Image Size

```bash
podman images | grep catalog

# Expected size: ~60-100MB (executable catalog with cache)
# Compare to previous: ~1MB (metadata-only image)
```

### Verify Entrypoint and Command

```bash
podman inspect ghcr.io/stacklok/toolhive/catalog:v0.2.17 | \
  jq -r '.[0].Config.Entrypoint, .[0].Config.Cmd'

# Expected output:
# ["/bin/opm"]
# ["serve", "/configs", "--cache-dir=/tmp/cache"]
```

### Test gRPC API Endpoints

```bash
# Start catalog server
podman run -d -p 50051:50051 --name test \
  ghcr.io/stacklok/toolhive/catalog:v0.2.17

# List all gRPC services
grpcurl -plaintext localhost:50051 list

# Expected services:
# - api.Registry
# - grpc.health.v1.Health

# List packages
grpcurl -plaintext localhost:50051 api.Registry/ListPackages

# Get specific package
grpcurl -plaintext -d '{"name":"toolhive-operator"}' \
  localhost:50051 api.Registry/GetPackage

# Get bundle for channel
grpcurl -plaintext -d '{"pkgName":"toolhive-operator","channelName":"fast"}' \
  localhost:50051 api.Registry/GetBundleForChannel

# Cleanup
podman stop test && podman rm test
```

---

## Troubleshooting

### Issue: Build fails with "cache generation error"

**Symptoms**: Builder stage RUN step exits with non-zero code

**Diagnosis**:
```bash
# Validate catalog manually
opm validate catalog/

# Check for YAML syntax errors
yamllint catalog/toolhive-operator/catalog.yaml
```

**Solution**: Fix validation errors in catalog.yaml, ensure all required fields are present

---

### Issue: Container starts but health probe fails

**Symptoms**: Pod stays in CrashLoopBackOff, health check returns error

**Diagnosis**:
```bash
# Check container logs
podman logs toolhive-catalog-test

# Test health probe manually
grpc_health_probe -addr localhost:50051
```

**Possible Causes**:
- Cache corruption: Rebuild image without layer cache (`--no-cache`)
- Port conflict: Check if port 50051 is already in use
- Cache missing: Verify COPY --from=builder steps succeeded

**Solution**: Rebuild image, verify cache exists in /tmp/cache

---

### Issue: OLM doesn't discover operator

**Symptoms**: PackageManifest not created, operator not in OperatorHub

**Diagnosis**:
```bash
# Check catalog pod status
oc get pods -n openshift-marketplace | grep toolhive-catalog

# Check catalog pod logs
oc logs -n openshift-marketplace <catalog-pod-name>

# Verify label is correct
oc get catalogsource toolhive-catalog -n openshift-marketplace -o yaml
```

**Possible Causes**:
- Label missing or incorrect: Verify `operators.operatorframework.io.index.configs.v1=/configs`
- Image pull failure: Check registry access and image name
- Registry-server not starting: Check pod logs for errors

**Solution**: Verify label, ensure image is accessible, check pod logs for startup errors

---

### Issue: Slow startup time

**Symptoms**: Pod takes >10 seconds to become ready

**Diagnosis**:
```bash
# Check if cache is being used
podman run --rm ghcr.io/stacklok/toolhive/catalog:v0.2.17 \
  ls -la /tmp/cache

# Check startup logs
podman run -d -p 50051:50051 --name test \
  ghcr.io/stacklok/toolhive/catalog:v0.2.17
podman logs -f test
```

**Possible Causes**:
- Cache not pre-built: Builder stage didn't generate cache
- Cache integrity check failing: Falling back to runtime parsing

**Solution**: Ensure builder RUN step completes successfully, verify cache files exist in image

---

## Performance Benchmarking

### Measure Startup Time

```bash
# Test with cache (executable catalog)
time podman run --rm -p 50051:50051 \
  ghcr.io/stacklok/toolhive/catalog:v0.2.17 &
sleep 2
grpc_health_probe -addr localhost:50051
# Expected: ~1-3 seconds to SERVING status

# Kill background process
killall opm
```

### Measure Query Response Time

```bash
# Start server
podman run -d -p 50051:50051 --name test \
  ghcr.io/stacklok/toolhive/catalog:v0.2.17

# Benchmark ListPackages query
time grpcurl -plaintext localhost:50051 api.Registry/ListPackages

# Expected: <500ms response time

# Cleanup
podman stop test && podman rm test
```

---

## Next Steps

After successfully building and testing the executable catalog:

1. **Push to Production Registry**: `make catalog-push` with production credentials
2. **Update CatalogSource**: Deploy CatalogSource to production OpenShift cluster
3. **Monitor Health**: Set up alerts for catalog pod health and availability
4. **Version Management**: Tag images with semantic versions matching operator releases
5. **Automation**: Integrate catalog-build into CI/CD pipeline

---

## Reference Commands

```bash
# Build
make catalog-build

# Validate
opm validate catalog/
opm validate <image-reference>

# Test Locally
podman run -d -p 50051:50051 --name test <image-reference>
grpc_health_probe -addr localhost:50051
grpcurl -plaintext localhost:50051 api.Registry/ListPackages

# Push
make catalog-push

# Deploy to Cluster
oc apply -f catalogsource.yaml
oc get catalogsource -n openshift-marketplace
oc get packagemanifest toolhive-operator

# Cleanup
podman stop test && podman rm test
oc delete catalogsource <name> -n openshift-marketplace
```

---

## Additional Resources

- [OLM File-Based Catalogs Documentation](https://olm.operatorframework.io/docs/tasks/creating-a-catalog/)
- [OPM CLI Reference](https://github.com/operator-framework/operator-registry)
- [gRPC Health Checking Protocol](https://github.com/grpc/grpc/blob/master/doc/health-checking.md)
- [Containerfile.catalog Source](../../Containerfile.catalog)
- [Feature Specification](spec.md)
- [Implementation Plan](plan.md)
