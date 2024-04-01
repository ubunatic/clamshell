.PHONY: ⚙️  # make all commands phony

SRC=clamshell.sh
VERSION=
LATEST=$(shell git describe --tags --abbrev=0)

all: ⚙️ lint test

# holistic shell script linting
lint: ⚙️
	shellcheck $(SRC)

# excute embedded selftest
test: ⚙️ lint
	./$(SRC) selftest

# local install
install: ⚙️
	install -m 0755 $(SRC) /usr/local/bin/clamshell

# local uninstall
uninstall: ⚙️
	rm -f /usr/local/bin/clamshell

# release creates a new release for the specified VERSION tag.
release: ⚙️
	./release.sh $(VERSION)

# update-release updates or creates a new release for the latest tag.
# It is safe to use during development. But it is not safe to update
# tags that have been merged to brew.sh already. Use a new tag for that!
update-release: ⚙️
	@test -z "$(VERSION)" || echo "ignoring VERSION=$(VERSION), use 'make release VERSION=vX.Y.Z' instead"
	git pull --tags
	./release.sh $(LATEST)

brew-install:   ⚙️; brew install --build-from-source Formula/clamshell.rb
brew-uninstall: ⚙️; brew uninstall -f clamshell
brew-cleanup:   ⚙️; brew cleanup
