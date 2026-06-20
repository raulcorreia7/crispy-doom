# Building Crispy Doom with DMCP

This is the current source-build recipe used by the DMCP release workflow.
The release keeps the layers explicit:

```text
Crispy Doom -> Crispy adapter -> Doom MCP -> Generic MCP -> core API/runtime
```

Crispy builds the adapter sources natively, links the DMCP runtime, and packages
ready-to-use Codex, OpenCode, Claude Code, Pi, and generic MCP config files.

## Build Dependencies

### Linux (Debian/Ubuntu)

```bash
sudo apt-get update
sudo apt-get install -y \
  build-essential cmake git pkg-config \
  libsdl2-dev libsdl2-net-dev libsdl2-mixer-dev \
  libpng-dev libsamplerate0-dev zlib1g-dev
```

Verify the development packages are visible before configuring:

```bash
pkg-config --modversion sdl2 SDL2_net SDL2_mixer libpng samplerate zlib
```

If CMake reports missing `SDL2::SDL2` or `SDL2::SDL2main`, check that
`libsdl2-dev` is installed. Runtime-only packages such as `libsdl2-2.0-0` are
not enough to build Crispy Doom.

### macOS

```bash
brew install cmake git pkg-config sdl2 sdl2_net sdl2_mixer libpng libsamplerate
```

### Windows

- Visual Studio with C/C++ build tools
- CMake
- Git
- vcpkg
- vcpkg packages: `zlib`, `sdl2`, `sdl2-net`, `sdl2-mixer`, `libpng`, `libsamplerate`

## Build DMCP

`doom-mcp` is consumed as the pinned `third_party/doom-mcp` submodule. Clone this
repository with submodules, or initialize them after checkout:

```bash
git submodule update --init --recursive
```

Build the DMCP runtime:

```bash
cmake -S third_party/doom-mcp -B build/dmcp \
  -DDMCP_BUILD_SHARED=ON \
  -DDMCP_BUILD_SINGLE_DLL=ON \
  -DDMCP_BUILD_EXAMPLES=OFF \
  -DDMCP_BUILD_ADAPTER_FAKE=OFF \
  -DDMCP_BUILD_ADAPTER_ZDOOM=OFF \
  -DDMCP_BUILD_ADAPTER_CRISPY=OFF \
  -DCMAKE_BUILD_TYPE=Release

cmake --build build/dmcp --config Release --parallel
```

## Build Crispy Doom

From the `crispy-doom` repository root:

```bash
cmake -S . -B build-dmcp \
  -DDMCP_ENABLE=ON \
  -DDMCP_FRAME_CAPTURE=OFF \
  -DDMCP_ROOT="$PWD/third_party/doom-mcp" \
  -DDMCP_ADAPTER_DIR="$PWD/third_party/doom-mcp/adapters/crispy-doom" \
  -DDMCP_BUILD_DIR="$PWD/build/dmcp" \
  -DDMCP_LIBRARY_DIR="$PWD/build/dmcp" \
  -DCMAKE_BUILD_TYPE=Release

cmake --build build-dmcp --config Release --parallel
```

The current CMake integration requires the unified DMCP shared runtime:
`libdmcp.so` on Linux, `libdmcp.dylib` on macOS, or `dmcp.dll` on Windows.
Crispy does not link static DMCP archives or ship split DMCP layer libraries.

DMCP framebuffer capture is disabled by default with `DMCP_FRAME_CAPTURE=OFF`.
With capture disabled, screenshot tools are not exposed and the DMCP
frame-capture hook is empty.

`DMCP_BUILD_ADAPTER_CRISPY=OFF` is intentional: `crispy-doom` builds the Crispy
adapter sources directly from `DMCP_ADAPTER_DIR`, so the adapter is native to
the game binary rather than shipped as a separate adapter library.

The DMCP public boundary is the C API in the `third_party/doom-mcp/include/` headers. C++
SDK consumers can use the source-stable protocol-name wrappers from
`third_party/doom-mcp/include/dmcp/doom/protocol.h`.

## Release Packaging

The GitHub release workflow runs for `crispy-dmcp-v*` tags. It builds
Linux, macOS, and Windows archives, uploads each archive as a workflow artifact,
then creates the GitHub release from those downloaded artifacts.

Each archive includes:

- `crispy-doom` or `crispy-doom.exe`
- the DMCP runtime library for the platform
- `go.sh`/`go.bat` and `download_wad.sh`/`download_wad.bat`
- `agent-presets/` with Codex, OpenCode, Claude Code, Pi, and generic MCP presets
- `agents/python/` with the optional Python `dmcp-agent` helper
- `README.md`, `BUILDING.md`, `AGENTS.md`, and `VERSION.txt`

WAD files are intentionally not bundled.

## SDK Validation

Run this in `doom-mcp` when you need SDK CI coverage without a Crispy binary or
IWAD:

```bash
cmake -B build/default -DDMCP_BUILD_TESTS=ON -DDMCP_BUILD_INTEGRATION_TESTS=ON -DDMCP_BUILD_ADAPTER_FAKE=ON
cmake --build build/default --parallel
ctest --test-dir build/default -L 'unit|sdk' -LE 'requires_game|e2e' --output-on-failure
```

Use the Crispy build below for engine-backed verification.

## Verify

Do this only for local human verification, not in CI:

```bash
./build-dmcp/src/crispy-doom -iwad /path/to/doom.wad
curl http://localhost:6060/health
```

Use `-dmcp_port <port>` if you need the MCP server on a non-default port.
