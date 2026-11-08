# Retro Town Story

Your game library becomes a little town. Play the games you own to earn coins, then spend them in the
town's stores to unlock more of your collection.

- Earn 2 coins per minute of play, and coins for RetroAchievements.
- Get your first console from Professor Cork at the museum and buy more at the Console Dealer.
- Each console you own opens a game store in the mall, with new picks every day.
- Play and buy Arcade games at the Arcade Club, with new cabinets every week.
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
