# Metaretro: working notes

LÖVE 11.5 + LuaJIT game distributed as a PortMaster port. The target is an Anbernic RG40XXV running Knulli (Batocera EmulationStation) at 640x480. The README covers what the game is, setup and credits. These notes cover how the code fits together and what was decided.

## Commands
- Tests: `~/.luarocks/bin/busted` (specs in `tests/`, `.busted` puts `src/` on the path). Run them after every change.
- Desktop run: `/Applications/love.app/Contents/MacOS/love src` (mock backend). Before handing a build over, run it once with the device's exact args, `love src --layout nintendo`.
- Screenshot: `love src --screenshot 1` writes `~/Library/Application Support/LOVE/metaretro/screenshot.png`.
- Port: `scripts/build-port.sh` builds `dist/ports/`. The user copies that to the device and pastes back `log.txt`.
- Launch titles: `scripts/generate-launch-titles.py [page.html] [roms dir]` regenerates `src/core/launchtitles.lua`. Never edit that file by hand.
- Console sprites: `love scripts/draw-consoles src` redraws `src/assets/metaretro/Consoles.png` and `src/world/consolelooks.lua` from the drawings in the script. Never edit those two files by hand. A preview with names goes to the script's LÖVE save folder.

## Code map (src/)
- `main.lua`: the `app` table (state, backend, catalog, stores, town), startup, and the LÖVE callbacks.
  - **Startup:** the title screen shows while `services/library` reads the gamelists and the save on a thread. It sends one system per message, and the main thread takes one per frame.
  - **Preparing ahead:** once the library is read, `prepare` sets up the title's first option (Continue, or New Game without a save) without saving anything. It runs as a coroutine, a step per frame, so the title keeps responding.
  - **Choosing:** `start` goes straight to town if that choice is ready; otherwise it shows "Loading your library..." until it is.
  - **Entering town** (`enterTown`) saves and starts the RetroAchievements sync.
  - **After a game:** the launcher leaves `resume.txt` in the save folder. The next start removes it and skips the title. This replaced a `--resume` argument from `Metaretro.sh`, which didn't work on the device for reasons we never pinned down. `$LOVE_RUN` does pass arguments: the log shows `started with: --layout nintendo`. The title, preparing ahead and coming back from a game all work on the device (2026-11-07).
- `core/`: pure logic, all unit-tested.
  - `economy`: prices, earnings, purchases and starter packs.
  - `progression`: the console timeline and generations, the gift's choices (oldest), the museum's best sellers (`mostPopular`, by `sold` in `core/consoles.lua`).
  - `arcade`: the Arcade Club's systems, its weekly cabinets (`arcade.week`, Monday to Sunday) and its price.
  - `stores`: the store list, daily offers and billboard `featured` picks.
  - `catalog`: owned and locked games.
  - `genres`: 12 categories.
  - `townsfolk`: the villager cast, daily roster, wandering rule and recommendations.
  - `achievements`: RetroAchievements pay rules, and finding game ids from ROM hashes (`hashIds`, `resolveIds`, `consolesToRefresh`).
  - `daily`: a deterministic random generator keyed by date.
  - `save`: defaults and migration.
  - `input`: key repeat, `stopRepeats`, Nintendo layout.
  - `scenes`: the scene stack; `drawBelow` overlays and `onChange`.
- `backends/`: `knulli` reads gamelist.xml and lists files with `find`; `mock` is for the desktop; `gamelist` is the parser.
- `services/`:
  - `covers` and `coverworker`: threaded cover loading with prefetch, an LRU of 64, and GPU shrinking to 320px.
  - `http` and `httpworker`: curl or wget on a thread. They retry 429s, which RetroAchievements sends to bursts. A `parser` ("module:function") can decode a big response on the thread.
  - `retroachievements`: the sync.
  - `library` and `libraryworker`: read every system's games on a thread; backends take the result with `useListing`.
  - `playtime`: session log plus gametime.
  - `video` and `videoworker`: video playback for the TV. ffmpeg decodes the picture (320x240 at 20fps) and the sound (44.1kHz stereo, into a QueueableSource) on two threads; both start together.
  - `launcher`.
- `world/`:
  - `townmap`: the ASCII map; its legend is in `world/town.lua`.
  - `town`: parsing, walkability and plots. The town has fixed buildings only (home, museum, dealer, mall); stores live in the mall.
  - `mall`: the mall's inside, laid out for the open stores: storefront doors (`S`) alternating along the top and bottom walls, longer as stores open.
  - `storemap`: the inside of a store or the dealer: shelves, and the clerk (`C`) behind the counter.
  - `interior`, `homemap` and `museummap`: buildings' insides, as a rooms layer and a furniture layer. The furniture layer also marks spots (`P` the professor, `S` where a new game wakes up). Wall pieces come from where the floor is (`interior.wallPiece`).
  - `art`: all town and Home drawing from the Ninja Adventure sheets, plus our own TV, console and sofa in `assets/metaretro/` (the pack has none).
- `scenes/`:
  - `walker`: the base for scenes the player walks around (town and interiors): steps, door fades, camera, toasts, the quit prompt.
  - `interior`: the base for buildings' insides (walking, furniture, people, storefront doors, the door out). `home`, `museum`, `mall` and `store` extend it through hooks (`interact`, `hintFor`, `live`, `absent`, `drawOnTop`, `enterStorefront`, `storefrontHint`).
  - title (Continue / New Game / Quit), intro (Professor Cork, boy or girl), town, museum, arcade (the Arcade Club), mall (the corridor of storefronts), store (a store or the dealer inside; A on the clerk or the counter in front of them opens the shop menu), tv (the reel), shop (the store/dealer menu), collection (opened from the console at home), gamedetail, dialog, confirm, loading.
- `ui.lua`: fonts, panels (nine-slice), hint bars with button icons, lists, covers, and the `ui.boxArt` (thumbnail) / `ui.fullImage` (image) helpers.

## Rules and numbers (change here, not in the README)
- **Prices:**
  - A game costs `(generation - 1) * 20`, scaled 0.75–1.25 by rating and rounded to 5.
  - A console costs `generation * 100`.
- **Earning coins:**
  - Play: 2 coins per minute, capped at 120 minutes per session.
  - RetroAchievements: 5 coins per point, x2 in hardcore. Unlocks from before tracking started pay x0.5, once.
  - Game ids: scrapers often give a `cheevosHash` without a `cheevosId`. The sync then fetches the game lists of owned consoles (`API_GetGameList`, with hashes; one console per request), at most weekly, and keeps the ids of library games in `cheevos.txt` in the save folder. Owned games that get an id this way are checked at once, and played games without one wait in `pendingAchievementHashes`. Consoles' RetroAchievements ids are `ra` in `core/consoles.lua`. Matching by hash only is deliberate: a title match without a hash match is a ROM version the emulator won't award achievements for. Checked on the device on 2026-11-07: Tomb Raider II (hash match) showed achievements, and Tomb Raider III (title match only) showed none. The lookup itself was confirmed on the device the same day: only the owned consoles were looked up, and Psychic World (hash only) paid out.
- **Starting out:**
  - New Game resets the save. Play already in `sessions.log` doesn't pay again, and RetroAchievements tracking starts over from then (older unlocks pay x0.5, once).
  - Starter wallet: 1000.
  - New Game: the intro (pick boy or girl), then waking up at home with no console. Professor Cork, in the museum next to Home, offers one of the 3 oldest consoles in the library (`progression.giftChoices`). Picking it from his table gives it free with its starter pack (`economy.giftConsole`).
  - The console dealer is closed, with a door over its doorway, until the gift (`Town:isClosed`).
  - Saves from before the intro skip it, and the gift counts as received (`save.migrate`).
  - Starter packs: 3 games from curated launch titles, then the launch window, then the rest. Japanese-only games come last: they're only used when there aren't enough others, as with the PC Engine. Buying a console grants its own pack.
- **Stores:**
  - Genre stores need ≥30 games of that genre across owned consoles (`stores.MIN_GENRE_GAMES`).
  - Daily offer: 5 random games per store.
- **Villagers:** 20 in the cast, 4 for each of 5 kinds; one villager per kind each day. Each starts on a random grass tile (not above a tree), at least 8 tiles from the others and 3 from the player's start (`townsfolk.MIN_SPACING`, `START_CLEARANCE`); wander radius 2, grass only.

## What's left out of the library
- **Non-console systems:** Metaretro's library only uses the consoles in `core/consoles.lua`. Computers and engines (dos, amiga, devilutionx, cannonball, xash3d…) appear nowhere. Arcade systems (fbneo, mame, arcade, naomi, cps…, see `arcade.SYSTEMS`) appear only in the Arcade Club's cabinets, never in stores, Home, starter packs or counts.
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
- **Doors:** you enter by walking up into them; A doesn't enter. In the town map, a door goes where its building's sprite draws the doorway: one tile from the left for most buildings, two for the museum. Each building's left edge comes from its `B` tiles. A talks to villagers and reads the signpost. You leave Home by walking down onto its front door.
- **Home:** an open-plan kitchen and living room, plus a bedroom. The console under the TV opens the collection (A); it only appears once the player owns a console. The TV (A) plays a nonstop reel of scraped videos of the games on sale in town today (`stores.onSale`), shuffled; videos that won't play drop out of the reel. Walls are `TilesetWallSimple` pieces. The wall between two rooms is one tile thick, made from the halves of the pieces on either side (see `WALLS` in `world/art.lua`).
- **Museum:** the big wooden hall in town. Inside are pillars and statues, six glass cases with the library's best-selling consoles (A: the year and roughly how many were sold), and Professor Cork with his gift table. Every console in `core/consoles.lua` has a sprite after the real hardware (drawn by `scripts/draw-consoles`, which also draws the glass case and the cabinets). The controller sits one empty row below the console, joined by a one-pixel black cable. Wireless controllers have no cable, and handhelds have no controller. Unknown systems use the generic sprite. The console under the TV at home is the one the player last played an owned game on (`townsfolk.lastPlayedGame`). Before any play, it's the gift, then the oldest owned console. The intro's text is original; we don't copy Pokémon's script or names.
- **Arcade Club:** four cabinets with this week's arcade games, the same for everyone that week (`arcade.cabinets`). A play costs 1 coin and launches the game like the collection does. Play pays coins as usual, through `sessions.log`.
- **Player look:** `state.player` is "boy" (`Boy.png`) or "girl" (`Girl.png`, the pack's SorcererBlack).

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
- **Startup:** parsing a ~9,600-game library takes ~4.5s, now on a thread behind the title screen. The user chose not to add a library cache. Setting up the save afterwards runs on the main thread; it's about 10% of the parse time on the desktop with the JIT off.
- **Secrets:** device logs contain the RetroAchievements token. Never echo it back.
- **FPS:** steady 60. Select toggles the FPS counter.
- **Videos:** LÖVE only plays Ogg Theora, and scraped videos are MP4, so the TV decodes them with ffmpeg. The log line `video: ffmpeg <path>` shows whether ffmpeg was found. Picture and sound play smoothly and in step on the device (2026-11-07).

## Roadmap (as of 2026-11-06)
- **Not started** (agreed with the user, from the genre-data analysis):
  - **Genre bounties:** timed requests, possibly from a villager (e.g. "play an RPG this week"), that pay bonus coins for playing a matching owned game.
  - **Collector rewards:** bonus coins for owning every game of a series in the library. The series comes from the gamelist `family` field, which about 3,700 of the example-data entries have.
  - **RetroAchievements badges:** show progress in game details (e.g. "12 / 40 unlocked", mastery). This needs one more per-game RetroAchievements lookup, which could share the sync's request.
  - **Japanese-only warning in stores:** mark games whose `lang` is only `jp`/`ja` (see `economy.isJapaneseOnly`). Starter packs only use them as a last resort.
  - **Hiding categories:** a setting to hide genre categories (e.g. Tabletop, Misc) from genre stores, store picks and villager suggestions.
- **Parked:**
  - library cache
  - completion times (RetroAchievements `MedianTimeToBeat`)
  - computers and engines (dos, amiga…), which are excluded from consoles for now (arcade systems are only in the Arcade Club)
- **Wishlist (README):**
  - Games of the Month
  - ES favorites
