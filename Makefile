PREFIX     ?= $(HOME)/.local
BINDIR     ?= $(PREFIX)/bin
AGENTS_DIR ?= $(HOME)/Library/LaunchAgents
LABEL      ?= io.github.lykoi18.noflickerbar
POLL       ?= 0.25
DIM_STEP   ?= 2

ARCHS   ?= -arch x86_64 -arch arm64
CFLAGS  ?= -O2 -Wall -Wextra -mmacosx-version-min=10.15
OBJC     = clang $(ARCHS) $(CFLAGS) -fobjc-arc

BUILD   = build
PLIST   = $(AGENTS_DIR)/$(LABEL).plist
DOMAIN  = gui/$(shell id -u)

.PHONY: all install uninstall status clean

all: $(BUILD)/noflickerbar $(BUILD)/dfrbright

$(BUILD)/noflickerbar: src/noflickerbar.m | $(BUILD)
	$(OBJC) -framework Foundation -framework CoreGraphics -framework IOKit -o $@ $<

$(BUILD)/dfrbright: src/dfrbright.m | $(BUILD)
	$(OBJC) -framework Foundation -o $@ $<

$(BUILD):
	mkdir -p $@

install: $(BUILD)/noflickerbar
	mkdir -p "$(BINDIR)" "$(AGENTS_DIR)"
	[ "$(abspath $(BINDIR))" = "$(abspath $(BUILD))" ] || install -m 755 $(BUILD)/noflickerbar "$(BINDIR)/noflickerbar"
	sed -e 's|@LABEL@|$(LABEL)|g' -e 's|@BIN@|$(abspath $(BINDIR))/noflickerbar|g' \
	    -e 's|@POLL@|$(POLL)|g' -e 's|@DIM_STEP@|$(DIM_STEP)|g' \
	    launchd/noflickerbar.plist.in > "$(PLIST)"
	@launchctl bootout $(DOMAIN)/$(LABEL) 2>/dev/null || true
	launchctl bootstrap $(DOMAIN) "$(PLIST)"
	@echo "noflickerbar installed and running ($(LABEL))"

uninstall:
	@launchctl bootout $(DOMAIN)/$(LABEL) 2>/dev/null || true
	rm -f "$(PLIST)"
	[ "$(abspath $(BINDIR))" = "$(abspath $(BUILD))" ] || rm -f "$(BINDIR)/noflickerbar"
	@echo "noflickerbar removed"

status:
	@launchctl print $(DOMAIN)/$(LABEL) 2>/dev/null | grep -E '^\s*(state|pid|last exit code)' || echo "not loaded"
	@/usr/bin/log show --last 1h --style compact --predicate 'process == "noflickerbar" AND sender == "noflickerbar"' | tail -5

clean:
	rm -rf $(BUILD)
