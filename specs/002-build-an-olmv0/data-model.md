# Data Model: OLMv0 Bundle Container Image Build System

**Feature**: OLMv0 Bundle Container Image Build System
**Branch**: `002-build-an-olmv0`
**Date**: 2025-10-09

## Overview

This feature is a build system, not a data-driven application. However, it operates on structured data entities defined by the OLM specification. This document catalogs the key entities involved in bundle image construction and their relationships.

## Key Entities

### 1. Bundle Container Image

**Description**: A container image containing operator manifests and metadata compliant with the OLM bundle format specification (registry+v1).

**Attributes**:
- **Image Reference** (string): Full container image name (e.g., `ghcr.io/stacklok/toolhive/bundle:v0.2.17`)
- **Base Image** (string): Container base layer (`scratch`)
- **Filesystem Paths**:
  - `/manifests/`: Directory containing CSV and CRD YAML files
  - `/metadata/`: Directory containing annotations.yaml
- **Labels** (key-value map): Container image labels for OLM discovery
  - `operators.operatorframework.io.bundle.mediatype.v1`
  - `operators.operatorframework.io.bundle.manifests.v1`
  - `operators.operatorframework.io.bundle.metadata.v1`
  - `operators.operatorframework.io.bundle.package.v1`
  - `operators.operatorframework.io.bundle.channels.v1`
  - `operators.operatorframework.io.bundle.channel.default.v1`
- **Size** (bytes): Total image size (target: <50MB)
- **Created Timestamp** (RFC3339): Image build time
- **Digest** (SHA256): Content-addressable image identifier

**Relationships**:
- CONTAINS 1 Bundle Metadata entity
- CONTAINS 1+ Bundle Manifest entities
- REFERENCED BY 0+ CatalogSource entities (in target clusters)

**Validation Rules**:
- MUST have labels matching annotations in Bundle Metadata
- MUST contain `/manifests/` and `/metadata/` directories
- MUST pass `operator-sdk bundle validate` with zero errors

**Lifecycle States**:
1. **Built**: Image exists locally (podman images shows it)
2. **Tagged**: Image has version and latest tags applied
3. **Pushed**: Image exists in remote registry
4. **Deployed**: CatalogSource in cluster references this image

---

### 2. Bundle Metadata

**Description**: OLM-specific annotations defining package, channels, and format. Stored in `/metadata/annotations.yaml` within the bundle image.

**Attributes**:
- **Package Name** (string): Operator package identifier (`toolhive-operator`)
- **Mediatype** (string): Bundle format version (`registry+v1`)
- **Channels** (string, comma-separated): Available update channels (`fast`)
- **Default Channel** (string): Channel used when not specified (`fast`)
- **Manifests Path** (string): Location of manifests in image (`manifests/`)
- **Metadata Path** (string): Location of metadata in image (`metadata/`)
- **OpenShift Versions** (string): Supported OpenShift versions (`v4.10-v4.19`)
- **Builder** (string): Tool used to generate bundle (`operator-sdk-v1.30.0`)
- **Project Layout** (string): Operator framework type (`go.kubebuilder.io/v3`)
- **Bundle Images** (JSON array): Container images used by operator

**Relationships**:
- CONTAINED BY 1 Bundle Container Image
- REFERENCES 1 Package entity (conceptual, defined in catalog)
- MUST MATCH labels on Container Image

**Validation Rules**:
- Required annotations: `bundle.mediatype.v1`, `bundle.manifests.v1`, `bundle.metadata.v1`, `bundle.package.v1`, `bundle.channels.v1`, `bundle.channel.default.v1`
- Channels list MUST include default channel
- Paths MUST match actual filesystem locations in image

**Source**: `/bundle/metadata/annotations.yaml` (read-only input)

---

### 3. Bundle Manifest (CSV)

**Description**: ClusterServiceVersion defining the operator's metadata, deployment, permissions, and owned CRDs.

**Attributes**:
- **Name** (string): CSV resource name (`toolhive-operator.v0.2.17`)
- **Display Name** (string): Human-readable operator name
- **Description** (string): Operator purpose and capabilities
- **Version** (semver string): Operator version (`0.2.17`)
- **Maturity** (string): Development stage (e.g., `alpha`, `stable`)
- **Provider** (object): Organization information
- **Owned CRDs** (array of CRD references):
  - Group: `toolhive.stacklok.dev`
  - Kinds: `MCPRegistry`, `MCPServer`
  - Versions: `v1alpha1`
- **Deployment Spec** (Kubernetes Deployment): Operator controller deployment
  - Container images
  - Resource limits
  - Environment variables
- **RBAC Permissions** (array):
  - ClusterPermissions (cluster-scoped)
  - Permissions (namespace-scoped)

**Relationships**:
- CONTAINED BY 1 Bundle Container Image (at `/manifests/*.clusterserviceversion.yaml`)
- OWNS 2 CRD entities (MCPRegistry, MCPServer)
- DECLARES deployment that USES 2 container images (operator, proxyrunner)

**Validation Rules**:
- `spec.version` MUST match version in image tag
- `spec.customresourcedefinitions.owned` MUST reference all CRDs in manifests/
- All RBAC permissions MUST be necessary for operator functionality
- All container image references MUST be pullable

**Source**: `/bundle/manifests/toolhive-operator.clusterserviceversion.yaml` (read-only input)

---

### 4. Bundle Manifest (CRD)

**Description**: CustomResourceDefinition manifests for MCPRegistry and MCPServer APIs.

**Attributes**:
- **API Group** (string): `toolhive.stacklok.dev`
- **Kind** (string): `MCPRegistry` or `MCPServer`
- **Versions** (array): Supported API versions (`v1alpha1`)
- **Scope** (string): `Namespaced`
- **Schema** (OpenAPIv3): Validation schema for custom resources
- **Printer Columns** (array): kubectl display columns

**Relationships**:
- CONTAINED BY 1 Bundle Container Image (at `/manifests/*.crd.yaml`)
- OWNED BY 1 CSV entity
- MUST MATCH upstream CRD definitions (immutable)

**Validation Rules**:
- MUST NOT be modified from upstream operator source
- Schema MUST be valid OpenAPI v3
- `metadata.name` MUST follow `<plural>.<group>` pattern

**Source**:
- `/bundle/manifests/mcpregistries.crd.yaml` (read-only input)
- `/bundle/manifests/mcpservers.crd.yaml` (read-only input)

---

### 5. Containerfile

**Description**: Build instructions defining how to construct the bundle container image from the bundle/ directory.

**Attributes**:
- **FROM Directive** (string): Base image (`scratch`)
- **COPY/ADD Directives** (array): File copy operations
  - Source: `bundle/manifests` → Dest: `/manifests/`
  - Source: `bundle/metadata` → Dest: `/metadata/`
- **LABEL Directives** (key-value map): Image labels (OLM discovery + metadata)
- **File Path** (string): `Containerfile.bundle` (repository root)

**Relationships**:
- READS FROM bundle/ directory (input)
- PRODUCES 1 Bundle Container Image (output)
- REFERENCED BY Makefile targets (`bundle-build`)

**Validation Rules**:
- MUST use scratch or minimal base image
- MUST copy `/manifests/` and `/metadata/` directories
- MUST declare all required OLM labels
- MUST be compatible with podman and docker

---

### 6. Makefile Targets

**Description**: Automation scripts for building, validating, and pushing bundle images.

**Attributes**:
- **Target Name** (string): `bundle-build`, `bundle-validate-sdk`, `bundle-push`, `bundle-all`
- **Dependencies** (array of target names): Prerequisites
- **Commands** (array of shell commands): Execution steps
- **Documentation** (string): Help text (after `##`)

**Relationships**:
- `bundle-build` DEPENDS ON `bundle-validate-sdk`
- `bundle-validate-sdk` VALIDATES bundle/ directory
- `bundle-push` DEPENDS ON `bundle-build`
- `bundle-all` DEPENDS ON `bundle-validate-sdk` and `bundle-build`

**Validation Rules**:
- Targets MUST be marked `.PHONY` (no file outputs)
- Validation MUST run before build
- Build MUST fail if validation fails
- Push MUST fail if build fails

---

## Entity Relationships Diagram (Textual)

```
Bundle Container Image
├── CONTAINS Bundle Metadata (annotations.yaml)
├── CONTAINS Bundle Manifest (CSV)
│   ├── OWNS CRD (MCPRegistry)
│   └── OWNS CRD (MCPServer)
└── CONTAINS 2 CRD Manifests
    ├── mcpregistries.crd.yaml
    └── mcpservers.crd.yaml

Build Process Flow:
Containerfile.bundle
  └─ READS bundle/ directory
      ├── manifests/
      │   ├── toolhive-operator.clusterserviceversion.yaml
      │   ├── mcpregistries.crd.yaml
      │   └── mcpservers.crd.yaml
      └── metadata/
          └── annotations.yaml
  └─ PRODUCES Bundle Container Image
      └─ TAGGED AS ghcr.io/stacklok/toolhive/bundle:v0.2.17

Makefile Target Dependencies:
bundle-all
├── bundle-validate-sdk
│   └── operator-sdk bundle validate ./bundle
└── bundle-build
    └── podman build -f Containerfile.bundle
```

---

## Data Sources and Immutability

| Entity | Source | Mutability |
|--------|--------|------------|
| Bundle Metadata | bundle/metadata/annotations.yaml | READ-ONLY (existing file) |
| CSV Manifest | bundle/manifests/toolhive-operator.clusterserviceversion.yaml | READ-ONLY (existing file) |
| CRD Manifests | bundle/manifests/*.crd.yaml | READ-ONLY (upstream immutable) |
| Containerfile | Containerfile.bundle | NEW FILE (created by this feature) |
| Makefile Targets | Makefile | APPEND-ONLY (existing file extended) |
| Container Image | Built artifact (podman/docker) | WRITE (generated output) |

---

## Notes

This "data model" is unconventional because the feature is infrastructure (build system) rather than a data application. However, understanding the structure of OLM bundle entities and their validation constraints is critical for correct implementation. All manifests and metadata are read-only inputs—the feature only creates build artifacts (Containerfile, Makefile targets, container image).