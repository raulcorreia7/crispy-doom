# Crispy Doom

<p align="center">
  <a href="https://github.com/raulcorreia7/crispy-doom">
    <img src="https://raw.githubusercontent.com/raulcorreia7/crispy-doom/master/data/doom.png" alt="Crispy Doom icon">
  </a>
</p>

<p align="center">
  <a href="https://github.com/raulcorreia7/crispy-doom"><img src="https://img.shields.io/github/languages/top/raulcorreia7/crispy-doom.svg" alt="Top Language"></a>
  <a href="https://github.com/raulcorreia7/crispy-doom"><img src="https://img.shields.io/github/languages/code-size/raulcorreia7/crispy-doom.svg" alt="Code Size"></a>
  <a href="https://github.com/raulcorreia7/crispy-doom/blob/master/COPYING.md"><img src="https://img.shields.io/github/license/raulcorreia7/crispy-doom.svg?logo=gnu" alt="License"></a>
  <a href="https://github.com/raulcorreia7/crispy-doom/releases"><img src="https://img.shields.io/github/release/raulcorreia7/crispy-doom.svg" alt="Release"></a>
  <a href="https://github.com/raulcorreia7/crispy-doom/releases"><img src="https://img.shields.io/github/release-date/raulcorreia7/crispy-doom.svg" alt="Release Date"></a>
  <a href="https://github.com/raulcorreia7/crispy-doom/releases"><img src="https://img.shields.io/github/downloads/raulcorreia7/crispy-doom/latest/total.svg" alt="Downloads"></a>
  <a href="https://github.com/raulcorreia7/crispy-doom/commits/master"><img src="https://img.shields.io/github/commits-since/raulcorreia7/crispy-doom/latest.svg" alt="Commits Since Release"></a>
  <a href="https://github.com/raulcorreia7/crispy-doom/commits/master"><img src="https://img.shields.io/github/last-commit/raulcorreia7/crispy-doom.svg" alt="Last Commit"></a>
  <a href="https://github.com/raulcorreia7/crispy-doom/actions/workflows/main.yml"><img src="https://github.com/raulcorreia7/crispy-doom/actions/workflows/main.yml/badge.svg" alt="Build Status"></a>
</p>

<p align="center">
  This fork tracks upstream <a href="https://github.com/fabiangreffrath/crispy-doom">Crispy Doom</a>
  and adds <a href="https://github.com/raulcorreia7/crispy-doom/blob/master/README.DMCP.md">DMCP</a>
  support so agents can inspect and control a running Doom game through MCP.
</p>

<p align="center">
  <a href="https://www.youtube.com/watch?v=G82a40hI-H8">
    <img src="https://img.youtube.com/vi/G82a40hI-H8/hqdefault.jpg" alt="DMCP Crispy Doom demo" width="480">
  </a>
  <br>
  Demo: <a href="https://www.youtube.com/watch?v=G82a40hI-H8">https://www.youtube.com/watch?v=G82a40hI-H8</a>
</p>

Crispy Doom is a limit-removing enhanced-resolution Doom source port based on [Chocolate Doom](https://www.chocolate-doom.org/wiki/index.php/Chocolate_Doom).

Its name means that its internal 640x400 resolution looks "crisp" and is also a [slight reference](http://www.mathsisfun.com/recipie.html) to its origin.

## Synopsis

Crispy Doom is a friendly fork of [Chocolate Doom](https://www.chocolate-doom.org/wiki/index.php/Chocolate_Doom) that provides a higher display resolution, removes the [static limits](https://doomwiki.org/wiki/Static_limits) of the Doom engine and offers further optional visual, tactical and physical enhancements while remaining entirely config file, savegame, netplay and demo compatible with the original.

## Objectives and features

Crispy Doom is a source port that aims to provide a faithful Doom gaming experience while also featuring some user-requested improvements and enhancements. It is forked off of Chocolate Doom to take advantage of its free and open-source code base, portability, accuracy and compatibility with Vanilla Doom.

Its core features are:

 * Enhanced 640x400 display resolution, with the original 320x200 resolution still available in the "High Resolution Rendering: Off" mode.
 * Widescreen rendering for using all the available horizontal space of screens with aspect ratios up to 24:9.
 * Uncapped rendering framerate with interpolation and optional vertical synchronization (VSync) with the screen refresh rate.
 * Intermediate gamma correction levels (0.5, 1.5, 2.5 and 3.5).
 * Removal of all static engine limits, or at least raising of the less crucial ones.
 * Full support for the "Doom Classic" WADs shipped with the "Doom 3: BFG Edition", especially the "No Rest For The Living" episode shipped in the NERVE.WAD file.
 * Support for all versions of John Romero's Episode 5: Sigil for Ultimate Doom.

Furthermore, the following optional user-visible and audible features are available:

 * Jumping.
 * Free vertical looking, including mouse look and vertical aiming.
 * Aiming support by a crosshair that may get directly rendered into the game world.
 * A new minimal Crispy HUD, displaying only the status bar numbers.
 * Clean Screenshot feature, enabling to take screenshots without HUD elements and even without status bar numbers and weapon sprites at higher screen sizes.
 * Colorized status bar numbers, HUD texts and blood sprites for certain monsters.
 * Translucency for certain sprites and status bar elements in the Crispy HUD.
 * Randomly mirrored death animations and corpse sprites.
 * Command line options to allow for playing with flipped player weapon sprites and/or entirely flipped level geometry.
 * Players may walk over or under monsters and hanging corpses.
 * Centered Weapons when firing, weapon recoil thrust and pitch.
 * Reports whenever a secret is revealed.
 * Level statistics and extended coloring in the Automap.
 * Playing sounds in full length, and misc. other sound fixes.
 * Demo recording and/or playback timers and progress bar.
 * Demo continue, fast-forward and take-over features, handing controls over to the player when demo playback is finished or interrupted.

Most of these features are disabled by default and need to get enabled either in the in-game "Crispness" menu, in the crispy-doom-setup tool or as command line parameters. They are implemented in a way that preserves demo-compatibility with Vanilla Doom and network game compatibility with Chocolate Doom. Furthermore, Crispy Doom's savegames and config files are compatible, though not identical (see the [Compatibility section in the Wiki](https://github.com/fabiangreffrath/crispy-doom/wiki/Compatibility), to Vanilla Doom's. 

Crispy Doom strives for maximum compatibility with all "limit-removing Vanilla" maps -- but not Boom or ZDoom maps. More specifically, Crispy Doom supports some select advanced features such as [ANIMATED](https://doomwiki.org/wiki/ANIMATED) and [SWITCHES](https://doomwiki.org/wiki/SWITCHES) lumps, MBF sky transfers, SMMU swirling flats and [MUSINFO](https://doomwiki.org/wiki/MUSINFO) -- but neither generalized linedef and sector types nor DECORATE and MAPINFO.

Many additional less user-visible features have been implemented, e.g. fixed engine limitations and crashes, fixed rendering bugs, fixed harmless game logic bugs, full support for DEHACKED files and lumps in BEX format, additional and improved cheat codes, an improved Automap, and many more! Due to the extra DEHACKED states added from [MBF](https://doomwiki.org/wiki/MBF), Crispy Doom supports [enhancer](https://www.doomworld.com/forum/topic/84859-black-ops-smooth-weapons-dehacked-mod) [mods](https://www.doomworld.com/forum/topic/85991-smoothed-smooth-monsters-for-doom-retro-and-crispy-doom) that can make the gameplay even more pleasing to the eyes. For a detailed list of features and changes please refer to the release notes below.

## Download

* Windows: [Get binaries of the latest DMCP-enabled fork release](https://github.com/raulcorreia7/crispy-doom/releases/latest).
* MacOS: [Get the latest DMCP-enabled fork release](https://github.com/raulcorreia7/crispy-doom/releases/latest). Upstream Crispy Doom is also available through MacPorts: `sudo port install crispy-doom` or Homebrew: `brew install crispy-doom`.
* Linux: [Get the latest DMCP-enabled fork release](https://github.com/raulcorreia7/crispy-doom/releases/latest). Upstream Crispy Doom is also available on Ubuntu (“Eoan Ermine” 19.10 and later)/Debian (“Buster” 10 and later) based systems: `sudo apt-get install crispy-doom`


The most recent list of changes in this fork can be found in the [Changelog](https://github.com/raulcorreia7/crispy-doom/blob/master/CHANGELOG.md).
A complete upstream history of changes and releases can be found in the [upstream Wiki](https://github.com/fabiangreffrath/crispy-doom/wiki/Changelog-History), and fork releases are published on the [Releases](https://github.com/raulcorreia7/crispy-doom/releases) page.

Daily builds of Crispy Doom can be found here:
http://latest.chocolate-doom.org/

Crispy Doom can play nearly all variants of Doom. If you don't own any, you may download the [Shareware version of Doom](http://cdn.debian.net/debian/pool/non-free/d/doom-wad-shareware/doom-wad-shareware_1.9.fixed.orig.tar.gz), extract it and copy the DOOM1.WAD file into your Crispy Doom directory. Alternatively, you may want to play Crispy Doom with [Freedoom](https://www.chocolate-doom.org/wiki/index.php/Freedoom) and a MegaWAD.

### DMCP-enabled fork builds

Download the latest release artifact for your OS:

```bash
curl -L https://github.com/raulcorreia7/crispy-doom/releases/latest/download/crispy-doom-dmcp-linux.tar.gz | tar -xz
cd crispy-doom-dmcp-linux
./go.sh
```

```bash
curl -L https://github.com/raulcorreia7/crispy-doom/releases/latest/download/crispy-doom-dmcp-macos.tar.gz | tar -xz
cd crispy-doom-dmcp-macos
./go.sh
```

```powershell
Invoke-WebRequest https://github.com/raulcorreia7/crispy-doom/releases/latest/download/crispy-doom-dmcp-windows.zip -OutFile crispy-doom-dmcp-windows.zip; Expand-Archive crispy-doom-dmcp-windows.zip -DestinationPath . -Force
cd crispy-doom-dmcp-windows
.\go.bat
```

The release artifact includes launch scripts, raw MCP presets under
`agent-presets/`, and the token-efficient Python helper under `agents/python`.
The `go.sh` / `go.bat` launcher auto-downloads the checksum-verified Doom
shareware IWAD if `doom1.wad` is missing. Put another IWAD beside the executable
or set `DOOM_WAD` when you want a different game data file.

DMCP listens at `http://localhost:6060/mcp` by default. For CLI agents, prefer
the bundled Python `dmcp-agent` helper before calling MCP tools directly:

```bash
./dmcp-agent --pretty brief
./dmcp-agent --pretty content enemies
./dmcp-agent spawn DoomImp --x 160 --y 96
```

On Windows use `.\dmcp-agent.bat`. The helper requires `uv`; install it from
<https://docs.astral.sh/uv/> if the launcher reports it is missing.

Linux/macOS packages use system SDL2, FluidSynth, png, samplerate, and zlib
runtime libraries. If the loader reports a missing library, install the runtime
packages shown in [README.DMCP.md](README.DMCP.md).

For the DMCP-enabled release artifact, agent-ready config files and quickstart,
see [README.DMCP.md](README.DMCP.md). Source build dependencies and local build
steps are documented in [docs/build-dmcp.md](docs/build-dmcp.md).

### Sources

<p align="center">
  <a href="https://www.openhub.net/p/crispy-doom">
    <img src="https://www.openhub.net/p/crispy-doom/widgets/project_thin_badge?style=flat&amp;format=gif" alt="Open Hub">
  </a>
</p>

This fork's source code is available at GitHub: https://github.com/raulcorreia7/crispy-doom.
It can be [downloaded in either ZIP or TAR.GZ format](https://github.com/raulcorreia7/crispy-doom/releases)
or cloned via

```
 git clone --recurse-submodules https://github.com/raulcorreia7/crispy-doom.git
```


 * Brief instructions to set up a build system on Windows can be found [in the Crispy Doom Wiki](https://github.com/fabiangreffrath/crispy-doom/wiki/Building-on-Windows). A much more detailed guide is provided [in the Chocolate Doom Wiki](https://www.chocolate-doom.org/wiki/index.php/Building_Chocolate_Doom_on_Windows), but applies to Crispy Doom as well for most parts.
 * There are also instructions for building on [Linux](https://github.com/fabiangreffrath/crispy-doom/wiki/Building-on-Linux) and [MacOS](https://github.com/fabiangreffrath/crispy-doom/wiki/Building-on-Mac)


## Documentation

 * **[DMCP Quick Start and agent presets](README.DMCP.md)**
 * **[DMCP source build dependencies](docs/build-dmcp.md)**

Upstream Crispy Doom documentation:

 * **[New Cheat Codes](https://github.com/fabiangreffrath/crispy-doom/wiki/New-Cheats)**
 * **[New Command-Line Parameters](https://github.com/fabiangreffrath/crispy-doom/wiki/New-Command-line-Parameters)**
 * **[New Controls](https://github.com/fabiangreffrath/crispy-doom/wiki/New-Controls) (With default bindings)**
 * **[Crispness](https://github.com/fabiangreffrath/crispy-doom/wiki/Crispness-Menu)**
 * **[Compatibility](https://github.com/fabiangreffrath/crispy-doom/wiki/Compatibility)**
 * **[FAQ](https://github.com/fabiangreffrath/crispy-doom/wiki/FAQ)**

## Contact

This DMCP-enabled fork is maintained at https://github.com/raulcorreia7/crispy-doom.
The canonical upstream homepage for Crispy Doom is https://github.com/fabiangreffrath/crispy-doom

Crispy Doom is maintained by [Fabian Greffrath](mailto:fabian@greffXremovethisXrath.com). 

Please report bugs, glitches or crashes in this fork to the fork's GitHub [Issue Tracker](https://github.com/raulcorreia7/crispy-doom/issues). Upstream-only Crispy Doom issues should be checked against the upstream project first.

## Acknowledgement

Although I have played the thought of hacking on Chocolate Doom's renderer for quite some time already, it was Brad Harding's [Doom Retro](https://www.chocolate-doom.org/wiki/index.php/Doom_Retro) that provided the incentive to finally do it. However, his fork aims at a different direction and I did not take a single line of code from it. Lee Killough's [MBF](https://doomwiki.org/wiki/WinMBF) was studied and used to debug the code, especially in the form of Team Eternity's [WinMBF](https://doomwiki.org/wiki/WinMBF) source port, which made it easier to compile and run on my machine. And of course there is fraggle's [Chocolate Doom](https://www.chocolate-doom.org/wiki/index.php/Chocolate_Doom) with its exceptionally clean and legible source code. Please let me take this opportunity to appreciate all these authors for their work!

Also, thanks to plums of the [Doomworld forums](https://www.doomworld.com/vb/) for beta testing, "release manager" SoDOOManiac and "art director" JNechaevsky for the continuous flow of support and inspiration during the post-3.x development cycle and (last but not the least) [Cacodemon9000](http://www.moddb.com/members/cacodemon9000) for his [Infested Outpost](http://www.moddb.com/games/doom-ii/addons/infested-outpost) map that helped to track down quite a few bugs!

Furthermore, thanks to VGA for his aid with adding support for his two mods: [PerK & NightFright's Black Ops smooth weapons add-on converted to DEHACKED](https://www.doomworld.com/forum/topic/84859-black-ops-smooth-weapons-dehacked-mod) and [Gifty's Smooth Doom smooth monster animations converted to DEHACKED](https://www.doomworld.com/forum/topic/85991-smoothed-smooth-monsters-for-doom-retro-and-crispy-doom) that can make the gameplay even more pleasing to the eyes.

## Legalese

Doom is © 1993-1996 Id Software, Inc.; 
Boom 2.02 is © 1999 id Software, Chi Hoang, Lee Killough, Jim Flynn, Rand Phares, Ty Halderman;
PrBoom+ is © 1999 id Software, Chi Hoang, Lee Killough, Jim Flynn, Rand Phares, Ty Halderman,
© 1999-2000 Jess Haas, Nicolas Kalkhof, Colin Phipps, Florian Schulze,
© 2005-2006 Florian Schulze, Colin Phipps, Neil Stevens, Andrey Budko;
Chocolate Doom is © 1993-1996 Id Software, Inc., © 2005 Simon Howard; 
Chocolate Hexen is © 1993-1996 Id Software, Inc., © 1993-2008 Raven Software, © 2008 Simon Howard;
Strawberry Doom is © 1993-1996 Id Software, Inc., © 2005 Simon Howard, © 2008-2010 GhostlyDeath; 
Crispy Doom is additionally © 2014-2019 Fabian Greffrath;
all of the above are released under the [GPL-2+](https://www.gnu.org/licenses/gpl-2.0.html).

SDL 2.0, SDL_mixer 2.0 and SDL_net 2.0 are © 1997-2016 Sam Lantinga and are released under the [zlib license](http://www.gzip.org/zlib/zlib_license.html).

Secret Rabbit Code (libsamplerate) is © 2002-2011 Erik de Castro Lopo and is released under the [GPL-2+](http://www.gnu.org/licenses/gpl-2.0.html).
Libpng is © 1998-2014 Glenn Randers-Pehrson, © 1996-1997 Andreas Dilger, © 1995-1996 Guy Eric Schalnat, Group 42, Inc. and is released under the [libpng license](http://www.libpng.org/pub/png/src/libpng-LICENSE.txt).
Zlib is © 1995-2013 Jean-loup Gailly and Mark Adler and is released under the [zlib license](http://www.zlib.net/zlib_license.html).

The Crispy Doom icon (as shown at the top of this page) has been contributed by Philip K.
