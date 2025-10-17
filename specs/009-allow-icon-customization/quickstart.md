# Quickstart: Custom Icon Support

**Feature**: 009-allow-icon-customization
**For**: Developers building OLM bundles and catalogs
**Time to Complete**: 5 minutes

## Prerequisites

- Makefile-based build environment
- Icon file meeting OLM requirements:
  - Format: PNG, JPEG, GIF, or SVG
  - Max dimensions: 80px width × 40px height
  - Aspect ratio: 1:2 (height:width)

## Quick Start

### 1. Prepare Your Icon

Create or obtain an icon that meets OLM requirements:

```bash
# Example: Create a simple SVG icon (80x40, 1:2 aspect ratio)
cat > my-operator-icon.svg <<'EOF'
<svg width="80" height="40" xmlns="http://www.w3.org/2000/svg">
  <rect width="80" height="40" fill="#007fff"/>
  <text x="50%" y="50%" font-size="24" fill="white"
        text-anchor="middle" dominant-baseline="middle">OP</text>
</svg>
EOF
```

### 2. Validate Your Icon (Optional but Recommended)

```bash
make validate-icon ICON=my-operator-icon.svg
```

**Expected output**:
- Silence = validation passed ✅
- Error message = validation failed ❌ (fix and retry)

### 3. Build Bundle with Custom Icon

```bash
make bundle BUNDLE_ICON=my-operator-icon.svg
```

**What happens**:
1. Icon is validated automatically
2. Icon is base64-encoded
3. Icon is injected into bundle CSV
4. Bundle generation completes

**Result**: `bundle/manifests/toolhive-operator.clusterserviceversion.yaml` contains your custom icon

### 4. Build Catalog (Inherits Bundle Icon)

```bash
make catalog
```

**What happens**:
- Catalog uses the same icon from the bundle (no additional configuration needed)

**Result**: `catalog/toolhive-operator/catalog.yaml` embeds the bundle CSV (with your icon)

### 5. Verify Icon in CSV

```bash
yq eval '.spec.icon[0].mediatype' bundle/manifests/toolhive-operator.clusterserviceversion.yaml
```

**Expected output**: `image/svg+xml` (or appropriate mediatype for your format)

## Advanced Usage

### Use Different Icons for Bundle vs Catalog

```bash
# Build bundle with PNG icon
make bundle BUNDLE_ICON=icons/my-logo-hires.png

# Build catalog with optimized SVG icon
make catalog CATALOG_ICON=icons/my-logo-optimized.svg
```

**Use case**: High-resolution PNG for development, optimized SVG for distribution

### Revert to Default Icon

```bash
# Build without specifying BUNDLE_ICON
make bundle

# This uses the default icon from icons/default-icon.svg
```

### Validate Multiple Icons

```bash
# Test all icons in a directory
for icon in icons/*.{png,svg}; do
  echo "Validating: $icon"
  make validate-icon ICON="$icon" && echo "✅ PASS" || echo "❌ FAIL"
done
```

## Common Scenarios

### Scenario 1: Branding Operator for Enterprise Deployment

**Goal**: Replace default icon with company logo

**Steps**:
1. Export company logo as 80x40 PNG (1:2 aspect ratio)
2. Save as `icons/company-logo.png`
3. Build bundle: `make bundle BUNDLE_ICON=icons/company-logo.png`
4. Build catalog: `make catalog`
5. Deploy to OpenShift, verify logo appears in OperatorHub

**Time**: ~2 minutes

### Scenario 2: Testing Multiple Icon Variants

**Goal**: Test how different formats render in OperatorHub

**Steps**:

```bash
# Test PNG version
make bundle BUNDLE_ICON=icons/variant1.png
make catalog
# Deploy and observe rendering

# Test SVG version
make bundle BUNDLE_ICON=icons/variant2.svg
make catalog
# Deploy and observe rendering

# Test JPEG version (not recommended, but supported)
make bundle BUNDLE_ICON=icons/variant3.jpg
make catalog
# Deploy and observe rendering
```

**Recommendation**: SVG provides best quality and smallest file size

### Scenario 3: Continuous Integration (CI/CD)

**Goal**: Automatically inject custom icon during CI build

**GitHub Actions Example**:

```yaml
- name: Build OLM Bundle with Custom Icon
  run: |
    make bundle BUNDLE_ICON=${{ github.workspace }}/branding/operator-icon.svg
    make catalog
  env:
    BUNDLE_ICON: branding/operator-icon.svg
```

**GitLab CI Example**:

```yaml
build-bundle:
  script:
    - make bundle BUNDLE_ICON=branding/operator-icon.png
    - make catalog
```

## Troubleshooting

### Error: "Icon dimensions 100x50 exceed maximum 80x40"

**Cause**: Icon is too large

**Solution**: Resize icon to 80x40 pixels

```bash
# Using ImageMagick
convert my-icon.png -resize 80x40! my-icon-resized.png

# Using GIMP (GUI)
# Image → Scale Image → 80x40 pixels → Interpolation: Cubic
```

### Error: "Icon aspect ratio 0.667 must be 1:2"

**Cause**: Icon is not 1:2 aspect ratio (e.g., 60x40 instead of 80x40)

**Solution**: Crop or resize to 1:2 ratio

```bash
# Crop to 1:2 aspect ratio (center crop)
convert my-icon.png -gravity center -extent 80x40 my-icon-cropped.png
```

### Error: "Unsupported format 'image/webp'"

**Cause**: Icon is in WebP format (not supported by OLM)

**Solution**: Convert to PNG or SVG

```bash
# Convert WebP to PNG
convert my-icon.webp my-icon.png

# Then resize to 80x40 if needed
convert my-icon.png -resize 80x40! my-icon-final.png
```

### Icon Not Appearing in OperatorHub

**Possible causes**:

1. **CSV not updated**: Check `bundle/manifests/toolhive-operator.clusterserviceversion.yaml` contains icon
   ```bash
   yq eval '.spec.icon[0].base64data' bundle/manifests/toolhive-operator.clusterserviceversion.yaml | head -c 50
   ```
   Should output base64 string (not empty or null)

2. **Catalog not rebuilt**: Ensure you ran `make catalog` after `make bundle`

3. **Cache issue**: OperatorHub may cache old icon
   - Solution: Increment operator version in CSV
   - Or: Clear browser cache and refresh

4. **SVG rendering blocked**: OperatorHub Content Security Policy blocks certain SVG features
   - Avoid: `<script>` tags, external resources, event handlers
   - Use: Simple shapes, text, inline styles

### Build Fails with "Cannot read icon file"

**Possible causes**:

1. **File path incorrect**: Use absolute path or path relative to Makefile
   ```bash
   make bundle BUNDLE_ICON=./icons/my-icon.png  # Relative path
   make bundle BUNDLE_ICON=/full/path/to/icon.png  # Absolute path
   ```

2. **File permissions**: Ensure icon file is readable
   ```bash
   chmod 644 my-icon.png
   ```

3. **File corrupted**: Verify file opens correctly
   ```bash
   file my-icon.png  # Should show image type
   identify my-icon.png  # Should show dimensions
   ```

## Icon Creation Tips

### Recommended Tools

- **SVG**: Inkscape (free, cross-platform)
- **PNG**: GIMP (free, cross-platform) or Photoshop
- **Conversion**: ImageMagick (command-line), XnConvert (GUI)

### Design Guidelines

1. **Keep it simple**: Icon will be displayed at small size (typically 40-80px)
2. **High contrast**: Use solid colors, avoid gradients
3. **Minimal text**: 1-3 characters max, large font size
4. **Test at size**: View icon at 80x40 before finalizing

### SVG Optimization

To minimize file size:

```bash
# Using SVGO
svgo my-icon.svg -o my-icon-optimized.svg

# Typical savings: 30-70% smaller
```

**Benefits**:
- Smaller CSV file size
- Faster catalog generation
- Better OLM performance

### Creating Icons from Existing Logos

```bash
# Start with full-size logo (e.g., 512x512)
# Resize and crop to 80x40 aspect ratio

# Step 1: Resize width to 80px (maintains aspect ratio)
convert logo.png -resize 80x logo-80w.png

# Step 2: Crop to 40px height (center crop)
convert logo-80w.png -gravity center -extent 80x40 logo-final.png

# Step 3: Validate
make validate-icon ICON=logo-final.png
```

## Examples

### Example 1: Minimal SVG Icon

```svg
<svg width="80" height="40" xmlns="http://www.w3.org/2000/svg">
  <rect width="80" height="40" fill="#FF6B35"/>
  <circle cx="20" cy="20" r="12" fill="#FFF"/>
  <circle cx="60" cy="20" r="12" fill="#FFF"/>
</svg>
```

**Size**: 178 bytes
**Base64**: ~240 bytes
**Renders as**: Orange rectangle with two white circles

### Example 2: Text-Based Icon

```svg
<svg width="80" height="40" xmlns="http://www.w3.org/2000/svg">
  <rect width="80" height="40" fill="#2E5266"/>
  <text x="40" y="20" font-family="monospace" font-size="28"
        fill="#D3F8E2" text-anchor="middle"
        dominant-baseline="middle">OPS</text>
</svg>
```

**Size**: 219 bytes
**Base64**: ~292 bytes
**Renders as**: Dark blue background with "OPS" text

### Example 3: Using Existing PNG

```bash
# Assuming you have company-logo.png (300x300)

# Resize to fit 80x40 (1:2 aspect ratio)
convert company-logo.png \
  -resize 80x40\! \
  -gravity center \
  -background none \
  -extent 80x40 \
  company-logo-80x40.png

# Validate
make validate-icon ICON=company-logo-80x40.png

# Use in build
make bundle BUNDLE_ICON=company-logo-80x40.png
```

## Next Steps

After customizing your icon:

1. **Test locally**: Build bundle and catalog, verify icon appears in CSV
2. **Deploy to test environment**: Install operator, check icon in OperatorHub
3. **Gather feedback**: Verify icon is visible and recognizable at small size
4. **Iterate if needed**: Adjust colors, simplify design, or try different format
5. **Document**: Add your icon to `icons/` directory for future builds

## FAQ

**Q: Can I use animated GIFs?**
A: Technically supported, but not recommended. OperatorHub typically shows first frame only.

**Q: What if I don't have ImageMagick installed?**
A: Icon validation requires ImageMagick. Install via:
- Ubuntu/Debian: `sudo apt install imagemagick`
- RHEL/Fedora: `sudo dnf install ImageMagick`
- macOS: `brew install imagemagick`

**Q: Can I skip validation and encode manually?**
A: Not recommended. Validation prevents deployment issues. If you must skip, use:
```bash
base64 -w 0 my-icon.png > icon.b64
# Then manually edit CSV
```

**Q: Does the icon affect operator functionality?**
A: No. Icon is purely cosmetic metadata for OperatorHub UI. Operator behavior is unchanged.

**Q: Can I change the icon after deployment?**
A: Yes, but requires creating a new operator version (increment CSV version). OLM treats icon changes as updates.

## Related Documentation

- [OLM Icon Requirements](https://github.com/operator-framework/community-operators/blob/master/docs/packaging-required-fields.md)
- [Feature Specification](./spec.md)
- [Implementation Plan](./plan.md)
- [Validation Contract](./contracts/validate-icon-contract.md)
- [Encoding Contract](./contracts/encode-icon-contract.md)
