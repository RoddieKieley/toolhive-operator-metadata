# Toolhive Operator Metadata

Kubernetes/OpenShift manifest metadata and OLM bundle for the [Toolhive Operator](https://github.com/stacklok/toolhive), which manages MCP (Model Context Protocol) servers and registries.

## Overview

This repository contains:
- **Kustomize manifests** for deploying the Toolhive Operator
- **OLMv1 File-Based Catalog (FBC)** for operator distribution via Operator Lifecycle Manager
- **Bundle metadata** following Operator Framework standards

## Quick Start

### Prerequisites

- `kustomize` (v5.0.0+)
- `podman` or `docker`
- `opm` (Operator Package Manager) - for catalog operations
- Kubernetes 1.24+ or OpenShift 4.12+

**OpenShift Compatibility**: The operator is fully compatible with OpenShift's `restricted-v2` Security Context Constraint (SCC). The manifests in `config/base/` are specifically configured to run under OpenShift's restrictive security policies without requiring custom SCCs or elevated privileges.

### Building Manifests

Build kustomize manifests:

```shell
# Standard Kubernetes deployment
kustomize build config/default

# OpenShift-specific deployment (includes security context patches)
kustomize build config/base
```

**Security Context Configuration**: The OpenShift deployment (`config/base`) applies JSON patches to ensure compliance with the `restricted-v2` SCC:
- Removes hardcoded `runAsUser` to allow dynamic UID assignment
- Adds `seccompProfile: RuntimeDefault` for container sandboxing
- Maintains `runAsNonRoot`, `allowPrivilegeEscalation: false`, and `readOnlyRootFilesystem: true`

See `config/base/openshift_sec_patches.yaml` for details.

### Building OLM Catalog

Build the File-Based Catalog container image:

```shell
# Using Makefile (recommended)
make olm-all

# Or manually
opm validate catalog/
podman build -f Containerfile.catalog -t ghcr.io/stacklok/toolhive/catalog:v0.2.17 .
```

### Installing via OLM

#### Modern OpenShift (4.19+) - Recommended

1. Deploy the CatalogSource:
   ```shell
   kubectl apply -f examples/catalogsource-olmv1.yaml
   ```

2. Install the operator:
   ```shell
   kubectl create namespace toolhive-system
   kubectl apply -f examples/subscription.yaml
   ```

3. Verify installation:
   ```shell
   kubectl get csv -n toolhive-system
   kubectl get pods -n toolhive-system
   ```

#### Legacy OpenShift (4.15-4.18)

For older OpenShift versions, use the OLMv0 index image:

1. Build the OLMv0 index image:
   ```shell
   make index-olmv0-build
   ```

2. Deploy the CatalogSource:
   ```shell
   kubectl apply -f examples/catalogsource-olmv0.yaml
   ```

3. Install the operator (same as modern OpenShift)

**Note**: OLMv0 support is temporary for legacy versions and will be sunset when OpenShift 4.18 reaches end-of-life.

## Repository Structure

```
.
├── bundle/                 # OLM bundle (CSV, CRDs, metadata)
├── catalog/                # OLMv1 File-Based Catalog metadata
├── config/                 # Kustomize manifests
│   ├── base/              # OpenShift overlay
│   ├── default/           # Standard Kubernetes config
│   ├── crd/               # Custom Resource Definitions
│   ├── manager/           # Operator deployment
│   └── rbac/              # RBAC manifests
├── examples/              # Example deployment manifests
├── Containerfile.catalog  # Catalog image build file
├── Makefile              # Build and validation targets
└── VALIDATION.md         # Validation status and compliance report
```

## Makefile Targets

```shell
make help                   # Show all available targets
make kustomize-validate     # Validate kustomize builds
make bundle-validate        # Validate OLM bundle
make catalog-validate       # Validate FBC catalog
make catalog-build          # Build catalog container image
make catalog-push           # Push catalog image to registry
make olm-all               # Complete OLM workflow
make constitution-check     # Verify constitution compliance
make validate-all          # Run all validations
```

## Development

### Constitution Compliance

This repository follows strict constitutional principles:

1. **Manifest Integrity**: All kustomize builds must pass
2. **Kustomize-Based Customization**: Use overlays, not direct modifications
3. **CRD Immutability**: CRDs are never modified here (upstream only)
4. **OpenShift Compatibility**: Maintained via config/base overlay
5. **Namespace Awareness**: Explicit namespace handling

Verify compliance:
```shell
make constitution-check
```

### Adding New Operator Versions

1. Update bundle CSV version in `bundle/manifests/toolhive-operator.clusterserviceversion.yaml`
2. Update catalog metadata in `catalog/toolhive-operator/catalog.yaml`
3. Add new bundle entry to the channel
4. Validate and build:
   ```shell
   make olm-all
   ```

## Validation

All validation results are documented in [VALIDATION.md](VALIDATION.md).

Current status: ✅ All validations passing

- FBC Schema: ✅ opm validate passed
- Bundle Structure: ✅ Complete and correct
- Constitution Compliance: ✅ All principles satisfied
- Catalog Image: ✅ Built successfully (7.88 KB)

## Custom Resources

The operator manages two primary CRDs:

- **MCPRegistry** (`mcpregistries.toolhive.stacklok.dev`) - Manages registries of MCP server definitions
- **MCPServer** (`mcpservers.toolhive.stacklok.dev`) - Manages individual MCP server instances

## License

TBD
