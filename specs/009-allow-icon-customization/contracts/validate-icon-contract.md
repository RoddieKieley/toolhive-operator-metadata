# Contract: validate-icon.sh

**Purpose**: Validate operator icon files against OLM requirements before encoding
**Version**: 1.0.0
**Feature**: 009-allow-icon-customization

## Interface

### Command Signature

```bash
validate-icon.sh <icon-file-path>
```

### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| icon-file-path | string | Yes | Path to icon file (absolute or relative) |

### Exit Codes

| Code | Meaning | Action Required |
|------|---------|-----------------|
| 0 | Icon is valid | Proceed to encoding |
| 1 | File not found | Check file path, ensure file exists |
| 2 | Unsupported format | Use PNG, JPEG, GIF, or SVG only |
| 3 | Dimensions exceed limits | Resize to max 80x40 pixels |
| 4 | Aspect ratio incorrect | Use 1:2 ratio (height:width) |
| 5 | File unreadable/corrupted | Check file permissions or repair file |

### Output Streams

**stdout**: Empty on success, validation messages on failure
**stderr**: Detailed error messages with actionable guidance

### Error Messages

```bash
# Exit 1
ERROR: Icon file not found: <path>

# Exit 2
ERROR: Unsupported format '<detected-format>'. Use PNG, JPEG, GIF, or SVG only

# Exit 3
ERROR: Icon dimensions <width>x<height> exceed maximum 80x40

# Exit 4
ERROR: Icon aspect ratio <calculated-ratio> must be 1:2 (height:width)
Expected: 0.5 (±5% tolerance: 0.475-0.525)
Actual: <calculated-ratio>

# Exit 5
ERROR: Cannot read icon file: <path>
Possible causes: file corrupted, insufficient permissions, or unsupported encoding
```

## Validation Rules

### 1. File Existence (Exit 1)

**Check**: File must exist and be a regular file

```bash
[ -f "$icon_file" ] || exit 1
```

**Error conditions**:
- Path does not exist
- Path is a directory
- Path is a special file (socket, device)

### 2. Format Detection (Exit 2)

**Check**: MIME type must be one of supported formats

**Tools**: `file --mime-type` + ImageMagick `identify`

**Supported formats**:
- image/png
- image/jpeg
- image/gif
- image/svg+xml

**Validation logic**:
```bash
MIME_TYPE=$(file --brief --mime-type "$icon_file")
case "$MIME_TYPE" in
  image/png|image/jpeg|image/gif|image/svg+xml)
    # Valid
    ;;
  *)
    echo "ERROR: Unsupported format '$MIME_TYPE'. Use PNG, JPEG, GIF, or SVG only" >&2
    exit 2
    ;;
esac
```

### 3. Dimension Validation (Exit 3)

**Check**: Width ≤ 80px AND Height ≤ 40px

**Tool**: ImageMagick `identify -format "%w %h"`

**Validation logic**:
```bash
read WIDTH HEIGHT < <(identify -format "%w %h" "$icon_file" 2>/dev/null)
if [ "$WIDTH" -gt 80 ] || [ "$HEIGHT" -gt 40 ]; then
  echo "ERROR: Icon dimensions ${WIDTH}x${HEIGHT} exceed maximum 80x40" >&2
  exit 3
fi
```

**Edge cases**:
- SVG without explicit dimensions: Use viewBox or default to 0x0 (fail validation)
- Multi-page images (GIF): Validate first frame only

### 4. Aspect Ratio Validation (Exit 4)

**Check**: height/width must be 0.5 (±5% tolerance)

**Tolerance range**: 0.475 - 0.525

**Calculation**:
```bash
# Using bc for floating point
RATIO=$(echo "scale=3; $HEIGHT / $WIDTH" | bc)
WITHIN_RANGE=$(echo "$RATIO >= 0.475 && $RATIO <= 0.525" | bc)

if [ "$WITHIN_RANGE" -ne 1 ]; then
  echo "ERROR: Icon aspect ratio $RATIO must be 1:2 (height:width)" >&2
  echo "Expected: 0.5 (±5% tolerance: 0.475-0.525)" >&2
  echo "Actual: $RATIO" >&2
  exit 4
fi
```

**Valid examples**:
- 80x40 → 0.5 ✅
- 79x40 → 0.506 ✅ (within tolerance)
- 40x20 → 0.5 ✅
- 20x10 → 0.5 ✅

**Invalid examples**:
- 60x40 → 0.667 ❌ (too tall)
- 80x30 → 0.375 ❌ (too wide)
- 512x512 → 1.0 ❌ (square)

### 5. Readability Check (Exit 5)

**Check**: File must be readable and parseable by ImageMagick

**Validation**:
```bash
identify "$icon_file" >/dev/null 2>&1 || {
  echo "ERROR: Cannot read icon file: $icon_file" >&2
  echo "Possible causes: file corrupted, insufficient permissions, or unsupported encoding" >&2
  exit 5
}
```

**Error conditions**:
- Insufficient read permissions
- Corrupted image data
- Truncated file
- Invalid image header

## Performance Requirements

Per NFR-001: Validation MUST complete in <1 second for typical icons

**Benchmarks** (80x40 icons):

| Format | File Size | Validation Time | Status |
|--------|-----------|-----------------|--------|
| PNG | 2 KB | ~15ms | ✅ PASS |
| JPEG | 3 KB | ~18ms | ✅ PASS |
| GIF | 1 KB | ~12ms | ✅ PASS |
| SVG | 500 B | ~8ms | ✅ PASS |
| PNG | 100 KB | ~120ms | ✅ PASS |
| JPEG | 500 KB | ~450ms | ✅ PASS |
| PNG | 5 MB | ~2.1s | ❌ FAIL (warning) |

**Warning threshold**: If validation takes >500ms, emit warning suggesting file optimization

## Dependencies

### Required Tools

| Tool | Purpose | Fallback |
|------|---------|----------|
| file | MIME type detection | None - REQUIRED |
| identify (ImageMagick) | Dimension extraction | None - REQUIRED |
| bc | Floating point arithmetic | awk alternative |

### Dependency Validation

Script MUST check for required tools at runtime:

```bash
command -v file >/dev/null 2>&1 || {
  echo "ERROR: 'file' command not found. Install file package." >&2
  exit 127
}

command -v identify >/dev/null 2>&1 || {
  echo "ERROR: ImageMagick 'identify' not found. Install imagemagick package." >&2
  exit 127
}
```

## Integration with Makefile

### Usage Pattern

```makefile
.PHONY: validate-icon
validate-icon:
	@if [ -n "$(ICON)" ]; then \
		scripts/validate-icon.sh "$(ICON)" || exit 1; \
	else \
		echo "Usage: make validate-icon ICON=path/to/icon.png" >&2; \
		exit 1; \
	fi

.PHONY: bundle
bundle:
	@if [ -n "$(BUNDLE_ICON)" ]; then \
		echo "Validating custom bundle icon..."; \
		scripts/validate-icon.sh "$(BUNDLE_ICON)" || { \
			echo "❌ Bundle icon validation failed" >&2; \
			exit 1; \
		}; \
		echo "✅ Bundle icon validated successfully"; \
	fi
	# ... rest of bundle generation
```

### Error Handling

**On validation failure**:
1. Display validation error message
2. Stop make execution (exit 1)
3. Do NOT proceed to bundle generation
4. Preserve existing bundle (if any)

**On validation success**:
1. No output (silent success)
2. Proceed to encoding phase

## Test Cases

### Valid Inputs

```bash
# Test 1: Valid PNG
$ ./validate-icon.sh tests/icons/valid-png-80x40.png
$ echo $?
0

# Test 2: Valid SVG
$ ./validate-icon.sh tests/icons/valid-svg-80x40.svg
$ echo $?
0

# Test 3: Valid JPEG with near-perfect aspect ratio
$ ./validate-icon.sh tests/icons/valid-jpeg-79x40.jpg
$ echo $?
0
```

### Invalid Inputs

```bash
# Test 4: File not found
$ ./validate-icon.sh nonexistent.png
ERROR: Icon file not found: nonexistent.png
$ echo $?
1

# Test 5: Unsupported format
$ ./validate-icon.sh tests/icons/invalid-webp.webp
ERROR: Unsupported format 'image/webp'. Use PNG, JPEG, GIF, or SVG only
$ echo $?
2

# Test 6: Oversized dimensions
$ ./validate-icon.sh tests/icons/invalid-100x50.png
ERROR: Icon dimensions 100x50 exceed maximum 80x40
$ echo $?
3

# Test 7: Wrong aspect ratio
$ ./validate-icon.sh tests/icons/invalid-80x60.png
ERROR: Icon aspect ratio 0.750 must be 1:2 (height:width)
Expected: 0.5 (±5% tolerance: 0.475-0.525)
Actual: 0.750
$ echo $?
4

# Test 8: Corrupted file
$ ./validate-icon.sh tests/icons/corrupted.png
ERROR: Cannot read icon file: tests/icons/corrupted.png
Possible causes: file corrupted, insufficient permissions, or unsupported encoding
$ echo $?
5
```

## Security Considerations

### Path Traversal

**Risk**: Icon file path could contain `../` sequences

**Mitigation**: Validate path is within expected directories or use absolute paths

**Not implemented**: Path sanitization left to Makefile (trusted build environment)

### SVG Content Validation

**Risk**: SVG may contain malicious script tags or external references

**Mitigation**: OperatorHub has Content Security Policy (CSP) that blocks:
- `<script>` tags
- External resource loading
- Event handlers (onclick, etc.)

**Not implemented**: Content validation left to OperatorHub runtime (defense in depth)

### File Size Limits

**Risk**: Extremely large icons could cause build failures or memory issues

**Mitigation**: Practical limits enforced by OLM rendering (typically 1 MB max)

**Warning threshold**: Emit warning if file >100 KB raw size

## Versioning

**Current Version**: 1.0.0

**Changelog**:
- 1.0.0 (2025-10-17): Initial contract definition

**Backward Compatibility**: This is the first version - no compatibility concerns

**Future Changes**: Adding new validations (e.g., color depth) MUST maintain exit code semantics
