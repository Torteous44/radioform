# Radioform Development Makefile
# Shortcuts for building, testing, and running Radioform

.PHONY: help clean build run dev reset bundle install-deps test sign verify release test-release quick rebuild dmg full-release

# Default target - show help
help:
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "  Radioform Development Commands"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo ""
	@echo "  Development:"
	@echo "    make dev          - Start from scratch (reset + build + run with onboarding)"
	@echo "    make run          - Run app without onboarding (keeps existing state)"
	@echo "    make reset        - Reset onboarding + uninstall driver"
	@echo ""
	@echo "  Building:"
	@echo "    make build        - Build all components (DSP, driver, host, app)"
	@echo "    make bundle       - Create .app bundle in dist/"
	@echo "    make clean        - Clean all build artifacts"
	@echo "    make rebuild      - Full clean + rebuild"
	@echo ""
	@echo "  Release (Code Signing):"
	@echo "    make release      - Build, sign, and verify for distribution"
	@echo "    make sign         - Code sign the .app bundle"
	@echo "    make verify       - Verify all code signatures"
	@echo "    make test-release - Test the signed release build"
	@echo ""
	@echo "  Distribution:"
	@echo "    make dmg          - Create DMG with drag-to-Applications layout"
	@echo "    make full-release - Complete pipeline (build + sign + DMG)"
	@echo ""
	@echo "  Other:"
	@echo "    make test         - Run DSP tests"
	@echo "    make install-deps - Install build dependencies"
	@echo ""
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Start from scratch - full developer workflow with onboarding
dev: reset build bundle
	@echo ""
	@echo "🚀 Starting Radioform with onboarding..."
	@echo ""
	@open dist/Radioform.app

# Run app normally without resetting onboarding
run:
	@echo "🚀 Starting Radioform..."
	@if [ -d "dist/Radioform.app" ]; then \
		open dist/Radioform.app; \
	else \
		echo "❌ App bundle not found. Run 'make bundle' first."; \
		exit 1; \
	fi

# Build all components
build:
	@echo "🔨 Building all components..."
	@./tools/build_release.sh

# Create .app bundle
bundle:
	@echo "📦 Creating .app bundle..."
	@./tools/create_app_bundle.sh

# Clean all build artifacts
clean:
	@echo "🧹 Cleaning build artifacts..."
	@rm -rf packages/dsp/build
	@rm -rf packages/driver/build
	@rm -rf packages/host/.build
	@rm -rf apps/mac/RadioformApp/.build
	@rm -rf dist
	@echo "✓ Clean complete"

# Reset onboarding and uninstall driver (for testing onboarding flow)
reset:
	@echo "🔄 Resetting Radioform for fresh start..."
	@pkill -f "RadioformApp|RadioformHost" 2>/dev/null || true
	@./tools/uninstall_driver.sh || echo "⚠️  No driver to uninstall (this is fine)"
	@defaults delete com.radioform.menubar hasCompletedOnboarding 2>/dev/null || true
	@defaults delete com.radioform.menubar onboardingVersion 2>/dev/null || true
	@defaults delete com.radioform.menubar driverInstallDate 2>/dev/null || true
	@sleep 2
	@echo "✓ Reset complete - next launch will show onboarding"

# Install build dependencies
install-deps:
	@echo "📥 Checking build dependencies..."
	@which cmake > /dev/null || (echo "❌ CMake not found. Install with: brew install cmake" && exit 1)
	@which swift > /dev/null || (echo "❌ Swift not found. Install Xcode." && exit 1)
	@echo "✓ All dependencies installed"

# Run DSP tests
test:
	@echo "🧪 Running DSP tests..."
	@cd packages/dsp && \
	mkdir -p build && \
	cd build && \
	cmake .. && \
	cmake --build . && \
	./radioform_dsp_tests

# Quick rebuild (for when you only changed Swift code)
quick:
	@echo "⚡ Quick rebuild (Swift only)..."
	@cd apps/mac/RadioformApp && swift build -c release
	@cd packages/host && swift build -c release
	@./tools/create_app_bundle.sh
	@echo "✓ Quick rebuild complete"

# Full clean + rebuild
rebuild: clean build bundle
	@echo "✓ Full rebuild complete"

# Code signing targets
sign:
	@echo "🔐 Code signing Radioform.app..."
	@./tools/codesign.sh

verify:
	@echo "🔍 Verifying signatures..."
	@./tools/verify_signatures.sh

# Build and sign (for release)
release: build bundle sign verify
	@echo ""
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "  ✅ Release Build Complete!"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo ""
	@echo "Signed app: dist/Radioform.app"
	@echo ""
	@echo "Next steps:"
	@echo "  • Test: make test-release"
	@echo "  • Notarize: ./tools/notarize.sh (Phase 2)"
	@echo "  • Package DMG: ./tools/create_dmg.sh (Phase 3)"
	@echo ""

# Test the signed release build
test-release:
	@echo "🧪 Testing signed release build..."
	@open dist/Radioform.app

# Create DMG for distribution
dmg:
	@echo "💿 Creating DMG..."
	@./tools/create_dmg.sh

# Full release pipeline (build, sign, create DMG)
full-release: build bundle sign verify dmg
	@echo ""
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "  ✅ Full Release Build Complete!"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo ""
	@ls -lh dist/*.dmg
