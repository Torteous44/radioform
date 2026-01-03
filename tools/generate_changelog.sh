#!/bin/bash
set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <version>"
    echo "Example: $0 v1.0.0"
    exit 1
fi

if ! command -v git-cliff &> /dev/null; then
    echo "Error: git-cliff not installed"
    echo "Install with: brew install git-cliff"
    exit 1
fi

VERSION=$1

echo "Generating changelog for $VERSION..."

git cliff --config .github/cliff.toml --tag "$VERSION" > CHANGELOG.md

echo "✓ CHANGELOG.md updated"
echo "Review changes and commit with: git add CHANGELOG.md && git commit -m 'docs: update changelog for $VERSION'"
