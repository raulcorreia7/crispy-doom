# Crispy Doom Agent Notes

Start a game with DMCP before using an MCP client:

```bash
./go.sh [doom|heretic|hexen|strife]
```

On Windows use `.\go.bat`. The server is `http://127.0.0.1:6060/mcp`
(Streamable HTTP, JSON mode); health is `GET /health`. Use `-dmcp_port <port>`
for another port.

`go.sh` and `go.bat` start the game with `-dmcp_allow_cheats`. Without that flag
the tools that change the game (`change_level`, `spawn`, `give`, `cheat`,
`teleport`, `damage`, `console`) are not registered. Read the live tool list
with `tools/list` or `./dmcp-agent tools`; tool arguments are in
`DMCP-TOOLS.md`.

## Python agent

`dmcp-agent` needs Python 3.10 or newer and no other packages.

```bash
./dmcp-agent tools
./dmcp-agent state --sections player --limit 8
./dmcp-agent input "forward 35; turn_to 90; attack 10; wait"
./dmcp-agent call spawn '{"things":[{"type":"imp","distance":128}]}'
./dmcp-agent call give items='[{"name":"Shotgun"}]'
./dmcp-agent batch calls.json
```

On Windows use `.\dmcp-agent.bat`. Get type and map names for the running game
from `./dmcp-agent call list_content`.
