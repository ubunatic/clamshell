#!/usr/bin/env bash
VERSION=$1
TITLE="${2:-"Clamshell $VERSION"}"

set -o errexit

if [[ "$VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]
then echo "Releasing Clamshell version $VERSION"
else echo "Usage: $0 VERSION"
     echo "Got version VERSION=$VERSION"
     echo "Allowed patterns: vX.Y.Z"
     echo "Previous version: $(git describe --tags --abbrev=0)"
     exit 1
fi

if git diff --exit-code
then echo "Working directory is clean"
elif read -rp "Stage all changes? (y/N) " yesno && test "$yesno" = "y" && git add .
then echo "Staged pending changes"
else echo "Please commit changes before running this script!"; exit 1
fi

if grep -q "$VERSION" Formula/clamshell.rb
then echo "Version $VERSION found in Formula/clamshell.rb"
else echo "Setting $VERSION in Formula/clamshell.rb"
     sed -i '' -e "s/tag: \"v.*\"/tag: \"$VERSION\"/g" Formula/clamshell.rb
     git add Formula/clamshell.rb
     git commit -m "set version to $VERSION"
     git tag "$VERSION" -f
fi

git push -f
git push --tags -f
echo "Version $VERSION code and tag committed and pushed"

if ! type gh > /dev/null
then echo "Github CLI not found, release incomplete"; exit 1
fi

if gh release view "$VERSION" > /dev/null
then echo "Release $VERSION already exists, deleting old release"
     # also delete all files attached to the release
     gh release view "$VERSION" --json assets --jq '.assets[].id' | xargs -I {}
     # gh release delete -y "$VERSION"
fi

echo "Creating release $VERSION"
gh release create "$VERSION" --title "$TITLE" --notes "Release $VERSION"
