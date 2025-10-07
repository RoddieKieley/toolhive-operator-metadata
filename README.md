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
- Kubernetes 1.16+ or OpenShift 4.10+

### Building Manifests

Build kustomize manifests:

```shell
# Standard Kubernetes deployment
kustomize build config/default

# OpenShift-specific deployment
kustomize build config/base
```

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

1. Deploy the CatalogSource:
   ```shell
   kubectl apply -f examples/catalogsource.yaml
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
