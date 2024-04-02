.PHONY: ⚙️  # make all commands phony

SRC=clamshell.sh
VERSION=
LATEST=$(shell git describe --tags --abbrev=0)
TAP=ubunatic/clamshell
TAP_LOCAL=/opt/homebrew/Library/Taps/ubunatic/homebrew-clamshell
FORMULA=$(TAP)/clamshell

all: ⚙️ lint test

# holistic shell script linting
lint: ⚙️
	shellcheck $(SRC)
	brew style Formula/clamshell.rb
	misspell *.md **/*.md

# excute embedded selftest
test: ⚙️ lint
	./$(SRC) selftest

# local install
install: ⚙️ brew-uninstall
	install -m 0755 $(SRC) /usr/local/bin/clamshell
	type clamshell | grep -q /usr/local/bin/clamshell

# local uninstall
uninstall: ⚙️
	rm -f /usr/local/bin/clamshell
	! type clamshell 2>/dev/null

# release creates a new release for the specified VERSION tag.
release: ⚙️
	./release.sh $(VERSION)

brew-tap:       ⚙️; brew tap ubunatic/clamshell git@github.com:ubunatic/clamshell.git
brew-audit:     ⚙️; brew audit --new --git $(FORMULA)
brew-install:   ⚙️; brew install $(FORMULA) && type clamshell | grep -q /opt/homebrew/bin/clamshell
brew-uninstall: ⚙️; brew uninstall -f clamshell
brew-cleanup:   ⚙️; brew cleanup -s clamshell; rm -rf $(TAP_LOCAL)

cicd: VERSION=$(LATEST)
cicd: ⚙️ lint test
	# ---------------------------
	# 🧪 testing local install 🧪
	# ---------------------------
	@$(MAKE) install
	clamshell selftest
	clamshell version | grep -q "$(VERSION)"
	clamshell install
	clamshell pid | grep -qE '[0-9]+'
	clamshell uninstall
	@$(MAKE) uninstall
	@echo "✅ local install tests: OK"
	# --------------------------
	# 🧪 testing brew install 🧪
	# --------------------------
	@$(MAKE) brew-tap brew-audit brew-install
	clamshell selftest
	clamshell version | grep -q "$(VERSION)"
	clamshell install
	clamshell pid | grep -qE '[0-9]+'
	clamshell uninstall
	@$(MAKE) brew-uninstall brew-cleanup
	@echo "✅ brew install tests: OK"
