# Building Crispy Doom with DMCP

This is the current source-build recipe used by the DMCP release workflow.

## Build Dependencies

### Linux

```bash
sudo apt-get update
sudo apt-get install -y \
  build-essential cmake \
  libsdl2-dev libsdl2-net-dev libsdl2-mixer-dev \
  libpng-dev libsamplerate0-dev zlib1g-dev
```

### macOS

```bash
brew install sdl2 sdl2_net sdl2_mixer libpng libsamplerate
```

### Windows

- Visual Studio with C/C++ build tools
- CMake
- Git
- vcpkg
- vcpkg packages: `zlib`, `sdl2`, `libuv`

## Build DMCP

Clone the latest `doom-mcp` `dev` branch used by the release workflow:

```bash
git clone --branch dev --single-branch https://github.com/raulcorreia7/doom-mcp.git

cmake -S doom-mcp -B doom-mcp/build \
  -DDMCP_BUILD_SHARED=ON \
  -DDMCP_BUILD_SINGLE_DLL=ON \
  -DDMCP_BUILD_EXAMPLES=OFF \
  -DDMCP_BUILD_ADAPTER_FAKE=OFF \
  -DDMCP_BUILD_ADAPTER_ZDOOM=OFF \
  -DDMCP_BUILD_ADAPTER_CRISPY=OFF \
  -DCMAKE_BUILD_TYPE=Release

cmake --build doom-mcp/build --config Release --parallel
```

## Build Crispy Doom

From the `crispy-doom` repository root:

```bash
cmake -S . -B build-dmcp \
  -DDMCP_ENABLE=ON \
  -DDMCP_ROOT="$PWD/doom-mcp" \
  -DDMCP_ADAPTER_DIR="$PWD/doom-mcp/adapters/crispy-doom" \
  -DCMAKE_BUILD_TYPE=Release

cmake --build build-dmcp --config Release --parallel
```

The current CMake integration prefers the unified `dmcp` shared library and
falls back to `dmcp_core` + `dmcp_generic` when needed.

## Verify

```bash
./build-dmcp/src/crispy-doom -iwad /path/to/doom.wad
curl http://localhost:6060/health
```

Use `-dmcp_port <port>` if you need the MCP server on a non-default port.
