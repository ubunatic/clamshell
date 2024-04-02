.PHONY: ⚙️  # make all commands phony

SRC=clamshell.sh
VERSION=
TAP=ubunatic/clamshell
TAP_LOCAL=/opt/homebrew/Library/Taps/ubunatic/homebrew-clamshell
FORMULA=$(TAP)/clamshell

all: ⚙️ lint test

# holistic shell script linting
lint: ⚙️
	shellcheck $(SRC)
	brew style Formula/clamshell.rb

# excute embedded selftest
test: ⚙️ lint
	./$(SRC) selftest

# local install
install: ⚙️
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
brew-install:   ⚙️; brew install $(FORMULA)
brew-uninstall: ⚙️; brew uninstall -f clamshell
brew-cleanup:   ⚙️; brew cleanup -s clamshell; rm -rf $(TAP_LOCAL)

cicd: ⚙️ lint test
	# ---------------------------
	# 🧪 testing local install 🧪
	# ---------------------------
	@$(MAKE) install
	type clamshell | grep -q /usr/local/bin/clamshell
	clamshell selftest
	clamshell version
	clamshell install
	clamshell uninstall
	@$(MAKE) uninstall
	@echo "✅ local install tests: OK"
	# --------------------------
	# 🧪 testing brew install 🧪
	# --------------------------
	@$(MAKE) brew-tap brew-audit brew-install
	type clamshell | grep -q /opt/homebrew/bin/clamshell
	clamshell selftest
	clamshell version
	clamshell install
	clamshell uninstall
	@$(MAKE) brew-uninstall brew-cleanup
	@echo "✅ brew install tests: OK"
