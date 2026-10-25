# Crispy Doom with DMCP

Crispy Doom, Crispy Heretic, Crispy Hexen, and Crispy Strife with an embedded
MCP server. Play normally while an AI assistant reads the game state and
controls the player through [MCP](https://modelcontextprotocol.io).

The server listens on `http://127.0.0.1:6060/mcp` (Streamable HTTP, JSON mode)
and accepts connections from your machine only.

## Quick start

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

Check the server from a second terminal:

```bash
curl http://127.0.0.1:6060/health
```

## Launchers

`go.sh [doom|heretic|hexen|strife] [args...]` (`go.bat` on Windows) starts a
game, `doom` by default. It passes `-dmcp_allow_cheats` (see
[Flags](#flags)) and forwards every other argument.

- Doom: uses `-iwad` if you pass it, else `DOOM_WAD`, else `./doom1.wad`. A
  missing `doom1.wad` is downloaded as the checksum-verified shareware IWAD.
- Heretic, Hexen, Strife: use `-iwad` or `DOOM_WAD` if set, else the IWAD search
  of the engine. The package contains no WAD files.

To start without cheat tools, run `./crispy-doom` (or `crispy-heretic`,
`crispy-hexen`, `crispy-strife`) directly.

## Flags

| Flag or variable | Meaning |
|---|---|
| `-nodmcp` | Do not start the server. |
| `-dmcp_port N` | Listen on port `N` (default `6060`). |
| `-dmcp_bind ADDR` | Listen on `ADDR` (default `127.0.0.1`). |
| `-dmcp_allow_cheats` | Register the tools that change the game. Without it they do not exist. |
| `DMCP_BIND_ADDRESS` | Same as `-dmcp_bind`. |
| `DMCP_ALLOWED_ORIGIN` | Browser `Origin` the server accepts besides loopback origins. |

Anyone who can reach the port can control the game. Bind to a non-loopback
address only on a network you trust.

## Connect an MCP client

Claude Code:

```bash
claude mcp add --transport http doom http://127.0.0.1:6060/mcp
```

Other clients: copy or merge a preset from `agent-presets/` into the client
configuration.

- Codex: `agent-presets/codex/config.toml`
- OpenCode: `agent-presets/opencode/opencode.json`
- Claude Code: `agent-presets/claude/mcp.json`
- Pi: `agent-presets/pi/mcp.json`
- Other clients: `agent-presets/generic/mcp.json`

All presets point to `http://127.0.0.1:6060/mcp`. Start the game first, then
the client.

## Tools

| Tool | Purpose |
|---|---|
| `get_state` | Game, level, player, and nearby entities. |
| `list_content` | Maps, thing types, and cheat names of the running game. |
| `screenshot` | Frame as PNG, JPEG, or ASCII art. |
| `wait` | Wait a number of tics. |
| `input` | Move, turn, aim, attack, use, and switch weapon as a step plan. |
| `batch` | Run several tool calls in one frame. |

These tools need `-dmcp_allow_cheats`:

| Tool | Purpose |
|---|---|
| `change_level` | Warp to a map. |
| `spawn` | Spawn things. |
| `give` | Give items, weapons, ammo, keys. |
| `cheat` | God mode, noclip, all weapons, and similar. |
| `teleport` | Move the player. |
| `damage` | Damage or kill an entity. |
| `console` | Send a cheat code string. |

A tool is also absent when the game does not support it. Arguments, results,
and units are in `DMCP-TOOLS.md` (in the repository:
`third_party/doom-mcp/docs/design/v1-tools.md`).

## Python agent

`dmcp-agent` (`dmcp-agent.bat` on Windows) is a small command-line client for
the server. It needs Python 3.10 or newer and no other packages.

```bash
./dmcp-agent health
./dmcp-agent tools                      # names and one-line descriptions
./dmcp-agent tools screenshot           # input schema of one tool
./dmcp-agent state --sections player --limit 8
./dmcp-agent shot --format ascii --width 100
./dmcp-agent input "forward 35; turn_to 90; attack 10; wait"
./dmcp-agent call give items='[{"name":"Shotgun"}]'
./dmcp-agent shell                      # one MCP session, many commands
```

Options: `--url URL` (env `DMCP_URL`) and `--timeout SECONDS` before the
command; `--pretty` and `--out PATH` after it. More in `agents/python/README.md`, or run
`./dmcp-agent --help`.

## Package contents

- `crispy-doom`, `crispy-heretic`, `crispy-hexen`, `crispy-strife`
  (`.exe` on Windows; with the SDL runtime DLLs).
- `go.sh` / `go.bat`, `download_wad.sh` / `download_wad.bat`,
  `dmcp-agent` / `dmcp-agent.bat`.
- `agents/python/`: the Python agent source.
- `agent-presets/`: MCP client configuration files.
- `AGENTS.md`: usage notes for AI agents.
- `DMCP-TOOLS.md`: the tool contract.
- `BUILDING.md`: build from source.
- `VERSION.txt`, `COPYING.md`, `AUTHORS`, `DMCP-LICENSE` (MIT),
  `third-party-licenses/`.

## Runtime dependencies

- Linux: SDL2, SDL2_net, SDL2_mixer, FluidSynth, libpng, libsamplerate, zlib.
  On Debian or Ubuntu:
  `sudo apt-get install libsdl2-2.0-0 libsdl2-net-2.0-0 libsdl2-mixer-2.0-0 libfluidsynth3 libpng16-16 libsamplerate0 zlib1g`
- macOS: `brew install sdl2 sdl2_net sdl2_mixer fluid-synth libpng libsamplerate`
- Windows: none; the DLLs are in the package.
- `download_wad.sh` needs `curl` or `wget`, and `sha256sum` or `shasum`.
