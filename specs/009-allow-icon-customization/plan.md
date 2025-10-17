# Implementation Plan: Custom Icon Support for OLM Bundle and Catalog

**Branch**: `009-allow-icon-customization` | **Date**: 2025-10-17 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/009-allow-icon-customization/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Enable developers to customize operator icons for OLM bundles and File-Based Catalogs by providing custom image files during the build process. The system will validate icon format (PNG, JPEG, GIF, SVG), dimensions (max 80x40px), and aspect ratio (1:2), then base64-encode and inject the icon into the ClusterServiceVersion. Supports both unified icon usage (same for bundle and catalog) and separate icons for advanced use cases.

## Technical Context

**Language/Version**: Shell scripts (Bash), Make (GNU Make 4.x+), YAML processing (yq v4.x)
**Primary Dependencies**:
- `yq` (YAML processor for CSV manipulation)
- `file` (file type detection)
- ImageMagick `identify` (dimension validation)
- `base64` (encoding utility - standard Unix tool)

**Storage**: Filesystem (icon files read from developer's local system)
**Testing**: Manual testing with sample icons, shell script unit tests (bats framework)
**Target Platform**: Linux/macOS development environments with Makefile tooling
**Project Type**: Build tooling enhancement (Makefile targets)
**Performance Goals**: Icon validation <1 second, total build overhead <5%
**Constraints**:
- Must not break existing Makefile workflow
- OLM icon limits: 80px × 40px maximum, 1:2 aspect ratio
- Supported formats only: PNG, JPEG, GIF, SVG+XML

**Scale/Scope**:
- Single feature addition to existing Makefile
- 2-3 new Makefile functions/targets
- Input validation script (~100-150 lines)
- Documentation updates

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Principle I: Manifest Integrity ✅ COMPLIANT

**Status**: This feature modifies the bundle generation process but preserves kustomize build functionality.

- `kustomize build config/base` will continue to work (operates on manifests, not bundle)
- `kustomize build config/default` will continue to work (operates on manifests, not bundle)
- Icon customization happens during `make bundle` after manifests are copied
- No changes to kustomize overlays or patches

**Validation**: Existing kustomize builds remain unaffected.

### Principle II: Kustomize-Based Customization ✅ COMPLIANT

**Status**: Icon customization is a build-time operation, not a manifest customization.

- Icons are injected into CSV via yq during bundle generation (Makefile)
- Not a kustomize concern - this modifies OLM bundle artifacts, not Kubernetes manifests
- Similar pattern to existing `make bundle` target that applies security patches via yq

**Validation**: Follows established pattern of build-time CSV modification.

### Principle III: CRD Immutability ✅ COMPLIANT

**Status**: No CRD modifications - this feature only touches ClusterServiceVersion (CSV).

- MCPRegistry and MCPServer CRDs remain unchanged
- Icon field exists in CSV metadata, not CRD schemas
- Downloaded CRD files are copied as-is

**Validation**: CRDs remain untouched throughout feature implementation.

### Principle IV: OpenShift Compatibility ✅ COMPLIANT

**Status**: Icon customization is platform-agnostic and doesn't affect OpenShift security contexts.

- Icon validation and encoding apply equally to all deployments
- No changes to `config/base` security patches or overlays
- OLM/OperatorHub behavior is consistent across Kubernetes and OpenShift

**Validation**: Feature is orthogonal to OpenShift-specific customizations.

### Principle V: Namespace Awareness ✅ COMPLIANT

**Status**: Icons are bundle metadata and don't involve namespace-scoped resources.

- CSV icon field is metadata, not a deployed resource
- No new namespace-scoped resources created
- Existing namespace handling (`opendatahub` vs `toolhive-operator-system`) unaffected

**Validation**: No namespace implications.

### Principle VI: OLM Catalog Multi-Bundle Support ✅ COMPLIANT

**Status**: Icon customization supports multi-bundle catalogs naturally.

- Each bundle version can have its own custom icon
- Catalog generation (`opm render`) embeds bundle icons in `olm.bundle.object`
- Multiple bundles with different icons can coexist in same catalog
- Icon inheritance: catalog reuses bundle icon by default (user story P3)

**Validation**: Feature enhances multi-bundle support by enabling per-version icon branding.

### Git Operations Policy ✅ COMPLIANT

**Status**: No automated git operations required - this is a build tooling feature.

- Icon validation and encoding happen during `make bundle`/`make catalog`
- No commits, pushes, or repository modifications
- Developers manually commit updated bundle/catalog if desired

**Validation**: All git operations remain human-initiated.

## Constitution Check Summary

**Result**: ✅ ALL PRINCIPLES COMPLIANT

No constitutional violations. Feature is a build-time enhancement that:
- Preserves manifest integrity
- Operates outside kustomize workflow (bundle generation phase)
- Doesn't touch CRDs
- Platform-agnostic
- No namespace concerns
- Enhances multi-bundle catalog support
- No automated git operations

**Gate Status**: PASSED - Proceed to Phase 0

## Project Structure

### Documentation (this feature)

```
specs/009-allow-icon-customization/
├── spec.md              # Feature specification (completed)
├── checklists/
│   └── requirements.md  # Specification quality validation (completed)
├── plan.md              # This file (/speckit.plan command output - IN PROGRESS)
├── research.md          # Phase 0 output (/speckit.plan command - PENDING)
├── data-model.md        # Phase 1 output (/speckit.plan command - PENDING)
├── quickstart.md        # Phase 1 output (/speckit.plan command - PENDING)
├── contracts/           # Phase 1 output (/speckit.plan command - PENDING)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```
# Build tooling structure (existing Makefile project)
Makefile                          # Enhanced with icon validation targets
scripts/
├── validate-icon.sh              # NEW: Icon validation script
└── encode-icon.sh                # NEW: Icon encoding script

bundle/manifests/
└── toolhive-operator.clusterserviceversion.yaml  # Modified by icon injection

catalog/toolhive-operator/
└── catalog.yaml                  # Inherits icon from bundle

icons/                            # NEW: Example/default icons directory
├── default-icon.svg              # Default icon (80x40, 1:2 aspect ratio)
└── README.md                     # Icon requirements documentation

tests/
└── icons/                        # NEW: Test fixtures
    ├── valid-png-80x40.png       # Valid test icon
    ├── valid-svg-80x40.svg       # Valid test icon
    ├── invalid-webp.webp         # Invalid format test
    ├── invalid-100x50.png        # Invalid dimensions test
    └── invalid-512x512.png       # Oversized test
```

**Structure Decision**: This is a build tooling enhancement to an existing Makefile project. Icon validation will be implemented as standalone shell scripts invoked by Makefile targets. This follows the existing pattern where the Makefile orchestrates yq commands and external utilities for bundle generation.

## Complexity Tracking

*No constitutional violations - this section not applicable.*

---

## Phase 0: Research

**Status**: PENDING - Awaiting research.md generation

### Research Tasks

1. **Image Validation Tools**: Determine best approach for validating image formats and dimensions
   - Option A: ImageMagick `identify` (widely available, detailed metadata)
   - Option B: `file` command (lightweight, format detection only)
   - Option C: Custom PNG/SVG header parsing (minimal dependencies)
   - **Decision criteria**: Availability on target systems, validation accuracy, performance

2. **Error Handling Patterns**: Research Makefile error handling best practices
   - How to fail builds gracefully with clear messages
   - How to integrate validation scripts into Makefile targets
   - Exit code conventions for different error types (missing file, invalid format, invalid dimensions)

3. **Base64 Encoding Edge Cases**: Research base64 encoding behavior
   - Line wrapping/formatting requirements for CSV embedding
   - Maximum practical size limits for embedded icons
   - SVG optimization considerations (SVGO compatibility)

4. **Makefile Parameter Passing**: Research best practices for passing parameters to Make targets
   - Environment variables vs make variables vs command-line args
   - Default value handling
   - Multi-parameter scenarios (bundle icon vs catalog icon)

5. **OLM Icon Display Behavior**: Research OperatorHub icon rendering
   - How aspect ratio violations are handled
   - Behavior with missing mediatype
   - SVG security restrictions (script tags, external references)

**Output**: research.md documenting decisions for each area above

---

## Phase 1: Design & Contracts

**Status**: PENDING - Awaiting Phase 0 completion

### Data Model (data-model.md)

**Icon Metadata Entity**:
- Format: {PNG | JPEG | GIF | SVG}
- Dimensions: {width: pixels, height: pixels}
- Aspect Ratio: height/width (must be 0.5 for 1:2 ratio)
- File Size: bytes
- Base64 Data: string (encoded icon)
- Media Type: {image/png | image/jpeg | image/gif | image/svg+xml}

**Validation Rules**:
- Width ≤ 80px
- Height ≤ 40px
- Aspect ratio = 1:2 (tolerance: exact or within 5% for rounding)
- Format ∈ {PNG, JPEG, GIF, SVG}
- File must exist and be readable
- Base64 output must be valid (no encoding errors)

### Contracts (contracts/)

**validate-icon.sh Contract**:

```bash
# Input: Icon file path
# Output: Exit code 0 (valid) or 1 (invalid) + error message to stderr
# Environment: None required

validate-icon.sh <icon-file-path>

# Exit codes:
# 0  - Icon is valid (format, dimensions, aspect ratio all OK)
# 1  - File not found
# 2  - Unsupported format
# 3  - Dimensions exceed limits
# 4  - Aspect ratio incorrect
# 5  - File unreadable/corrupted

# Error messages (stderr):
# "ERROR: Icon file not found: <path>"
# "ERROR: Unsupported format '<format>'. Use PNG, JPEG, GIF, or SVG only"
# "ERROR: Icon dimensions <W>x<H> exceed maximum 80x40"
# "ERROR: Icon aspect ratio <ratio> must be 1:2 (height:width)"
# "ERROR: Cannot read icon file: <path>"
```

**encode-icon.sh Contract**:

```bash
# Input: Icon file path, media type (optional - auto-detect if omitted)
# Output: Base64-encoded string to stdout
# Environment: None required

encode-icon.sh <icon-file-path> [media-type]

# Exit codes:
# 0  - Successfully encoded
# 1  - Encoding failed

# Output format (stdout):
# <base64-encoded-data>

# Media type detection:
# .png  -> image/png
# .jpg/.jpeg -> image/jpeg
# .gif  -> image/gif
# .svg  -> image/svg+xml
```

**Makefile Targets Contract**:

```makefile
# New environment variables:
# BUNDLE_ICON - Path to icon for bundle CSV (optional)
# CATALOG_ICON - Path to icon for catalog (optional, defaults to BUNDLE_ICON)

# Modified targets:
make bundle                           # Uses BUNDLE_ICON if set, else default
make bundle BUNDLE_ICON=path/to/icon.png

make catalog                          # Uses CATALOG_ICON if set, else BUNDLE_ICON, else default
make catalog CATALOG_ICON=path/to/icon.svg

# Validation:
make validate-icon ICON=path/to/icon.png  # Manual validation target
```

### Quickstart (quickstart.md)

**Usage Examples**:

1. Build bundle with custom icon:
   ```bash
   make bundle BUNDLE_ICON=icons/my-logo.png
   ```

2. Build catalog with same icon:
   ```bash
   make catalog
   ```

3. Build catalog with different icon:
   ```bash
   make catalog CATALOG_ICON=icons/my-logo.svg
   ```

4. Validate icon before building:
   ```bash
   make validate-icon ICON=icons/my-logo.png
   ```

5. Revert to default icon:
   ```bash
   make bundle   # No BUNDLE_ICON specified
   ```

---

## Phase 2: Task Generation

**Status**: BLOCKED - Will be created by `/speckit.tasks` command after Phase 0-1 complete

Phase 2 is NOT part of this plan document. Tasks will be generated by the `/speckit.tasks` command which creates `tasks.md` with dependency-ordered implementation steps.

---

## Notes

- Default icon at `icons/default-icon.svg` needs to be created/updated to meet 80x40 dimension requirement (current default is 512x512 which violates OLM limits)
- Consider adding icon validation to CI/CD pipeline as future enhancement
- May want to add `make clean-icons` target to reset to defaults
- Documentation should include OperatorHub screenshot showing custom icon
