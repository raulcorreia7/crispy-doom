# DMCP Agent Helper

This package includes the Python helper used by the package-root `dmcp-agent`
launcher. Prefer that launcher for live gameplay and agent demos:

```bash
cd ../..
./dmcp-agent --pretty brief
./dmcp-agent --pretty content
./dmcp-agent --pretty read player
./dmcp-agent --pretty read enemies --status alive --limit 8
./dmcp-agent spawn DoomImp --x 160 --y 96
./dmcp-agent give Shotgun --amount 1
./dmcp-agent weapon 3
./dmcp-agent input-plan forward --ticks 8
```

On Windows, use `..\..\dmcp-agent.bat` from this directory or
`.\dmcp-agent.bat` from the package root.

The game must already be running. From this directory, start it in one terminal:

```bash
cd ../..
./go.sh
```

Then verify the MCP server from a second terminal:

```bash
curl http://localhost:6060/health
```

The helper requires `uv` and Python 3.10 or newer. First run may download the
locked Python dependencies unless they are already in the local `uv` cache.

If you want to run from this directory directly:

```bash
uv run dmcp-agent --help
uv run dmcp-agent --pretty brief
uv run dmcp-agent --pretty content enemies
uv run dmcp-agent --pretty shell
```

Useful commands:

- `brief`: compact game state, available content, and agent rules.
- `content`: available enemies, entities, items, weapons, ammo, keys, maps, and
  giveable objects for the current game mode.
- `read`: granular reads such as `player`, `map`, `game`, `enemies`,
  `entities`, `items`, and `inventory`.
- `spawn`, `spawn-many`: spawn available entities.
- `give`, `give-many`: give available items, weapons, ammo, keys, or armor.
- `level`: change level after content validation.
- `weapon`, `input`, `input-plan`: control player input.
- `shell`: keep one MCP connection open for repeated commands.
- `tools --compact`: list callable MCP tools without dumping full schemas.

Weapon slots follow Doom controls: `1` Fist/Chainsaw, `2` Pistol, `3`
Shotgun/SuperShotgun, `4` Chaingun, `5` RocketLauncher, `6` PlasmaRifle, `7`
BFG9000.
