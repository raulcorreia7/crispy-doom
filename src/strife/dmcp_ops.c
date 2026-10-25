//
// DMCP engine ops for Strife: reads the game for the MCP tools and applies
// their requests. Runs on the game thread, between tics.
//

#include <math.h>
#include <stdio.h>
#include <string.h>

#include "config.h"
#include "dmcp_host.h"
#include "dmcp_ops.h"

#include "d_event.h"
#include "d_items.h"
#include "d_main.h"
#include "d_player.h"
#include "deh_misc.h"
#include "deh_str.h"
#include "doomdef.h"
#include "doomstat.h"
#include "g_game.h"
#include "hu_stuff.h"
#include "info.h"
#include "m_misc.h"
#include "p_inter.h"
#include "p_local.h"
#include "r_state.h"
#include "st_stuff.h"
#include "w_wad.h"

// Strife has MAP01..MAP34 (the demo has MAP32..MAP34); mapnames has one
// title for each.
#define NUMMAPS 34

// The first key set; the demo version has no others (see the "jimmy" cheat).
#define FIRSTKEYSET 16

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

// Canonical name of a mobjtype_t, from the DMCP type table.
static const char *TypeName(int type)
{
    static const dmcp_type_info_t *types;
    static size_t count;

    if (types == NULL)
    {
        types = dmcp_types(DMCP_GAME_STRIFE, &count);
    }
    if (types == NULL || type < 0 || (size_t) type >= count
     || types[type].name == NULL)
    {
        return "Unknown";
    }
    return types[type].name;
}

static void MapName(char *buf, size_t size, int map)
{
    M_snprintf(buf, size, "MAP%02d", map);
}

// Level title without the "AREA  1: " prefix, or NULL.
static const char *MapTitle(int map)
{
    const char *title;
    const char *colon;

    if (map < 1 || map > NUMMAPS)
    {
        return NULL;
    }

    title = DEH_String(mapnames[map - 1]);
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

static boolean ParseMap(const char *name, int *map)
{
    return sscanf(name, "%*1[Mm]%*1[Aa]%*1[Pp]%d", map) == 1
        && *map >= 1 && *map <= NUMMAPS;
}

static boolean WeaponAvailable(int w)
{
    return !isdemoversion || weaponinfo[w].availabledemo;
}

// --- reading -----------------------------------------------------------------

static const char *const weapon_names[NUMWEAPONS] = {
    "PunchDagger", "StrifeCrossbow", "AssaultGun", "MiniMissileLauncher",
    "StrifeGrenadeLauncher", "FlameThrower", "Mauler", "Sigil",
    "StrifeCrossbow2", "StrifeGrenadeLauncher2", "Mauler2",
};
static const char *const ammo_names[NUMAMMO] = {
    "ClipOfBullets", "ElectricBolts", "PoisonBolts", "EnergyPod",
    "MiniMissiles", "HEGrenadeRounds", "PhosphorusGrenadeRounds",
};
// In card_t order, which is mobjtype_t order from MT_KEY_BASE. The names
// are the type table's: card_t calls cards 3 and 10 IDCard and IDBadge, the
// things are the other way around.
static const char *const key_names[NUMCARDS] = {
    "BaseKey", "GovsKey", "Passcard", "IDBadge", "PrisonKey", "SeveredHand",
    "Power1Key", "Power2Key", "Power3Key", "GoldKey", "IDCard", "SilverKey",
    "OracleKey", "MilitaryID", "OrderKey", "WarehouseKey", "BrassKey",
    "RedCrystalKey", "BlueCrystalKey", "ChapelKey", "CatacombKey",
    "SecurityKey", "CoreKey", "MaulerKey", "FactoryKey", "MineKey", "NewKey5",
};
static const char *const power_names[NUMPOWERS] = {
    "PowerStrength", "PowerInvisibility", "PowerIronFeet", "PowerAllmap",
    "PowerCommunicator", "PowerTargeter",
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
        case GS_LEVEL:      out->state = DMCP_STATE_LEVEL; break;
        case GS_FINALE:     out->state = DMCP_STATE_FINALE; break;
        case GS_DEMOSCREEN: out->state = DMCP_STATE_DEMO; break;
        default:            out->state = DMCP_STATE_OTHER; break;
    }
    out->paused = paused;
    out->menu_open = menuactive;
    out->automap_open = automapactive;
    out->netgame = netgame;
    out->demo_playback = demoplayback;
    out->demo_recording = demorecording;
    out->skill = (int) gameskill + 1;
    out->mode = isdemoversion ? "demo" : "registered";
    out->world_epoch = world_epoch;
    return true;
}

// Strife has no items or secrets to count.
static bool ReadLevel(void *user, dmcp_level_info_t *out)
{
    static char map[9];
    player_t *player = Player();

    (void) user;

    if (gamestate != GS_LEVEL)
    {
        return false;
    }
    MapName(map, sizeof(map), gamemap);
    out->map = map;
    out->title = MapTitle(gamemap);
    out->level_time = leveltime;
    out->kills = player->killcount;
    out->total_kills = totalkills;
    return true;
}

static bool ReadPlayer(void *user, dmcp_player_info_t *out)
{
    static dmcp_item_t weapons[NUMWEAPONS];
    static dmcp_item_t ammo[NUMAMMO];
    static dmcp_item_t keys[NUMCARDS];
    static dmcp_item_t powers[NUMPOWERS];
    static dmcp_item_t inventory[NUMINVENTORY];
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
    out->x = DMCP_FixedToDouble(mo->x);
    out->y = DMCP_FixedToDouble(mo->y);
    out->z = DMCP_FixedToDouble(mo->z);
    out->angle = DMCP_AngleToDegrees(mo->angle);
    out->momx = DMCP_FixedToDouble(mo->momx);
    out->momy = DMCP_FixedToDouble(mo->momy);
    out->momz = DMCP_FixedToDouble(mo->momz);
    out->floor_z = DMCP_FixedToDouble(mo->floorz);
    out->ceiling_z = DMCP_FixedToDouble(mo->ceilingz);
    out->health = player->health;
    out->armor = player->armorpoints;
    out->armor_type = player->armortype == 1 ? "LeatherArmor"
                    : player->armortype == 2 ? "MetalArmor" : NULL;
    out->weapon = player->readyweapon < NUMWEAPONS
                ? weapon_names[player->readyweapon] : NULL;
    out->pending_weapon = player->pendingweapon < NUMWEAPONS
                        ? weapon_names[player->pendingweapon] : NULL;
    out->alive = player->playerstate == PST_LIVE;
    out->god = (player->cheats & CF_GODMODE) != 0;
    out->noclip = (player->cheats & CF_NOCLIP) != 0;
    out->kills = player->killcount;

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
            powers[n].count = (i == pw_strength || i == pw_allmap
                            || i == pw_communicator)
                            ? -1 : player->powers[i];
            powers[n].max = 0;
            ++n;
        }
    }
    out->powers = powers;
    out->power_count = n;

    for (i = 0, n = 0; i < player->numinventory && i < NUMINVENTORY; ++i)
    {
        if (player->inventory[i].amount > 0)
        {
            inventory[n].name = TypeName(player->inventory[i].type);
            inventory[n].count = player->inventory[i].amount;
            inventory[n].max = 0;
            ++n;
        }
    }
    out->inventory = inventory;
    out->inventory_count = n;
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
        e.x = DMCP_FixedToDouble(mo->x);
        e.y = DMCP_FixedToDouble(mo->y);
        e.z = DMCP_FixedToDouble(mo->z);
        e.angle = DMCP_AngleToDegrees(mo->angle);
        e.radius = DMCP_FixedToDouble(mo->radius);
        e.height = DMCP_FixedToDouble(mo->height);
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
    int map;

    (void) user;

    for (map = 1; map <= NUMMAPS; ++map)
    {
        MapName(name, sizeof(name), map);
        if (W_CheckNumForName(name) < 0)
        {
            continue;
        }
        info.map = name;
        info.title = MapTitle(map);
        cb(ctx, &info);
    }
}

static bool ReadFrame(void *user, dmcp_frame_t *out)
{
    (void) user;
    return DMCP_HostReadFrame(out);
}

// Hides types whose sprites are missing from the loaded WADs (demo).
static bool TypeAvailable(void *user, int type)
{
    int sprite;

    (void) user;

    if (type < 0 || type >= NUMMOBJTYPES)
    {
        return false;
    }
    sprite = states[mobjinfo[type].spawnstate].sprite;
    return sprite >= 0 && sprite < numsprites && sprites[sprite].numframes > 0;
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
        z = DMCP_DoubleToFixed(s->z);
    }
    else
    {
        z = (info->flags & MF_SPAWNCEILING) ? ONCEILINGZ : ONFLOORZ;
    }
    mo = P_SpawnMobj(DMCP_DoubleToFixed(s->x), DMCP_DoubleToFixed(s->y), z,
                     (mobjtype_t) s->type);
    mo->angle = DMCP_DegreesToAngle(s->angle);
    if (mo->flags & MF_COUNTKILL)
    {
        ++totalkills;
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
                player->mo->health = 100;
                player->health = deh_god_mode_health;
            }
            player->st_update = true;
            break;
        case DMCP_CHEAT_NOCLIP:
            // Unlike Doom, nothing but the cheat sets MF_NOCLIP.
            if (SetFlag(&player->cheats, CF_NOCLIP, state))
            {
                player->mo->flags |= MF_NOCLIP;
            }
            else
            {
                player->mo->flags &= ~MF_NOCLIP;
            }
            break;
        case DMCP_CHEAT_ALL_WEAPONS:
            player->armorpoints = deh_idkfa_armor;
            player->armortype = deh_idkfa_armor_class;
            if (!player->backpack)
            {
                for (i = 0; i < NUMAMMO; ++i)
                {
                    player->maxammo[i] *= 2;
                }
                player->backpack = true;
            }
            // The Sigil is a quest reward: leave it as it is.
            for (i = 0; i < NUMWEAPONS; ++i)
            {
                if (i != wp_sigil && WeaponAvailable(i))
                {
                    player->weaponowned[i] = true;
                }
            }
            for (i = 0; i < NUMAMMO; ++i)
            {
                player->ammo[i] = player->maxammo[i];
            }
            player->st_update = true;
            break;
        case DMCP_CHEAT_ALL_KEYS:
            for (i = 0; i < (isdemoversion ? FIRSTKEYSET : NUMCARDS); ++i)
            {
                player->cards[i] = true;
            }
            break;
        case DMCP_CHEAT_FULL_HEALTH:
            player->health = player->mo->health = MAXHEALTH + player->stamina;
            if (player->armorpoints < 100)
            {
                player->armorpoints = 100;
                if (player->armortype == 0)
                {
                    player->armortype = 1;
                }
            }
            player->st_update = true;
            break;
        case DMCP_CHEAT_KILL_ALL:
            for (th = thinkercap.next; th != &thinkercap; th = th->next)
            {
                mobj_t *mo = (mobj_t *) th;

                // Allies (the Front's rebels) fight for the player.
                if (IsMobj(th) && (mo->flags & MF_COUNTKILL)
                 && !(mo->flags & MF_ALLY) && mo->health > 0)
                {
                    P_DamageMobj(mo, NULL, NULL, 10000);
                }
            }
            break;
        case DMCP_CHEAT_REVEAL_MAP:
            P_GivePower(player, pw_allmap);
            break;
        default:
            return "unsupported cheat";
    }
    return NULL;
}

// Leaves the level the way an exit does, so the hub saves the current map
// and the player keeps the inventory. A skill change needs a new game.
static const char *ChangeLevel(void *user, const char *map, int skill)
{
    char name[9];
    int number;

    (void) user;

    if (!ParseMap(map, &number))
    {
        return "expected a map like MAP01";
    }
    MapName(name, sizeof(name), number);
    if (W_CheckNumForName(name) < 0)
    {
        return "map not found in the loaded WADs";
    }
    if (InLevel() && (skill <= 0 || skill - 1 == (int) gameskill))
    {
        G_ExitLevel(number);
    }
    else
    {
        G_DeferedInitNew(skill > 0 ? (skill_t) (skill - 1) : gameskill,
                         number);
    }
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
    if (!P_TeleportMove(mo, DMCP_DoubleToFixed(pose->x),
                        DMCP_DoubleToFixed(pose->y)))
    {
        return "the destination is blocked";
    }
    mo->z = pose->has_z ? DMCP_DoubleToFixed(pose->z) : mo->floorz;
    if (pose->has_angle)
    {
        mo->angle = DMCP_DegreesToAngle(pose->angle);
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

// Types the string into the cheat responder, like a player would. The cheats
// read data2; data1 is the key, which the inventory keys would also match,
// so it holds a value no key has.
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
        ev.data1 = -1;
        ev.data2 = ev.data3 = (unsigned char) *c;
        ST_Responder(&ev);
    }
    return NULL;
}

// Given pickups join the item respawn queue without a thing number, which
// P_RespawnSpecials (deathmatch 2) cannot place.
static bool MutationsAllowed(void *user)
{
    (void) user;
    return !netgame && !demoplayback && !demorecording && deathmatch != 2;
}

static const dmcp_engine_ops_t strife_ops = {
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

void DMCP_StrifeStart(void)
{
    DMCP_HostStart(DMCP_GAME_STRIFE, PACKAGE_STRING, &strife_ops);
}

// --- input -------------------------------------------------------------------

// Turns sent in ticcmds the game has not run yet. Adding them to the mobj
// angle predicts the view angle the next ticcmd starts from, so turn_to and
// face do not overshoot while maketic runs ahead of gametic.
#define TURN_HISTORY 128

static struct
{
    int tic;
    short turn;
} sent_turns[TURN_HISTORY];

static double PredictedAngle(int maketic)
{
    angle_t angle = Player()->mo->angle;
    int tic;

    for (tic = gametic; tic < maketic; ++tic)
    {
        if (sent_turns[tic % TURN_HISTORY].tic == tic)
        {
            angle += (angle_t) sent_turns[tic % TURN_HISTORY].turn << 16;
        }
    }
    return DMCP_AngleToDegrees(angle);
}

static int Clamp(int value, int limit)
{
    return value > limit ? limit : value < -limit ? -limit : value;
}

void DMCP_ApplyInput(ticcmd_t *cmd, int maketic)
{
    player_t *player = Player();
    dmcp_input_frame_t in;
    int run;
    short turn;

    if (dmcp_host == NULL || !InLevel())
    {
        return;
    }
    if (!dmcp_input_next(dmcp_host, PredictedAngle(maketic), &in))
    {
        return;
    }

    // Like G_BuildTiccmd, which does not let a hurt player run.
    run = (in.buttons & DMCP_BTN_RUN) != 0 && player->health > 15;
    cmd->forwardmove = (signed char) Clamp(
        cmd->forwardmove + (int) lround(in.forward * forwardmove[run]),
        forwardmove[1]);
    cmd->sidemove = (signed char) Clamp(
        cmd->sidemove + (int) lround(in.strafe * sidemove[run]),
        forwardmove[1]);

    turn = (short) lround(in.turn * (65536.0 / 360.0));
    cmd->angleturn += turn;
    sent_turns[maketic % TURN_HISTORY].tic = maketic;
    sent_turns[maketic % TURN_HISTORY].turn = turn;

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
        cmd->buttons2 |= BT2_JUMP;
    }
    if ((in.buttons & DMCP_BTN_USE_ITEM) && player->numinventory > 0)
    {
        cmd->buttons2 |= BT2_INVUSE;
        cmd->inventory = player->inventory[player->inventorycursor].sprite;
    }
    if (in.weapon_slot >= 1 && in.weapon_slot <= 8)
    {
        cmd->buttons &= ~BT_WEAPONMASK;
        cmd->buttons |= BT_CHANGE | ((in.weapon_slot - 1) << BT_WEAPONSHIFT);
    }
}
