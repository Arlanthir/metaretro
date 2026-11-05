# Metaretro

This is a (meta)game intended to run in retro handhelds like the Anbernic RG 40XXV, to help the user progressively unlock their collection of games and help them choose what to play from their collection. At least Emulationstation must be supported, with additional backends to follow.

The original idea came from PakUI's BitPal that has the same aim.

The innovation is to have a top-down RPG (like Pokemon) where the main character explores shops that sell retro games.

The available games are populated by the user's game collection and their scraped metadata. When the user is browsing a store catalog, he can see the game covers and relevant information.

Money to buy more games is unlocked by playing the games you already have (time) and unlocking retroachievements in games that support them.

The player can check his collection, organized by console, and play his games.
## Development

Built with [LÖVE](https://love2d.org) 11.x and distributed as a PortMaster port.

- Run on desktop: `love src` (uses the mock backend; force one with `love src --backend mock`).
- Controls on keyboard: arrows, `Z`/`Enter` = A, `X`/`Esc` = B, `Q`/`W` = L/R, `Tab` = toggle FPS.
- Tests: `luarocks install busted`, then `busted` from the repo root.
- Screenshot: `love src --screenshot 2` saves `screenshot.png` to the LÖVE save folder after 2 seconds and quits.

### Art

Town art comes from the [Ninja Adventure asset pack](https://pixel-boy.itch.io/ninja-adventure-asset-pack) by Pixel-boy and AAA (CC0). Only the images in use are in `src/assets/ninja-adventure/`; the full pack can be unzipped into `example-data/ninja-adventure/` (ignored by git) to pick more.

### RetroAchievements

To earn coins from achievements, create `retroachievements.txt` next to `metaretro.love` with your web API key from <https://retroachievements.org/settings>:

```
apikey=YOUR_WEB_API_KEY
username=YourName
```

- On the device: `/userdata/roms/ports/metaretro/retroachievements.txt` (`roms/ports/metaretro/` on the SD card). `scripts/build-port.sh` doesn't copy it, so copy it yourself; updating the port's files leaves it in place.
- On desktop: `retroachievements.txt` at the repo root, since `love src` looks in the folder above `src/`. It's in `.gitignore`.
- `username` is optional on Knulli, where it's read from the RetroAchievements login in `batocera.conf`. On desktop (mock backend) it's required.

After you play an owned game, the next launch checks its achievements online (games that can't be checked stay queued). New unlocks pay 5 coins per point (twice in hardcore); unlocks from before tracking started pay half, once.

# Metaretro

This is a (meta)game intended to run in retro handhelds like the Anbernic RG 40XXV, to help the user progressively unlock their collection of games and help them choose what to play from their collection. At least Emulationstation must be supported, with additional backends to follow.

The original idea came from PakUI's BitPal that has the same aim.

The innovation is to have a top-down RPG (like Pokemon) where the main character explores shops that sell retro games.

The available games are populated by the user's game collection and their scraped metadata. When the user is browsing a store catalog, he can see the game covers and relevant information.

Money to buy more games is unlocked by playing the games you already have (time) and unlocking retroachievements in games that support them.

The player can check his collection, organized by console, and play his games.

## Wishlist 

- Integrate with [Games of the Month](https://retrohandhelds.gg/games-of-the-month/), its GotX and RetroBits (Saturday Nights), to have strong recommendations for popular games that the player may have in their collection.
- Recommend games from the favorites EmulationStation collection the user may already have.
- Check and display the rating for the games.
- Sell games for half their buying price.
- Integrate with Time To Beat.
- Release date flashbacks (this game came out on this day X years ago!)
- Have some trivia about games.
- Have different types of store, like a more expensive "system sellers" store or a "deep cuts" / underrated game store for cheaper.
- Have stores for different game genres (like shooters, fighting games, etc)