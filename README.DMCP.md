# Crispy Doom with DMCP

This is a Crispy Doom package with DMCP support. It lets you play Doom normally
and, at the same time, let an AI assistant inspect or control the running game
through MCP.

DMCP runs locally at `http://localhost:6060/mcp` by default. For Codex,
OpenCode, Claude Code, Pi, and similar tools, use the bundled `dmcp-agent`
helper first. It is easier for models to use than raw MCP because it returns
compact, structured output and hides verbose schemas.

## Quick Start

Linux:

```bash
curl -fL https://github.com/raulcorreia7/crispy-doom/releases/latest/download/crispy-doom-linux-x86_64.tar.gz | tar -xz
cd crispy-doom-linux-x86_64
./go.sh
```

macOS:

```bash
curl -fL https://github.com/raulcorreia7/crispy-doom/releases/latest/download/crispy-doom-macos-arm64.tar.gz | tar -xz
cd crispy-doom-macos-arm64
./go.sh
```

Windows PowerShell:

```powershell
Invoke-WebRequest https://github.com/raulcorreia7/crispy-doom/releases/latest/download/crispy-doom-windows-x86_64.zip -OutFile crispy-doom-windows-x86_64.zip; Expand-Archive crispy-doom-windows-x86_64.zip -DestinationPath . -Force
cd crispy-doom-windows-x86_64
.\go.bat
```

`go.sh` / `go.bat` starts the game. If `doom1.wad` is missing, it downloads the
checksum-verified Doom shareware IWAD. You can also set `DOOM_WAD` or pass
`-iwad` to use your own IWAD.

Keep the game running. Open a second terminal in the extracted package folder
for AI interaction.

## For Players

Recommended path:

```bash
./dmcp-agent --pretty brief
./dmcp-agent --pretty content enemies
./dmcp-agent --pretty read player
./dmcp-agent --pretty read enemies --status alive --limit 8
```

Once a level is loaded, try controlled actions:

```bash
./dmcp-agent spawn DoomImp --x 160 --y 96
./dmcp-agent give Shotgun --amount 1
./dmcp-agent give-many --items-json '[{"item_class":"Shotgun","amount":1},{"item_class":"Shells","amount":20}]'
./dmcp-agent weapon 3
./dmcp-agent input-plan forward --ticks 8
./dmcp-agent level E1M2 --skill-level 3
```

On Windows, use `.\dmcp-agent.bat` instead of `./dmcp-agent`.

The helper requires `uv` and Python 3.10 or newer. Install `uv` from
<https://docs.astral.sh/uv/> if the launcher reports it is missing. First run
may download locked Python dependencies unless they are already cached.

## Agent CLI

Use `dmcp-agent` when you are asking a coding or chat agent to play with the
game. It keeps commands stable and compact:

```bash
./dmcp-agent --pretty brief
./dmcp-agent --pretty content
./dmcp-agent --pretty tools --compact
./dmcp-agent --pretty shell
```

Useful commands:

- `brief`: compact game state, available content, and agent rules.
- `content`: available enemies, items, weapons, ammo, keys, maps, and giveable
  objects for the current game mode.
- `read`: granular reads such as `player`, `map`, `game`, `enemies`,
  `entities`, `items`, and `inventory`.
- `spawn`, `spawn-many`: spawn available entities.
- `give`, `give-many`: give available items, weapons, ammo, keys, or armor.
- `level`: change level after content validation.
- `weapon`, `input`, `input-plan`: control player input.
- `shell`: keep one MCP connection open for repeated commands.

Weapon slots follow Doom controls: `1` Fist/Chainsaw, `2` Pistol, `3`
Shotgun/SuperShotgun, `4` Chaingun, `5` RocketLauncher, `6` PlasmaRifle, `7`
BFG9000.

More examples are in `agents/python/README.md`.

## Code Editors and MCP Clients

Use raw MCP config when your preferred editor or agent client supports MCP
directly. This package includes copy-ready presets:

- Codex: `agent-presets/codex/config.toml`
- OpenCode: `agent-presets/opencode/opencode.json`
- Claude Code: `agent-presets/claude/mcp.json`
- Pi: `agent-presets/pi/mcp.json`
- Generic MCP clients: `agent-presets/generic/mcp.json`

All presets point to the local server:

```text
http://localhost:6060/mcp
```

Minimal Codex config:

```toml
[mcp_servers.doom]
url = "http://localhost:6060/mcp"
enabled = true
```

Minimal MCP JSON config:

```json
{
  "mcpServers": {
    "doom": {
      "type": "http",
      "url": "http://localhost:6060/mcp"
    }
  }
}
```

Copy or merge the matching preset into your MCP client configuration when you
want direct MCP access. The package does not auto-enable editor configs from the
extracted folder. Use raw MCP for custom clients, debugging, or tools not
exposed by the helper. For normal agent gameplay, prefer `dmcp-agent`.

## For Developers

Package layout:

- `crispy-doom` / `crispy-doom.exe`: game executable.
- `libdmcp.so`, `libdmcp.dylib`, or `dmcp.dll`: bundled DMCP shared runtime.
- `go.sh` / `go.bat`: start the game with a default IWAD.
- `dmcp-agent` / `dmcp-agent.bat`: run the Python agent helper from package root.
- `agents/python/`: helper source and `uv.lock`.
- `agent-presets/`: raw MCP config files for common clients.
- `BUILDING.md`: source build notes for this fork.
- `AGENTS.md`: concise agent-oriented usage notes.
- `COPYING.md`, `AUTHORS`: license and attribution files.

Useful checks:

```bash
curl http://localhost:6060/health
./dmcp-agent --pretty tools --compact
./dmcp-agent --pretty content
```

The game integration uses a single shared DMCP runtime and a thin Crispy adapter:

```text
Crispy Doom -> Crispy adapter -> Doom MCP -> Generic MCP -> core API/runtime
```

The boundary from Crispy into DMCP is C-compatible. C++ SDK consumers can use
the source-stable protocol wrappers from the `doom-mcp` SDK.

## Runtime Dependencies

- Linux packages expect SDL2, SDL2_net, SDL2_mixer, FluidSynth, libpng,
  libsamplerate, and zlib runtime libraries from the system package manager. On
  Debian/Ubuntu:
  `sudo apt-get install libsdl2-2.0-0 libsdl2-net-2.0-0 libsdl2-mixer-2.0-0 libfluidsynth3 libpng16-16 libsamplerate0 zlib1g`.
- macOS packages expect the same runtime libraries from Homebrew when they are
  not already available:
  `brew install sdl2 sdl2_net sdl2_mixer fluid-synth libpng libsamplerate`.
- Unix WAD download uses `curl` or `wget`, `tar` for the fallback archive, and
  `sha256sum` or `shasum` for checksum verification.
- The agent helper requires `uv` and Python 3.10 or newer:
  <https://docs.astral.sh/uv/>. First run may download locked Python
  dependencies unless the `uv` cache is already warm.

## Notes

- Pass `-dmcp_port 6061` to use a different MCP port.
- DMCP framebuffer capture is compiled out in release builds for now, so
  screenshot tools are not exposed.
- DMCP does not require a global config file in this fork. Runtime behavior is
  controlled by command-line flags; MCP client files in `agent-presets/` are
  templates to copy or merge into your preferred client.
- Release archives do not bundle WAD files. The included downloader verifies
  the expected SHA256 for the shareware `doom1.wad`.
