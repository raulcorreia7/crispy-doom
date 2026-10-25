//
// DMCP engine ops for Doom: reads the game for the MCP tools and applies
// their requests. Runs on the game thread, between tics.
//

#include <math.h>
#include <stdio.h>
#include <string.h>

#include "config.h"
#include "dmcp_host.h"
#include "dmcp_ops.h"

#include "d_event.h"
#include "d_player.h"
#include "deh_misc.h"
#include "deh_str.h"
#include "doomdef.h"
#include "doomstat.h"
#include "g_game.h"
#include "info.h"
#include "m_misc.h"
#include "p_local.h"
#include "r_state.h"
#include "st_stuff.h"
#include "w_wad.h"

extern const char *mapnames[];
extern const char *mapnames_commercial[];

// --- helpers -----------------------------------------------------------------

static player_t *Player(void)
{
    return &players[consoleplayer];
}

static boolean IsMobj(thinker_t *th)
{
    return th->function.acp1 == (actionf_p1) P_MobjThinker;
}

static mobj_t *FindMobj(uint32_t id)
{
    thinker_t *th;

    if (id == 0)
    {
        return Player()->mo;
    }
    for (th = thinkercap.next; th != &thinkercap; th = th->next)
    {
        if (IsMobj(th) && ((mobj_t *) th)->dmcp_id == id)
        {
            return (mobj_t *) th;
        }
    }
    return NULL;
}

static boolean InLevel(void)
{
    return gamestate == GS_LEVEL && Player()->mo != NULL;
}

static void MapName(char *buf, size_t size, int episode, int map)
{
    if (gamemode == commercial)
    {
        M_snprintf(buf, size, "MAP%02d", map);
    }
    else
    {
        M_snprintf(buf, size, "E%dM%d", episode, map);
    }
}

// Level title without the "E1M1: " / "level 1: " prefix, or NULL.
static const char *MapTitle(int episode, int map)
{
    const char *title = NULL;
    const char *colon;

    if (gamemode == commercial)
    {
        if (map < 1 || map > 32)
        {
            return NULL;
        }
        switch (logical_gamemission)
        {
            case doom2:     title = mapnames_commercial[map - 1]; break;
            case pack_plut: title = mapnames_commercial[map - 1 + 32]; break;
            case pack_tnt:  title = mapnames_commercial[map - 1 + 64]; break;
            default:        return NULL;
        }
    }
    else
    {
        if (episode < 1 || episode > 4 || map < 1 || map > 9)
        {
            return NULL;
        }
        title = mapnames[(episode - 1) * 9 + map - 1];
    }

    title = DEH_String(title);
    colon = strchr(title, ':');
    if (colon != NULL)
    {
        title = colon + 1;
        while (*title == ' ')
        {
            ++title;
        }
    }
    return title;
}

static boolean ParseMap(const char *name, int *episode, int *map)
{
    if (gamemode == commercial)
    {
        *episode = 1;
        return sscanf(name, "%*1[Mm]%*1[Aa]%*1[Pp]%d", map) == 1;
    }
    return sscanf(name, "%*1[Ee]%d%*1[Mm]%d", episode, map) == 2;
}

static boolean WeaponAvailable(int w)
{
    if (w == wp_supershotgun && !crispy->havessg)
    {
        return false;
    }
    if ((w == wp_bfg || w == wp_plasma) && gamemode == shareware)
    {
        return false;
    }
    return true;
}

// --- reading -----------------------------------------------------------------

static const char *const weapon_names[NUMWEAPONS] = {
    "Fist", "Pistol", "Shotgun", "Chaingun", "RocketLauncher",
    "PlasmaRifle", "BFG9000", "Chainsaw", "SuperShotgun",
};
static const char *const ammo_names[NUMAMMO] = {
    "Clip", "Shell", "Cell", "RocketAmmo",
};
static const char *const key_names[NUMCARDS] = {
    "BlueCard", "YellowCard", "RedCard", "BlueSkull", "YellowSkull", "RedSkull",
};
static const char *const power_names[NUMPOWERS] = {
    "PowerInvulnerable", "PowerStrength", "PowerInvisibility",
    "PowerIronFeet", "PowerAllmap", "PowerLightAmp",
};

static uint32_t world_epoch;
static int last_levelstarttic = -1;

static bool ReadGame(void *user, dmcp_game_info_t *out)
{
    (void) user;

    if (gamestate == GS_LEVEL && levelstarttic != last_levelstarttic)
    {
        last_levelstarttic = levelstarttic;
        ++world_epoch;
    }

    out->tic = gametic;
    switch (gamestate)
    {
        case GS_LEVEL:        out->state = DMCP_STATE_LEVEL; break;
        case GS_INTERMISSION: out->state = DMCP_STATE_INTERMISSION; break;
        case GS_FINALE:       out->state = DMCP_STATE_FINALE; break;
        case GS_DEMOSCREEN:   out->state = DMCP_STATE_DEMO; break;
        default:              out->state = DMCP_STATE_OTHER; break;
    }
    out->paused = paused;
    out->menu_open = menuactive;
    out->automap_open = automapactive;
    out->netgame = netgame;
    out->demo_playback = demoplayback;
    out->demo_recording = demorecording;
    out->skill = (int) gameskill + 1;
    switch (gamemode)
    {
        case shareware:  out->mode = "shareware"; break;
        case registered: out->mode = "registered"; break;
        case commercial: out->mode = "commercial"; break;
        case retail:     out->mode = "retail"; break;
        default:         out->mode = "unknown"; break;
    }
    out->world_epoch = world_epoch;
    return true;
}

static bool ReadLevel(void *user, dmcp_level_info_t *out)
{
    static char map[9];
    player_t *player = Player();

    (void) user;

    if (gamestate != GS_LEVEL && gamestate != GS_INTERMISSION)
    {
        return false;
    }
    MapName(map, sizeof(map), gameepisode, gamemap);
    out->map = map;
    out->title = MapTitle(gameepisode, gamemap);
    out->level_time = leveltime;
    out->kills = player->killcount;
    out->total_kills = totalkills;
    out->items = player->itemcount;
    out->total_items = totalitems;
    out->secrets = player->secretcount;
    out->total_secrets = totalsecret;
    return true;
}

static bool ReadPlayer(void *user, dmcp_player_info_t *out)
{
    static dmcp_item_t weapons[NUMWEAPONS];
    static dmcp_item_t ammo[NUMAMMO];
    static dmcp_item_t keys[NUMCARDS];
    static dmcp_item_t powers[NUMPOWERS];
    player_t *player = Player();
    mobj_t *mo = player->mo;
    size_t n;
    int i;

    (void) user;

    if (!InLevel())
    {
        return false;
    }

    out->id = mo->dmcp_id;
    out->x = dmcp_fixed_to_double(mo->x);
    out->y = dmcp_fixed_to_double(mo->y);
    out->z = dmcp_fixed_to_double(mo->z);
    out->angle = dmcp_bam_to_degrees(mo->angle);
    out->momx = dmcp_fixed_to_double(mo->momx);
    out->momy = dmcp_fixed_to_double(mo->momy);
    out->momz = dmcp_fixed_to_double(mo->momz);
    out->floor_z = dmcp_fixed_to_double(mo->floorz);
    out->ceiling_z = dmcp_fixed_to_double(mo->ceilingz);
    out->health = player->health;
    out->armor = player->armorpoints;
    out->armor_type = player->armortype == 1 ? "GreenArmor"
                    : player->armortype == 2 ? "BlueArmor" : NULL;
    out->weapon = player->readyweapon < NUMWEAPONS
                ? weapon_names[player->readyweapon] : NULL;
    out->pending_weapon = player->pendingweapon < NUMWEAPONS
                        ? weapon_names[player->pendingweapon] : NULL;
    out->alive = player->playerstate == PST_LIVE;
    out->god = (player->cheats & CF_GODMODE) != 0;
    out->noclip = (player->cheats & CF_NOCLIP) != 0;
    out->kills = player->killcount;
    out->items = player->itemcount;
    out->secrets = player->secretcount;

    for (i = 0, n = 0; i < NUMWEAPONS; ++i)
    {
        if (player->weaponowned[i])
        {
            weapons[n].name = weapon_names[i];
            weapons[n].count = 1;
            weapons[n].max = 0;
            ++n;
        }
    }
    out->weapons = weapons;
    out->weapon_count = n;

    for (i = 0; i < NUMAMMO; ++i)
    {
        ammo[i].name = ammo_names[i];
        ammo[i].count = player->ammo[i];
        ammo[i].max = player->maxammo[i];
    }
    out->ammo = ammo;
    out->ammo_count = NUMAMMO;

    for (i = 0, n = 0; i < NUMCARDS; ++i)
    {
        if (player->cards[i])
        {
            keys[n].name = key_names[i];
            keys[n].count = 1;
            keys[n].max = 0;
            ++n;
        }
    }
    out->keys = keys;
    out->key_count = n;

    for (i = 0, n = 0; i < NUMPOWERS; ++i)
    {
        if (player->powers[i])
        {
            powers[n].name = power_names[i];
            powers[n].count = (i == pw_allmap || (i == pw_strength))
                            ? -1 : player->powers[i];
            powers[n].max = 0;
            ++n;
        }
    }
    out->powers = powers;
    out->power_count = n;
    return true;
}

static void IterateEntities(void *user, dmcp_entity_cb cb, void *ctx)
{
    mobj_t *pmo = Player()->mo;
    thinker_t *th;

    (void) user;

    if (gamestate != GS_LEVEL)
    {
        return;
    }
    for (th = thinkercap.next; th != &thinkercap; th = th->next)
    {
        mobj_t *mo;
        dmcp_entity_t e;

        if (!IsMobj(th))
        {
            continue;
        }
        mo = (mobj_t *) th;
        memset(&e, 0, sizeof(e));
        e.id = mo->dmcp_id;
        e.type = (int) mo->type;
        e.x = dmcp_fixed_to_double(mo->x);
        e.y = dmcp_fixed_to_double(mo->y);
        e.z = dmcp_fixed_to_double(mo->z);
        e.angle = dmcp_bam_to_degrees(mo->angle);
        e.radius = dmcp_fixed_to_double(mo->radius);
        e.height = dmcp_fixed_to_double(mo->height);
        e.health = mo->health;
        e.target_id = mo->target ? mo->target->dmcp_id : 0;
        if (mo->flags & MF_SHOOTABLE) e.flags |= DMCP_ENT_SHOOTABLE;
        if (mo->flags & MF_COUNTKILL) e.flags |= DMCP_ENT_COUNTKILL;
        if (mo->flags & MF_SPECIAL)   e.flags |= DMCP_ENT_PICKUP;
        if (mo->flags & MF_MISSILE)   e.flags |= DMCP_ENT_MISSILE;
        if (mo->flags & MF_SOLID)     e.flags |= DMCP_ENT_SOLID;
        if (mo->flags & MF_CORPSE)    e.flags |= DMCP_ENT_CORPSE;
        if (mo->flags & MF_AMBUSH)    e.flags |= DMCP_ENT_AMBUSH;
        // Line of sight is costly; only answer it for things that fight.
        if (pmo != NULL && mo != pmo && (mo->flags & MF_SHOOTABLE)
         && P_CheckSight(pmo, mo))
        {
            e.flags |= DMCP_ENT_VISIBLE;
        }
        if (!cb(ctx, &e))
        {
            return;
        }
    }
}

static void IterateMaps(void *user, dmcp_map_cb cb, void *ctx)
{
    char name[9];
    dmcp_map_info_t info;
    int episode, map;
    int episodes = gamemode == commercial ? 1 : 9;
    int maps = gamemode == commercial ? 99 : 9;

    (void) user;

    for (episode = 1; episode <= episodes; ++episode)
    {
        for (map = 1; map <= maps; ++map)
        {
            MapName(name, sizeof(name), episode, map);
            if (W_CheckNumForName(name) < 0)
            {
                continue;
            }
            info.map = name;
            info.title = MapTitle(episode, map);
            cb(ctx, &info);
        }
    }
}

static bool ReadFrame(void *user, dmcp_frame_t *out)
{
    (void) user;
    return DMCP_HostReadFrame(out);
}

// Hides types whose sprites are missing from the loaded WADs (shareware).
static bool TypeAvailable(void *user, int type)
{
    (void) user;

    if (type < 0 || type >= NUMMOBJTYPES)
    {
        return false;
    }
    return sprites[states[mobjinfo[type].spawnstate].sprite].numframes > 0;
}

// --- mutations ---------------------------------------------------------------

static const char *Spawn(void *user, const dmcp_spawn_t *s, uint32_t *out_id)
{
    mobjinfo_t *info;
    mobj_t *mo;
    fixed_t z;

    (void) user;

    if (!InLevel())
    {
        return "not in a level";
    }
    if (s->type < 0 || s->type >= NUMMOBJTYPES)
    {
        return "unknown type";
    }
    info = &mobjinfo[s->type];
    if (s->has_z)
    {
        z = dmcp_double_to_fixed(s->z);
    }
    else
    {
        z = (info->flags & MF_SPAWNCEILING) ? ONCEILINGZ : ONFLOORZ;
    }
    mo = P_SpawnMobj(dmcp_double_to_fixed(s->x), dmcp_double_to_fixed(s->y), z,
                     (mobjtype_t) s->type);
    mo->angle = dmcp_degrees_to_bam(s->angle);
    if (mo->flags & MF_COUNTKILL)
    {
        ++totalkills;
    }
    if (mo->flags & MF_COUNTITEM)
    {
        ++totalitems;
    }
    *out_id = mo->dmcp_id;
    return NULL;
}

// Spawns the pickup on the player and lets the game apply it, so every rule
// (limits, messages, sounds) is the engine's own.
static const char *Give(void *user, const dmcp_give_t *g)
{
    player_t *player = Player();
    int given = 0;
    int i;

    (void) user;

    if (!InLevel())
    {
        return "not in a level";
    }
    if (g->type < 0 || g->type >= NUMMOBJTYPES)
    {
        return "unknown item";
    }
    if (!(mobjinfo[g->type].flags & MF_SPECIAL))
    {
        return "not a pickup";
    }
    for (i = 0; i < g->amount; ++i)
    {
        mobj_t *item = P_SpawnMobj(player->mo->x, player->mo->y,
                                   player->mo->z, (mobjtype_t) g->type);

        item->flags &= ~MF_COUNTITEM;
        P_TouchSpecialThing(item, player->mo);
        if (item->thinker.function.acv == (actionf_v) (-1))
        {
            ++given;
        }
        else
        {
            P_RemoveMobj(item);
            break;
        }
    }
    return given > 0 ? NULL : "cannot pick it up now (already at the maximum?)";
}

static boolean SetFlag(int *flags, int flag, int state)
{
    boolean on = state < 0 ? !(*flags & flag) : state != 0;

    if (on)
    {
        *flags |= flag;
    }
    else
    {
        *flags &= ~flag;
    }
    return on;
}

static const char *Cheat(void *user, dmcp_cheat_t cheat, int state)
{
    player_t *player = Player();
    thinker_t *th;
    int i;

    (void) user;

    if (!InLevel())
    {
        return "not in a level";
    }
    switch (cheat)
    {
        case DMCP_CHEAT_GOD:
            if (SetFlag(&player->cheats, CF_GODMODE, state))
            {
                player->health = player->mo->health = deh_god_mode_health;
            }
            break;
        case DMCP_CHEAT_NOCLIP:
            SetFlag(&player->cheats, CF_NOCLIP, state);
            break;
        case DMCP_CHEAT_ALL_WEAPONS:
            player->armorpoints = deh_idfa_armor;
            player->armortype = deh_idfa_armor_class;
            if (!player->backpack)
            {
                for (i = 0; i < NUMAMMO; ++i)
                {
                    player->maxammo[i] *= 2;
                }
                player->backpack = true;
            }
            for (i = 0; i < NUMWEAPONS; ++i)
            {
                if (WeaponAvailable(i))
                {
                    player->weaponowned[i] = true;
                }
            }
            for (i = 0; i < NUMAMMO; ++i)
            {
                player->ammo[i] = player->maxammo[i];
            }
            break;
        case DMCP_CHEAT_ALL_KEYS:
            for (i = 0; i < NUMCARDS; ++i)
            {
                player->cards[i] = true;
            }
            break;
        case DMCP_CHEAT_FULL_HEALTH:
            player->health = player->mo->health = MAXHEALTH;
            if (player->armorpoints < 100)
            {
                player->armorpoints = 100;
                if (player->armortype == 0)
                {
                    player->armortype = 1;
                }
            }
            break;
        case DMCP_CHEAT_KILL_ALL:
            for (th = thinkercap.next; th != &thinkercap; th = th->next)
            {
                mobj_t *mo = (mobj_t *) th;

                if (IsMobj(th) && (mo->flags & MF_COUNTKILL) && mo->health > 0)
                {
                    P_DamageMobj(mo, NULL, NULL, 10000);
                }
            }
            break;
        case DMCP_CHEAT_REVEAL_MAP:
            player->powers[pw_allmap] = 1;
            break;
        default:
            return "unsupported cheat";
    }
    return NULL;
}

static const char *ChangeLevel(void *user, const char *map, int skill)
{
    int episode, number;

    (void) user;

    if (!ParseMap(map, &episode, &number))
    {
        return gamemode == commercial ? "expected a map like MAP01"
                                      : "expected a map like E1M1";
    }
    if (W_CheckNumForName(map) < 0)
    {
        return "map not found in the loaded WADs";
    }
    G_DeferedInitNew(skill > 0 ? (skill_t) (skill - 1) : gameskill,
                     episode, number);
    return NULL;
}

static const char *Teleport(void *user, const dmcp_pose_t *pose)
{
    player_t *player = Player();
    mobj_t *mo = player->mo;

    (void) user;

    if (!InLevel())
    {
        return "not in a level";
    }
    if (!P_TeleportMove(mo, dmcp_double_to_fixed(pose->x),
                        dmcp_double_to_fixed(pose->y)))
    {
        return "the destination is blocked";
    }
    mo->z = pose->has_z ? dmcp_double_to_fixed(pose->z) : mo->floorz;
    if (pose->has_angle)
    {
        mo->angle = dmcp_degrees_to_bam(pose->angle);
    }
    mo->momx = mo->momy = mo->momz = 0;
    mo->interp = false;
    player->viewz = mo->z + player->viewheight;
    return NULL;
}

static const char *Damage(void *user, uint32_t id, int amount)
{
    mobj_t *mo;

    (void) user;

    if (!InLevel())
    {
        return "not in a level";
    }
    mo = FindMobj(id);
    if (mo == NULL)
    {
        return "no entity with that id";
    }
    if (!(mo->flags & MF_SHOOTABLE))
    {
        return "that entity cannot be damaged";
    }
    P_DamageMobj(mo, NULL, NULL, amount);
    return NULL;
}

// Types the string into the cheat responder, like a player would.
static const char *Console(void *user, const char *command)
{
    const char *c;

    (void) user;

    if (!InLevel())
    {
        return "not in a level";
    }
    for (c = command; *c != '\0'; ++c)
    {
        event_t ev;

        memset(&ev, 0, sizeof(ev));
        ev.type = ev_keydown;
        ev.data1 = ev.data2 = ev.data3 = (unsigned char) *c;
        ST_Responder(&ev);
    }
    return NULL;
}

static bool MutationsAllowed(void *user)
{
    (void) user;
    return !netgame && !demoplayback && !demorecording;
}

static const dmcp_engine_ops_t doom_ops = {
    sizeof(dmcp_engine_ops_t),
    ReadGame,
    ReadLevel,
    ReadPlayer,
    IterateEntities,
    IterateMaps,
    ReadFrame,
    TypeAvailable,
    Spawn,
    Give,
    Cheat,
    ChangeLevel,
    Teleport,
    Damage,
    Console,
    MutationsAllowed,
};

void DMCP_DoomStart(void)
{
    DMCP_HostStart(DMCP_GAME_DOOM, PACKAGE_STRING, &doom_ops);
}

// --- input -------------------------------------------------------------------

static int Clamp(int value, int limit)
{
    return value > limit ? limit : value < -limit ? -limit : value;
}

void DMCP_ApplyInput(ticcmd_t *cmd, int maketic)
{
    dmcp_input_frame_t in;
    int run;
    short turn;

    if (dmcp_host == NULL || !InLevel())
    {
        return;
    }
    if (!dmcp_input_next(dmcp_host, maketic, gametic,
                         dmcp_bam_to_degrees(Player()->mo->angle), &in))
    {
        return;
    }

    run = (in.buttons & DMCP_BTN_RUN) != 0;
    cmd->forwardmove = (signed char) Clamp(
        cmd->forwardmove + (int) lround(in.forward * forwardmove[run]),
        forwardmove[1]);
    cmd->sidemove = (signed char) Clamp(
        cmd->sidemove + (int) lround(in.strafe * sidemove[run]),
        forwardmove[1]);

    turn = (short) lround(in.turn * (65536.0 / 360.0));
    cmd->angleturn += turn;

    if (in.buttons & DMCP_BTN_ATTACK)
    {
        cmd->buttons |= BT_ATTACK;
    }
    if (in.buttons & DMCP_BTN_USE)
    {
        cmd->buttons |= BT_USE;
    }
    if (in.buttons & DMCP_BTN_JUMP)
    {
        cmd->arti |= AFLAG_JUMP;
    }
    if (in.weapon_slot >= 1 && in.weapon_slot <= 7)
    {
        cmd->buttons &= ~BT_WEAPONMASK;
        cmd->buttons |= BT_CHANGE | ((in.weapon_slot - 1) << BT_WEAPONSHIFT);
    }
}
