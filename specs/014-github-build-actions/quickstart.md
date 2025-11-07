# Quickstart: GitHub Actions Build Workflows

**Feature**: Automated container image builds for bundle, index, and catalog
**Branch**: `014-github-build-actions`
**Related**: [spec.md](spec.md) | [plan.md](plan.md)

## Overview

This guide documents how to use the GitHub Actions workflows to build and publish OLM container images to GitHub Container Registry (ghcr.io).

## Workflows Available

All workflows are now implemented and ready for use:

1. **[build-bundle.yml](../../.github/workflows/build-bundle.yml)** - Builds and pushes bundle image (required for all OLM versions)
2. **[build-index.yml](../../.github/workflows/build-index.yml)** - Builds and pushes OLMv0 index image (legacy OpenShift 4.15-4.18)
3. **[build-catalog.yml](../../.github/workflows/build-catalog.yml)** - Builds and pushes OLMv1 catalog image (modern OpenShift 4.19+)

## Prerequisites

- Push access to the repository (for triggering workflows)
- Repository must have `packages: write` permission (enabled by default)

## Manual Workflow Triggers

### Triggering Bundle Build

1. Go to: `https://github.com/{owner}/{repo}/actions`
2. Click **"Build Bundle Image"** in the left sidebar
3. Click **"Run workflow"** dropdown button
4. Select branch (usually `main` or your feature branch)
5. Click **"Run workflow"** green button
6. Monitor progress in the Actions tab

**Result**: Bundle image published to `ghcr.io/{owner}/{repo}/bundle:v{version}` and `:latest`

### Triggering Index Build (OLMv0)

1. Go to: `https://github.com/{owner}/{repo}/actions`
2. Click **"Build Index Image (OLMv0)"** in the left sidebar
3. Click **"Run workflow"** dropdown button
4. Select branch
5. Click **"Run workflow"** green button

**Result**: Index image published to `ghcr.io/{owner}/{repo}/index:v{version}` and `:latest`

### Triggering Catalog Build (OLMv1)

1. Go to: `https://github.com/{owner}/{repo}/actions`
2. Click **"Build Catalog Image (OLMv1)"** in the left sidebar
3. Click **"Run workflow"** dropdown button
4. Select branch
5. Click **"Run workflow"** green button

**Result**: Catalog image published to `ghcr.io/{owner}/{repo}/catalog:v{version}` and `:latest`

## Verifying Published Images

### Via GitHub Web UI

1. Go to the repository main page: `https://github.com/{owner}/{repo}`
2. Click **"Packages"** in the right sidebar
3. You should see:
   - `bundle` (if bundle workflow ran)
   - `index` (if index workflow ran)
   - `catalog` (if catalog workflow ran)
4. Click on a package to see available tags

### Via Command Line

```bash
# Pull the published images
podman pull ghcr.io/{owner}/{repo}/bundle:v0.4.2
podman pull ghcr.io/{owner}/{repo}/index:v0.4.2
podman pull ghcr.io/{owner}/{repo}/catalog:v0.4.2

# Or with latest tag
podman pull ghcr.io/{owner}/{repo}/bundle:latest
```

### Via Workflow Logs

1. Go to: `https://github.com/{owner}/{repo}/actions`
2. Click on the completed workflow run
3. Expand the build job
4. Look for "Published image URL" in the logs

Example output:
```
✅ Published: ghcr.io/stacklok/toolhive-operator-metadata/bundle:v0.4.2
✅ Published: ghcr.io/stacklok/toolhive-operator-metadata/bundle:latest
```

## Repository-Based Naming

Images are published to the repository's ghcr.io namespace:

**Upstream (stacklok/toolhive-operator-metadata)**:
- Bundle: `ghcr.io/stacklok/toolhive-operator-metadata/bundle:v{version}`
- Index: `ghcr.io/stacklok/toolhive-operator-metadata/index:v{version}`
- Catalog: `ghcr.io/stacklok/toolhive-operator-metadata/catalog:v{version}`

**Fork (roddiekieley/toolhive-operator-metadata)**:
- Bundle: `ghcr.io/roddiekieley/toolhive-operator-metadata/bundle:v{version}`
- Index: `ghcr.io/roddiekieley/toolhive-operator-metadata/index:v{version}`
- Catalog: `ghcr.io/roddiekieley/toolhive-operator-metadata/catalog:v{version}`

This allows each fork to have its own image registry for development/testing.

## Workflow Details

### Build Bundle Image

**Duration**: ~2-3 minutes

**Steps**:
1. Checkout repository
2. Install dependencies (yq)
3. Generate bundle manifests (`make bundle`)
4. Validate bundle (`operator-sdk bundle validate`)
5. Build and push bundle image
6. Tag as `:latest`

**Prerequisites**:
- Makefile with `bundle` target
- Bundle generation script
- CRDs in `config/crd/bases/`

### Build Index Image (OLMv0)

**Duration**: ~4-5 minutes

**Steps**:
1. Checkout repository
2. Install dependencies (yq, opm)
3. Generate bundle
4. Build bundle image (locally)
5. Build index using `opm index add --permissive`
6. Push index image
7. Tag as `:latest`

**Prerequisites**:
- Makefile with `index-olmv0-build` target
- Bundle artifacts

**Note**: Uses `--permissive` mode to work with local bundle images.

### Build Catalog Image (OLMv1)

**Duration**: ~3-4 minutes

**Steps**:
1. Checkout repository
2. Install dependencies (yq, opm)
3. Generate bundle
4. Generate catalog (`make catalog`)
5. Validate catalog (`opm validate`)
6. Build and push catalog image
7. Tag as `:latest`

**Prerequisites**:
- Makefile with `catalog` target
- Catalog generation working
- FBC structure valid

## Troubleshooting

### Workflow Fails: "Permission denied"

**Cause**: User doesn't have push access to repository

**Solution**: Request write access from repository maintainers

### Workflow Fails: "Error: GITHUB_TOKEN permissions"

**Cause**: Token lacks `packages: write` permission

**Solution**:
1. Go to repository Settings → Actions → General
2. Scroll to "Workflow permissions"
3. Select "Read and write permissions"
4. Save changes
5. Re-run workflow

### Workflow Fails: "make: command not found"

**Cause**: Workflow runner missing dependencies

**Solution**: This should not happen with ubuntu-latest runners. If it does, check workflow YAML for correct runner specification.

### Image Not Visible in Packages

**Cause**: Package visibility set to private or not linked to repository

**Solution**:
1. Go to `https://github.com/{owner}?tab=packages`
2. Find the package (`bundle`, `index`, or `catalog`)
3. Click on it
4. Click "Package settings"
5. Change visibility if needed
6. Link to repository if not linked

### Bundle Validation Fails

**Cause**: CSV or CRD structure invalid

**Solution**:
1. Check workflow logs for specific validation errors
2. Fix issues locally using `make bundle-validate-sdk`
3. Commit fixes
4. Re-run workflow

### Index Build Fails: "Bundle image not found"

**Cause**: Bundle image doesn't exist locally or remotely

**Solution**: Run bundle workflow first, then run index workflow

### Catalog Validation Fails

**Cause**: FBC structure invalid

**Solution**:
1. Test locally: `make catalog-validate`
2. Fix FBC structure in `catalog/` directory
3. Commit fixes
4. Re-run workflow

## Best Practices

1. **Build Order**: Always build bundle first, then index/catalog
2. **Test Locally**: Run `make bundle`, `make catalog`, etc. locally before triggering workflows
3. **Check Logs**: Always review workflow logs for warnings or issues
4. **Version Tags**: Workflows use version from Makefile - ensure it's correct before building
5. **Fork Development**: Test in your fork before pushing to upstream

## Integration with Local Development

Workflows use the same Makefile targets as local development:

**Local**:
```bash
make bundle
make bundle-build
make bundle-push
```

**GitHub Actions**:
- Uses `make bundle` for manifest generation
- Uses Docker commands for build/push
- Automatically tags `:latest`

This ensures consistency between local and CI/CD builds.

## Next Steps

After successfully building images:

1. **Deploy to cluster**: Use the published images in your CatalogSource
2. **Test operator installation**: Verify OLM can install from published images
3. **Update documentation**: Document which image versions are tested/supported
4. **Consider automation**: Add automatic triggers (on git tags, releases, etc.)

## Security Notes

- `GITHUB_TOKEN` is automatically provided and scoped to the workflow
- Images are published to repository's ghcr.io namespace
- Package visibility can be public or private (configure in package settings)
- No manual PAT (Personal Access Token) required