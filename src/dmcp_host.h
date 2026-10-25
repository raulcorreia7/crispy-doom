//
// DMCP host glue shared by the Crispy games: starts the embedded MCP server,
// services it between tics, and provides the frame and unit helpers that the
// per-game ops (src/<game>/dmcp_ops.c) use.
//

#ifndef __DMCP_HOST__
#define __DMCP_HOST__

#ifdef DMCP

#include "dmcp/dmcp.h"

#include "doomtype.h"
#include "m_fixed.h"
#include "tables.h"

extern dmcp_t *dmcp_host;

// Starts DMCP for a game unless -nodmcp is given. Call once, right before
// the main loop. Reads -dmcp_port, -dmcp_bind and -dmcp_allow_cheats.
void DMCP_HostStart(dmcp_game_t game, const char *engine_name,
                    const dmcp_engine_ops_t *ops);

// Fills a frame with the last rendered screen (I_VideoBuffer).
boolean DMCP_HostReadFrame(dmcp_frame_t *out);

// Unit conversions between engine and DMCP (map units, degrees).
static inline double DMCP_FixedToDouble(fixed_t value)
{
    return (double) value / FRACUNIT;
}

static inline fixed_t DMCP_DoubleToFixed(double value)
{
    return (fixed_t) (value * FRACUNIT);
}

static inline double DMCP_AngleToDegrees(angle_t angle)
{
    return (double) angle * (360.0 / 4294967296.0);
}

static inline angle_t DMCP_DegreesToAngle(double degrees)
{
    double turns = degrees / 360.0;

    turns -= (double) (long long) turns;
    if (turns < 0)
    {
        turns += 1.0;
    }
    return (angle_t) (turns * 4294967296.0);
}

#endif // DMCP

#endif
