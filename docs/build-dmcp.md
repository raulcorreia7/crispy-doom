# Building Crispy Doom with DMCP

DMCP is two static libraries (`gmcp`, `dmcp`) from the `third_party/doom-mcp`
submodule. CMake builds them with the games and links them into
`crispy-doom`, `crispy-heretic`, `crispy-hexen`, and `crispy-strife`. DMCP needs no
separate build step.

## Dependencies

- CMake 3.16 or newer, git, and a C and C++17 compiler.
- Network access on the first configure: DMCP downloads yyjson and cpp-httplib
  into `third_party/doom-mcp/.cache`.

### Linux (Debian/Ubuntu)

```bash
sudo apt-get update
sudo apt-get install -y \
  build-essential cmake git pkg-config \
  libsdl2-dev libsdl2-net-dev libsdl2-mixer-dev \
  libfluidsynth-dev libpng-dev libsamplerate0-dev zlib1g-dev
```

Runtime-only packages such as `libsdl2-2.0-0` are not enough to build.

### macOS

```bash
brew install cmake git pkg-config sdl2 sdl2_net sdl2_mixer fluid-synth libpng libsamplerate
```

### Windows

- Visual Studio with C/C++ build tools, CMake, Git
- vcpkg with `zlib`, `sdl2`, `sdl2-net`, `sdl2-mixer`, `fluidsynth`, `libpng`,
  `libsamplerate`

## Build

Clone with submodules, or initialize them after checkout:

```bash
git submodule update --init --recursive
```

From the repository root:

```bash
cmake -S . -B build -DDMCP_ENABLE=ON -DCMAKE_BUILD_TYPE=Release
cmake --build build --config Release --parallel \
  --target crispy-doom crispy-heretic crispy-hexen crispy-strife
```

`DMCP_ENABLE` is `ON` by default. With `-DDMCP_ENABLE=OFF` the games build
without the submodule.

On Windows, add `-DCMAKE_TOOLCHAIN_FILE=<vcpkg>/scripts/buildsystems/vcpkg.cmake`
and `-DVCPKG_TARGET_TRIPLET=x64-windows`. The executables are in
`build/src/Release`.

The binaries are `build/src/crispy-doom`, `crispy-heretic`, `crispy-hexen`,
and `crispy-strife`.

## Run

```bash
./build/src/crispy-doom -iwad /path/to/doom.wad
curl http://127.0.0.1:6060/health
```

Runtime flags: `-nodmcp`, `-dmcp_port N`, `-dmcp_bind ADDR`,
`-dmcp_allow_cheats`. See `README.DMCP.md`.

## Release packages

`scripts/dmcp-release` builds and packages the archives that the
`Crispy Doom Release` workflow publishes for `crispy-doom-v*` tags:

```bash
scripts/dmcp-release/install_deps.sh --platform linux
scripts/dmcp-release/build.sh --platform linux
scripts/dmcp-release/package.sh --platform linux \
  --artifact-name crispy-doom-linux-x86_64 \
  --asset-name crispy-doom-linux-x86_64.tar.gz
```

`build.sh` options: `--platform linux|macos|windows` (required),
`--build-dir DIR` (default `build`), `--build-type TYPE` (default `Release`).

`package.sh` writes `--asset-name` and runs `verify_package.sh` on it. Options:
`--package-arch`, `--release-tag`, `--build-dir`, `--build-type`,
`--package-root`. The archive name includes the platform and the native
architecture, for example `crispy-doom-macos-arm64.tar.gz` or
`crispy-doom-windows-x86_64.zip`.

Each archive contains the four game executables (and the SDL runtime DLLs on
Windows), the launchers, the stdlib-only Python agent, MCP client presets,
`README.md`, `BUILDING.md`, `AGENTS.md`, `DMCP-TOOLS.md`, `VERSION.txt`, and the
license files (`COPYING.md`, `AUTHORS`, `DMCP-LICENSE`,
`third-party-licenses/`). WAD files are not bundled.

## DMCP tests

Run in `third_party/doom-mcp` (needs no game or IWAD):

```bash
cmake -B build -DDMCP_BUILD_TESTS=ON
cmake --build build --parallel
ctest --test-dir build --output-on-failure
```
