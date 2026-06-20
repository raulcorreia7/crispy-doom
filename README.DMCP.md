# Crispy Doom with DMCP

DMCP-enabled `crispy-doom` build with ready-to-use agent config files.
DMCP exposes the running game to MCP clients through one bundled shared runtime
while keeping the code organized into clear layers:

```text
Crispy Doom -> Crispy adapter -> Doom MCP -> Generic MCP -> core API/runtime
```

The boundary from Crispy into DMCP is C-compatible. C++ consumers of the SDK use
the source-stable protocol-name wrappers in `include/dmcp/doom/protocol.h` from
the `doom-mcp` repository.

## Quick Start

Linux:

```bash
curl -L https://github.com/raulcorreia7/crispy-doom/releases/latest/download/crispy-doom-dmcp-linux.tar.gz | tar -xz
```

macOS:

```bash
curl -L https://github.com/raulcorreia7/crispy-doom/releases/latest/download/crispy-doom-dmcp-macos.tar.gz | tar -xz
```

Windows (PowerShell):

```powershell
Invoke-WebRequest https://github.com/raulcorreia7/crispy-doom/releases/latest/download/crispy-doom-dmcp-windows.zip -OutFile crispy-doom-dmcp-windows.zip; Expand-Archive crispy-doom-dmcp-windows.zip -DestinationPath . -Force
```

Then:

1. Put an IWAD in the extracted folder, or run `./download_wad.sh` / `download_wad.bat`.
2. Run `./crispy-doom -iwad ./doom1.wad`.
3. `./go.sh` / `go.bat` is the convenience path and auto-downloads `doom1.wad`
   if it is missing.
4. Prefer the bundled Python helper for CLI agents:
   ```bash
   cd agents/python
   uv run dmcp-agent --pretty brief
   uv run dmcp-agent --pretty content enemies
   uv run dmcp-agent spawn DoomImp --x 160 --y 96
   ```
5. Use the preset for your agent tool when you need raw MCP access:
   - Codex uses `agent-presets/codex/config.toml`
   - OpenCode uses `agent-presets/opencode/opencode.json`
   - Claude Code uses `agent-presets/claude/mcp.json`
   - Pi uses `agent-presets/pi/mcp.json`
   - Generic MCP clients use `agent-presets/generic/mcp.json`

MCP runs on `http://localhost:6060/mcp` by default.

For Codex, OpenCode, Claude Code, and similar CLI agents, use `dmcp-agent`
first. It wraps the MCP tools in compact, structured commands so the model does
not need to spend tokens discovering schemas or repeating verbose payloads. Use
direct MCP only for custom clients, debugging, or when you need a tool the helper
does not expose yet.

## Included MCP Configs

Codex:

```toml
[mcp_servers.doom]
url = "http://localhost:6060/mcp"
enabled = true
```

OpenCode:

```json
{
  "mcp": {
    "doom": {
      "type": "remote",
      "url": "http://localhost:6060/mcp",
      "enabled": true
    }
  }
}
```

Claude Code:

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

Generic MCP clients use the same `mcpServers` shape in
`agent-presets/generic/mcp.json`.

The release archive also includes `AGENTS.md` with agent-oriented notes,
`agent-presets/` for raw MCP client configuration, and the optional Python
`dmcp-agent` helper under `agents/python`.

## Notes

- Set `DOOM_WAD` to use a different IWAD.
- Pass `-dmcp_port 6061` if you want a different MCP port.
- DMCP framebuffer capture is compiled out in release builds for now, so
  screenshot tools are not exposed.
- DMCP does not require a global config file in this fork. Runtime behavior is
  controlled by command-line flags; MCP client config files are release payload
  templates only.
- Claude Code and Codex may ask you to trust the project-local MCP config the
  first time you open the extracted folder.
- Source build dependencies and local build steps are in `docs/build-dmcp.md`
  in the repository and `BUILDING.md` in the release artifact.
- Release archives do not bundle WAD files; use your own IWAD or the included
  download script for the Doom shareware WAD.
