# Retro Town Story

Your game library becomes a little town. Play the games you own to earn coins, then spend them in the
town's stores to unlock more of your collection.

- Start with only one console, three games and a few coins.
- Play your games to earn more coins. Unlock their RetroAchievements to earn a coin bonus.
- Spend coins on new consoles and games.
- Play and buy Arcade games at the Arcade Club, with new cabinets every week.
- Sell games you don't wish to play anymore.
- Watch trailers for new games on TV, or ask the townsfolk to suggest what to play next.

## Setup

Ready to run on EmulationStation (Knulli, Batocera): it reads your scraped library.

For coins from RetroAchievements, create `retroachievements.txt` in `ports/retrotownstory/`:

```
apikey=YOUR_WEB_API_KEY
username=YourName
```

Grab your key from the [retroachievements website](https://retroachievements.org/settings?tab=applications).

## Controls

| Button | Action |
| --- | --- |
| D-pad | Walk, move in menus |
| A | Talk, read, choose |
| B | Back; hold to run |
| L / R | Switch consoles in your collection |
| Start | Quit |

## Credits

Inspiration from PakUI's BitPal.
Art from the [Ninja Adventure asset pack](https://pixel-boy.itch.io/ninja-adventure-asset-pack) by Pixel-boy and AAA (CC0).
Font: [Ark Pixel](https://github.com/TakWolf/ark-pixel-font) (SIL Open Font License).
Runs on LÖVE 11.5.
