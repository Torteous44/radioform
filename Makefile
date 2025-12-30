# Radioform Development Makefile
# Shortcuts for building, testing, and running Radioform

.PHONY: help clean build run dev reset bundle install-deps test

# Default target - show help
help:
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "  Radioform Development Commands"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo ""
	@echo "  make dev          - Start from scratch (reset + build + run with onboarding)"
	@echo "  make run          - Run app without onboarding (keeps existing state)"
	@echo ""
	@echo "  make build        - Build all components (DSP, driver, host, app)"
	@echo "  make bundle       - Create .app bundle in dist/"
	@echo "  make clean        - Clean all build artifacts"
	@echo ""
	@echo "  make reset        - Reset onboarding + uninstall driver"
	@echo "  make test         - Run DSP tests"
	@echo "  make install-deps - Install build dependencies"
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
