LAZBUILD ?= lazbuild
LAZFLAGS ?= --pcp=bin/.lazarus
ifeq ($(OS),Windows_NT)
WIDGETSET ?= win32
WIDGETSETS := win32
else
WIDGETSET ?= gtk2
WIDGETSETS := qt6 qt5 gtk2 gtk3
endif

# Lazarus maintains a shared package cache: serialize widget-set builds.
.NOTPARALLEL:
.PHONY: all default debug release linux clean $(addprefix release-,$(WIDGETSETS)) $(addprefix linux-,$(WIDGETSETS))
all: default debug release
default:
	$(LAZBUILD) $(LAZFLAGS) --ws=$(WIDGETSET) --build-mode=Default pastex.lpi
debug:
	$(LAZBUILD) $(LAZFLAGS) --ws=$(WIDGETSET) --build-mode=Debug pastex.lpi
release: $(addprefix release-,$(WIDGETSETS))
linux: release
$(addprefix release-,$(WIDGETSETS)): release-%:
	$(LAZBUILD) $(LAZFLAGS) --ws=$* --build-mode=Release pastex.lpi
$(addprefix linux-,$(WIDGETSETS)): linux-%: release-%
clean:
	rm -rf bin
