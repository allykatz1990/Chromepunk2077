# Chromepunk 2077: OS Evolution v0.5 (initial release)

Your operating system learns from how you fight. Cyberdecks, Sandevistans and Berserks level up as you use them, and the best chrome may turn into something more. A companion to Weaponpunk 2077.

## What's in it
- **Every operating system levels up**, every tier, modded ones included. Levels are per model.
  - Cyberdecks count finished quickhack uploads (every target a spreading quickhack reaches counts).
  - Sandevistans and Berserks count activations.
  - Each level gives +1 Max RAM (decks) or +0.25 s duration (Sandevistans, Berserks). 25 uses for level 1, 15% more per level, cap 20. All configurable.
- **A hidden system** for the sixteen Tier 5++ operating systems. Play and find out. `SPOILERS.md` has everything.
- **OS card** on activation or upload (level, uses, level-ups), right edge by default, clear of Weaponpunk's weapon card.
- **Tooltip line** on the Cyberware screen and in the inventory: level, uses and bonus.
- **Mod Settings / Mod Configuration Menu** for everything.

## Requirements
- Cyberpunk 2077 2.x with Phantom Liberty
- redscript
- Codeware
- Mod Settings (optional, to change settings)

## Compatibility
- Weaponpunk 2077: made to run alongside it.
- Sandevistan Customization – Time Dilation (Tier 5+ and 5++ All in One): compatible, bonuses stack on its values.
- Quickhacks Boost: compatible, both apply.
- CyberwareEx: supported; every equipped operating system counts and levels.

## Install / remove
- Install: copy `r6` into the game folder (`Cyberpunk 2077\r6\scripts\ChromepunkOSEvo\`), or install with Vortex.
- Remove: delete `r6\scripts\ChromepunkOSEvo\`. Saves still load.

## Known limits
- A handful of hidden perks are marked "coming in a later build" in the tooltip and do nothing yet.
- English only for now.
- Bug reports: turn on "Debug log" in Mod Settings, reproduce, and attach `bin\x64\plugins\cyber_engine_tweaks\gamelog.log`.

Back up your saves. Open source, GPL-3.0: https://github.com/allykatz1990/Chromepunk2077
