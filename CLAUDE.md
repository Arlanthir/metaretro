# Retro Town Story (codebase: Metaretro): working notes

LÖVE 11.5 + LuaJIT game distributed as a PortMaster port. The target is an Anbernic RG40XXV running Knulli (Batocera EmulationStation) at 640x480. The README covers what the game is, setup and credits. These notes cover how the code fits together and what was decided.

## Commands
- Tests: `~/.luarocks/bin/busted` (specs in `tests/`, `.busted` puts `src/` on the path). Run them after every change.
- Desktop run: `/Applications/love.app/Contents/MacOS/love src` (mock backend). Before handing a build over, run it once with the device's exact args, `love src --layout nintendo`.
- Screenshot: `love src --screenshot 1` writes `~/Library/Application Support/LOVE/metaretro/screenshot.png`.
- Port: `scripts/build-port.sh` builds `dist/ports/` (`Retro Town Story.sh` and `metaretro/`) and `dist/metaretro.zip` (the same, for PortMaster's installer). The user copies `dist/ports/` to the device and pastes back `log.txt`.
- Port art: `scripts/port-art.sh` redraws `port/screenshot.png` (gameplay in town; the billboards show box art the script draws for the mock games, since the port's images must not show real games' art), `port/cover.png` (box art, with no building signs) and `port/logo.png` (the name on transparency), from the game's own drawing (`scripts/port-art/driver.lua`, run on a copy of `src/` with its own save). Rerun it after visual changes to the town or the logo.
- Launch titles: `scripts/generate-launch-titles.py [page.html] [roms dir]` regenerates `src/core/launchtitles.lua`. Never edit that file by hand.
- Console sprites: `love scripts/draw-consoles src` redraws `src/assets/metaretro/Consoles.png` and `src/world/consolelooks.lua` from the drawings in the script. Never edit those two files by hand. A preview with names goes to the script's LÖVE save folder.

## Code map (src/)
- `main.lua`: the `app` table (state, backend, catalog, stores, town), startup, and the LÖVE callbacks.
  - **Startup:** the title screen shows while `services/library` reads the gamelists and the save on a thread. It sends one system per message, and the main thread takes one per frame.
  - **Preparing ahead:** once the library is read, `prepare` sets up the title's first option (Continue, or New Game without a save) without saving anything. It runs as a coroutine, a step per frame, so the title keeps responding.
  - **Choosing:** `start` goes straight to town if that choice is ready; otherwise it shows "Loading your library..." until it is.
  - **Entering town** (`enterTown`) saves and starts the RetroAchievements sync. Continue starts the player at home; coming back from a game puts them where they were.
  - **After a game:** the launcher leaves `resume.txt` in the save folder: JSON with the game's id and where the player was (`Town:location`: their town tile and, inside a building, its door and their spot there). The next start removes it, skips the title and puts the player back there (`Town:restore`; a spot that no longer works falls back to the door). Games launch through `app:launch`, which records the location. This replaced a `--resume` argument from the launcher, which didn't work on the device for reasons we never pinned down. `$LOVE_RUN` does pass arguments: the log shows `started with: --layout nintendo`. The title, preparing ahead and coming back from a game all work on the device (2026-11-07).
- `core/`: pure logic, all unit-tested.
  - `economy`: prices, earnings, purchases and starter packs.
  - `progression`: the console timeline and generations, the gift's choices (oldest), the museum's best sellers (`mostPopular`, by `sold` in `core/consoles.lua`).
  - `arcade`: the Arcade Club's systems, its weekly cabinets (`arcade.week`, Monday to Sunday), its prices, and buying a cabinet's game (`arcade.buy`; a cabinet whose game is owned takes the week's next one).
  - `stores`: the store list, daily offers and billboard `featured` picks.
  - `catalog`: owned and locked games.
  - `genres`: 12 categories.
  - `townsfolk`: the villager cast, daily roster, wandering rule and recommendations; the houses' `RESIDENTS` (with their hints) and `GRANDMA`.
  - `achievements`: RetroAchievements pay rules, and finding game ids from ROM hashes (`hashIds`, `resolveIds`, `consolesToRefresh`).
  - `daily`: a deterministic random generator keyed by date.
  - `save`: defaults and migration.
  - `input`: key repeat, `stopRepeats`, Nintendo layout.
  - `scenes`: the scene stack; `drawBelow` overlays and `onChange`.
- `backends/`: `knulli` reads gamelist.xml and lists files with `find`; `mock` is for the desktop (with an arcade system, `fbneo`, for the Arcade Club); `gamelist` is the parser.
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
  - `town`: parsing, walkability and plots. The town has fixed buildings only: home, dealer, museum, mall, arcade club, Granny Rose's house (`G`) and four residents' houses (`V`). Stores live in the mall. The layout is a north street with the town's buildings, a paved plaza with a pond, and a residential street to the south, where Home sits with Granny Rose's house on its left.
  - `mall`: the mall's inside, laid out for the open stores, all in view at once: no doors, and no separate screen per store. A tiled corridor (the wood parquet's 3x3 pattern breaks up in narrow rows) has the first half of the stores along its top side and the rest along its bottom side, after the way out. Each store is a small room, 4 tiles wide, on a 1x1 tiled shop floor (`:`, since the parquet's pattern breaks up in rooms this small), open to the corridor through a 2-tile opening with front wall either side (so both of its ends look the same): its name on a plaque on its back wall, one block of shelves against it, and its clerk (`C`) beside them, behind the counter, which the player reaches from the opening. Bottom stores are the top ones mirrored, a row deeper (shelves stand on the floor, since they can't reach into a bottom wall); that row, behind their opening, has the corridor's floor, so they look as deep as the top ones. Stores are two tiles of wall apart (a right wall next to a left wall); the posters hang on those walls, on the corridor's side, a little narrower than them, between the top stores, each showing the box art of a game on sale in the store to its left. Which store is where changes every day (`mall.order`), so the posters change too. With up to 5 stores, the mall fits on one screen; it gets longer as stores open.
  - `storemap`: the console dealer's inside: shelves, and the clerk (`C`) behind the counter.
  - `interior`, `homemap`, `housemap` and `museummap`: buildings' insides, as a rooms layer and a furniture layer. The furniture layer also marks spots (`P` the professor, `S` where the player starts at home, `R` a house's resident, `C` a clerk; `map.allSpots` lists repeated ones). Wall tiles are drawn a quarter at a time, each quarter from the piece that closes the room next to it (`interior.wallPiece`), so walls between rooms and their junctions need no special cases. Whole corner pieces stay whole. A wall two tiles thick is two walls side by side, each closing its own room.
  - `art`: all town and Home drawing from the Ninja Adventure sheets, plus our own TV, console and sofa in `assets/metaretro/` (the pack has none).
- `scenes/`:
  - `walker`: the base for scenes the player walks around (town and interiors): steps, door fades, camera, toasts, the quit prompt. The camera centres maps that fit between the wallet bar and the hint bar between them, so nothing hides behind either; taller maps scroll above the hint bar. Walking out of a building, the player keeps going while the d-pad is held.
  - `interior`: the base for buildings' insides (walking, furniture, people, the door out). `home`, `museum`, `mall`, `store` and `house` extend it through hooks (`interact`, `hintFor`, `live`, `absent`, `drawOnTop`).
  - title (Continue / New Game / Quit), intro (Professor Cork, boy or girl), town, museum, arcade (the Arcade Club), mall (the stores along a corridor; A on a clerk or the counter in front of them opens that store's menu), store (the dealer's inside, the same way), advert (a billboard's or poster's ad up close, on A), house (a resident or Granny Rose), tv (the reel), shop (the store, dealer, Granny Rose and Arcade Club menus), collection (the console's games, or with `Collection.arcade` the home cabinet's), gamedetail, dialog, confirm, loading.
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
  - Starter wallet: 100.
  - Cheat: Select pressed 10 times in quick succession (each within 0.5s) pays 1000 coins (`core/selectbutton`).
  - New Game: the intro (pick boy or girl), then waking up at home with no console. Professor Cork, in the museum next to Home, offers one of the 3 oldest consoles in the library (`progression.giftChoices`). Picking it from his table gives it free with its starter pack (`economy.giftConsole`).
  - The console dealer is closed, with a door over its doorway, until the gift, and the mall until the player owns a console (`Town:isClosed`). Until then, every villager sends the player to Professor Cork in the museum (`townsfolk.NO_CONSOLE`).
  - Saves from before the intro skip it, and the gift counts as received (`save.migrate`).
  - Starter packs: 3 games from curated launch titles, then the launch window, then the rest. Japanese-only games come last: they're only used when there aren't enough others, as with the PC Engine. Buying a console grants its own pack.
- **Stores:**
  - Genre stores need ≥30 games of that genre across owned consoles (`stores.MIN_GENRE_GAMES`).
  - Daily offer: 5 random games per store.
- **Houses:** every house can be entered. Each of the four residents (`townsfolk.RESIDENTS`, by house in reading order) gives hints about how Metaretro works, one after another. They never wander in town.
- **Granny Rose:** lives left of Home and buys any owned game for half its price, rounded down (`economy.sellPrice`, `Shop.grandma`). A sold game goes back to the stores. She left the wandering cast; Sultan Amir took her place.
- **Villagers:** 20 in the cast, 4 for each of 5 kinds; one villager per kind each day. Each starts on a random grass tile (not above a tree), at least 8 tiles from the others and 3 from the player's start (`townsfolk.MIN_SPACING`, `START_CLEARANCE`); wander radius 2, grass only.

## What's left out of the library
- **Non-console systems:** Metaretro's library only uses the consoles in `core/consoles.lua`. Computers and engines (dos, amiga, devilutionx, cannonball, xash3d…) appear nowhere. Arcade systems (fbneo, mame, arcade, naomi, cps…, see `arcade.SYSTEMS`) appear only in the Arcade Club's cabinets, never in stores, Home, starter packs or counts.
- **Ports:** Knulli's `ports` folder is ignored; Metaretro itself lives there.
- **Gamelist entries:** entries marked `<hidden>`, and entries whose ROM file is missing (gamelists keep stale ones), are skipped by `backends/knulli.lua`.
- **No genre setting yet:** no genres are hidden by choice. Small genres only lack a genre store (see the rules above; Music, in the user's library); their games still sell in console stores.

## Look and feel decisions
- **Title screen:** the town (`Town.paint`) pans slowly across behind a darkened band with the logo ("Retro Town", 3x, over a "Story" ribbon; `Title.drawLogo`, also used for the port's art) and the tagline; the player and a few townsfolk stroll along the main street; the menu sits over the plaza.
- **Art:** pixel art is 16px drawn at 2x (`art.TILE` = 32).
- **Font:** Ark Pixel 10px at 20px; it's only crisp at multiples of 10. Every text size is 20px, including the town signs. The user rejected Pixelify (ambiguous 5), Jersey 10 (illegible) and Ark 12px (too big).
- **Menus:**
  - Panels have a thin orange frame and a dark brown fill (`ui.colors.panelFill`) with cream text.
  - The wallet sits in the same spot in town and in menus (`ui.walletPanel`).
- **Covers:** stores and Home show box art (`thumbnail`); details pages show the composite `image`. Billboards show box art, take the box's shape, and aren't drawn at all without an ad. A on a billboard or a mall poster shows its box art filling the screen (`scenes/advert.lua`).
- **Console dealer:** no mention of console generations anywhere the player sees. Each console shows its year and its number of titles; "Even more consoles yet to come!" sits under the list while the library has consoles not yet for sale (`progression.moreToCome`).
- **Hints:** a hint too wide for the screen has its last label cut short with "..." (`ui.hintPanel`).
- **Counters:** the shop counter sprite is a slice of a longer counter, so its right end is its left end mirrored (`closeRight` in `world/art.lua`).
- **Walking:** holding B makes the player run, 1.8 times as fast (`scenes/walker.lua`).
- **Doors:** you enter by walking up into them; A doesn't enter. In the town map, a door goes where its building's sprite draws the doorway: one tile from the left for most buildings, two for the museum. Each building's left edge comes from its `B` tiles. A talks to villagers and reads the signpost. You leave Home by walking down onto its front door.
- **Home:** an open-plan kitchen and living room, a small bedroom, and an office below the bedroom, both entered from the living room. The TV and a two-seat sofa (`loveseat`, the sofa sprite without its middle) stand in the living room's leftmost column, with the console under the TV's right half and room to walk around it. The office has a two-tile desk (`wideDesk`: the desk sprite with its papers cleared off and nothing between its feet, `EmptyDesk` in `world/art.lua`, widened) and a chair in its top-left corner. Chairs and stools can be walked over (`interior.isWalkable`). The player starts at home (a new game, or Continue) in the middle of the living room (spot `S`). The console opens the collection (A); it only appears once the player owns a console. The player's arcade cabinet stands against the office's right wall. It appears with the first game bought at the Arcade Club, lists the arcade games owned (A), plays them for free, and shows the art of the last arcade game played or bought (`state.cabinetGame`, set by `arcade.buy` and `app:launch`). Arcade games never count as owning a console (`progression.syncOwnedConsoles`). The TV (A) plays a nonstop reel of scraped videos of the games on sale in town today (`stores.onSale`), shuffled; videos that won't play drop out of the reel. Walls are `TilesetWallSimple` pieces. The wall between two rooms, side by side or one above the other, is one tile thick, made from the quarters of the pieces on either side (see `WALLS` in `world/art.lua`).
- **Museum:** the big wooden hall in town, deeper than it's wide, and so is its inside: a gallery with pillars and statues at the back, three glass cases along each wall with the library's best-selling consoles (A: the year and roughly how many were sold), and Professor Cork in the middle of the gallery, in front of his gift table, which stands between the front cases, so the player meets him first. Every console in `core/consoles.lua` has a sprite after the real hardware (drawn by `scripts/draw-consoles`, which also draws the glass case and the cabinets). The controller sits one empty row below the console, joined by a one-pixel black cable. Wireless controllers have no cable, and handhelds have no controller. Unknown systems use the generic sprite. The console under the TV at home is the one the player last played an owned game on (`townsfolk.lastPlayedGame`). Before any play, it's the gift, then the oldest owned console. The intro's text is original; we don't copy Pokémon's script or names.
- **Arcade Club:** a rectangular room with four big cabinets (2x3 tiles) against its left and right walls. They're seen from the side, and the game's cover art fills each cabinet's whole shape (`art.cabinet`: the art is cut to `CabinetMask.png`, `CabinetTrims.png` goes on top, and the result is kept per cover). Right-wall cabinets mirror their shape, never the art. The games are this week's (`arcade.cabinets`), the same for everyone that week. A on a cabinet shows it up close, filling the screen (`scenes/attract.lua`): the cabinet in its color, the game's marquee art (or its name), and a 4:3 screen. The screen shows the screenshot until the video loads, then loops the video in the same spot. There, A plays the game for 1 coin, launching it like the collection does; play pays coins as usual, through `sessions.log`. A clerk (the RobotGreen sprite) behind a counter at the back explains the coin and the weekly games, and sells any cabinet's game for 100 coins (`Shop.arcade`). That cabinet then shows the week's next game, until the next Monday.
- **Preloading:** the town loads the mall's posters, the home cabinet's art and the arcade's art (side art, screenshots, marquees) along with its billboards (`Mall.adPaths`, `Arcade.artPaths`), so they show as soon as the player walks in.
- **Buildings:** a building can widen its sprite by repeating columns (`columns` in `HOUSES`); the mall is 6 wide.
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
- **Name:** the game is Retro Town Story (the town is Retro Town). Its files, save identity (`metaretro`) and port folder keep the old name, so saves carry over. The launcher (`port/Retro Town Story.sh`) registers the port with EmulationStation itself, posting `gameinfo.xml` to ES's local web API (`POST http://127.0.0.1:1234/addgames/ports`, the same metadata PortMaster merges on install), once per version of the file. It never deletes anything: the user removes the old `Metaretro.sh` entry from the device themselves. Not yet checked on the device.
- **Startup:** parsing a ~9,600-game library takes ~4.5s, now on a thread behind the title screen. The user chose not to add a library cache. Setting up the save afterwards runs on the main thread; it's about 10% of the parse time on the desktop with the JIT off.
- **Secrets:** device logs contain the RetroAchievements token. Never echo it back.
- **FPS:** steady 60. Holding Select for 2 seconds toggles the FPS counter.
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
