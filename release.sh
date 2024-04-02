#!/usr/bin/env bash
VERSION=$1

set -o errexit


# Input Validation
# ================

if [[ "$VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]
then echo "Releasing Clamshell version $VERSION"
else echo "Usage: $0 VERSION"
     echo "Got version VERSION=$VERSION"
     echo "Allowed patterns: vX.Y.Z"
     echo "Previous version: $(git describe --tags --abbrev=0)"
     exit 1
fi


# Variables
# =========

tarball_prefix="https://github.com/ubunatic/clamshell/archive/refs/tags"
tarball_url="$tarball_prefix/$VERSION.tar.gz"
tarball="$(mktemp -d -t clamshell-release-XXXXXX)/$VERSION.tar.gz"


# Version Update
# ==============

echo "Setting version $VERSION in clamshell.sh"
if sed -i '' -e "s|^clamshell_version=.*|clamshell_version=\"$VERSION\"|g" clamshell.sh &&
   ./clamshell.sh --version | grep -q "$VERSION"
then echo "Updated clamshell.sh with version $VERSION"
else echo "Failed to update clamshell.sh"; exit 1
fi

echo "Setting version $VERSION and resetting sha256 in in Formula/clamshell.rb"
if sed -i '' \
     -e "s|url \"$tarball_prefix/.*\"|url \"$tarball_url\"|g" \
     -e "s|sha256 \".*\"|sha256 \"\"|g" \
     Formula/clamshell.rb &&
   grep -q "$VERSION" Formula/clamshell.rb
then echo "Updated formula with version $VERSION and empty sha256"
else echo "Failed to update formula"; exit 1
fi

echo "Checking for pending changes"
if git diff --exit-code
then echo "Working directory is clean"
elif read -rp "Stage all changes? (y/N) " yesno &&
     test "$yesno" = "y" &&
     git add . &&
     git commit -m "release step 1: set version $VERSION"
then echo "Committed pending changes"
else echo "Please commit changes before running this script!"; exit 1
fi

echo "Tagging release $VERSION"
if git tag "$VERSION" -f &&
   git push &&
   git push --tags -f
then echo "Version $VERSION tagged and pushed"
else echo "Failed to tag and push version $VERSION"; exit 1
fi


# Formula Validation
# ==================

if curl -L "$tarball_url" -o "$tarball" --silent
then echo "Downloaded release tarball to $tarball"
else echo "Failed to download release tarball"; exit 1
fi

if sha="$(shasum -a 256 "$tarball" | cut -d ' ' -f 1)"
then echo "Calculated sha256 checksum: $sha"
else echo "Failed to calculate sha256 checksum"; exit 1
fi

echo "Updating formula with sha256:$sha"
if sed -i '' -e "s|sha256 \".*\"|sha256 \"$sha\"|g" Formula/clamshell.rb &&
   grep -q "$sha" Formula/clamshell.rb
then echo "Updated formula with version $VERSION"
else echo "Failed to update formula"; exit 1
fi

echo "Testing formula build"
rm -f "$HOME"/Library/Caches/Homebrew/downloads/*clamshell-*.tar.gz
brew uninstall --force clamshell 2>/dev/null

if brew install --build-from-source --formula Formula/clamshell.rb &&
   /opt/homebrew/bin/clamshell --version | grep -q "$VERSION"
then echo "Formula build successful"
else echo "Failed to build formula"; exit 1
fi

if git diff --exit-code --quiet
then echo "Formula changes are clean"; exit 0
fi

echo "Committing and pushing formula changes"
if git add Formula/clamshell.rb &&
   git commit -m "release step 2: update sha256 for $VERSION" &&
   git push
then echo "Formula sha256 committed and pushed"
else echo "Failed to commit and push formula sha256"; exit 1
fi

echo "Please run 'make cicd' to perform a complete test of the release"
