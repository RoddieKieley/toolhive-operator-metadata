# Research: OLMv1 File-Based Catalog Bundle

**Feature**: 001-build-an-olmv1
**Date**: 2025-10-07
**Status**: Complete

## Research Questions

### 1. Number of Release Channels

**Question**: Should we create a single default channel or multiple channels (stable, candidate, fast) for the initial FBC bundle?

**Decision**: Start with a single default channel named "stable"

**Rationale**:
- OLM documentation recommends at least one channel for initial catalog creation
- The feature specification prioritizes single-channel support as P1 and multi-channel support as P4
- Current operator version (v0.2.17) represents a single stable release track
- Multi-channel support can be added incrementally without restructuring existing FBC metadata
- Simpler to validate and test with a single channel initially

**Alternatives considered**:
- **Multiple channels from start**: Rejected because we only have one current version (v0.2.17) and no defined upgrade paths or stability tiers yet. Creating empty channels adds complexity without value.
- **No default channel**: Invalid - OLM requires at least one channel per package

**Implementation Impact**:
- Create one `olm.channel` schema with name "stable"
- Set "stable" as defaultChannel in `olm.package` schema
- Document path to add additional channels in future versions

---

### 2. FBC Schema Format (JSON vs YAML)

**Question**: Should we use JSON or YAML for FBC metadata files?

**Decision**: Use YAML format

**Rationale**:
- Existing repository uses YAML for all Kubernetes manifests (config/crd/, config/rbac/, etc.)
- YAML is more readable for human maintenance and code reviews
- OLM documentation shows examples in both formats and explicitly supports both
- Consistency with existing manifest format reduces cognitive load

**Alternatives considered**:
- **JSON format**: Rejected for consistency reasons, though technically equivalent
- **Mixed format**: Rejected to maintain consistency

**Implementation Impact**:
- All FBC schema files will use `.yaml` extension
- Follow existing YAML formatting conventions from config/ directory

---

### 3. Bundle Generation Approach

**Question**: Should we generate the traditional bundle format first and then convert to FBC, or create FBC metadata directly?

**Decision**: Generate traditional bundle format first, then convert to FBC using `opm`

**Rationale**:
- operator-sdk has mature tooling for bundle generation from kustomize manifests
- `operator-sdk generate bundle` creates ClusterServiceVersion (CSV) and bundle metadata
- `opm render` can convert traditional bundles to FBC format automatically
- This approach provides both bundle formats for maximum compatibility
- Validates that our manifests are correct before FBC conversion

**Alternatives considered**:
- **Direct FBC creation**: Rejected because it requires manual CSV authoring without validation tooling
- **Only traditional bundle**: Rejected because the requirement specifically asks for FBC format

**Implementation Impact**:
- Step 1: Use `operator-sdk generate bundle` to create bundle/ directory
- Step 2: Use `opm render bundle/` to generate FBC schemas
- Step 3: Place FBC output in catalog/toolhive-operator/ directory
- Maintain both bundle/ and catalog/ directories

---

### 4. ClusterServiceVersion (CSV) Metadata

**Question**: What metadata should be included in the ClusterServiceVersion manifest?

**Research Findings**:

**Required CSV fields** (from OLM best practices):
- `metadata.name`: Format `<operator-name>.v<version>` (e.g., toolhive-operator.v0.2.17)
- `spec.displayName`: Human-readable operator name
- `spec.description`: Operator description
- `spec.version`: Semantic version (0.2.17)
- `spec.minKubeVersion`: Minimum Kubernetes version (1.16.0 based on current manifests)
- `spec.install.spec.deployments`: Deployment specifications (from config/manager/)
- `spec.install.spec.permissions`: RBAC permissions (from config/rbac/)
- `spec.customresourcedefinitions.owned`: CRDs owned by operator (MCPRegistry, MCPServer)

**Recommended CSV fields**:
- `spec.icon`: Base64-encoded icon for UI display
- `spec.keywords`: Search keywords (e.g., "mcp", "model-context-protocol", "ai")
- `spec.maintainers`: Maintainer contact information
- `spec.provider.name`: Provider organization (stacklok)
- `spec.links`: Documentation and source links
- `spec.maturity`: alpha/beta/stable designation

**Decision**: Include all required fields plus recommended fields for better UX

**Implementation Impact**:
- CSV will pull deployment spec from config/manager/manager.yaml
- CSV will reference both CRDs from config/crd/
- CSV will include comprehensive metadata for operator hub display

---

### 5. Bundle Validation Requirements

**Question**: What specific validations must pass for operator-sdk compliance?

**Research Findings** (from https://olm.operatorframework.io/docs/best-practices/common):

**Required validations**:
1. `operator-sdk bundle validate ./bundle` - basic bundle structure
2. `operator-sdk bundle validate ./bundle --select-optional suite=operatorframework` - framework compliance
3. Optional: `operator-sdk scorecard ./bundle` - quality and best practices

**Common validation failures to avoid**:
- Missing CSV fields (displayName, description, version)
- Missing or incorrect CRD references
- Invalid semantic versioning
- Missing RBAC permissions in CSV
- Incorrect bundle annotations in metadata/annotations.yaml

**Decision**: Implement all required validations as part of the build process

**Implementation Impact**:
- Add Makefile targets for bundle-validate and catalog-validate
- Document validation commands in quickstart.md
- Include validation in CI/CD workflow (if applicable)

---

### 6. Container Image Build Process

**Question**: How should we structure the Containerfile for catalog image builds?

**Research Findings** (from opm documentation):

**Standard approach**:
```dockerfile
FROM scratch
ADD catalog /configs
LABEL operators.operatorframework.io.index.configs.v1=/configs
```

**Best practices**:
- Use `FROM scratch` for minimal image size
- Add entire catalog directory to `/configs` path
- Include the required label for OLM to locate catalog metadata
- Keep images immutable (use version tags, not latest)

**Decision**: Use standard scratch-based Containerfile with proper labeling

**Implementation Impact**:
- Create Containerfile.catalog at repository root
- Use opm tooling to validate image can be parsed by OLM
- Tag images with version (e.g., ghcr.io/stacklok/toolhive/catalog:v0.2.17)

---

## Technology Stack Summary

| Component | Technology | Version | Purpose |
|-----------|-----------|---------|---------|
| Schema Format | YAML | N/A | FBC metadata files |
| Bundle Generator | operator-sdk | Latest | Generate traditional bundle from kustomize |
| FBC Converter | opm | Latest | Convert bundle to FBC format, validate catalogs |
| Validation | operator-sdk | Latest | Bundle validation, scorecard testing |
| Container Build | podman/docker | Latest | Build catalog container image |
| Base Image | scratch | N/A | Minimal catalog image |

---

## Dependencies and Integration Points

### Upstream Dependencies
- **Kubebuilder manifests** (config/default/): Source of base manifests
- **CRD definitions** (config/crd/): MCPRegistry and MCPServer schemas
- **RBAC manifests** (config/rbac/): Permissions for operator
- **Manager deployment** (config/manager/): Operator controller deployment spec

### External Tools Required
- `operator-sdk` (bundle generation and validation)
- `opm` (FBC rendering and catalog building)
- `kustomize` (manifest building - already in use)
- `podman` or `docker` (container image building)

### Integration Constraints
- Must not modify any files in config/ (constitution II)
- Must maintain CRD immutability (constitution III)
- Must ensure kustomize builds continue to pass (constitution I)

---

## Open Questions Resolved

All NEEDS CLARIFICATION items from Technical Context resolved:

✅ **Number of release channels**: Single "stable" channel initially
✅ **Schema format**: YAML for consistency with existing manifests
✅ **Bundle generation approach**: Traditional bundle → FBC conversion workflow
✅ **CSV metadata**: Comprehensive metadata including required and recommended fields
✅ **Validation requirements**: Full operator-sdk validation suite
✅ **Image build process**: Standard scratch-based Containerfile with OLM labels

---

## Next Steps

Proceed to Phase 1: Design & Contracts
- Create data-model.md (FBC schema structure)
- Create contracts/ (FBC schema examples)
- Create quickstart.md (build and validation instructions)
