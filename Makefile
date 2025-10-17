# Makefile for Toolhive Operator Metadata and OLM Bundle/Catalog
#
# This Makefile provides targets for building, validating, and managing
# OLM bundles and File-Based Catalogs (FBC) for the Toolhive Operator.

# OLMv1 Catalog Image Configuration (Modern OpenShift 4.19+)
# Components can be overridden via environment variables or make arguments:
#   make catalog-build CATALOG_REGISTRY=quay.io CATALOG_ORG=myuser
CATALOG_REGISTRY ?= ghcr.io
CATALOG_ORG ?= stacklok/toolhive
CATALOG_NAME ?= catalog
CATALOG_TAG ?= v0.2.17
CATALOG_IMG := $(CATALOG_REGISTRY)/$(CATALOG_ORG)/$(CATALOG_NAME):$(CATALOG_TAG)

# OLMv0 Bundle Image Configuration
# Components can be overridden independently:
#   make bundle-build BUNDLE_REGISTRY=ghcr.io BUNDLE_ORG=stacklok/toolhive BUNDLE_TAG=dev
BUNDLE_REGISTRY ?= quay.io
BUNDLE_ORG ?= roddiekieley
BUNDLE_NAME ?= toolhive-operator-catalog
BUNDLE_TAG ?= v0.2.17
BUNDLE_IMG := $(BUNDLE_REGISTRY)/$(BUNDLE_ORG)/$(BUNDLE_NAME):$(BUNDLE_TAG)

# OLMv0 Index Image Configuration (Legacy OpenShift 4.15-4.18)
# Components can be overridden independently:
#   make index-olmv0-build INDEX_REGISTRY=quay.io INDEX_ORG=myteam
INDEX_REGISTRY ?= ghcr.io
INDEX_ORG ?= stacklok/toolhive
INDEX_NAME ?= index-olmv0
INDEX_TAG ?= v0.2.17
INDEX_OLMV0_IMG := $(INDEX_REGISTRY)/$(INDEX_ORG)/$(INDEX_NAME):$(INDEX_TAG)

# Build tool configuration
OPM_MODE ?= semver
CONTAINER_TOOL ?= podman

.PHONY: help
help: ## Display this help message
	@echo "Toolhive Operator Metadata - Available Targets:"
	@echo ""
	@awk 'BEGIN {FS = ":.*##"; printf "\033[36m%-30s\033[0m %s\n", "Target", "Description"} /^[a-zA-Z0-9_-]+:.*?##/ { printf "\033[36m%-30s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Kustomize Targets

.PHONY: kustomize-build-default
kustomize-build-default: ## Build default kustomize configuration
	kustomize build config/default

.PHONY: kustomize-build-base
kustomize-build-base: ## Build base (OpenShift) kustomize configuration
	kustomize build config/base

.PHONY: kustomize-validate
kustomize-validate: ## Validate both kustomize builds (constitution compliance)
	@echo "Validating config/default..."
	@kustomize build config/default > /dev/null && echo "✅ config/default build passed"
	@echo "Validating config/base..."
	@kustomize build config/base > /dev/null && echo "✅ config/base build passed"

##@ OLM Bundle Targets

.PHONY: bundle
bundle: ## Generate OLM bundle (CSV, CRDs, metadata) with OpenShift security patches
	@echo "Generating OLM bundle from downloaded operator files..."
	@mkdir -p bundle/manifests bundle/metadata
	@if [ -d "downloaded/toolhive-operator/0.2.17" ]; then \
		echo "Copying manifests from downloaded/toolhive-operator/0.2.17/..."; \
		cp downloaded/toolhive-operator/0.2.17/*.yaml bundle/manifests/; \
		echo "Applying OpenShift security patches to CSV..."; \
		yq eval 'del(.spec.install.spec.deployments[0].spec.template.spec.containers[0].securityContext.runAsUser)' -i bundle/manifests/toolhive-operator.clusterserviceversion.yaml; \
		yq eval '.spec.install.spec.deployments[0].spec.template.spec.securityContext.seccompProfile = {"type": "RuntimeDefault"}' -i bundle/manifests/toolhive-operator.clusterserviceversion.yaml; \
		yq eval 'del(.spec.install.spec.deployments[0].spec.template.spec.containers[0].command)' -i bundle/manifests/toolhive-operator.clusterserviceversion.yaml; \
		echo "Adding leader election RBAC permissions to CSV..."; \
		yq eval '.spec.install.spec.permissions = [{"serviceAccountName": "toolhive-operator-controller-manager", "rules": [{"apiGroups": [""], "resources": ["configmaps"], "verbs": ["get", "list", "watch", "create", "update", "patch", "delete"]}, {"apiGroups": ["coordination.k8s.io"], "resources": ["leases"], "verbs": ["get", "list", "watch", "create", "update", "patch", "delete"]}, {"apiGroups": [""], "resources": ["events"], "verbs": ["create", "patch"]}]}]' -i bundle/manifests/toolhive-operator.clusterserviceversion.yaml; \
		echo "  ✓ Removed hardcoded runAsUser from container securityContext"; \
		echo "  ✓ Added seccompProfile: RuntimeDefault to pod securityContext"; \
		echo "  ✓ Removed explicit command field (using container ENTRYPOINT)"; \
		echo "  ✓ Added leader election RBAC permissions (configmaps, leases, events)"; \
		echo "annotations:" > bundle/metadata/annotations.yaml; \
		echo "  operators.operatorframework.io.bundle.mediatype.v1: registry+v1" >> bundle/metadata/annotations.yaml; \
		echo "  operators.operatorframework.io.bundle.manifests.v1: manifests/" >> bundle/metadata/annotations.yaml; \
		echo "  operators.operatorframework.io.bundle.metadata.v1: metadata/" >> bundle/metadata/annotations.yaml; \
		echo "  operators.operatorframework.io.bundle.package.v1: toolhive-operator" >> bundle/metadata/annotations.yaml; \
		echo "  operators.operatorframework.io.bundle.channels.v1: fast" >> bundle/metadata/annotations.yaml; \
		echo "  operators.operatorframework.io.bundle.channel.default.v1: fast" >> bundle/metadata/annotations.yaml; \
		echo "✅ Bundle generated successfully with OpenShift patches applied"; \
		echo "Contents:"; \
		ls -lh bundle/manifests/ bundle/metadata/; \
	else \
		echo "❌ Error: downloaded/toolhive-operator/0.2.17/ directory not found"; \
		echo "Run download script first or check directory structure"; \
		exit 1; \
	fi

.PHONY: bundle-validate
bundle-validate: ## Validate OLM bundle with operator-sdk
	@echo "Validating bundle structure..."
	@if [ -d "bundle/manifests" ] && [ -d "bundle/metadata" ]; then \
		echo "✅ Bundle directory structure valid"; \
	else \
		echo "❌ Bundle directory structure invalid"; \
		exit 1; \
	fi
	@echo "Validating bundle manifests..."
	@if [ -f "bundle/manifests/toolhive-operator.clusterserviceversion.yaml" ]; then \
		echo "✅ CSV present"; \
	else \
		echo "❌ CSV missing"; \
		exit 1; \
	fi
	@echo "Bundle validation: manual checks passed"
	@echo "Note: For full operator-sdk validation, run: operator-sdk bundle validate ./bundle"

##@ OLM Catalog Targets (OLMv1 - Modern OpenShift 4.19+)
#
# These targets work with File-Based Catalog (FBC) images for modern OLM.
# The catalog image IS the index/catalog image - no wrapper needed.
# For legacy OpenShift 4.15-4.18, see "OLM Index Targets (OLMv0)" below.

.PHONY: catalog
catalog: bundle ## Generate FBC catalog metadata from bundle
	@echo "Generating FBC catalog from bundle..."
	@mkdir -p catalog/toolhive-operator
	@echo "---" > catalog/toolhive-operator/catalog.yaml
	@echo "# Package Schema - defines the toolhive-operator package" >> catalog/toolhive-operator/catalog.yaml
	@echo "schema: olm.package" >> catalog/toolhive-operator/catalog.yaml
	@echo "name: toolhive-operator" >> catalog/toolhive-operator/catalog.yaml
	@echo "defaultChannel: fast" >> catalog/toolhive-operator/catalog.yaml
	@echo "description: |" >> catalog/toolhive-operator/catalog.yaml
	@echo "  Toolhive Operator manages Model Context Protocol (MCP) servers and registries." >> catalog/toolhive-operator/catalog.yaml
	@echo "" >> catalog/toolhive-operator/catalog.yaml
	@echo "  The operator provides custom resources for:" >> catalog/toolhive-operator/catalog.yaml
	@echo "  - MCPRegistry: Manages registries of MCP server definitions" >> catalog/toolhive-operator/catalog.yaml
	@echo "  - MCPServer: Manages individual MCP server instances" >> catalog/toolhive-operator/catalog.yaml
	@echo "" >> catalog/toolhive-operator/catalog.yaml
	@echo "  MCP enables AI assistants to securely access external tools and data sources." >> catalog/toolhive-operator/catalog.yaml
	@echo "icon:" >> catalog/toolhive-operator/catalog.yaml
	@echo "  base64data: PHN2ZyB3aWR0aD0iNTEyIiBoZWlnaHQ9IjUxMiIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj4KICA8cmVjdCB3aWR0aD0iNTEyIiBoZWlnaHQ9IjUxMiIgZmlsbD0iIzAwN2ZmZiIvPgogIDx0ZXh0IHg9IjUwJSIgeT0iNTAlIiBmb250LXNpemU9IjI1NiIgZmlsbD0id2hpdGUiIHRleHQtYW5jaG9yPSJtaWRkbGUiIGRvbWluYW50LWJhc2VsaW5lPSJtaWRkbGUiPk08L3RleHQ+Cjwvc3ZnPg==" >> catalog/toolhive-operator/catalog.yaml
	@echo "  mediatype: image/svg+xml" >> catalog/toolhive-operator/catalog.yaml
	@echo "" >> catalog/toolhive-operator/catalog.yaml
	@echo "---" >> catalog/toolhive-operator/catalog.yaml
	@echo "# Channel Schema - defines the fast release channel" >> catalog/toolhive-operator/catalog.yaml
	@echo "schema: olm.channel" >> catalog/toolhive-operator/catalog.yaml
	@echo "name: fast" >> catalog/toolhive-operator/catalog.yaml
	@echo "package: toolhive-operator" >> catalog/toolhive-operator/catalog.yaml
	@echo "entries:" >> catalog/toolhive-operator/catalog.yaml
	@echo "  - name: toolhive-operator.v0.2.17" >> catalog/toolhive-operator/catalog.yaml
	@echo "    # Initial release - no replaces/skips" >> catalog/toolhive-operator/catalog.yaml
	@echo "" >> catalog/toolhive-operator/catalog.yaml
	@echo "---" >> catalog/toolhive-operator/catalog.yaml
	@echo "# Bundle Schema - generated by opm render with embedded bundle objects" >> catalog/toolhive-operator/catalog.yaml
	@echo "# Note: image field removed - using embedded olm.bundle.object data only" >> catalog/toolhive-operator/catalog.yaml
	@opm render bundle/ -o yaml | sed '1d' | sed '/^image:/d' >> catalog/toolhive-operator/catalog.yaml
	@echo "✅ Catalog generated successfully with embedded bundle objects (no image reference)"
	@echo "Contents:"
	@ls -lh catalog/toolhive-operator/

.PHONY: catalog-validate
catalog-validate: ## Validate FBC catalog with opm
	@echo "Validating FBC catalog..."
	@opm validate catalog/
	@echo "✅ FBC catalog validation passed"

.PHONY: catalog-validate-existing
catalog-validate-existing: ## Validate existing OLMv1 catalog (no rebuild needed)
	@echo "Validating existing OLMv1 FBC catalog..."
	@opm validate catalog/
	@echo "✅ OLMv1 catalog validation passed"
	@echo "   The catalog image is already a valid index/catalog image."
	@echo "   No additional index wrapper needed for OLMv1."

.PHONY: catalog-build
catalog-build: catalog-validate ## Build catalog container image
	@echo "Building catalog container image: $(CATALOG_IMG)"
	$(CONTAINER_TOOL) build -f Containerfile.catalog -t $(CATALOG_IMG) .
	$(CONTAINER_TOOL) tag $(CATALOG_IMG) $(CATALOG_REGISTRY)/$(CATALOG_ORG)/$(CATALOG_NAME):latest
	@echo "✅ Catalog image built: $(CATALOG_IMG)"
	@$(CONTAINER_TOOL) images $(CATALOG_REGISTRY)/$(CATALOG_ORG)/$(CATALOG_NAME)

.PHONY: catalog-push
catalog-push: ## Push catalog image to registry
	@echo "Pushing catalog image: $(CATALOG_IMG)"
	$(CONTAINER_TOOL) push $(CATALOG_IMG)
	$(CONTAINER_TOOL) push $(CATALOG_REGISTRY)/$(CATALOG_ORG)/$(CATALOG_NAME):latest
	@echo "✅ Catalog image pushed"

.PHONY: catalog-inspect
catalog-inspect: ## Inspect built catalog image contents and metadata
	@echo "=== Catalog Image Inspection: $(CATALOG_IMG) ==="
	@echo ""
	@echo "--- Labels ---"
	@$(CONTAINER_TOOL) inspect $(CATALOG_IMG) | jq -r '.[0].Config.Labels | to_entries | map(select(.key | startswith("org.opencontainers.image") or startswith("operators.operatorframework"))) | sort_by(.key) | .[] | "  \(.key) = \(.value)"'
	@echo ""
	@echo "--- Entrypoint & Command ---"
	@$(CONTAINER_TOOL) inspect $(CATALOG_IMG) | jq -r '.[0].Config | "  ENTRYPOINT: \(.Entrypoint)\n  CMD: \(.Cmd)"'
	@echo ""
	@echo "--- Catalog Contents (/configs) ---"
	@$(CONTAINER_TOOL) run --rm --entrypoint="" $(CATALOG_IMG) find /configs -type f
	@echo ""
	@echo "--- Cache Contents (/tmp/cache) ---"
	@$(CONTAINER_TOOL) run --rm --entrypoint="" $(CATALOG_IMG) sh -c "du -sh /tmp/cache && find /tmp/cache -type f | wc -l | xargs echo '  Files:'"
	@echo ""
	@echo "--- Binaries ---"
	@$(CONTAINER_TOOL) run --rm --entrypoint="" $(CATALOG_IMG) sh -c "ls -lh /bin/opm /bin/grpc_health_probe 2>/dev/null || echo '  Error: binaries not found'"
	@echo ""

.PHONY: catalog-test-local
catalog-test-local: ## Start catalog registry-server locally for testing
	@echo "Starting catalog registry-server locally..."
	@echo "  Image: $(CATALOG_IMG)"
	@echo "  Port: 50051 (gRPC)"
	@echo ""
	@if $(CONTAINER_TOOL) ps -a | grep -q catalog-test-local; then \
		echo "⚠️  Removing existing catalog-test-local container..."; \
		$(CONTAINER_TOOL) rm -f catalog-test-local; \
	fi
	@$(CONTAINER_TOOL) run -d -p 50051:50051 --name catalog-test-local $(CATALOG_IMG)
	@echo ""
	@echo "Waiting for registry-server startup..."
	@sleep 3
	@$(CONTAINER_TOOL) logs catalog-test-local | grep -q "serving registry" && echo "✅ Registry-server is running" || echo "⚠️  Server may not be ready yet"
	@echo ""
	@echo "Test commands:"
	@echo "  grpcurl -plaintext localhost:50051 api.Registry/ListPackages"
	@echo "  grpcurl -plaintext localhost:50051 grpc.health.v1.Health/Check"
	@echo ""
	@echo "View logs:"
	@echo "  podman logs -f catalog-test-local"
	@echo ""
	@echo "Stop and remove:"
	@echo "  make catalog-test-local-stop"
	@echo ""

.PHONY: catalog-test-local-stop
catalog-test-local-stop: ## Stop and remove local catalog test container
	@echo "Stopping catalog-test-local container..."
	@$(CONTAINER_TOOL) stop catalog-test-local 2>/dev/null || true
	@$(CONTAINER_TOOL) rm catalog-test-local 2>/dev/null || true
	@echo "✅ Container removed"

.PHONY: catalog-validate-executable
catalog-validate-executable: ## Validate executable catalog image has required components
	@echo "=== Validating Executable Catalog Image ==="
	@echo "  Image: $(CATALOG_IMG)"
	@echo ""
	@echo "Checking for required binaries..."
	@$(CONTAINER_TOOL) run --rm --entrypoint="" $(CATALOG_IMG) sh -c "test -x /bin/opm && echo '  ✅ /bin/opm present'" || (echo "  ❌ /bin/opm missing or not executable" && exit 1)
	@$(CONTAINER_TOOL) run --rm --entrypoint="" $(CATALOG_IMG) sh -c "test -x /bin/grpc_health_probe && echo '  ✅ /bin/grpc_health_probe present'" || (echo "  ❌ /bin/grpc_health_probe missing or not executable" && exit 1)
	@echo ""
	@echo "Checking for catalog metadata..."
	@$(CONTAINER_TOOL) run --rm --entrypoint="" $(CATALOG_IMG) sh -c "test -f /configs/toolhive-operator/catalog.yaml && echo '  ✅ catalog.yaml present'" || (echo "  ❌ catalog.yaml missing" && exit 1)
	@echo ""
	@echo "Checking for pre-built cache..."
	@$(CONTAINER_TOOL) run --rm --entrypoint="" $(CATALOG_IMG) sh -c "test -d /tmp/cache && echo '  ✅ /tmp/cache directory exists'" || (echo "  ❌ /tmp/cache missing" && exit 1)
	@$(CONTAINER_TOOL) run --rm --entrypoint="" $(CATALOG_IMG) sh -c "find /tmp/cache -type f | grep -q . && echo '  ✅ Cache files present'" || (echo "  ❌ Cache is empty" && exit 1)
	@echo ""
	@echo "Checking image configuration..."
	@$(CONTAINER_TOOL) inspect $(CATALOG_IMG) | jq -e '.[0].Config.Entrypoint == ["/bin/opm"]' >/dev/null && echo "  ✅ ENTRYPOINT configured correctly" || (echo "  ❌ ENTRYPOINT incorrect" && exit 1)
	@$(CONTAINER_TOOL) inspect $(CATALOG_IMG) | jq -e '.[0].Config.Cmd == ["serve", "/configs", "--cache-dir=/tmp/cache"]' >/dev/null && echo "  ✅ CMD configured correctly" || (echo "  ❌ CMD incorrect" && exit 1)
	@echo ""
	@echo "Checking OLM labels..."
	@$(CONTAINER_TOOL) inspect $(CATALOG_IMG) | jq -e '.[0].Config.Labels."operators.operatorframework.io.index.configs.v1" == "/configs"' >/dev/null && echo "  ✅ OLM config label present" || (echo "  ❌ OLM config label missing or incorrect" && exit 1)
	@echo ""
	@echo "✅ All validation checks passed - catalog image is executable"

##@ OLM Bundle Image Targets

.PHONY: bundle-validate-sdk
bundle-validate-sdk: ## Validate OLM bundle with operator-sdk
	@echo "Validating bundle with operator-sdk..."
	operator-sdk --plugins go.kubebuilder.io/v4 bundle validate ./bundle
	@echo "✅ Bundle validation passed"

.PHONY: bundle-build
bundle-build: bundle-validate-sdk ## Build bundle container image
	@echo "Building bundle container image: $(BUNDLE_IMG)"
	$(CONTAINER_TOOL) build -f Containerfile.bundle -t $(BUNDLE_IMG) .
	$(CONTAINER_TOOL) tag $(BUNDLE_IMG) $(BUNDLE_REGISTRY)/$(BUNDLE_ORG)/$(BUNDLE_NAME):latest
	@echo "✅ Bundle image built: $(BUNDLE_IMG)"
	@$(CONTAINER_TOOL) images $(BUNDLE_REGISTRY)/$(BUNDLE_ORG)/$(BUNDLE_NAME)

.PHONY: bundle-push
bundle-push: ## Push bundle image to registry
	@echo "Pushing bundle image: $(BUNDLE_IMG)"
	$(CONTAINER_TOOL) push $(BUNDLE_IMG)
	$(CONTAINER_TOOL) push $(BUNDLE_REGISTRY)/$(BUNDLE_ORG)/$(BUNDLE_NAME):latest
	@echo "✅ Bundle image pushed"

.PHONY: bundle-all
bundle-all: bundle-validate-sdk bundle-build ## Run complete bundle workflow (validate, build)
	@echo ""
	@echo "========================================="
	@echo "✅ Complete bundle workflow finished"
	@echo "========================================="
	@echo ""
	@echo "Next steps:"
	@echo "  1. Push bundle image: make bundle-push"
	@echo "  2. Build OLMv0 index: make index-olmv0-build"
	@echo "  3. Deploy to cluster: create CatalogSource referencing index image"
	@echo ""

##@ OLM Index Targets (OLMv0 - Legacy OpenShift 4.15-4.18)
#
# ⚠️  DEPRECATION NOTICE: SQLite-based index images are deprecated by operator-framework.
# These targets are for legacy OpenShift compatibility ONLY.
#
# Key differences from OLMv1:
#   - OLMv0 bundle images MUST be wrapped in a SQLite index image
#   - Use `opm index add` (deprecated) to create index from bundle
#   - Index contains SQLite database at /database/index.db
#   - Separate image name: index-olmv0 (vs catalog for OLMv1)
#
# DO NOT mix OLMv0 and OLMv1 formats for the same operator version.
# Use EITHER catalog targets (OLMv1) OR index-olmv0 targets (OLMv0), not both.
#
# Sunset timeline: When OpenShift 4.18 reaches EOL (Q1 2026), remove these targets.

.PHONY: index-olmv0-build
index-olmv0-build: ## Build OLMv0 index image (SQLite-based, deprecated)
	@echo "⚠️  Building OLMv0 index image (SQLite-based, deprecated)"
	@echo "   Use only for legacy OpenShift 4.15-4.18 compatibility"
	@echo ""
	@echo "Building index referencing bundle: $(BUNDLE_IMG)"
	opm index add \
		--bundles $(BUNDLE_IMG) \
		--tag $(INDEX_OLMV0_IMG) \
		--mode $(OPM_MODE) \
		--container-tool $(CONTAINER_TOOL)
	@echo ""
	@echo "✅ OLMv0 index image built: $(INDEX_OLMV0_IMG)"
	@$(CONTAINER_TOOL) images $(INDEX_OLMV0_IMG)
	@echo ""
	@echo "Tagging as latest..."
	$(CONTAINER_TOOL) tag $(INDEX_OLMV0_IMG) $(INDEX_REGISTRY)/$(INDEX_ORG)/$(INDEX_NAME):latest
	@echo "✅ Also tagged: $(INDEX_REGISTRY)/$(INDEX_ORG)/$(INDEX_NAME):latest"

.PHONY: index-olmv0-validate
index-olmv0-validate: ## Validate OLMv0 index image
	@echo "Validating OLMv0 index image..."
	@echo "Exporting package manifest from index..."
	@opm index export \
		--index=$(INDEX_OLMV0_IMG) \
		--package=toolhive-operator > /tmp/toolhive-index-olmv0-export.yaml
	@echo ""
	@echo "✅ OLMv0 index validation passed"
	@echo "   Package manifest exported to /tmp/toolhive-index-olmv0-export.yaml"
	@echo ""
	@echo "Package summary:"
	@if command -v yq > /dev/null 2>&1; then \
		yq eval '.metadata.name, .spec.channels[].name, .spec.channels[].currentCSV' /tmp/toolhive-index-olmv0-export.yaml; \
	else \
		echo "   (install yq for formatted output)"; \
		grep -E '(name:|currentCSV:)' /tmp/toolhive-index-olmv0-export.yaml | head -5; \
	fi

.PHONY: index-olmv0-push
index-olmv0-push: ## Push OLMv0 index image to registry
	@echo "Pushing OLMv0 index image: $(INDEX_OLMV0_IMG)"
	$(CONTAINER_TOOL) push $(INDEX_OLMV0_IMG)
	$(CONTAINER_TOOL) push $(INDEX_REGISTRY)/$(INDEX_ORG)/$(INDEX_NAME):latest
	@echo "✅ OLMv0 index image pushed"
	@echo "   - $(INDEX_OLMV0_IMG)"
	@echo "   - $(INDEX_REGISTRY)/$(INDEX_ORG)/$(INDEX_NAME):latest"

.PHONY: index-olmv0-all
index-olmv0-all: index-olmv0-build index-olmv0-validate index-olmv0-push ## Run complete OLMv0 index workflow
	@echo ""
	@echo "========================================="
	@echo "✅ Complete OLMv0 index workflow finished"
	@echo "========================================="
	@echo ""
	@echo "⚠️  REMINDER: SQLite-based indexes are deprecated"
	@echo "   Use only for legacy OpenShift 4.15-4.18 deployments"
	@echo ""
	@echo "Next steps:"
	@echo "  1. Deploy CatalogSource: kubectl apply -f examples/catalogsource-olmv0.yaml"
	@echo "  2. Verify catalog: kubectl get catalogsource -n olm toolhive-catalog-olmv0"
	@echo "  3. Check OperatorHub for Toolhive Operator"
	@echo ""

.PHONY: index-clean
index-clean: ## Remove local OLMv0 index images
	@echo "Removing OLMv0 index images..."
	-$(CONTAINER_TOOL) rmi ghcr.io/stacklok/toolhive/index-olmv0:v0.2.17
	-$(CONTAINER_TOOL) rmi ghcr.io/stacklok/toolhive/index-olmv0:latest
	@echo "✅ OLMv0 index images removed"

.PHONY: index-validate-all
index-validate-all: catalog-validate index-olmv0-validate ## Validate both OLMv1 catalog and OLMv0 index
	@echo ""
	@echo "========================================="
	@echo "✅ All index/catalog validations passed"
	@echo "========================================="
	@echo ""
	@echo "Validated:"
	@echo "  ✅ OLMv1 FBC Catalog (modern OpenShift 4.19+)"
	@echo "  ✅ OLMv0 SQLite Index (legacy OpenShift 4.15-4.18)"
	@echo ""

##@ Complete OLM Workflow

.PHONY: olm-all
olm-all: kustomize-validate bundle-validate catalog-validate catalog-build ## Run complete OLM workflow (validate, build catalog)
	@echo ""
	@echo "========================================="
	@echo "✅ Complete OLM workflow finished"
	@echo "========================================="
	@echo ""
	@echo "Next steps:"
	@echo "  1. Push catalog image: make catalog-push"
	@echo "  2. Deploy to cluster: see VALIDATION.md for CatalogSource example"
	@echo ""

##@ Validation & Compliance

.PHONY: constitution-check
constitution-check: kustomize-validate ## Verify constitution compliance
	@echo "Checking CRD immutability (constitution III)..."
	@git diff --exit-code config/crd/ && echo "✅ CRDs unchanged" || (echo "❌ CRDs have been modified"; exit 1)
	@echo "Constitution compliance: ✅ PASSED"

.PHONY: validate-all
validate-all: constitution-check bundle-validate bundle-validate-sdk catalog-validate index-olmv0-validate ## Run all validation checks
	@echo ""
	@echo "========================================="
	@echo "✅ All validations passed"
	@echo "========================================="
	@echo ""
	@echo "Validated components:"
	@echo "  ✅ Constitution compliance (kustomize builds, CRD immutability)"
	@echo "  ✅ OLMv0 Bundle structure and manifests"
	@echo "  ✅ OLMv1 FBC Catalog"
	@echo "  ✅ OLMv0 SQLite Index"
	@echo ""

##@ Cleanup

.PHONY: clean
clean: ## Clean generated bundle and catalog artifacts
	@echo "Cleaning generated artifacts..."
	rm -rf bundle/
	rm -rf catalog/
	@echo "✅ Cleaned bundle/ and catalog/ directories"

.PHONY: clean-images
clean-images: ## Remove local catalog and index container images
	@echo "Removing catalog, bundle, and index images..."
	-$(CONTAINER_TOOL) rmi $(CATALOG_IMG)
	-$(CONTAINER_TOOL) rmi $(CATALOG_REGISTRY)/$(CATALOG_ORG)/$(CATALOG_NAME):latest
	-$(CONTAINER_TOOL) rmi $(BUNDLE_IMG)
	-$(CONTAINER_TOOL) rmi $(BUNDLE_REGISTRY)/$(BUNDLE_ORG)/$(BUNDLE_NAME):latest
	-$(CONTAINER_TOOL) rmi $(INDEX_OLMV0_IMG)
	-$(CONTAINER_TOOL) rmi $(INDEX_REGISTRY)/$(INDEX_ORG)/$(INDEX_NAME):latest
	@echo "✅ Catalog, bundle, and index images removed"

##@ Documentation

.PHONY: show-image-vars
show-image-vars: ## Display effective image variable values (for debugging overrides)
	@echo "=== Container Image Variables ==="
	@echo ""
	@echo "Catalog Image (OLMv1):"
	@echo "  CATALOG_REGISTRY = $(CATALOG_REGISTRY)"
	@echo "  CATALOG_ORG      = $(CATALOG_ORG)"
	@echo "  CATALOG_NAME     = $(CATALOG_NAME)"
	@echo "  CATALOG_TAG      = $(CATALOG_TAG)"
	@echo "  CATALOG_IMG      = $(CATALOG_IMG)"
	@echo ""
	@echo "Bundle Image (OLMv0):"
	@echo "  BUNDLE_REGISTRY  = $(BUNDLE_REGISTRY)"
	@echo "  BUNDLE_ORG       = $(BUNDLE_ORG)"
	@echo "  BUNDLE_NAME      = $(BUNDLE_NAME)"
	@echo "  BUNDLE_TAG       = $(BUNDLE_TAG)"
	@echo "  BUNDLE_IMG       = $(BUNDLE_IMG)"
	@echo ""
	@echo "Index Image (OLMv0):"
	@echo "  INDEX_REGISTRY   = $(INDEX_REGISTRY)"
	@echo "  INDEX_ORG        = $(INDEX_ORG)"
	@echo "  INDEX_NAME       = $(INDEX_NAME)"
	@echo "  INDEX_TAG        = $(INDEX_TAG)"
	@echo "  INDEX_OLMV0_IMG  = $(INDEX_OLMV0_IMG)"
	@echo ""
	@echo "Override example:"
	@echo "  make catalog-build CATALOG_REGISTRY=quay.io CATALOG_ORG=myuser"

.PHONY: show-catalog
show-catalog: ## Display catalog metadata
	@echo "=== OLM Package Schema ==="
	@yq eval 'select(.schema == "olm.package")' catalog/toolhive-operator/catalog.yaml
	@echo ""
	@echo "=== OLM Channel Schema ==="
	@yq eval 'select(.schema == "olm.channel")' catalog/toolhive-operator/catalog.yaml
	@echo ""
	@echo "=== OLM Bundle Schema ==="
	@yq eval 'select(.schema == "olm.bundle")' catalog/toolhive-operator/catalog.yaml

.PHONY: show-csv
show-csv: ## Display CSV metadata
	@yq eval '.metadata.name, .spec.version, .spec.displayName, .spec.description' bundle/manifests/toolhive-operator.clusterserviceversion.yaml

##@ Quick Reference

.PHONY: quick-start
quick-start: ## Quick start: validate and build everything
	@echo "Quick start: Running full OLM workflow..."
	@$(MAKE) olm-all

.DEFAULT_GOAL := help
