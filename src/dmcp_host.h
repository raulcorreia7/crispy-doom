//
// DMCP host glue shared by the Crispy games: starts the embedded MCP server,
// services it between tics, and reads frames for the per-game ops
// (src/<game>/dmcp_ops.c).
//

#ifndef __DMCP_HOST__
#define __DMCP_HOST__

#ifdef DMCP

#include "dmcp/dmcp.h"

#include "doomtype.h"

extern dmcp_t *dmcp_host;

// Starts DMCP for a game unless -nodmcp is given. Call once, right before
// the main loop. Reads -dmcp_port, -dmcp_bind and -dmcp_allow_cheats.
void DMCP_HostStart(dmcp_game_t game, const char *engine_name,
                    const dmcp_engine_ops_t *ops);

// Fills a frame with the last rendered screen (I_VideoBuffer).
boolean DMCP_HostReadFrame(dmcp_frame_t *out);

#endif // DMCP

#endif
