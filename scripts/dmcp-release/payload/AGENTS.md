# Crispy Doom DMCP Agent Notes

Start the game with DMCP enabled before using an MCP client:

```bash
./go.sh
```

On Windows use:

```bat
.\go.bat
```

The release package listens on `http://localhost:6060/mcp` by default. Use
`-dmcp_port <port>` if you need a different port.
Framebuffer capture is compiled out in this release, so screenshot tools are
not exposed.

## Python Agent CLI

The package includes the DMCP Python helper under `agents/python`. It uses `uv`
and talks to the running MCP server.

```bash
./dmcp-agent --pretty brief
./dmcp-agent --pretty read enemies --status alive --limit 8
./dmcp-agent --pretty read items --kind armor --limit 8
./dmcp-agent spawn DoomImp --x 160 --y 96
./dmcp-agent give Shotgun --amount 1
./dmcp-agent weapon 3
./dmcp-agent input-plan forward --ticks 8
```

On Windows use `.\dmcp-agent.bat`. The helper requires `uv` and Python 3.10 or
newer; install `uv` from <https://docs.astral.sh/uv/> if the launcher reports it
is missing. First run may download locked Python dependencies unless they are
already cached.

Use exact names from `./dmcp-agent --pretty content`. Batch commands use
canonical DMCP fields only:

```bash
./dmcp-agent batch --calls-json '[{"name":"give_item","arguments":{"item_class":"Shotgun","amount":1}}]'
```

`change_level` and `player_input` are direct tools. Use `level`, `input`,
`weapon`, or `input-plan` rather than putting them in `batch`.
