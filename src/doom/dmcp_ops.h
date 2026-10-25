//
// DMCP engine ops for Doom (see src/dmcp_host.h).
//

#ifndef __DOOM_DMCP_OPS__
#define __DOOM_DMCP_OPS__

#include "d_ticcmd.h"

// Starts the MCP server. Called once from D_DoomMain.
void DMCP_DoomStart(void);

// Merges agent input into a ticcmd. Called from G_BuildTiccmd.
void DMCP_ApplyInput(ticcmd_t *cmd, int maketic);

#endif
