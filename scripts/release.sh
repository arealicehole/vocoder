#!/bin/bash
# Create a release with proper versioning

set -euo pipefail

VERSION=$(cat VERSION)
RELEASE_NOTES=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --major) VERSION=$(echo $VERSION | awk -F. '{print $1+1".0.0"}');;
        --minor) VERSION=$(echo $VERSION | awk -F. '{print $1"."$2+1".0"}');;
        --patch) VERSION=$(echo $VERSION | awk -F. '{print $1"."$2"."$3+1}');;
        --notes) RELEASE_NOTES="$2"; shift;;
        *) echo "Usage: $0 [--major|--minor|--patch] [--notes 'release notes']"; exit 1;;
    esac
    shift
done

echo "Creating release v$VERSION"

# Update VERSION file
echo $VERSION > VERSION

# Update pyproject.toml
sed -i "s/^version = .*/version = \"$VERSION\"/" pyproject.toml

# Freeze current dependencies
pip freeze > requirements.lock

# Git operations
git add VERSION pyproject.toml requirements.lock
git commit -m "Release v$VERSION

$RELEASE_NOTES"

git tag -a "v$VERSION" -m "Version $VERSION

$RELEASE_NOTES"

echo "✅ Release v$VERSION created!"
echo "Push with: git push origin main --tags"