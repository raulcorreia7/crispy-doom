//
// DMCP engine ops for Hexen (see src/dmcp_host.h).
//

#ifndef __HEXEN_DMCP_OPS__
#define __HEXEN_DMCP_OPS__

#include "d_ticcmd.h"

// Starts the MCP server. Called once from H2_Main.
void DMCP_HexenStart(void);

// Merges agent input into a ticcmd. Called from G_BuildTiccmd.
void DMCP_ApplyInput(ticcmd_t *cmd, int maketic);

#endif
