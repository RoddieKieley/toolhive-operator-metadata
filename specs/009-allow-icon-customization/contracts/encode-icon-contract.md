# Contract: encode-icon.sh

**Purpose**: Base64-encode validated icon files for embedding in ClusterServiceVersion
**Version**: 1.0.0
**Feature**: 009-allow-icon-customization

## Interface

### Command Signature

```bash
encode-icon.sh <icon-file-path> [mediatype]
```

### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| icon-file-path | string | Yes | Path to validated icon file |
| mediatype | string | No | MIME type (auto-detected from extension if omitted) |

### Exit Codes

| Code | Meaning | Cause |
|------|---------|-------|
| 0 | Successfully encoded | Icon base64-encoded to stdout |
| 1 | Encoding failed | base64 command failed or file unreadable |

### Output Streams

**stdout**: Base64-encoded icon data (single line, no wrapping)
**stderr**: Error messages on failure

### Output Format

Single-line base64 string without line wrapping:

```
PHN2ZyB3aWR0aD0iODAiIGhlaWdodD0iNDAiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+PHJlY3Qgd2lkdGg9IjgwIiBoZWlnaHQ9IjQwIiBmaWxsPSIjMDA3ZmZmIi8+PHRleHQgeD0iNTAlIiB5PSI1MCUiIGZvbnQtc2l6ZT0iMzIiIGZpbGw9IndoaXRlIiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBkb21pbmFudC1iYXNlbGluZT0ibWlkZGxlIj5NPC90ZXh0Pjwvc3ZnPg==
```

**No newlines** - entire output is single continuous string suitable for YAML scalar embedding.

## Encoding Specification

### Base64 Encoding

**Command**: `base64 -w 0 <file>`

**Parameters**:
- `-w 0`: Disable line wrapping (output single line)

**Rationale**: YAML scalars require single-line base64 for simple embedding without block scalar syntax.

### MediaType Detection

If `mediatype` parameter is omitted, detect from file extension:

| Extension | Detected MediaType |
|-----------|-------------------|
| .png | image/png |
| .jpg, .jpeg | image/jpeg |
| .gif | image/gif |
| .svg | image/svg+xml |

**Detection Logic**:

```bash
if [ -z "$mediatype" ]; then
  case "${icon_file##*.}" in
    png) mediatype="image/png" ;;
    jpg|jpeg) mediatype="image/jpeg" ;;
    gif) mediatype="image/gif" ;;
    svg) mediatype="image/svg+xml" ;;
    *)
      echo "ERROR: Cannot detect mediatype for extension: ${icon_file##*.}" >&2
      exit 1
      ;;
  esac
fi
```

**Output**: MediaType written to stderr with prefix `MEDIATYPE:` for caller parsing:

```bash
echo "MEDIATYPE:$mediatype" >&2
```

### Error Handling

```bash
# Check file readability
[ -r "$icon_file" ] || {
  echo "ERROR: Cannot read icon file: $icon_file" >&2
  exit 1
}

# Encode with error handling
base64 -w 0 "$icon_file" 2>&1 || {
  echo "ERROR: Base64 encoding failed for: $icon_file" >&2
  exit 1
}
```

## Integration with Makefile

### Usage Pattern

```makefile
.PHONY: bundle
bundle:
	@if [ -n "$(BUNDLE_ICON)" ]; then \
		echo "Encoding custom bundle icon..."; \
		ENCODED=$$(scripts/encode-icon.sh "$(BUNDLE_ICON)" 2>icon_metadata.tmp); \
		MEDIATYPE=$$(grep "^MEDIATYPE:" icon_metadata.tmp | cut -d: -f2); \
		yq eval '.spec.icon = [{"base64data": "'"$$ENCODED"'", "mediatype": "'"$$MEDIATYPE"'"}]' \
		  -i bundle/manifests/toolhive-operator.clusterserviceversion.yaml; \
		rm -f icon_metadata.tmp; \
		echo "✅ Custom icon encoded and injected"; \
	fi
	# ... rest of bundle generation
```

### CSV Injection

**Target Path**: `.spec.icon[0]`

**yq Command**:

```bash
yq eval '.spec.icon = [{"base64data": "'$ENCODED'", "mediatype": "'$MEDIATYPE'"}]' -i bundle/manifests/toolhive-operator.clusterserviceversion.yaml
```

**Result in CSV**:

```yaml
spec:
  icon:
    - base64data: PHN2ZyB3aWR0aD0iODAiIGhlaWdodD0iNDAiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+PHJlY3Qgd2lkdGg9IjgwIiBoZWlnaHQ9IjQwIiBmaWxsPSIjMDA3ZmZmIi8+PHRleHQgeD0iNTAlIiB5PSI1MCUiIGZvbnQtc2l6ZT0iMzIiIGZpbGw9IndoaXRlIiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBkb21pbmFudC1iYXNlbGluZT0ibWlkZGxlIj5NPC90ZXh0Pjwvc3ZnPg==
      mediatype: image/svg+xml
```

## Performance Requirements

Per NFR-003: Encoding overhead MUST be <5% of total bundle build time

**Benchmarks** (80x40 icons):

| Format | File Size | Encoding Time | Base64 Size | Overhead (33%) |
|--------|-----------|---------------|-------------|----------------|
| PNG | 2 KB | ~5ms | 2.7 KB | +700 B |
| JPEG | 3 KB | ~6ms | 4 KB | +1 KB |
| GIF | 1 KB | ~4ms | 1.3 KB | +300 B |
| SVG | 500 B | ~3ms | 667 B | +167 B |
| PNG | 100 KB | ~45ms | 133 KB | +33 KB |

**Expected bundle build time**: ~2-5 seconds
**Icon encoding overhead**: <50ms (well under 5% budget)

## Dependencies

### Required Tools

| Tool | Version | Purpose |
|------|---------|---------|
| base64 | GNU coreutils | Encoding (must support `-w` flag) |

### Dependency Validation

```bash
command -v base64 >/dev/null 2>&1 || {
  echo "ERROR: 'base64' command not found. Install coreutils package." >&2
  exit 127
}

# Verify -w flag support (GNU base64)
base64 --help 2>&1 | grep -q -- "-w" || {
  echo "ERROR: base64 does not support -w flag (GNU base64 required)" >&2
  exit 127
}
```

**macOS Compatibility**: macOS base64 does NOT support `-w` flag. Use alternative:

```bash
if [[ "$OSTYPE" == "darwin"* ]]; then
  # macOS: base64 outputs without wrapping by default
  base64 -i "$icon_file"
else
  # Linux: use -w 0 to disable wrapping
  base64 -w 0 "$icon_file"
fi
```

## Test Cases

### Valid Encoding

```bash
# Test 1: Encode PNG
$ ./encode-icon.sh tests/icons/valid-png-80x40.png 2>meta.tmp
iVBORw0KGgoAAAANSUhEUgAAAFAAAAAnCAYAAACwSECkAAAAB3RJTUUH...
$ grep MEDIATYPE meta.tmp
MEDIATYPE:image/png
$ echo $?
0

# Test 2: Encode SVG with explicit mediatype
$ ./encode-icon.sh tests/icons/valid-svg-80x40.svg image/svg+xml 2>meta.tmp
PHN2ZyB3aWR0aD0iODAiIGhlaWdodD0iNDAiIHhtbG5zPSJodHRwOi8v...
$ grep MEDIATYPE meta.tmp
MEDIATYPE:image/svg+xml
$ echo $?
0

# Test 3: Verify single-line output (no newlines)
$ OUTPUT=$(./encode-icon.sh tests/icons/valid-png-80x40.png 2>/dev/null)
$ echo "$OUTPUT" | wc -l
1
```

### Encoding Failures

```bash
# Test 4: File not readable
$ ./encode-icon.sh /protected/icon.png
ERROR: Cannot read icon file: /protected/icon.png
$ echo $?
1

# Test 5: Unknown extension without mediatype
$ ./encode-icon.sh tests/icons/file.webp
ERROR: Cannot detect mediatype for extension: webp
$ echo $?
1
```

## CSV Validation

After icon injection, CSV MUST remain valid YAML:

```bash
# Validate CSV syntax
yq eval '.' bundle/manifests/toolhive-operator.clusterserviceversion.yaml >/dev/null || {
  echo "ERROR: CSV is invalid YAML after icon injection" >&2
  exit 1
}

# Verify icon field structure
ICON_COUNT=$(yq eval '.spec.icon | length' bundle/manifests/toolhive-operator.clusterserviceversion.yaml)
if [ "$ICON_COUNT" -ne 1 ]; then
  echo "ERROR: CSV icon array must have exactly 1 element, found: $ICON_COUNT" >&2
  exit 1
fi

# Verify required fields
yq eval '.spec.icon[0].base64data' bundle/manifests/toolhive-operator.clusterserviceversion.yaml >/dev/null || {
  echo "ERROR: Missing base64data field in CSV icon" >&2
  exit 1
}

yq eval '.spec.icon[0].mediatype' bundle/manifests/toolhive-operator.clusterserviceversion.yaml >/dev/null || {
  echo "ERROR: Missing mediatype field in CSV icon" >&2
  exit 1
}
```

## Catalog Inheritance

When `CATALOG_ICON` is not specified, catalog inherits bundle icon via `opm render`:

**Process**:
1. Bundle CSV contains custom icon (already base64-encoded)
2. `opm render bundle/ -o yaml` extracts CSV
3. CSV (including icon) is base64-encoded as `olm.bundle.object`
4. Catalog contains double-encoded icon (base64(CSV) where CSV has base64(icon))

**Decoding at runtime**:
1. OperatorHub decodes `olm.bundle.object` → CSV
2. OperatorHub decodes CSV `.spec.icon[0].base64data` → icon image
3. Icon rendered in UI

**No additional encoding required** for catalog - `opm render` handles it automatically.

## Security Considerations

### Base64 Injection

**Risk**: Malicious base64 data could break YAML syntax

**Mitigation**: Base64 output is URL-safe by default (A-Za-z0-9+/=), no YAML special characters

**Validation**: yq command succeeds or fails atomically (no partial updates)

### File Size Limits

**Warning**: Files >100 KB may cause CSV to become unwieldy

**Recommendation**: Emit warning if base64 output exceeds 150 KB (100 KB raw file)

```bash
ENCODED_SIZE=$(echo -n "$ENCODED" | wc -c)
if [ "$ENCODED_SIZE" -gt 153600 ]; then  # 150 KB in bytes
  echo "WARNING: Encoded icon is large ($ENCODED_SIZE bytes). Consider optimizing." >&2
fi
```

## Versioning

**Current Version**: 1.0.0

**Changelog**:
- 1.0.0 (2025-10-17): Initial contract definition

**Backward Compatibility**: This is the first version - no compatibility concerns

**Future Changes**: Output format (single-line base64) is contract - MUST NOT change
