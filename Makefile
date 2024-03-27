.PHONY: ⚙️  # make all commands phony

SRC=clamshell.sh
VERSION=$(shell git describe --tags --abbrev=0)
LATEST=$(shell git describe --tags --abbrev=0)

all: lint test

lint: ⚙️
	shellcheck $(SRC)

test: ⚙️
	./$(SRC) selftest  # excute selftest

# safe-release creates a new release and requires a VERSION argument
safe-release: VERSION=
safe-release: ⚙️
	@echo "latest version is '$(LATEST)', given version is '$(VERSION)'"
	@test -n "$(VERSION)" || echo "Usage: make safe-release VERSION=v1.x.x"
	@test -n "$(VERSION)"
	./release.sh $(VERSION)

# release creates a new release for the latest tag
release: ⚙️
	git pull --tags
	./release.sh $(VERSION)

brew-install: ⚙️
	# install from local Formula/clamshell.rb
	brew install --build-from-source Formula/clamshell.rb
