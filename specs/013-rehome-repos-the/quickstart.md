# Quickstart: Repository Rehoming Implementation

**Feature**: Update repository location and container image URLs to production destinations
**Branch**: `013-rehome-repos-the`
**Related**: [spec.md](spec.md) | [plan.md](plan.md)

## Overview

This guide documents the process for updating all repository references and container image URLs from development/test locations to production locations at `github.com/stacklok/toolhive-operator-metadata` and `ghcr.io/stacklok/toolhive/` (operator-bundle, operator-catalog, operator-index).

## Prerequisites

- Repository cloned and on branch `013-rehome-repos-the`
- Development tools installed: kustomize, operator-sdk, yq, podman
- Ability to run `make` targets

## Implementation Steps

### 1. Identify Current URLs

First, locate all existing repository and image URL references:

```bash
# Find repository references
grep -r "github.com" --include="*.md" --include="Makefile" --include="*.sh" .

# Find container image registry references
grep -r "ghcr.io" --include="*.md" --include="Makefile" --include="*.yaml" --include="*.sh" .

# Find bundle/catalog/index image references
grep -r "bundle\|catalog\|index" Makefile scripts/
```

**Expected Locations**:
- `Makefile`: Image URL variables (BUNDLE_IMAGE, CATALOG_IMAGE, INDEX_IMAGE)
- `config/base/params.env`: Image base URLs for kustomize substitution
- `scripts/generate-csv-from-kustomize.sh`: Bundle image reference in CSV template
- `README.md`: Repository clone examples, image reference examples
- `CLAUDE.md`: Project description and repository location
- `VALIDATION.md`: Image URL examples in validation documentation

### 2. Update Configuration Files

#### Makefile

Update image URL variables to production destinations:

```makefile
# Find these variables and update base URLs:
BUNDLE_IMAGE ?= ghcr.io/stacklok/toolhive/operator-bundle:v$(VERSION)
CATALOG_IMAGE ?= ghcr.io/stacklok/toolhive/operator-catalog:latest
INDEX_IMAGE ?= ghcr.io/stacklok/toolhive/operator-index:v$(VERSION)
```

#### config/base/params.env

Update kustomize parameter values:

```bash
# Update image base URLs if present
# Format: KEY=VALUE
# Example: toolhive-bundle-image=ghcr.io/stacklok/toolhive/operator-bundle:v0.4.2
```

#### scripts/generate-csv-from-kustomize.sh

Update the CSV template section that references the bundle image:

```bash
# Find the section that generates the CSV containerImage field
# Update to reference: ghcr.io/stacklok/toolhive/operator-bundle:${VERSION}
```

### 3. Update Documentation

#### README.md

Update repository references:

```markdown
# Change git clone examples
git clone https://github.com/stacklok/toolhive-operator-metadata

# Update image reference examples
ghcr.io/stacklok/toolhive/operator-bundle:v0.4.2
ghcr.io/stacklok/toolhive/operator-catalog:latest
ghcr.io/stacklok/toolhive/operator-index:v0.4.2
```

#### CLAUDE.md

Update project description:

```markdown
# Update repository location reference
This repository (https://github.com/stacklok/toolhive-operator-metadata) contains...
```

#### VALIDATION.md

Update any image URL examples in validation documentation.

### 4. Enhance Version Consistency Script

Update `scripts/verify-version-consistency.sh` to validate image base URLs:

```bash
# Add validation section
EXPECTED_BUNDLE_BASE="ghcr.io/stacklok/toolhive/operator-bundle"
EXPECTED_CATALOG_BASE="ghcr.io/stacklok/toolhive/operator-catalog"
EXPECTED_INDEX_BASE="ghcr.io/stacklok/toolhive/operator-index"

# Check Makefile variables
# Check params.env
# Check generated bundle CSV
# Fail if non-production URLs detected
```

### 5. Verification

#### Clean and Rebuild

```bash
# Clean all generated artifacts
make clean-all

# Rebuild everything with new URLs
make olm-all
```

#### Verify Generated Artifacts

```bash
# Check bundle CSV for correct image URL
grep "containerImage:" bundle/manifests/toolhive-operator.clusterserviceversion.yaml
# Expected: ghcr.io/stacklok/toolhive/operator-bundle:v0.4.2

# Check catalog FBC for correct bundle reference
grep "image:" catalog/toolhive-operator-catalog.yaml | head -5
# Expected: ghcr.io/stacklok/toolhive/operator-bundle:v0.4.2

# Check index image tag
podman images | grep index
# Expected: ghcr.io/stacklok/toolhive/operator-index
```

#### Run Version Consistency Check

```bash
# Verify all version numbers AND image base URLs are correct
make verify-version-consistency
# Expected: PASS with no warnings about incorrect URLs
```

#### Run Constitutional Compliance Checks

```bash
# Verify kustomize builds
make kustomize-validate
# Expected: Both config/base and config/default build successfully

# Validate bundle
make bundle-validate
# Expected: Bundle structure valid

# Validate catalog
make catalog-validate
# Expected: Catalog FBC valid

# Run scorecard tests
make scorecard-test
# Expected: All 6 tests pass (URL changes should not affect scorecard)
```

### 6. Final Validation Checklist

- [ ] All Makefile image variables use `ghcr.io/stacklok/toolhive/` base
- [ ] `config/base/params.env` uses production image URLs (if applicable)
- [ ] `scripts/generate-csv-from-kustomize.sh` generates CSV with production bundle URL
- [ ] README.md references `github.com/stacklok/toolhive-operator-metadata`
- [ ] CLAUDE.md references correct repository location
- [ ] VALIDATION.md uses production image URLs in examples
- [ ] `make clean-all && make olm-all` succeeds
- [ ] Generated bundle CSV contains `ghcr.io/stacklok/toolhive/operator-bundle:v[VERSION]`
- [ ] Generated catalog FBC references production bundle URL
- [ ] Index image tagged as `ghcr.io/stacklok/toolhive/operator-index:v[VERSION]`
- [ ] `make verify-version-consistency` passes
- [ ] `make kustomize-validate` passes
- [ ] `make bundle-validate` passes
- [ ] `make catalog-validate` passes
- [ ] `make scorecard-test` passes (6/6 tests)
- [ ] No old/development URLs remain in any files

## Troubleshooting

### Issue: Scorecard tests fail after URL changes

**Cause**: Bundle image URL in CSV doesn't match expected format or is unreachable

**Solution**:
1. Verify CSV containerImage field format: `ghcr.io/stacklok/toolhive/operator-bundle:v[VERSION]`
2. Ensure VERSION matches OPERATOR_TAG in Makefile
3. Regenerate bundle: `make clean && make bundle`

### Issue: Catalog validation fails

**Cause**: Catalog FBC references non-existent bundle image

**Solution**:
1. Verify catalog generation script uses correct bundle URL
2. Check catalog YAML for image reference format
3. Regenerate catalog: `make catalog`

### Issue: Version consistency script reports errors

**Cause**: Mixed URL patterns or incorrect base URLs detected

**Solution**:
1. Review script output for specific file and line numbers
2. Update flagged files with production URLs
3. Re-run verification

## Success Criteria

All validation steps pass and generated artifacts contain only production URLs:

✅ `make olm-all` completes successfully
✅ `make verify-version-consistency` passes
✅ `make scorecard-test` shows 6/6 tests passing
✅ All constitutional compliance checks pass
✅ No development/test URLs found in any committed files or generated artifacts

## Next Steps

After successful validation:

1. Review changes with `git diff`
2. Commit changes with descriptive message referencing feature 013
3. Push to remote and create pull request
4. Verify CI/CD pipelines pass (if configured)
5. Deploy artifacts to production registry when approved