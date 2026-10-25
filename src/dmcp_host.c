//
// DMCP host glue shared by the Crispy games.
//

#ifdef DMCP

#include <stdlib.h>

#include "dmcp_host.h"

#include "d_loop.h"
#include "i_system.h"
#include "i_video.h"
#include "m_argv.h"

dmcp_t *dmcp_host = NULL;

static void DMCP_HostService(void)
{
    dmcp_service(dmcp_host);
}

static void DMCP_HostShutdown(void)
{
    D_LoopServiceHook = NULL;
    dmcp_destroy(dmcp_host);
    dmcp_host = NULL;
}

void DMCP_HostStart(dmcp_game_t game, const char *engine_name,
                    const dmcp_engine_ops_t *ops)
{
    dmcp_config_t config = dmcp_config_default();

    if (dmcp_host != NULL)
    {
        return;
    }

    dmcp_config_from_argv(&config, myargc, myargv);
    config.game = game;
    config.engine_name = engine_name;
    config.ops = ops;
    config.types = dmcp_types(game, &config.type_count);

    dmcp_host = dmcp_create(&config);
    if (dmcp_host == NULL)
    {
        return;
    }

    D_LoopServiceHook = DMCP_HostService;
    I_AtExit(DMCP_HostShutdown, true);
}

boolean DMCP_HostReadFrame(dmcp_frame_t *out)
{
#ifndef CRISPY_TRUECOLOR
    static byte palette[256 * 3];
#endif

    if (I_VideoBuffer == NULL)
    {
        return false;
    }

    out->pixels = (const uint8_t *) I_VideoBuffer;
    out->width = SCREENWIDTH;
    out->height = SCREENHEIGHT;
    out->pitch = SCREENWIDTH * (int) sizeof(pixel_t);
    out->pixel_aspect = 1.2;
#ifndef CRISPY_TRUECOLOR
    I_GetPaletteRGB(palette);
    out->format = DMCP_PIXELS_INDEXED8;
    out->palette = palette;
#else
    // ARGB8888 words, stored little-endian as B, G, R, A.
    out->format = DMCP_PIXELS_BGRA32;
    out->palette = NULL;
#endif
    return true;
}

#endif // DMCP
