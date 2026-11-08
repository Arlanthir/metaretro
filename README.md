# Retro Town Story

Retro Town Story is a (meta)game for retro handhelds like the Anbernic RG 40XXV, to help players progressively unlock their game collection and choose what to play from it. It runs on EmulationStation (Knulli, Batocera), with other backends to follow.

The original idea came from PakUI's BitPal, which has the same aim. The twist here is a top-down RPG (like Pokémon) where the player walks around a town whose shops sell retro games.

The games come from the player's own collection and its scraped metadata, so stores show real covers and details. Coins to buy more games are earned by playing the games already owned (play time) and by unlocking RetroAchievements.

## In the game

- **Home:** the console under the TV opens your collection, by console, and plays your games. The TV shows videos of the games on sale in town today. Your own arcade cabinet appears in the office once you buy an arcade game.
- **Museum:** Professor Cork gives you your first console. Glass cases show the best-selling consoles in your library.
- **Console Dealer:** buy more consoles, each with a starter pack of three games.
- **Mall:** a store per console you own, plus stores per game genre, all in a large mall. New picks every day; posters and billboards show what's on sale.
- **Arcade Club:** four cabinets with new arcade games every week, a coin a play. The clerk sells them for your cabinet at home.
- **Townsfolk:** villagers wander town each day, each with a different kind of tip on what to play next. Residents in their houses explain how things work, and Granny Rose buys games you're done with for half their price.
- Coming back from a game puts you right where you left off.

## Development

Built with [LÖVE](https://love2d.org) 11.5 and distributed as a PortMaster port.

- Run on desktop: `love src` (uses the mock backend; force one with `love src --backend mock`).
- Controls on keyboard: arrows, `Z`/`Enter` = A, `X`/`Esc` = B (hold to run), `A`/`S` = X/Y, `Q`/`W` = L/R, `Space` = Start, `Tab` = Select (hold for the FPS counter).
- Tests: `luarocks install busted`, then `busted` from the repo root.
- Screenshot: `love src --screenshot 2` saves `screenshot.png` to the LÖVE save folder after 2 seconds and quits.
- Port: `scripts/build-port.sh` builds `dist/ports/` (copy it to `/userdata/roms/ports/`) and `dist/retrotownstory.zip` (for PortMaster's installer). On its first run, the port adds its name, screenshot, box art and logo to EmulationStation. `scripts/port-art.sh` redraws that art in `port/`.

### Art

Town and menu art comes from the [Ninja Adventure asset pack](https://pixel-boy.itch.io/ninja-adventure-asset-pack) by Pixel-boy and AAA (CC0). The font is [Ark Pixel](https://github.com/TakWolf/ark-pixel-font) 10px (SIL Open Font License, see `src/assets/fonts/`), which also covers Japanese titles. Only the images in use are in `src/assets/ninja-adventure/`; the full pack can be unzipped into `example-data/ninja-adventure/` (ignored by git) to pick more. The TV, consoles, cabinets and sofa are the game's own, drawn in the pack's palette (`src/assets/retrotownstory/`).

### RetroAchievements

To earn coins from achievements, create `retroachievements.txt` next to `retrotownstory.love` with your web API key from <https://retroachievements.org/settings>:

```
apikey=YOUR_WEB_API_KEY
username=YourName
```

- On the device: `/userdata/roms/ports/retrotownstory/retroachievements.txt` (`roms/ports/retrotownstory/` on the SD card). `scripts/build-port.sh` doesn't copy it, so copy it yourself; updating the port's files leaves it in place.
- On desktop: `retroachievements.txt` at the repo root, since `love src` looks in the folder above `src/`. It's in `.gitignore`.
- `username` is optional on Knulli, where it's read from the RetroAchievements login in `batocera.conf`. On desktop (mock backend) it's required.

After you play an owned game, the next launch checks its achievements online (games that can't be checked stay queued). New unlocks pay 5 coins per point (twice in hardcore); unlocks from before tracking started pay half, once.

## Wishlist

- Integrate with [Games of the Month](https://retrohandhelds.gg/games-of-the-month/), its GotX and RetroBits (Saturday Nights), to have strong recommendations for popular games that the player may have in their collection.
- Release date flashbacks (this game came out on this day X years ago!)
- Have some trivia about games.
- Have different types of store, like a more expensive "system sellers" store or a "deep cuts" / underrated game store for cheaper.
