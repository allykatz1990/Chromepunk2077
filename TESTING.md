# v0.0.6 test checklist

0.0.6 shows a "Chromepunk 2077: OS Evolution 0.0.6 loaded" message shortly after a save loads. If you
don't see it, the mod isn't running: check section 1 and send me the log.

Back up your save first. Turn on **Mod Settings → Chromepunk 2077: OS Evolution → Debug → Debug log**.
The debug log is Cyber Engine Tweaks' `Cyberpunk 2077\bin\x64\plugins\cyber_engine_tweaks\gamelog.log`
(search for `ChromepunkOSEvo`). `r6\logs\redscript_rCURRENT.log` only shows whether the scripts compiled.

Console checks (Cyber Engine Tweaks console):

```lua
Game.GetScriptableSystemsContainer():Get("OSEvoSystem"):Report()                       -- levels, stages, stat values
Game.GetScriptableSystemsContainer():Get("OSEvoSystem"):CheatUses(100)                 -- +100 uses to everything equipped
Game.GetScriptableSystemsContainer():Get("OSEvoSystem"):CheatMetric("uploads", 50)     -- push a stage goal
Game.GetScriptableSystemsContainer():Get("OSEvoSystem"):ResetAll()                     -- wipe all progress
```

Stage goal names for `CheatMetric`: uploads, uploads_global, kills_active, streak, headshot_kills_active,
airborne_kills_active, melee_kills_active, close_kills_active, landing_hits, blunt_or_slam_kills_active,
dilated_seconds, activations.

## 00000. Berserk run times (0.0.9, ~3 minutes)
Fast-recovery cheat off. Zetatech Berserk equipped.
1. Wait until the Berserk is fully charged, activate, let it run out. Do this twice.
2. Run `evo:Report()` (setup as in section 00: `evo = Game.GetScriptableSystemsContainer():Get("OSEvoSystem")`).
3. Optional control: set "Enabled" off in Mod Settings, repeat step 1 once (vanilla time).
The log should show `Berserk ran ~12s, started at 100% charge` (about 9 s with the mod off).

## 0000. Berserk duration check (0.0.8, ~3 minutes)
Same setup. Fast-recovery cheat OFF.
1. Equip the titled Zetatech Berserk (or any titled Berserk), run `evo:Report()`: the line shows
   `Berserk full charge lasts N s`. The game log shows `Berserk duration +3.00s: A s -> B s` (A = before, B = after).
2. Activate from full charge and time it: it should last about B seconds.
3. `evo:ResetAll()`, reload the item's tooltip, activate from full again: it lasts about A seconds (the stock time).
4. Militech Berserk (all titles): kills log `extended by 1.00s (kill), Berserk drain …/s, full charge … s`;
   each kill visibly adds a small amount of charge, not a big jump.

## 000. Cooldown stat check (0.0.7, ~3 minutes)
Same setup (`evo = …`). Keep any fast-recovery cheat OFF.
1. Equip a titled Sandevistan (your Dynalar) **and** a titled Berserk (your Zetatech Berserk), then run `evo:Report()`.
   The report now has a `cooldown candidates:` line and an `in use:` line. Tell me if `in use` names stats
   whose number on the candidates line is above 0.
2. Zetatech Berserk: 3 melee kills, let it end → log `cooldown cut by 4.50s (3 melee kills), recharge N s from <stat>`
   (no "skipped"), and the Berserk is ready sooner than without the title.
3. Check the item tooltip's "Cooldown" against a run with `evo:ResetAll()` if you want: with titles the
   wait after it ends is shorter.

## FINAL. Release-candidate pass (everything, before 0.5)

Do these in order on a **backed-up** save. Setup is the same as section 00 (`evo = Game.GetScriptableSystemsContainer():Get("OSEvoSystem")`).
Tick each box; for anything that fails, note the step number. When done, tell me and I'll pull both logs.

### A. Install and load
- [ ] A1. Remove the old Chromepunk in Vortex, install the 0.0.6 zip fresh, launch. No redscript error popup.
- [ ] A2. Load a save: `Chromepunk 2077: OS Evolution 0.0.6 loaded` appears once.
- [ ] A3. Mod Settings → Chromepunk: categories General, OS card, Leveling (every operating system), Secrets, Debug. Nothing says "stage".

### B. Base leveling (every OS, any tier)
- [ ] B1. Deck: finish 5 uploads on one enemy each → card shows uses going 1, 2, 3, 4, 5.
- [ ] B2. `evo:CheatUses(25)` → "reached level 1" message; deck tooltip shows `OS level 1 - … uses` and `+1 Max RAM` on the next line;
      `evo:Report()` Max RAM is 1 higher than before.
- [ ] B3. Sandevistan: activate 3 times → uses +3 on the card. `evo:CheatUses(25)` → Report's "Sandevistan duration" is 0.25 higher.
- [ ] B4. Same for a Berserk ("Berserk duration").
- [ ] B5. Upgrade an OS one tier at a ripperdoc → same level, same uses.
- [ ] B6. Save, quit to menu, reload → levels, uses and bonuses all still there (`evo:Report()` same as before).

### C. Hidden titles
- [ ] C1. A Tier 5++ OS with no title: tooltip and card show only the level lines.
- [ ] C2. Arasaka Mk.5: `evo:CheatMetric("uploads", 50)` → `Arasaka Mk.5 earned a title: "Ghost in the Subnet"`, card line `TITLE EARNED: …`,
      title after the name, tooltip lists it and its perks only.
- [ ] C3. Same deck: Memory Wipe and Sonic Shock cost 1 RAM less in the quickhack menu.
- [ ] C4. `evo:CheatMetric("uploads_global", 100)` → netrunner titles block appears on the deck tooltip.
- [ ] C5. Save and reload → titles and their perks still there.

### D. The two numbers still missing from the logs (from section 00)
- [ ] D1. Dynalar (unlock lines in section 00), activate, kill → log `extended by 0.75s (kill), max duration N s`. N = ______
- [ ] D2. Zetatech Berserk (unlock lines in section 00), 3 melee kills, let it end → `cooldown cut by 4.50s …, recharge N s`. N = ______
      (If either line says "skipped … reads 0", that's the one I need to fix.)

### E. Spot checks of the perk types (one each is enough; section 00 has the full list)
- [ ] E1. Stat perk while active: Falcon all titles → `evo:Report()` crit chance higher while active, back to normal after.
- [ ] E2. Upload speed: Paraline all titles → a hack's upload time in the menu is shorter than with no titles.
- [ ] E3. Queue: Rippler all titles → you can queue 2 more hacks on one enemy.
- [ ] E4. Damage perk: Militech Berserk all titles → melee hits do visibly more while active.
- [ ] E5. Event perk: Warp Dancer early refund (section 00, test 4).
- [ ] E6. Spread: your multi-spread Synapse Burnout counts once per target; Suicide counts once.

### F. Compatibility
- [ ] F1. Weaponpunk: weapon card (middle left) and OS card (right) both show and don't overlap; Weaponpunk titles still work.
- [ ] F2. Sandevistan Customization: set a Sandevistan's Max Duration in its menu; Report's duration = that value + Chromepunk's bonus.
- [ ] F3. Quickhacks Boost: a hack's RAM cost = Quickhacks Boost's cost minus Chromepunk's discount (Arasaka title on, Memory Wipe).
- [ ] F4. CyberwareEx: two operating systems equipped → both level up, Report lists both.

### G. Settings and safety
- [ ] G1. Enabled off → `evo:Report()` shows 0 stat modifiers, no card; back on → everything returns.
- [ ] G2. Show the OS card off → no card; Card side 1 → card on the left.
- [ ] G3. Hidden goal size 50 → a fresh model's first title needs half (e.g. 25 uploads for a deck).
- [ ] G4. Level cap 5 with `evo:CheatUses(1000)` → stops at level 5, tooltip says (max).
- [ ] G5. Play 10 minutes of normal combat: no stutter; the game log has no flood of `bonuses rebuilt` lines.
- [ ] G6. Uninstall test (optional, on a copy of the save): remove the mod, load → the save loads fine.

### What to send me
D1 and D2 numbers, the step numbers of anything that failed, and "done". I'll read both logs myself.

## 00. New in 0.0.6 — exact steps

### Setup (once per game session)
1. Back up your save. Load it. You should see `Chromepunk 2077: OS Evolution 0.0.6 loaded`.
2. Open the Cyber Engine Tweaks console and type this line (it keeps a shortcut called `evo` for the session):
   ```lua
   evo = Game.GetScriptableSystemsContainer():Get("OSEvoSystem")
   ```
3. Spawn the items you're testing with the codes below (`Game.AddToInventory("<code>", 1)`) and **equip them on
   the Cyberware screen** before running their unlock lines. Unlock lines only count for what's equipped.
4. After each test, run `evo:Report()`. To read the debug lines: open
   `Cyberpunk 2077\bin\x64\plugins\cyber_engine_tweaks\gamelog.log` and search for `ChromepunkOSEvo`
   (or just tell me and I'll pull it).
5. To start over at any point: `evo:ResetAll()`.

### Unlock all three titles of a model (paste while it's equipped)
| Model | Spawn code | Unlock lines |
|---|---|---|
| Dynalar Sandevistan | `Items.AdvancedSandevistanC2MK4PlusPlus` | `evo:CheatMetric("kills_active", 250)` `evo:CheatMetric("streak", 8)` |
| Militech "Apogee" | `Items.AdvancedSandevistanApogeePlusPlus` | `evo:CheatMetric("headshot_kills_active", 40)` `evo:CheatMetric("streak", 12)` `evo:CheatMetric("kills_active", 300)` |
| Militech "Falcon" | `Items.AdvancedSandevistanC4MK5PlusPlus` | `evo:CheatMetric("dilated_seconds", 300)` `evo:CheatMetric("streak", 15)` `evo:CheatMetric("kills_active", 300)` |
| QianT "Warp Dancer" | `Items.AdvancedSandevistanC3MK5PlusPlus` | `evo:CheatMetric("activations", 200)` `evo:CheatMetric("close_kills_active", 100)` |
| Zetatech Sandevistan | `Items.AdvancedSandevistanC1MK4PlusPlus` | `evo:CheatMetric("airborne_kills_active", 75)` `evo:CheatMetric("kills_active", 200)` |
| BioDyne Berserk | `Items.AdvancedBerserkC2MK4PlusPlus` | `evo:CheatMetric("melee_kills_active", 250)` `evo:CheatMetric("streak", 10)` |
| Militech Berserk | `Items.AdvancedBerserkC4MK5PlusPlus` | `evo:CheatMetric("kills_active", 300)` `evo:CheatMetric("streak", 15)` |
| Moore Tech Berserk | `Items.AdvancedBerserkC1MK4PlusPlus` | `evo:CheatMetric("landing_hits", 30)` `evo:CheatMetric("blunt_or_slam_kills_active", 120)` `evo:CheatMetric("kills_active", 250)` |
| Zetatech Berserk | `Items.AdvancedBerserkC3MK5PlusPlus` | `evo:CheatMetric("activations", 175)` `evo:CheatMetric("streak", 10)` |
| Biotech Σ Mk.4 | `Items.AdvancedBiotechSigmaMKIVLegendaryPlusPlus` | `evo:CheatMetric("uploads", 350)` |
| Militech Canto Mk.6 | `Items.HauntedCyberdeck_LegendaryPlusPlus` | `evo:CheatMetric("uploads", 350)` |
| NetWatch Netdriver Mk.1 | `Items.AdvancedNetwatchNetdriverMKLegendaryPlusPlus` | `evo:CheatMetric("uploads", 350)` |

Each line ends with the title messages ("… earned a title"). Then `evo:Report()` should show `stage 3` for that
model and `event perks:` above 0 when the perk is an event perk.

### The tests (each: do this → expect this log line → expect this in game)
Kills only count while the Sandevistan/Berserk is **running**, on hostile NPCs (not civilians).

1. **Dynalar — kill extension.** Activate, kill an enemy.
   Log: `extended by 0.75s (kill), max duration N s` → **send me N** (it tells me the duration stat is right).
   Game: the charge bar jumps up a little per kill.
2. **Apogee — kill charge + headshots.** Activate, kill with a body shot, then with a headshot.
   Log: `kill charge +10%` on every kill; on the headshot also `headshot kill: stamina +15%` and `headshot kill: charge +10%`.
3. **Falcon — kill charge.** Activate, kill. Log: `kill charge +15%`.
4. **Warp Dancer — early refund.** Activate, turn it off with about half the charge left.
   Log: `early deactivation: refunded X% charge` (X ≈ a quarter of what was left). Game: the bar jumps up after it ends.
   Then let one run to empty: no refund line.
5. **Zetatech Sandevistan — mid-air.** Jump and activate in the air.
   Log: `extended by 1.50s (mid-air activation), …`. Kill something while you're in the air:
   `extended by 1.00s (mid-air kill), …`. Air-dash while active: stamina doesn't drop. Ground dodge: it still does.
6. **BioDyne Berserk — heal on end.** Lose some health, activate, kill 3, let it run out.
   Log: `ended after 3 kills: healed 30%`. Game: health goes up when it ends.
7. **Militech Berserk — capped extension + heal.** Activate, kill 7+ enemies in one run.
   Log: `extended by 1.00s (kill), …` for the first 5 kills only (cap +5 s), then when it ends
   `ended after N kills: healed …%` (25% per kill, never above 100%).
8. **Moore Tech Berserk — landing extension.** Activate, Superhero Landing onto a group (jump, then hold crouch in the air).
   Log: one `extended by 1.50s (Superhero Landing hit), …` per enemy hit.
9. **Zetatech Berserk — cooldown cut.** Activate, 3 melee kills, let it end.
   Log: `cooldown cut by 4.50s (3 melee kills), recharge N s` → **send me N**. Game: it's ready sooner.
10. **Biotech — RAM per spread.** Upload Contagion (or your multi-spread Synapse Burnout) on a group.
    Log: `upload finished: …` for the first target, then `spread hop: …, refunded 2 RAM` per extra target.
    Game: RAM goes up by 2 per extra target. Every target still counts as a use (watch the card's number).
11. **Canto — RAM per Blackwall jump.** Use Blackwall Gateway on a group.
    Log: `spread hop: …BlackWall…, refunded 4 RAM` per jump. Another spreading hack: `spread hop: …` with **no** refund.
12. **Netdriver — camera upload.** Open the quickhack menu on an enemy normally and note a hack's upload time;
    then take control of a camera that sees them and compare: about 25% faster through the camera.
13. **Biotech — Combat after Control.** Start a Control hack (e.g. Cripple Movement) on an enemy; while it's
    uploading, open the menu again: Combat hacks (Short Circuit, Overheat…) cost 1 RAM less on them.
14. **Suicide control test.** Unmodified Suicide on one enemy: exactly one `upload finished: …` line, no `spread hop`.
15. **No rebuild spam.** With only base levels (no titles), jump around for 30 s: no new `bonuses rebuilt` lines.

### What to send me
The numbers from tests 1 and 9, anything that didn't match, and I'll pull the game log myself.

## 0. Hidden titles (new in 0.0.5)
- [ ] A Tier 5++ OS with no title: its tooltip and the card show only the level lines, nothing about titles.
- [ ] `CheatMetric("uploads", 50)` with Arasaka Mk.5: message `Arasaka Mk.5 earned a title: "Ghost in the Subnet"`,
      card line `TITLE EARNED: "Ghost in the Subnet"`, title after the name, and the tooltip lists that title and
      its perks, nothing about the next one.
- [ ] Netrunner titles block appears on deck tooltips only after `CheatMetric("uploads_global", 100)`.
- [ ] Mod Settings shows a "Secrets" category with "Hidden goal size"; no "stage" wording anywhere.

## 1. It loads
- [ ] Game starts with no redscript error popup. If there is one, send me the whole message.
- [ ] Mod Settings shows "Chromepunk 2077: OS Evolution" with its categories (General, OS card, Leveling, Tier 5++ stages, Debug).
- [ ] The "… 0.0.6 loaded" message appears after loading a save.
- [ ] Finish one quickhack upload: the OS card appears on the right with the deck's level and uses.
- [ ] Activate the Sandevistan: the card shows the Sandevistan.
- [ ] Cyberware screen, deck tooltip: under "Cyberdeck" there is an "OS level …" line; on a Tier 5++ deck the
      bullet list ends with Stage entries (header, perks, progress).
- [ ] Cyberware screen, Sandevistan tooltip: "OS level …" under "Sandevistan"; Tier 5++ stages at the end of
      its description text.

## 2. Base leveling
- [ ] Any cyberdeck: upload 5 quickhacks, run `Report()`. Uses went up by 5.
- [ ] `CheatUses(100)`: on-screen "reached level …" message; `Report()` Max RAM is higher by the level number.
- [ ] Sandevistan (any tier): activate 3 times. Uses +3. After `CheatUses(100)`, Report's
      "Sandevistan duration" is higher by 0.25 × level. **If it doesn't move, tell me: wrong stat.**
- [ ] Same for a Berserk ("Berserk duration").
- [ ] Upgrade a deck at a ripperdoc: the level is kept.
- [ ] Save, reload: levels and bonuses are still there.

## 3. Tier 5++ stages
- [ ] Equip a Tier 5++ deck, `CheatMetric("uploads", 50)`: "reached Stage 1" message; the title shows after the
      name in the inventory tooltip; the tooltip lists the stage and its perks.
- [ ] Arasaka Mk.5 Stage 1: Memory Wipe and Sonic Shock cost 1 RAM less in the quickhack menu.
      With debug log on, finished uploads log their action name; send me a few lines.
- [ ] Rippler Mk.5 Stage 2: Ultimate quickhacks cost 3 less.
- [ ] Paraline/NetWatch/Raven Stage 3: upload times in the quickhack menu are shorter.
- [ ] Militech Canto Mk.6: Blackwall Gateway cost and upload time drop at Stage 1.
- [ ] Banking: on a fresh Dynalar, `CheatMetric("streak", 8)` alone does nothing; then
      `CheatMetric("kills_active", 50)` unlocks Stage 1 **and** Stage 2 right after.
- [ ] Sandevistan Stage perks: `Report()` crit chance rises while the Sandevistan runs and drops after.
- [ ] Kills while active count: with Debug log, each kill logs "kill counted" with [head]/[air]/[melee] tags.
- [ ] Moore Tech Berserk: Superhero Landing on enemies counts toward Stage 1 (one per enemy per landing).
- [ ] Falcon: time spent in slow motion counts (in seconds) toward Stage 1.
- [ ] Tooltip: does the OS tooltip show the extra lines at all? (Cyberware may use a different tooltip.)

## 4. Compatibility
- [ ] Weaponpunk installed too: weapon cards, titles and damage still work.
- [ ] Sandevistan Customization (Tier 5++): set Falcon "Max Duration" to 10 in its menu. `Report()` shows
      10 + Chromepunk's bonus, not 10 alone and not Chromepunk's bonus alone.
- [ ] Quickhacks Boost: change a quickhack's RAM cost in its menu, then check the quickhack menu with a
      Chromepunk RAM perk unlocked (`CheatMetric("uploads", 50)` on Arasaka Mk.5): Memory Wipe costs
      Quickhacks Boost's value minus 1.
- [ ] CyberwareEx with two operating systems equipped: both level up; `Report()` lists both.

## 5. Turning it off
- [ ] Mod Settings → Enabled off: `Report()` shows 0 stat modifiers; turning it back on restores them.
