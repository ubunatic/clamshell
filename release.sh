#!/usr/bin/env bash
VERSION=$1

set -o errexit

if test -z "$VERSION"
then echo "Usage: $0 VERSION"
     exit 1
fi

echo "Releasing Clamshell version $VERSION"

if git diff --exit-code
then echo "Working directory clean"
else echo "Please commit changes before running this script!"; exit 1
fi

if grep -q "$VERSION" Formula/clamshell.rb
then echo "Found version $VERSION in Formula/clamshell.rb"
else echo "Version $VERSION not found in Formula/clamshell.rb"
     sed -i '' -e "s/tag: \"v.*\"/tag: \"$VERSION\"/g" Formula/clamshell.rb
     git add Formula/clamshell.rb
     git commit -m "set version to $VERSION"
     git tag "$VERSION" -f
fi

git push --tags -f

if gh release view "$VERSION" > /dev/null
then echo "Release $VERSION already exists, updating tag"
     gh release delete "$VERSION"
fi

echo "Creating release $VERSION"
gh release create "$VERSION" --title "Clamshell $VERSION" --notes "Release $VERSION"
