PREFIX     ?= $(HOME)/.local
BINDIR     ?= $(PREFIX)/bin
AGENTS_DIR ?= $(HOME)/Library/LaunchAgents
LABEL      ?= io.github.touchbarkiller.tbkeepon
POLL       ?= 0.25
DIM_STEP   ?= 2

ARCHS   ?= -arch x86_64 -arch arm64
CFLAGS  ?= -O2 -Wall -Wextra -mmacosx-version-min=10.15
OBJC     = clang $(ARCHS) $(CFLAGS) -fobjc-arc

BUILD   = build
PLIST   = $(AGENTS_DIR)/$(LABEL).plist
DOMAIN  = gui/$(shell id -u)

.PHONY: all install uninstall status clean

all: $(BUILD)/tbkeepon $(BUILD)/dfrbright

$(BUILD)/tbkeepon: src/tbkeepon.m | $(BUILD)
	$(OBJC) -framework Foundation -framework CoreGraphics -framework IOKit -o $@ $<

$(BUILD)/dfrbright: src/dfrbright.m | $(BUILD)
	$(OBJC) -framework Foundation -o $@ $<

$(BUILD):
	mkdir -p $@

install: $(BUILD)/tbkeepon
	mkdir -p "$(BINDIR)" "$(AGENTS_DIR)"
	[ "$(abspath $(BINDIR))" = "$(abspath $(BUILD))" ] || install -m 755 $(BUILD)/tbkeepon "$(BINDIR)/tbkeepon"
	sed -e 's|@LABEL@|$(LABEL)|g' -e 's|@BIN@|$(abspath $(BINDIR))/tbkeepon|g' \
	    -e 's|@POLL@|$(POLL)|g' -e 's|@DIM_STEP@|$(DIM_STEP)|g' \
	    launchd/tbkeepon.plist.in > "$(PLIST)"
	-launchctl bootout $(DOMAIN)/$(LABEL) 2>/dev/null
	launchctl bootstrap $(DOMAIN) "$(PLIST)"
	@echo "tbkeepon installed and running ($(LABEL))"

uninstall:
	-launchctl bootout $(DOMAIN)/$(LABEL) 2>/dev/null
	rm -f "$(PLIST)"
	[ "$(abspath $(BINDIR))" = "$(abspath $(BUILD))" ] || rm -f "$(BINDIR)/tbkeepon"
	@echo "tbkeepon removed"

status:
	@launchctl print $(DOMAIN)/$(LABEL) 2>/dev/null | grep -E '^\s*(state|pid|last exit code)' || echo "not loaded"
	@/usr/bin/log show --last 1h --style compact --predicate 'process == "tbkeepon"' | tail -5

clean:
	rm -rf $(BUILD)
