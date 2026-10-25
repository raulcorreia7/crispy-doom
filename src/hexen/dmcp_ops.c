//
// DMCP engine ops for Hexen: reads the game for the MCP tools and applies
// their requests. Runs on the game thread, between tics.
//

#include <math.h>
#include <stdio.h>
#include <string.h>

#include "config.h"
#include "dmcp_host.h"
#include "dmcp_ops.h"

#include "d_event.h"
#include "d_loop.h"
#include "h2def.h"
#include "m_fixed.h"
#include "m_misc.h"
#include "p_local.h"
#include "am_map.h"
#include "r_local.h"
#include "w_wad.h"

// Defined in g_game.c, not declared in a header.
extern fixed_t MaxPlayerMove[NUMCLASSES];
extern fixed_t forwardmove[NUMCLASSES][2];
extern fixed_t sidemove[NUMCLASSES][2];

// A thinker that P_RemoveThinker marked; the game frees it on the next tic.
#define THINKER_REMOVED ((think_t) -1)

// P_GiveArtifact refuses a 26th item of one kind.
#define MAX_ARTIFACT_COUNT 25

// --- helpers -----------------------------------------------------------------

static player_t *Player(void)
{
    return &players[consoleplayer];
}

static boolean IsMobj(thinker_t *th)
{
    return th->function == P_MobjThinker;
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

// Lump name of a map number. Hexen maps are numbered 1..99, in one episode.
static void MapName(char *buf, size_t size, int map)
{
    M_snprintf(buf, size, "MAP%02d", map);
}

// Level title from MAPINFO, or NULL for a map MAPINFO does not list.
static const char *MapTitle(int map)
{
    if (map < 1 || map > 99 || P_GetMapWarpTrans(map) == 0)
    {
        return NULL;
    }
    return P_GetMapName(map);
}

static boolean ParseMap(const char *name, int *map)
{
    return sscanf(name, "%*1[Mm]%*1[Aa]%*1[Pp]%d", map) == 1
        && *map >= 1 && *map <= 99;
}

// Hexen's own class, which stays the same while the player is a pig.
static const char *ClassName(void)
{
    switch (PlayerClass[consoleplayer])
    {
        case PCLASS_FIGHTER: return "fighter";
        case PCLASS_CLERIC:  return "cleric";
        case PCLASS_MAGE:    return "mage";
        default:             return NULL;
    }
}

// --- reading -----------------------------------------------------------------

static const char *const weapon_names[3][NUMWEAPONS] = {
    {"FWeapFist", "FWeapAxe", "FWeapHammer", "FWeapQuietus"},
    {"CWeapMace", "CWeapStaff", "CWeapFlame", "CWeapWraithverge"},
    {"MWeapWand", "MWeapFrost", "MWeapLightning", "MWeapBloodscourge"},
};
static const char *const ammo_names[NUMMANA] = {
    "Mana1", "Mana2",
};
static const char *const key_names[NUM_KEY_TYPES] = {
    "KeySteel", "KeyCave", "KeyAxe", "KeyFire", "KeyEmerald", "KeyDungeon",
    "KeySilver", "KeyRusted", "KeyHorn", "KeySwamp", "KeyCastle",
};
static const char *const power_names[NUMPOWERS] = {
    NULL, "PowerInvulnerable", "PowerAllmap", "PowerTorch", "PowerFlight",
    "PowerShield", "PowerHealth2", "PowerSpeed", "PowerMinotaur",
};
static const char *const artifact_names[NUMARTIFACTS] = {
    NULL, "ArtiInvulnerability2", "ArtiHealth", "ArtiSuperHealth",
    "ArtiHealingRadius", "ArtiDarkServant", "ArtiTorch", "ArtiPork",
    "ArtiFly", "ArtiBlastRadius", "ArtiPoisonBag", "ArtiTeleportOther",
    "ArtiSpeedBoots", "ArtiBoostMana", "ArtiBoostArmor", "ArtiTeleport",
    "PuzzSkull", "PuzzGemBig", "PuzzGemRed", "PuzzGemGreen1", "PuzzGemGreen2",
    "PuzzGemBlue1", "PuzzGemBlue2", "PuzzBook1", "PuzzBook2",
    "PuzzFlameMask", "PuzzFWeapon", "PuzzCWeapon", "PuzzMWeapon",
    "PuzzGear1", "PuzzGear2", "PuzzGear3", "PuzzGear4",
};

static uint32_t world_epoch;
static int last_levelstarttic = -1;
static int last_map = -1;
static unsigned int last_player_id;

static bool ReadGame(void *user, dmcp_game_info_t *out)
{
    (void) user;

    // Hub travel and savegame loads keep levelstarttic, but spawn a new
    // player mobj, so its id tells them apart.
    if (InLevel() && (levelstarttic != last_levelstarttic
                   || gamemap != last_map
                   || Player()->mo->dmcp_id != last_player_id))
    {
        last_levelstarttic = levelstarttic;
        last_map = gamemap;
        last_player_id = Player()->mo->dmcp_id;
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
    out->menu_open = MenuActive;
    out->automap_open = automapactive;
    out->netgame = netgame;
    out->demo_playback = demoplayback;
    out->demo_recording = demorecording;
    out->skill = (int) gameskill + 1;
    out->mode = gamemode == shareware ? "shareware" : "commercial";
    out->world_epoch = world_epoch;
    return true;
}

// Hexen counts no level totals, so the totals stay 0.
static bool ReadLevel(void *user, dmcp_level_info_t *out)
{
    static char map[9];
    player_t *player = Player();

    (void) user;

    if (gamestate != GS_LEVEL && gamestate != GS_INTERMISSION)
    {
        return false;
    }
    MapName(map, sizeof(map), gamemap);
    out->map = map;
    out->title = MapTitle(gamemap);
    out->level_time = leveltime;
    out->kills = player->killcount;
    out->total_kills = 0;
    out->items = player->itemcount;
    out->total_items = 0;
    out->secrets = player->secretcount;
    out->total_secrets = 0;
    return true;
}

// The armor number the status bar shows.
static int ArmorDisplay(player_t *player)
{
    int total = AutoArmorSave[player->class]
              + player->armorpoints[ARMOR_ARMOR]
              + player->armorpoints[ARMOR_SHIELD]
              + player->armorpoints[ARMOR_HELMET]
              + player->armorpoints[ARMOR_AMULET];

    return FixedDiv(total, 5 * FRACUNIT) >> FRACBITS;
}

static bool ReadPlayer(void *user, dmcp_player_info_t *out)
{
    static dmcp_item_t weapons[NUMWEAPONS];
    static dmcp_item_t ammo[NUMMANA];
    static dmcp_item_t keys[NUM_KEY_TYPES];
    static dmcp_item_t powers[NUMPOWERS];
    static dmcp_item_t inventory[NUMINVENTORYSLOTS];
    player_t *player = Player();
    mobj_t *mo = player->mo;
    int pclass = PlayerClass[consoleplayer];
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
    // player->health is only valid between levels; mo->health is live.
    out->health = mo->health > 0 ? mo->health : 0;
    out->armor = ArmorDisplay(player);
    out->armor_type = NULL;
    out->player_class = ClassName();
    if (pclass < PCLASS_PIG)
    {
        out->weapon = player->readyweapon < NUMWEAPONS
                    ? weapon_names[pclass][player->readyweapon] : NULL;
        out->pending_weapon = player->pendingweapon < NUMWEAPONS
                            ? weapon_names[pclass][player->pendingweapon]
                            : NULL;
    }
    else
    {
        out->weapon = out->pending_weapon = NULL;
    }
    out->alive = player->playerstate == PST_LIVE;
    out->god = (player->cheats & CF_GODMODE) != 0;
    out->noclip = (player->cheats & CF_NOCLIP) != 0;
    out->kills = player->killcount;
    out->items = player->itemcount;
    out->secrets = player->secretcount;

    for (i = 0, n = 0; i < NUMWEAPONS && pclass < PCLASS_PIG; ++i)
    {
        if (player->weaponowned[i])
        {
            weapons[n].name = weapon_names[pclass][i];
            weapons[n].count = 1;
            weapons[n].max = 0;
            ++n;
        }
    }
    out->weapons = weapons;
    out->weapon_count = n;

    for (i = 0; i < NUMMANA; ++i)
    {
        ammo[i].name = ammo_names[i];
        ammo[i].count = player->mana[i];
        ammo[i].max = MAX_MANA;
    }
    out->ammo = ammo;
    out->ammo_count = NUMMANA;

    for (i = 0, n = 0; i < NUM_KEY_TYPES; ++i)
    {
        if (player->keys & (1 << i))
        {
            keys[n].name = key_names[i];
            keys[n].count = 1;
            keys[n].max = 0;
            ++n;
        }
    }
    out->keys = keys;
    out->key_count = n;

    for (i = 1, n = 0; i < NUMPOWERS; ++i)
    {
        if (player->powers[i])
        {
            powers[n].name = power_names[i];
            powers[n].count = i == pw_allmap ? -1 : player->powers[i];
            powers[n].max = 0;
            ++n;
        }
    }
    out->powers = powers;
    out->power_count = n;

    for (i = 0, n = 0; i < player->inventorySlotNum; ++i)
    {
        int type = player->inventory[i].type;

        if (type > arti_none && type < NUMARTIFACTS)
        {
            inventory[n].name = artifact_names[type];
            inventory[n].count = player->inventory[i].count;
            inventory[n].max = MAX_ARTIFACT_COUNT;
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
        e.tid = mo->tid;
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

    for (map = 1; map <= 99; ++map)
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
        z = DMCP_DoubleToFixed(s->z);
    }
    else
    {
        z = (info->flags & MF_SPAWNCEILING) ? ONCEILINGZ : ONFLOORZ;
    }
    mo = P_SpawnMobj(DMCP_DoubleToFixed(s->x), DMCP_DoubleToFixed(s->y), z,
                     (mobjtype_t) s->type);
    mo->angle = DMCP_DegreesToAngle(s->angle);
    *out_id = mo->dmcp_id;
    return NULL;
}

// Spawns the pickup on the player and lets the game apply it, so every rule
// (limits, messages, sounds) is the engine's own. A taken pickup is either
// removed or, for artifacts, left behind as a dormant mobj without
// MF_SPECIAL; the leftover is removed here.
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
        boolean removed;
        boolean taken;

        P_TouchSpecialThing(item, player->mo);
        removed = item->thinker.function == THINKER_REMOVED;
        taken = removed || !(item->flags & MF_SPECIAL);
        if (!removed)
        {
            P_RemoveMobj(item);
        }
        if (!taken)
        {
            break;
        }
        ++given;
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

// Raises each armor piece to the class maximum, like the weapons cheat.
static void FillArmor(player_t *player)
{
    int i;

    for (i = 0; i < NUMARMOR; ++i)
    {
        if (player->armorpoints[i] < ArmorIncrement[player->class][i])
        {
            player->armorpoints[i] = ArmorIncrement[player->class][i];
        }
    }
}

static const char *Cheat(void *user, dmcp_cheat_t cheat, int state)
{
    player_t *player = Player();
    int i;

    (void) user;

    if (!InLevel())
    {
        return "not in a level";
    }
    switch (cheat)
    {
        case DMCP_CHEAT_GOD:
            SetFlag(&player->cheats, CF_GODMODE, state);
            break;
        case DMCP_CHEAT_NOCLIP:
            SetFlag(&player->cheats, CF_NOCLIP, state);
            break;
        case DMCP_CHEAT_ALL_WEAPONS:
            FillArmor(player);
            for (i = 0; i < NUMWEAPONS; ++i)
            {
                player->weaponowned[i] = true;
            }
            for (i = 0; i < NUMMANA; ++i)
            {
                player->mana[i] = MAX_MANA;
            }
            break;
        case DMCP_CHEAT_ALL_KEYS:
            player->keys = (1 << NUM_KEY_TYPES) - 1;
            break;
        case DMCP_CHEAT_FULL_HEALTH:
            player->health = player->mo->health =
                player->morphTics ? MAXMORPHHEALTH : MAXHEALTH;
            FillArmor(player);
            break;
        case DMCP_CHEAT_KILL_ALL:
            P_Massacre();
            break;
        case DMCP_CHEAT_REVEAL_MAP:
            // The reveal cheat cycles lines only, lines and things, off.
            cheating = state < 0 ? (cheating ? 0 : 1) : (state != 0);
            break;
        default:
            return "unsupported cheat";
    }
    return NULL;
}

// Maps are named by lump (MAPxx), not by the warp number the warp cheat
// takes. Inside a level this takes the warp cheat's path: G_TeleportNewMap
// keeps the player, the inventory and the hub's saved maps. Elsewhere, on a
// skill change or on the current map it starts a new game there, like the
// "init" cheat.
static const char *ChangeLevel(void *user, const char *map, int skill)
{
    char name[9];
    int number;
    skill_t new_skill = skill > 0 ? (skill_t) (skill - 1) : gameskill;

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
    if (InLevel() && new_skill == gameskill && number != gamemap)
    {
        G_TeleportNewMap(number, 0);
    }
    else
    {
        G_DeferedInitNew(new_skill, gameepisode, number);
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
    if (mo->flags2 & MF2_FLOORCLIP)
    {
        mo->floorclip = (mo->z == mo->subsector->sector->floorheight
                      && P_GetThingFloorType(mo) > FLOOR_SOLID)
                      ? 10 * FRACUNIT : 0;
    }
    mo->interp = false;
    player->viewz = mo->z + player->viewheight;
    player->oldviewz = player->viewz;
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
        SB_Responder(&ev);
    }
    return NULL;
}

static bool MutationsAllowed(void *user)
{
    (void) user;
    return !netgame && !demoplayback && !demorecording;
}

static const dmcp_engine_ops_t hexen_ops = {
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

void DMCP_HexenStart(void)
{
    DMCP_HostStart(DMCP_GAME_HEXEN, PACKAGE_STRING, &hexen_ops);
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

// The agent's share of a move axis: scaled like G_BuildTiccmd scales keys,
// including the speed artifact.
static int MoveAmount(double axis, fixed_t speed, player_t *player)
{
    int amount = Clamp((int) lround(axis * speed),
                       MaxPlayerMove[player->class]);

    if (player->powers[pw_speed] && !player->morphTics)
    {
        amount = (3 * amount) >> 1;
    }
    return amount;
}

void DMCP_ApplyInput(ticcmd_t *cmd, int maketic)
{
    dmcp_input_frame_t in;
    player_t *player = Player();
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

    run = (in.buttons & DMCP_BTN_RUN) != 0;
    cmd->forwardmove = (signed char) Clamp(
        cmd->forwardmove
        + MoveAmount(in.forward, forwardmove[player->class][run], player),
        127);
    cmd->sidemove = (signed char) Clamp(
        cmd->sidemove
        + MoveAmount(in.strafe, sidemove[player->class][run], player),
        127);

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
        cmd->arti |= AFLAG_JUMP;
    }
    // The selected inventory item, as the use-artifact key picks it. Skipped
    // when a key already chose an item, since the bits would merge.
    if ((in.buttons & DMCP_BTN_USE_ITEM) && !(cmd->arti & AFLAG_MASK)
     && inv_ptr >= 0 && inv_ptr < player->inventorySlotNum
     && player->inventory[inv_ptr].type != arti_none)
    {
        cmd->arti |= player->inventory[inv_ptr].type & AFLAG_MASK;
    }
    // The high nibble of lookfly is the fly direction (+5 up, -5 down). Like
    // the fly keys, it uses a Wings of Wrath when the player has none active.
    if ((in.buttons & (DMCP_BTN_FLY_UP | DMCP_BTN_FLY_DOWN))
     && !(cmd->lookfly & 0xf0))
    {
        int fly = (in.buttons & DMCP_BTN_FLY_UP) ? 5 : -5;

        cmd->lookfly |= (fly & 15) << 4;
    }
    if (in.weapon_slot >= 1 && in.weapon_slot <= NUMWEAPONS)
    {
        cmd->buttons &= ~BT_WEAPONMASK;
        cmd->buttons |= BT_CHANGE | ((in.weapon_slot - 1) << BT_WEAPONSHIFT);
    }
}
