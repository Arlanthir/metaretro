# Metaretro: working notes

LÖVE 11.5 + LuaJIT game distributed as a PortMaster port. The target is an Anbernic RG40XXV running Knulli (Batocera EmulationStation) at 640x480. The README covers what the game is, setup and credits. These notes cover how the code fits together and what was decided.

## Commands
- Tests: `~/.luarocks/bin/busted` (specs in `tests/`, `.busted` puts `src/` on the path). Run them after every change.
- Desktop run: `/Applications/love.app/Contents/MacOS/love src` (mock backend). Before handing a build over, run it once with the device's exact args, `love src --layout nintendo`.
- Screenshot: `love src --screenshot 1` writes `~/Library/Application Support/LOVE/metaretro/screenshot.png`.
- Port: `scripts/build-port.sh` builds `dist/ports/`. The user copies that to the device and pastes back `log.txt`.
- Launch titles: `scripts/generate-launch-titles.py [page.html] [roms dir]` regenerates `src/core/launchtitles.lua`. Never edit that file by hand.

## Code map (src/)
- `main.lua`: the `app` table (state, backend, catalog, stores, town), `loadLibrary` (save, starter console and pack, play credit, RetroAchievements sync), and the LÖVE callbacks.
- `core/`: pure logic, all unit-tested.
  - `economy`: prices, earnings, purchases and starter packs.
  - `progression`: the console timeline and generations.
  - `stores`: the store list, daily offers and billboard `featured` picks.
  - `catalog`: owned and locked games.
  - `genres`: 12 categories.
  - `townsfolk`: the villager cast, daily roster, wandering rule and recommendations.
  - `achievements`: RetroAchievements pay rules.
  - `daily`: a deterministic random generator keyed by date.
  - `save`: defaults and migration.
  - `input`: key repeat, `stopRepeats`, Nintendo layout.
  - `scenes`: the scene stack; `drawBelow` overlays and `onChange`.
- `backends/`: `knulli` reads gamelist.xml and lists files with `find`; `mock` is for the desktop; `gamelist` is the parser.
- `services/`:
  - `covers` and `coverworker`: threaded cover loading with prefetch, an LRU of 64, and GPU shrinking to 320px.
  - `http` and `httpworker`: curl or wget on a thread.
  - `retroachievements`: the sync.
  - `playtime`: session log plus gametime.
  - `launcher`.
- `world/`:
  - `townmap`: the ASCII map; its legend is in `world/town.lua`.
  - `town`: parsing, walkability, plots and lots.
  - `homemap` and `home`: the inside of Home, as a rooms layer and a furniture layer; wall pieces come from where the floor is (`home.wallPiece`).
  - `art`: all town and Home drawing from the Ninja Adventure sheets, plus our own TV, console and sofa in `assets/metaretro/` (the pack has none).
- `scenes/`:
  - `walker`: the base for scenes the player walks around (town and home): steps, door fades, camera, the quit prompt.
  - town, home (inside), shop (store/dealer), collection (opened from the console at home), gamedetail, dialog, confirm, loading.
- `ui.lua`: fonts, panels (nine-slice), hint bars with button icons, lists, covers, and the `ui.boxArt` (thumbnail) / `ui.fullImage` (image) helpers.

## Rules and numbers (change here, not in the README)
- **Prices:**
  - A game costs `(generation - 1) * 20`, scaled 0.75–1.25 by rating and rounded to 5.
  - A console costs `generation * 100`.
- **Earning coins:**
  - Play: 2 coins per minute, capped at 120 minutes per session.
  - RetroAchievements: 5 coins per point, x2 in hardcore. Unlocks from before tracking started pay x0.5, once.
- **Starting out:**
  - Starter wallet: 1000.
  - Starter packs: 3 games from curated launch titles, then the launch window, then the rest. Japanese-only games are skipped. Buying a console grants its own pack.
- **Stores:**
  - Genre stores need ≥30 games of that genre across owned consoles (`stores.MIN_GENRE_GAMES`).
  - Daily offer: 5 random games per store.
- **Villagers:** 20 in the cast, 4 for each of 5 kinds; one villager per kind each day. Each starts on a random grass tile (not above a tree), at least 8 tiles from the others and 3 from the player's start (`townsfolk.MIN_SPACING`, `START_CLEARANCE`); wander radius 2, grass only.

## What's left out of the library
- **Non-console systems:** Metaretro only uses the consoles in `core/consoles.lua`. Computers, arcade and engines (dos, amiga, fbneo, devilutionx, cannonball, xash3d…) appear nowhere: not in stores, Home, starter packs or counts.
- **Ports:** Knulli's `ports` folder is ignored; Metaretro itself lives there.
- **Gamelist entries:** entries marked `<hidden>`, and entries whose ROM file is missing (gamelists keep stale ones), are skipped by `backends/knulli.lua`.
- **No genre setting yet:** no genres are hidden by choice. Small genres only lack a genre store (see the rules above; Music, in the user's library); their games still sell in console stores.

## Look and feel decisions
- **Art:** pixel art is 16px drawn at 2x (`art.TILE` = 32).
- **Font:** Ark Pixel 10px at 20px; it's only crisp at multiples of 10. Every text size is 20px, including the town signs. The user rejected Pixelify (ambiguous 5), Jersey 10 (illegible) and Ark 12px (too big).
- **Menus:**
  - Panels have a thin orange frame and a dark brown fill (`ui.colors.panelFill`) with cream text.
  - The wallet sits in the same spot in town and in menus (`ui.walletPanel`).
- **Covers:** stores and Home show box art (`thumbnail`); details pages show the composite `image`. Billboards show box art, take the box's shape, and aren't drawn at all without an ad.
- **Doors:** you enter by walking up into them; A doesn't enter. A talks to villagers and reads the signpost. You leave Home by walking down onto its front door.
- **Home:** an open-plan kitchen and living room, plus a bedroom. The console under the TV opens the collection (A). Walls are `TilesetWallSimple` pieces. The wall between two rooms is one tile thick, made from the halves of the pieces on either side (see `WALLS` in `world/art.lua`).

## Verifying changes visually
- **Harness:** for anything visual, copy `src/` into a scratch folder and append a driver to its `main.lua`:
  - Change `local app =` to a global so the driver can reach it.
  - Script the scene changes from a wrapped `love.update`.
  - Capture with `love.graphics.captureScreenshot`.
  - Files land in `~/Library/Application Support/LOVE/metaretro/`, because `conf.lua` sets the identity.
- **Screenshot timing:** a capture happens at the end of the frame, so change state in a later frame than the one that captures.
- **No error windows:** wrap the driver's `update` and `draw` in `pcall` and check paths before running. A LÖVE error opens a window on the user's screen.
- **Example media:** `example-data/` has real scraped gamelists, plus box art and composite images under `gamegear/images` and `gb/images`.

## Device facts (Knulli, RG40XXV)
- **No JIT:** LÖVE turns LuaJIT's JIT off on arm64, so per-pixel Lua work is slow there. Use the GPU (canvases) instead.
- **Launching:** `emulatorlauncher` needs ES's `%CONTROLLERSCONFIG%` args (see `backends/knulli.lua`).
- **Play time:** games launched from Metaretro don't update gamelist `gametime`, so play is credited from `sessions.log` as well (the larger of the two).
- **Startup:** parsing a ~9,600-game library takes ~4.5s. The user chose not to add a library cache.
- **Secrets:** device logs contain the RetroAchievements token. Never echo it back.
- **FPS:** steady 60. Select toggles the FPS counter.

## Roadmap (as of 2026-11-06)
- **Not started** (agreed with the user, from the genre-data analysis):
  - **Genre bounties:** timed requests, possibly from a villager (e.g. "play an RPG this week"), that pay bonus coins for playing a matching owned game.
  - **Collector rewards:** bonus coins for owning every game of a series in the library. The series comes from the gamelist `family` field, which about 3,700 of the example-data entries have.
  - **RetroAchievements badges:** show progress in game details (e.g. "12 / 40 unlocked", mastery). This needs one more per-game RetroAchievements lookup, which could share the sync's request.
  - **Japanese-only warning in stores:** mark games whose `lang` is only `jp`/`ja` (see `economy.isJapaneseOnly`). Starter packs already skip them.
  - **Hiding categories:** a setting to hide genre categories (e.g. Tabletop, Misc) from genre stores, store picks and villager suggestions.
- **Parked:**
  - library cache
  - completion times (RetroAchievements `MedianTimeToBeat`)
  - computers, arcade and engines (dos, amiga, fbneo…), which are excluded from consoles for now
- **Wishlist (README):**
  - Games of the Month
  - ES favorites
