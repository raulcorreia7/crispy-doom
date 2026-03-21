# Crispy Doom with DMCP

DMCP-enabled `crispy-doom` build with ready-to-use agent config files.

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
2. Start `./crispy-doom -iwad ./doom1.wad` or use `./go.sh` / `go.bat`.
3. Open that folder in your agent tool:
   - OpenCode loads `opencode.json`
   - Claude Code loads `.mcp.json`
   - Codex loads `.codex/config.toml`

MCP runs on `http://localhost:6060/mcp` by default.

## Notes

- Set `DOOM_WAD` to use a different IWAD.
- Pass `-dmcp_port 6061` if you want a different MCP port.
- Claude Code and Codex may ask you to trust the project-local MCP config the
  first time you open the extracted folder.
- Source build dependencies and local build steps are in `docs/build-dmcp.md`
  in the repository and `BUILDING.md` in the release artifact.
