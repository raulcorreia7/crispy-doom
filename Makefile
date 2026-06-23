SHELL := /bin/bash

.DEFAULT_GOAL := help

CMAKE ?= cmake
BUILD_TYPE ?= Release
DMCP_BUILD_DIR ?= build/dmcp
APP_BUILD_DIR ?= build-dmcp
PRESETS_DIR ?= scripts/dmcp-release/payload/agent-presets
PAYLOAD_DIR ?= scripts/dmcp-release/payload
DOWNLOAD_ARGS ?=

ROOT_DIR := $(CURDIR)
DMCP_ROOT := $(ROOT_DIR)/third_party/doom-mcp
DMCP_ADAPTER_DIR := $(DMCP_ROOT)/adapters/crispy-doom

.PHONY: help setup configure-dmcp build-dmcp configure build all \
	codex opencode claude pi generic agents ensure-agents \
	download-d1 download-d2 clean distclean

help:
	@printf '%s\n' 'Crispy Doom DMCP build helpers'
	@printf '\n%s\n' 'Targets:'
	@printf '  %-16s %s\n' 'all' 'Set up submodules and build DMCP plus the app'
	@printf '  %-16s %s\n' 'setup' 'Initialize and update all git submodules'
	@printf '  %-16s %s\n' 'configure-dmcp' 'Configure the DMCP runtime CMake build'
	@printf '  %-16s %s\n' 'build-dmcp' 'Build the DMCP runtime'
	@printf '  %-16s %s\n' 'configure' 'Configure the Crispy Doom DMCP app build'
	@printf '  %-16s %s\n' 'build' 'Build DMCP first, then the Crispy Doom app'
	@printf '  %-16s %s\n' 'codex' 'Install AGENTS.md and Codex MCP preset'
	@printf '  %-16s %s\n' 'opencode' 'Install AGENTS.md and OpenCode MCP preset'
	@printf '  %-16s %s\n' 'claude' 'Install AGENTS.md and Claude MCP preset'
	@printf '  %-16s %s\n' 'pi' 'Install AGENTS.md and Pi MCP preset'
	@printf '  %-16s %s\n' 'generic' 'Install AGENTS.md and generic MCP preset'
	@printf '  %-16s %s\n' 'agents' 'Install all packaged agent presets'
	@printf '  %-16s %s\n' 'download-d1' 'Download Doom shareware doom1.wad'
	@printf '  %-16s %s\n' 'download-d2' 'Download Doom II doom2.wad'
	@printf '  %-16s %s\n' 'clean' 'Run CMake clean for existing build trees'
	@printf '  %-16s %s\n' 'distclean' 'Remove DMCP and app build directories'
	@printf '\n%s\n' 'Variables: CMAKE, BUILD_TYPE, DMCP_BUILD_DIR, APP_BUILD_DIR, DOWNLOAD_ARGS'

setup:
	git submodule update --init --recursive

configure-dmcp:
	$(CMAKE) -S third_party/doom-mcp -B $(DMCP_BUILD_DIR) \
		-DDMCP_BUILD_SHARED=ON \
		-DDMCP_BUILD_SINGLE_DLL=ON \
		-DDMCP_BUILD_EXAMPLES=OFF \
		-DDMCP_BUILD_ADAPTER_FAKE=OFF \
		-DDMCP_BUILD_ADAPTER_ZDOOM=OFF \
		-DDMCP_BUILD_ADAPTER_CRISPY=OFF \
		-DCMAKE_BUILD_TYPE=$(BUILD_TYPE)

build-dmcp: configure-dmcp
	$(CMAKE) --build $(DMCP_BUILD_DIR) --config $(BUILD_TYPE) --parallel

configure:
	$(CMAKE) -S . -B $(APP_BUILD_DIR) \
		-DDMCP_ENABLE=ON \
		-DDMCP_FRAME_CAPTURE=OFF \
		-DDMCP_ROOT="$(DMCP_ROOT)" \
		-DDMCP_ADAPTER_DIR="$(DMCP_ADAPTER_DIR)" \
		-DDMCP_BUILD_DIR="$(ROOT_DIR)/$(DMCP_BUILD_DIR)" \
		-DDMCP_LIBRARY_DIR="$(ROOT_DIR)/$(DMCP_BUILD_DIR)" \
		-DCMAKE_BUILD_TYPE=$(BUILD_TYPE)

build: build-dmcp
	$(MAKE) configure
	$(CMAKE) --build $(APP_BUILD_DIR) --config $(BUILD_TYPE) --parallel

all:
	$(MAKE) setup
	$(MAKE) build

ensure-agents:
	@if [[ -f "$(PAYLOAD_DIR)/AGENTS.md" ]]; then \
		cp "$(PAYLOAD_DIR)/AGENTS.md" AGENTS.md; \
		printf '%s\n' 'Installed AGENTS.md from packaged payload'; \
	elif [[ -f AGENTS.md ]]; then \
		printf '%s\n' 'Packaged AGENTS.md not found; keeping existing root AGENTS.md'; \
	else \
		printf '%s\n' 'error: missing packaged AGENTS.md and no root AGENTS.md exists' >&2; \
		exit 1; \
	fi

codex: ensure-agents
	@test -f "$(PRESETS_DIR)/codex/config.toml" || { printf '%s\n' 'error: missing Codex preset' >&2; exit 1; }
	mkdir -p .codex
	cp "$(PRESETS_DIR)/codex/config.toml" .codex/config.toml
	@printf '%s\n' 'Installed Codex preset to .codex/config.toml'

opencode: ensure-agents
	@test -f "$(PRESETS_DIR)/opencode/opencode.json" || { printf '%s\n' 'error: missing OpenCode preset' >&2; exit 1; }
	cp "$(PRESETS_DIR)/opencode/opencode.json" opencode.json
	@printf '%s\n' 'Installed OpenCode preset to opencode.json'

claude: ensure-agents
	@test -f "$(PRESETS_DIR)/claude/mcp.json" || { printf '%s\n' 'error: missing Claude preset' >&2; exit 1; }
	cp "$(PRESETS_DIR)/claude/mcp.json" .mcp.json
	@printf '%s\n' 'Installed Claude preset to .mcp.json'

pi: ensure-agents
	@test -f "$(PRESETS_DIR)/pi/mcp.json" || { printf '%s\n' 'error: missing Pi preset' >&2; exit 1; }
	cp "$(PRESETS_DIR)/pi/mcp.json" pi.mcp.json
	@printf '%s\n' 'Installed Pi preset to pi.mcp.json'

generic: ensure-agents
	@test -f "$(PRESETS_DIR)/generic/mcp.json" || { printf '%s\n' 'error: missing generic preset' >&2; exit 1; }
	cp "$(PRESETS_DIR)/generic/mcp.json" mcp.json
	@printf '%s\n' 'Installed generic preset to mcp.json'

agents:
	$(MAKE) codex
	$(MAKE) opencode
	$(MAKE) claude
	$(MAKE) pi
	$(MAKE) generic

download-d1:
	scripts/dmcp-release/download_wad.sh -o doom1.wad $(DOWNLOAD_ARGS)

download-d2:
	scripts/download_doom2_wad.sh -o doom2.wad $(DOWNLOAD_ARGS)

clean:
	@if [[ -d "$(DMCP_BUILD_DIR)" ]]; then \
		$(CMAKE) --build "$(DMCP_BUILD_DIR)" --config "$(BUILD_TYPE)" --target clean; \
	fi
	@if [[ -d "$(APP_BUILD_DIR)" ]]; then \
		$(CMAKE) --build "$(APP_BUILD_DIR)" --config "$(BUILD_TYPE)" --target clean; \
	fi

distclean:
	rm -rf "$(DMCP_BUILD_DIR)" "$(APP_BUILD_DIR)"
