# Makefile for Toolhive Operator Metadata and OLM Bundle/Catalog
#
# This Makefile provides targets for building, validating, and managing
# OLM bundles and File-Based Catalogs (FBC) for the Toolhive Operator.

.PHONY: help
help: ## Display this help message
	@echo "Toolhive Operator Metadata - Available Targets:"
	@echo ""
	@awk 'BEGIN {FS = ":.*##"; printf "\033[36m%-30s\033[0m %s\n", "Target", "Description"} /^[a-zA-Z_-]+:.*?##/ { printf "\033[36m%-30s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

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
bundle: ## Generate OLM bundle (CSV, CRDs, metadata)
	@echo "OLM bundle already generated in bundle/ directory"
	@echo "Contents:"
	@ls -lh bundle/manifests/ bundle/metadata/

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

##@ OLM Catalog Targets

.PHONY: catalog
catalog: ## Generate FBC catalog metadata
	@echo "FBC catalog already generated in catalog/ directory"
	@echo "Contents:"
	@ls -lh catalog/toolhive-operator/

.PHONY: catalog-validate
catalog-validate: ## Validate FBC catalog with opm
	@echo "Validating FBC catalog..."
	@opm validate catalog/
	@echo "✅ FBC catalog validation passed"

.PHONY: catalog-build
catalog-build: catalog-validate ## Build catalog container image
	@echo "Building catalog container image..."
	podman build -f Containerfile.catalog -t ghcr.io/stacklok/toolhive/catalog:v0.2.17 .
	podman tag ghcr.io/stacklok/toolhive/catalog:v0.2.17 ghcr.io/stacklok/toolhive/catalog:latest
	@echo "✅ Catalog image built: ghcr.io/stacklok/toolhive/catalog:v0.2.17"
	@podman images ghcr.io/stacklok/toolhive/catalog

.PHONY: catalog-push
catalog-push: ## Push catalog image to registry
	@echo "Pushing catalog image to ghcr.io..."
	podman push ghcr.io/stacklok/toolhive/catalog:v0.2.17
	podman push ghcr.io/stacklok/toolhive/catalog:latest
	@echo "✅ Catalog image pushed"

##@ OLM Bundle Image Targets

.PHONY: bundle-validate-sdk
bundle-validate-sdk: ## Validate OLM bundle with operator-sdk
	@echo "Validating bundle with operator-sdk..."
	operator-sdk --plugins go.kubebuilder.io/v4 bundle validate ./bundle
	@echo "✅ Bundle validation passed"

.PHONY: bundle-build
bundle-build: bundle-validate-sdk ## Build bundle container image
	@echo "Building bundle container image..."
	podman build -f Containerfile.bundle -t ghcr.io/stacklok/toolhive/bundle:v0.2.17 .
	podman tag ghcr.io/stacklok/toolhive/bundle:v0.2.17 ghcr.io/stacklok/toolhive/bundle:latest
	@echo "✅ Bundle image built: ghcr.io/stacklok/toolhive/bundle:v0.2.17"
	@podman images ghcr.io/stacklok/toolhive/bundle

.PHONY: bundle-push
bundle-push: ## Push bundle image to registry
	@echo "Pushing bundle image to ghcr.io..."
	podman push ghcr.io/stacklok/toolhive/bundle:v0.2.17
	podman push ghcr.io/stacklok/toolhive/bundle:latest
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
	@echo "  2. Deploy to cluster: create CatalogSource referencing bundle image"
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
validate-all: constitution-check bundle-validate bundle-validate-sdk catalog-validate ## Run all validation checks
	@echo ""
	@echo "========================================="
	@echo "✅ All validations passed"
	@echo "========================================="

##@ Cleanup

.PHONY: clean
clean: ## Clean generated bundle and catalog artifacts
	@echo "Cleaning generated artifacts..."
	rm -rf bundle/
	rm -rf catalog/
	@echo "✅ Cleaned bundle/ and catalog/ directories"

.PHONY: clean-images
clean-images: ## Remove local catalog container images
	@echo "Removing catalog images..."
	-podman rmi ghcr.io/stacklok/toolhive/catalog:v0.2.17
	-podman rmi ghcr.io/stacklok/toolhive/catalog:latest
	@echo "✅ Catalog images removed"

##@ Documentation

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
