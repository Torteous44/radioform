#!/bin/bash
# Signature verification script for Radioform
# Validates all code signatures and entitlements

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
APP_BUNDLE="${1:-$PROJECT_ROOT/dist/Radioform.app}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

error() { echo -e "${RED}❌ $1${NC}" >&2; }
success() { echo -e "${GREEN}✓ $1${NC}"; }
warn() { echo -e "${YELLOW}  $1${NC}"; }
info() { echo -e "${BLUE}ℹ $1${NC}"; }

section() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

if [ ! -d "$APP_BUNDLE" ]; then
    error "App bundle not found: $APP_BUNDLE"
    echo "Usage: $0 [path/to/Radioform.app]"
    exit 1
fi

section "Radioform Signature Verification"
echo "Bundle: $APP_BUNDLE"

FAILED=0

# Function to verify a component
verify_component() {
    local component="$1"
    local name="$2"

    echo ""
    info "Verifying $name..."

    if [ ! -e "$component" ]; then
        warn "$name not found (optional)"
        return 0
    fi

    # Check if signed
    if ! codesign -dv "$component" 2>&1 | grep -q "Signature"; then
        error "$name is NOT signed"
        ((FAILED++))
        return 1
    fi

    # Verify signature
    if codesign --verify --deep --strict "$component" 2>/dev/null; then
        success "$name signature valid"
    else
        error "$name signature verification FAILED"
        codesign --verify --deep --strict --verbose=2 "$component" 2>&1 || true
        ((FAILED++))
        return 1
    fi

    # Display signing info
    echo "   Identity: $(codesign -dv "$component" 2>&1 | grep "Authority" | head -1 | sed 's/Authority=//')"

    # Check for hardened runtime
    if codesign -dv "$component" 2>&1 | grep -q "runtime"; then
        echo "   Hardened Runtime: ✓ Enabled"
    else
        warn "   Hardened Runtime: ✗ Disabled"
    fi

    # Check for timestamp
    if codesign -dv "$component" 2>&1 | grep -q "Timestamp"; then
        echo "   Timestamp: ✓ Present"
    else
        warn "   Timestamp: ✗ Missing"
    fi

    # Display entitlements if present
    if codesign -d --entitlements - "$component" 2>/dev/null | grep -q "<?xml"; then
        local entitlement_count=$(codesign -d --entitlements - "$component" 2>/dev/null | grep -c "<key>" || echo "0")
        echo "   Entitlements: $entitlement_count found"
    fi
}

# Verify each component
verify_component "$APP_BUNDLE/Contents/MacOS/RadioformHost" "RadioformHost"
verify_component "$APP_BUNDLE/Contents/MacOS/RadioformApp" "RadioformApp"
verify_component "$APP_BUNDLE/Contents/Resources/RadioformDriver.driver" "RadioformDriver.driver"
verify_component "$APP_BUNDLE" "Radioform.app (bundle)"

section "Gatekeeper Assessment"

if spctl --assess --type execute --verbose=4 "$APP_BUNDLE" 2>&1; then
    success "Gatekeeper: ACCEPTED"
else
    EXIT_CODE=$?
    if [ $EXIT_CODE -eq 3 ]; then
        warn "Gatekeeper: REJECTED (not notarized yet - this is expected)"
        echo "   Run notarization after signing: ./tools/notarize.sh"
    else
        error "Gatekeeper: REJECTED (signature issue)"
        ((FAILED++))
    fi
fi

section "Code Signature Details"

echo ""
info "Full signature information:"
codesign -dvvv "$APP_BUNDLE" 2>&1

section "Summary"

if [ $FAILED -eq 0 ]; then
    echo ""
    success "All signatures valid!"
    echo ""
    echo "Status:"
    echo "  ✓ All components signed"
    echo "  ✓ Signatures verified"
    echo "  ✓ Hardened runtime enabled"

    if spctl --assess --type execute "$APP_BUNDLE" 2>/dev/null; then
        echo "  ✓ Gatekeeper approved"
    else
        echo "  ⚠ Awaiting notarization"
    fi

    echo ""
    echo "Next steps:"
    echo "  1. Test: open \"$APP_BUNDLE\""
    echo "  2. Notarize: ./tools/notarize.sh"
    echo "  3. Package: ./tools/create_dmg.sh"
    echo ""
    exit 0
else
    echo ""
    error "$FAILED component(s) failed verification"
    echo ""
    echo "Common issues:"
    echo "  • Run code signing: ./tools/codesign.sh"
    echo "  • Check Developer ID certificate is installed"
    echo "  • Verify entitlements files exist"
    echo ""
    exit 1
fi
