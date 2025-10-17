# Implementation Tasks: Custom Icon Support for OLM Bundle and Catalog

**Feature**: 009-allow-icon-customization
**Branch**: `009-allow-icon-customization`
**Created**: 2025-10-17

## Overview

This document provides a dependency-ordered task breakdown for implementing custom icon support in OLM bundle and catalog builds. Tasks are organized by user story to enable independent implementation and testing of each feature increment.

**Total Tasks**: 21
**Estimated Time**: 4-6 hours
**MVP Scope**: Phase 3 (User Story 1) - Basic icon customization

## Implementation Strategy

**Incremental Delivery**: Each phase represents an independently testable feature increment:
- **Phase 1-2**: Setup and foundational work (required for all stories)
- **Phase 3 (US1)**: MVP - Basic icon customization with default fallback
- **Phase 4 (US2)**: Enhanced - Icon validation with clear error messages
- **Phase 5 (US3)**: Advanced - Separate bundle/catalog icon support
- **Phase 6**: Polish and documentation

Each user story can be demonstrated independently once its phase is complete.

---

## Phase 1: Setup & Infrastructure

**Purpose**: Initialize project structure and create test fixtures

**Dependencies**: None

### T001 - [Setup] Create icons directory structure

**Story**: Infrastructure
**File**: `icons/`
**Parallel**: No

Create directory structure for default icons and documentation:

```bash
mkdir -p icons
mkdir -p tests/icons
```

**Deliverable**: Empty directory structure ready for icon files

---

### T002 - [Setup] Create OLM-compliant default icon

**Story**: Infrastructure
**File**: `icons/default-icon.svg`
**Parallel**: No
**Depends on**: T001

Create a new default icon that meets OLM requirements (80x40, 1:2 aspect ratio):

```svg
<svg width="80" height="40" xmlns="http://www.w3.org/2000/svg">
  <rect width="80" height="40" fill="#007fff"/>
  <text x="50%" y="50%" font-size="24" fill="white"
        text-anchor="middle" dominant-baseline="middle">M</text>
</svg>
```

**Acceptance**: Icon is 80x40 pixels, displays correctly when opened

---

### T003 - [Setup] Create test fixture icons [P]

**Story**: Infrastructure
**File**: `tests/icons/`
**Parallel**: Yes (after T001)
**Depends on**: T001

Create test icon fixtures for validation testing:

1. `valid-png-80x40.png` - Valid 80x40 PNG (1:2 ratio)
2. `valid-svg-80x40.svg` - Valid 80x40 SVG
3. `valid-jpeg-80x40.jpg` - Valid 80x40 JPEG
4. `valid-gif-80x40.gif` - Valid 80x40 GIF
5. `invalid-webp.webp` - Unsupported format
6. `invalid-100x50.png` - Oversized dimensions
7. `invalid-80x60.png` - Wrong aspect ratio
8. `invalid-512x512.png` - Significantly oversized
9. `corrupted.png` - Intentionally corrupted file

**Acceptance**: All 9 test fixtures exist and have correct properties

---

### T004 - [Setup] Create scripts directory

**Story**: Infrastructure
**File**: `scripts/`
**Parallel**: Yes (after root)
**Depends on**: None

```bash
mkdir -p scripts
chmod +x scripts/  # Ensure scripts will be executable
```

**Deliverable**: Empty scripts directory

---

## Phase 2: Foundational Implementation

**Purpose**: Core validation and encoding scripts required by all user stories

**Dependencies**: Phase 1 complete

### T005 - [Foundation] Implement icon encoding script

**Story**: Foundation (required for US1, US2, US3)
**File**: `scripts/encode-icon.sh`
**Parallel**: Yes
**Depends on**: T004

Implement base64 encoding script per contract specification:

**Script requirements**:
- Accept icon file path and optional mediatype parameter
- Auto-detect mediatype from file extension if not provided
- Output single-line base64-encoded data to stdout
- Output `MEDIATYPE:<type>` to stderr for caller parsing
- Exit 0 on success, 1 on encoding failure
- Handle macOS vs Linux base64 differences (`-w 0` flag)

**Reference**: `contracts/encode-icon-contract.md`

**Test command**:
```bash
./scripts/encode-icon.sh tests/icons/valid-png-80x40.png 2>meta.tmp
```

**Acceptance**:
- Script encodes all valid test fixtures successfully
- Output is single-line base64
- MEDIATYPE correctly detected from extension

---

### T006 - [Foundation] Implement icon validation script

**Story**: Foundation (required for US2)
**File**: `scripts/validate-icon.sh`
**Parallel**: Yes
**Depends on**: T004

Implement comprehensive validation script per contract specification:

**Script requirements**:
- Check file existence and readability (exit 1 if not found)
- Validate format using `file` command (exit 2 if unsupported)
- Extract dimensions using ImageMagick `identify` (exit 3 if oversized)
- Calculate and validate aspect ratio (exit 4 if not 1:2 ±5%)
- Check file is parseable (exit 5 if corrupted)
- Output detailed error messages to stderr with actionable guidance

**Exit codes**:
- 0: Valid icon
- 1: File not found
- 2: Unsupported format
- 3: Dimensions exceed 80x40
- 4: Aspect ratio not 1:2
- 5: File unreadable/corrupted

**Reference**: `contracts/validate-icon-contract.md`

**Test commands**:
```bash
# Should pass
./scripts/validate-icon.sh tests/icons/valid-png-80x40.png
echo $?  # Should be 0

# Should fail with exit 2
./scripts/validate-icon.sh tests/icons/invalid-webp.webp

# Should fail with exit 3
./scripts/validate-icon.sh tests/icons/invalid-100x50.png

# Should fail with exit 4
./scripts/validate-icon.sh tests/icons/invalid-80x60.png
```

**Acceptance**:
- All test fixtures validate correctly
- Error messages are clear and actionable
- Validation completes in <1 second

---

## Phase 3: User Story 1 - Basic Icon Customization (MVP)

**Story**: US1 - Replace Default Icon with Custom Branding (Priority P1)

**Goal**: Enable developers to build bundles with custom icons by specifying `BUNDLE_ICON` parameter

**Independent Test**:
```bash
make bundle BUNDLE_ICON=tests/icons/valid-png-80x40.png
yq eval '.spec.icon[0].mediatype' bundle/manifests/toolhive-operator.clusterserviceversion.yaml
# Should output: image/png
```

**Dependencies**: Phase 2 complete

---

### T007 - [US1] Add BUNDLE_ICON parameter handling to Makefile

**Story**: US1
**File**: `Makefile` (bundle target)
**Parallel**: No
**Depends on**: T005

Modify the `bundle` target to support optional `BUNDLE_ICON` parameter:

```makefile
# Add after existing bundle target documentation
# New environment variable:
# BUNDLE_ICON - Path to custom icon file (optional, defaults to icons/default-icon.svg)

.PHONY: bundle
bundle:
	@echo "Generating OLM bundle from downloaded operator files..."
	# ... existing bundle generation code ...
	@# Icon customization (new code)
	@if [ -n "$(BUNDLE_ICON)" ]; then \
		echo "Encoding custom bundle icon: $(BUNDLE_ICON)"; \
		ENCODED=$$(scripts/encode-icon.sh "$(BUNDLE_ICON)" 2>bundle_icon_meta.tmp) || exit 1; \
		MEDIATYPE=$$(grep "^MEDIATYPE:" bundle_icon_meta.tmp | cut -d: -f2); \
		yq eval '.spec.icon = [{"base64data": "'"$$ENCODED"'", "mediatype": "'"$$MEDIATYPE"'"}]' \
		  -i bundle/manifests/toolhive-operator.clusterserviceversion.yaml || exit 1; \
		rm -f bundle_icon_meta.tmp; \
		echo "✅ Custom icon encoded and injected"; \
	else \
		echo "Using default icon from icons/default-icon.svg"; \
		ENCODED=$$(scripts/encode-icon.sh "icons/default-icon.svg" 2>bundle_icon_meta.tmp) || exit 1; \
		MEDIATYPE=$$(grep "^MEDIATYPE:" bundle_icon_meta.tmp | cut -d: -f2); \
		yq eval '.spec.icon = [{"base64data": "'"$$ENCODED"'", "mediatype": "'"$$MEDIATYPE"'"}]' \
		  -i bundle/manifests/toolhive-operator.clusterserviceversion.yaml || exit 1; \
		rm -f bundle_icon_meta.tmp; \
	fi
	# ... rest of existing bundle generation ...
```

**Acceptance**:
- `make bundle` works without BUNDLE_ICON (uses default)
- `make bundle BUNDLE_ICON=path/to/icon.png` uses custom icon
- CSV contains base64-encoded icon after build

---

### T008 - [US1] Update catalog target for icon inheritance

**Story**: US1
**File**: `Makefile` (catalog target)
**Parallel**: No
**Depends on**: T007

Ensure catalog inherits icon from bundle via `opm render`:

**Implementation**: No code changes needed - `opm render` automatically embeds the bundle CSV (with icon) into the catalog's `olm.bundle.object`.

**Verification task**: Add comment documenting icon inheritance:

```makefile
.PHONY: catalog
catalog: bundle  # Depends on bundle to ensure icon is embedded
	@echo "Generating FBC catalog from bundle..."
	# Note: Icon is automatically inherited from bundle CSV via opm render
	@opm render bundle/ -o yaml | sed '1d' | sed '/^image:/d' >> catalog/toolhive-operator/catalog.yaml
	# ... rest of catalog generation ...
```

**Acceptance**:
- `make catalog` embeds bundle icon in `olm.bundle.object`
- Decoding catalog's bundle object shows custom icon

---

### T009 - [US1] Create icon documentation

**Story**: US1
**File**: `icons/README.md`
**Parallel**: Yes
**Depends on**: T002

Document icon requirements and usage:

```markdown
# Operator Icons

This directory contains operator icons for OLM bundle and catalog builds.

## OLM Icon Requirements

- **Formats**: PNG, JPEG, GIF, or SVG
- **Maximum dimensions**: 80px width × 40px height
- **Aspect ratio**: 1:2 (height:width)
- **File size**: <100 KB recommended

## Default Icon

`default-icon.svg` - Blue background with white "M" letter (80x40, 1:2 ratio)

## Usage

### Build bundle with custom icon:
```bash
make bundle BUNDLE_ICON=path/to/your-icon.png
```

### Build bundle with default icon:
```bash
make bundle  # No BUNDLE_ICON parameter
```

## Creating Custom Icons

See [quickstart.md](../specs/009-allow-icon-customization/quickstart.md) for icon creation tips and examples.
```

**Acceptance**: README exists and documents basic usage

---

### ✅ CHECKPOINT: Phase 3 Complete - MVP Functional

**Deliverables**:
- ✅ Developers can specify `BUNDLE_ICON=path` to use custom icons
- ✅ Catalog inherits bundle icon automatically
- ✅ Default icon used when no custom icon specified
- ✅ Icon appears in bundle CSV as base64-encoded data

**Test US1 Acceptance Criteria**:
```bash
# Test 1: Custom PNG icon
make bundle BUNDLE_ICON=tests/icons/valid-png-80x40.png
yq eval '.spec.icon[0]' bundle/manifests/toolhive-operator.clusterserviceversion.yaml
# Should show base64data and mediatype: image/png

# Test 2: Custom SVG icon
make bundle BUNDLE_ICON=tests/icons/valid-svg-80x40.svg
# Should succeed

# Test 3: Default icon fallback
make bundle
# Should use icons/default-icon.svg
```

**MVP Decision Point**: Can ship Phase 3 as minimal viable feature

---

## Phase 4: User Story 2 - Icon Validation (Enhanced)

**Story**: US2 - Prevent Invalid Icons (Priority P2)

**Goal**: Add validation to prevent common icon mistakes with clear error messages

**Independent Test**:
```bash
# Should fail with clear error
make bundle BUNDLE_ICON=tests/icons/invalid-webp.webp
# Expected: "ERROR: Unsupported format 'image/webp'. Use PNG, JPEG, GIF, or SVG only"

make bundle BUNDLE_ICON=tests/icons/invalid-100x50.png
# Expected: "ERROR: Icon dimensions 100x50 exceed maximum 80x40"
```

**Dependencies**: Phase 3 complete, T006 (validation script) complete

---

### T010 - [US2] Integrate validation into bundle target

**Story**: US2
**File**: `Makefile` (bundle target)
**Parallel**: No
**Depends on**: T006, T007

Add validation call before encoding in bundle target:

```makefile
	@if [ -n "$(BUNDLE_ICON)" ]; then \
		echo "Validating custom bundle icon: $(BUNDLE_ICON)"; \
		scripts/validate-icon.sh "$(BUNDLE_ICON)" || { \
			echo "❌ Bundle icon validation failed" >&2; \
			exit 1; \
		}; \
		echo "✅ Icon validation passed"; \
		echo "Encoding custom bundle icon: $(BUNDLE_ICON)"; \
		# ... rest of encoding logic from T007 ...
	else \
		# Default icon - skip validation (already validated)
		# ... encoding logic for default icon ...
	fi
```

**Acceptance**:
- Invalid icons cause build to fail with clear error messages
- Valid icons pass validation and build succeeds
- Build stops immediately on validation failure (no partial updates)

---

### T011 - [US2] Add manual validation target

**Story**: US2
**File**: `Makefile` (new target)
**Parallel**: Yes
**Depends on**: T006

Create standalone validation target for manual testing:

```makefile
.PHONY: validate-icon
validate-icon: ## Validate an icon file against OLM requirements
	@if [ -z "$(ICON)" ]; then \
		echo "Usage: make validate-icon ICON=path/to/icon.png" >&2; \
		exit 1; \
	fi
	@scripts/validate-icon.sh "$(ICON)"
	@echo "✅ Icon is valid"
```

**Acceptance**:
```bash
make validate-icon ICON=tests/icons/valid-png-80x40.png
# Should output: ✅ Icon is valid

make validate-icon ICON=tests/icons/invalid-webp.webp
# Should fail with error message
```

---

### T012 - [US2] Update help target with validate-icon

**Story**: US2
**File**: `Makefile` (help target)
**Parallel**: Yes
**Depends on**: T011

Add validate-icon to Makefile help output:

```makefile
help: ## Display available targets
	# ... existing help entries ...
	@echo "  validate-icon    Validate an icon file (requires ICON=path)"
	@echo "  bundle           Generate OLM bundle (optional: BUNDLE_ICON=path)"
```

**Acceptance**: `make help` shows validate-icon target

---

### ✅ CHECKPOINT: Phase 4 Complete - Validation Active

**Deliverables**:
- ✅ Invalid icons rejected during build with actionable error messages
- ✅ Manual validation target available for pre-build testing
- ✅ Build process fails fast on validation errors

**Test US2 Acceptance Criteria**:
```bash
# Test 1: Unsupported format
make bundle BUNDLE_ICON=tests/icons/invalid-webp.webp
# Exit code 1, error: "Unsupported format..."

# Test 2: Oversized dimensions
make bundle BUNDLE_ICON=tests/icons/invalid-100x50.png
# Exit code 1, error: "Icon dimensions 100x50 exceed maximum 80x40"

# Test 3: Wrong aspect ratio
make bundle BUNDLE_ICON=tests/icons/invalid-80x60.png
# Exit code 1, error: "Icon aspect ratio ... must be 1:2"

# Test 4: Corrupted file
make bundle BUNDLE_ICON=tests/icons/corrupted.png
# Exit code 1, error: "Cannot read icon file"
```

---

## Phase 5: User Story 3 - Separate Bundle/Catalog Icons (Advanced)

**Story**: US3 - Use Different Icons for Bundle and Catalog (Priority P3)

**Goal**: Support different icons for bundle (high-res) vs catalog (optimized) for advanced users

**Independent Test**:
```bash
make bundle BUNDLE_ICON=tests/icons/valid-png-80x40.png
make catalog CATALOG_ICON=tests/icons/valid-svg-80x40.svg
# Bundle CSV should have PNG icon, catalog should have SVG icon
```

**Dependencies**: Phase 4 complete

---

### T013 - [US3] Add CATALOG_ICON parameter to catalog target

**Story**: US3
**File**: `Makefile` (catalog target)
**Parallel**: No
**Depends on**: T010

Modify catalog target to support optional `CATALOG_ICON` parameter:

```makefile
.PHONY: catalog
catalog: bundle
	@echo "Generating FBC catalog from bundle..."
	# ... existing catalog header generation ...

	@# Handle catalog-specific icon (new code)
	@if [ -n "$(CATALOG_ICON)" ]; then \
		echo "Using separate catalog icon: $(CATALOG_ICON)"; \
		echo "Validating catalog icon..."; \
		scripts/validate-icon.sh "$(CATALOG_ICON)" || { \
			echo "❌ Catalog icon validation failed" >&2; \
			exit 1; \
		}; \
		echo "Encoding catalog icon..."; \
		ENCODED=$$(scripts/encode-icon.sh "$(CATALOG_ICON)" 2>catalog_icon_meta.tmp) || exit 1; \
		MEDIATYPE=$$(grep "^MEDIATYPE:" catalog_icon_meta.tmp | cut -d: -f2); \
		echo "Updating bundle CSV with catalog icon before rendering..."; \
		yq eval '.spec.icon = [{"base64data": "'"$$ENCODED"'", "mediatype": "'"$$MEDIATYPE"'"}]' \
		  -i bundle/manifests/toolhive-operator.clusterserviceversion.yaml || exit 1; \
		rm -f catalog_icon_meta.tmp; \
		echo "✅ Catalog-specific icon applied"; \
	else \
		echo "Using bundle icon for catalog (no CATALOG_ICON specified)"; \
	fi

	@# Render bundle with (potentially updated) icon
	@opm render bundle/ -o yaml | sed '1d' | sed '/^image:/d' >> catalog/toolhive-operator/catalog.yaml
	# ... rest of catalog generation ...
```

**Acceptance**:
- `make catalog` uses bundle icon (no CATALOG_ICON)
- `make catalog CATALOG_ICON=path` uses separate catalog icon
- Catalog embeds correct icon in `olm.bundle.object`

---

### T014 - [US3] Document separate icon usage

**Story**: US3
**File**: `icons/README.md`
**Parallel**: Yes
**Depends on**: T009

Update icon README with advanced usage:

```markdown
## Advanced Usage

### Use different icons for bundle vs catalog:

```bash
# Build bundle with high-resolution PNG
make bundle BUNDLE_ICON=icons/logo-hires.png

# Build catalog with optimized SVG
make catalog CATALOG_ICON=icons/logo-optimized.svg
```

**Use case**: Balance quality (bundle) and file size (catalog)

### Icon inheritance:

By default, catalog uses the same icon as bundle. Specify `CATALOG_ICON` only if you need a different icon for distribution.
```

**Acceptance**: README documents advanced usage

---

### ✅ CHECKPOINT: Phase 5 Complete - Advanced Features

**Deliverables**:
- ✅ Support for separate bundle and catalog icons
- ✅ Catalog inherits bundle icon by default (backward compatible)
- ✅ Documentation covers advanced use cases

**Test US3 Acceptance Criteria**:
```bash
# Test 1: Separate icons for bundle and catalog
make bundle BUNDLE_ICON=tests/icons/valid-png-80x40.png
make catalog CATALOG_ICON=tests/icons/valid-svg-80x40.svg
# Catalog should have SVG icon embedded

# Test 2: Icon inheritance
make bundle BUNDLE_ICON=tests/icons/valid-png-80x40.png
make catalog  # No CATALOG_ICON specified
# Catalog should inherit PNG icon from bundle
```

---

## Phase 6: Polish & Documentation

**Purpose**: Cross-cutting improvements, documentation, and quality enhancements

**Dependencies**: Phases 3-5 complete

---

### T015 - [Polish] Make scripts executable

**Story**: Polish
**File**: `scripts/*.sh`
**Parallel**: No
**Depends on**: T005, T006

Ensure all scripts have execute permissions:

```bash
chmod +x scripts/validate-icon.sh
chmod +x scripts/encode-icon.sh
```

**Acceptance**: Scripts can be executed directly without `bash` prefix

---

### T016 - [Polish] Add scripts dependency check

**Story**: Polish
**File**: `scripts/validate-icon.sh`
**Parallel**: Yes
**Depends on**: T006

Add dependency validation at top of validate-icon.sh:

```bash
#!/usr/bin/env bash
set -euo pipefail

# Check required tools
command -v file >/dev/null 2>&1 || {
  echo "ERROR: 'file' command not found. Install file package." >&2
  exit 127
}

command -v identify >/dev/null 2>&1 || {
  echo "ERROR: ImageMagick 'identify' not found. Install imagemagick package." >&2
  exit 127
}

command -v bc >/dev/null 2>&1 || {
  echo "ERROR: 'bc' command not found. Install bc package." >&2
  exit 127
}

# ... rest of validation script ...
```

**Acceptance**: Script fails gracefully if dependencies missing

---

### T017 - [Polish] Add macOS base64 compatibility

**Story**: Polish
**File**: `scripts/encode-icon.sh`
**Parallel**: Yes
**Depends on**: T005

Handle macOS vs Linux base64 flag differences:

```bash
#!/usr/bin/env bash
set -euo pipefail

# ... parameter handling ...

# Encode with platform-specific flags
if [[ "$OSTYPE" == "darwin"* ]]; then
  # macOS: base64 outputs without wrapping by default
  base64 -i "$icon_file" 2>&1 || {
    echo "ERROR: Base64 encoding failed for: $icon_file" >&2
    exit 1
  }
else
  # Linux: use -w 0 to disable wrapping
  base64 -w 0 "$icon_file" 2>&1 || {
    echo "ERROR: Base64 encoding failed for: $icon_file" >&2
    exit 1
  }
fi
```

**Acceptance**: Script works on both Linux and macOS

---

### T018 - [Polish] Update main README

**Story**: Polish
**File**: `README.md` (root)
**Parallel**: Yes
**Depends on**: T014

Add icon customization section to main README:

```markdown
## Icon Customization

Customize the operator icon displayed in OperatorHub:

```bash
# Build with custom icon
make bundle BUNDLE_ICON=path/to/your-icon.png

# Icon requirements:
# - Format: PNG, JPEG, GIF, or SVG
# - Max size: 80x40 pixels
# - Aspect ratio: 1:2 (height:width)
```

See [icons/README.md](icons/README.md) for details and [quickstart guide](specs/009-allow-icon-customization/quickstart.md) for examples.
```

**Acceptance**: Main README mentions icon customization

---

### T019 - [Polish] Add .gitignore entry for icon metadata temp files

**Story**: Polish
**File**: `.gitignore`
**Parallel**: Yes
**Depends on**: None

Add temporary icon metadata files to .gitignore:

```gitignore
# Icon processing temp files
bundle_icon_meta.tmp
catalog_icon_meta.tmp
icon_metadata.tmp
```

**Acceptance**: Temp files not tracked by git

---

### T020 - [Polish] Create example icon usage in examples directory

**Story**: Polish
**File**: `examples/custom-icon-example.sh`
**Parallel**: Yes
**Depends on**: T013

Create example script demonstrating icon usage:

```bash
#!/usr/bin/env bash
# Example: Building OLM bundle and catalog with custom icons

set -euo pipefail

echo "=== Custom Icon Example ==="
echo ""

# Example 1: Build with single custom icon
echo "1. Building bundle with custom PNG icon..."
make bundle BUNDLE_ICON=icons/default-icon.svg
echo "✅ Bundle built with custom icon"
echo ""

# Example 2: Build catalog (inherits bundle icon)
echo "2. Building catalog (inherits bundle icon)..."
make catalog
echo "✅ Catalog built with inherited icon"
echo ""

# Example 3: Verify icon in CSV
echo "3. Verifying icon in CSV..."
MEDIATYPE=$(yq eval '.spec.icon[0].mediatype' bundle/manifests/toolhive-operator.clusterserviceversion.yaml)
echo "Icon mediatype: $MEDIATYPE"
echo ""

echo "=== Example Complete ==="
echo "See icons/README.md for more usage examples"
```

**Acceptance**: Example script demonstrates basic and advanced usage

---

### T021 - [Documentation] Create consolidated feature documentation

**Story**: Documentation
**File**: `specs/009-allow-icon-customization/README.md`
**Parallel**: Yes
**Depends on**: All previous tasks

Create feature overview document linking to all artifacts:

```markdown
# Feature 009: Custom Icon Support for OLM Bundle and Catalog

## Overview

Enable developers to customize operator icons for OLM bundles and File-Based Catalogs.

## Documentation

- **[Specification](spec.md)** - Feature requirements and user stories
- **[Implementation Plan](plan.md)** - Technical approach and architecture
- **[Quickstart Guide](quickstart.md)** - 5-minute getting started
- **[Tasks](tasks.md)** - Implementation task breakdown (this feature)

## Design Artifacts

- **[Research](research.md)** - Technical decisions and alternatives
- **[Data Model](data-model.md)** - Icon metadata and validation rules
- **[Contracts](contracts/)** - Script interfaces and error codes

## Usage

```bash
# Validate icon
make validate-icon ICON=path/to/icon.png

# Build with custom icon
make bundle BUNDLE_ICON=path/to/icon.png

# Build catalog
make catalog
```

## Requirements

- Icon format: PNG, JPEG, GIF, or SVG
- Max dimensions: 80x40 pixels
- Aspect ratio: 1:2 (height:width)

## Implementation Status

See [tasks.md](tasks.md) for task-by-task progress tracking.
```

**Acceptance**: Feature README provides navigation to all artifacts

---

### ✅ CHECKPOINT: Phase 6 Complete - Feature Finalized

**Deliverables**:
- ✅ Scripts are executable and platform-compatible
- ✅ Documentation is complete and consolidated
- ✅ Examples demonstrate usage
- ✅ Temp files ignored by git

---

## Task Dependencies

```
Setup Phase (T001-T004)
├── T001: Create icons directory
│   ├── T002: Create default icon
│   └── T003: Create test fixtures [P]
└── T004: Create scripts directory [P]

Foundation Phase (T005-T006)
├── T005: Implement encode-icon.sh (depends: T004) [P]
└── T006: Implement validate-icon.sh (depends: T004) [P]

User Story 1 - MVP (T007-T009)
├── T007: Add BUNDLE_ICON to Makefile (depends: T005)
├── T008: Update catalog target (depends: T007)
└── T009: Create icon docs (depends: T002) [P]

User Story 2 - Validation (T010-T012)
├── T010: Integrate validation into bundle (depends: T006, T007)
├── T011: Add validate-icon target (depends: T006) [P]
└── T012: Update help target (depends: T011) [P]

User Story 3 - Advanced (T013-T014)
├── T013: Add CATALOG_ICON to catalog (depends: T010)
└── T014: Document advanced usage (depends: T009) [P]

Polish Phase (T015-T021)
├── T015: Make scripts executable (depends: T005, T006)
├── T016: Add dependency checks (depends: T006) [P]
├── T017: macOS compatibility (depends: T005) [P]
├── T018: Update main README (depends: T014) [P]
├── T019: Update .gitignore [P]
├── T020: Create examples (depends: T013) [P]
└── T021: Feature documentation [P]
```

## Parallel Execution Opportunities

**Phase 1 Setup**:
```bash
# Can run in parallel after T001:
T003 (test fixtures) & T004 (scripts directory)
```

**Phase 2 Foundation**:
```bash
# Can run in parallel after T004:
T005 (encoding script) & T006 (validation script)
```

**Phase 4 Validation**:
```bash
# Can run in parallel after T010:
T011 (validate target) & T012 (help update)
```

**Phase 6 Polish**:
```bash
# Can run in parallel:
T016 & T017 & T018 & T019 & T020 & T021
```

**Total parallelizable tasks**: 11 out of 21 (52% can run in parallel)

## User Story Completion Order

1. **Phase 3 (US1)** - MVP: Basic icon customization
   - Delivers: Custom icon support with default fallback
   - Test: `make bundle BUNDLE_ICON=icon.png`

2. **Phase 4 (US2)** - Enhanced: Icon validation
   - Delivers: Error prevention with clear messages
   - Test: Invalid icons rejected at build time

3. **Phase 5 (US3)** - Advanced: Separate bundle/catalog icons
   - Delivers: Optimization flexibility
   - Test: Different icons for bundle vs catalog

Each story is independently deliverable and testable.

## Implementation Recommendations

### MVP First Approach (Fastest Time to Value)

1. Complete **Phase 1-2** (Setup + Foundation): ~1 hour
2. Complete **Phase 3** (US1 - MVP): ~1 hour
3. **Ship MVP** - Users can customize icons
4. Complete **Phase 4** (US2 - Validation): ~1 hour (optional enhancement)
5. Complete **Phase 5** (US3 - Advanced): ~30 minutes (optional)
6. Complete **Phase 6** (Polish): ~1 hour (documentation)

### Complete Feature Approach

Execute all phases sequentially: ~4-6 hours total

### Parallel Development Approach

With 2 developers:
- Developer A: T001-T006 (Setup + Foundation)
- Developer B: T003 (test fixtures creation)
- Then collaborate on US1-US3 implementation

Reduces total time to ~3-4 hours

## Testing Strategy

**Manual Testing** (no automated test suite requested):

After each phase, manually verify:

**Phase 3 (US1)**:
- Build with custom PNG icon
- Build with custom SVG icon
- Build without icon (default)
- Verify CSV contains base64 icon
- Deploy to OpenShift, check OperatorHub display

**Phase 4 (US2)**:
- Test all invalid fixtures (should fail)
- Test all valid fixtures (should pass)
- Verify error messages are clear

**Phase 5 (US3)**:
- Build with separate bundle/catalog icons
- Verify catalog has correct icon

## Files Modified/Created

**New Files** (11):
- `scripts/validate-icon.sh`
- `scripts/encode-icon.sh`
- `icons/default-icon.svg`
- `icons/README.md`
- `tests/icons/*.png|svg|jpg|gif|webp` (9 fixtures)
- `examples/custom-icon-example.sh`
- `specs/009-allow-icon-customization/README.md`

**Modified Files** (3):
- `Makefile` (bundle, catalog, validate-icon, help targets)
- `.gitignore` (temp files)
- `README.md` (icon section)

**Total**: 14 files created, 3 files modified

---

## Summary

- **Total Tasks**: 21
- **Parallel Tasks**: 11 (52%)
- **Estimated Time**: 4-6 hours (complete), 2-3 hours (MVP only)
- **MVP Scope**: Phases 1-3 (T001-T009)
- **User Stories**: 3 (prioritized P1, P2, P3)
- **Dependencies**: ImageMagick, yq, file, base64 (all standard Unix tools)

**Next Steps**: Begin with T001 (create icons directory structure)
