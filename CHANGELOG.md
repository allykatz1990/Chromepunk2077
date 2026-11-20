# Changelog

Notes for players and for anyone who maintains this mod later. Each entry says what changed, why,
and where in the code to look.

## Unreleased (0.0.9 internal beta)

### Confirmed in game: Berserk duration bonus works
- 0.0.8 test (author, Nov 19): with the Zetatech Berserk titled (+3 s), every run from full charge took
  12 s (6 runs, 18:57–19:01). The log predicted 7.2 s -> 10.2 s from the drain alone: pool max is about
  16.4 points (not 100, so the "about 44 s" in the 0.0.8 notes was wrong) at 2.272 per second. The
  missing ~1.8 s is most likely the game's wait before the drain starts. So vanilla is about 9 s and the
  title makes it about 12 s.
- Runs of 2–3 s right after one ended were started on a nearly empty charge (the game allows that).
  Not a Chromepunk bug.

### Added: measured run times (debug log)
- **Why:** to confirm the above with numbers instead of guesses.
- **What:** every Sandevistan/Berserk ending logs `Berserk ran N s, started at P% charge`
  (`OnActivated`/`OnDeactivated`, fields `m_actStart`, `m_actStartCharge`). Report adds the Berserk pool
  max, `BerserkChargesDecayStartDelay` and `BerserkChargesDecayRateMult`.

### Fixed: Debug log setting pointed to the wrong file
- **Why:** the settings screenshot showed the description naming `r6/logs/redscript_rCURRENT.log`; the mod
  logs to Cyber Engine Tweaks' `gamelog.log` (see README, "Debug log location").
- **What:** description text only (`OSEvoConfig.debugLog`).

## 0.0.8 internal beta

### Confirmed in game: the cooldown stats
- 0.0.7 test (Report): `TimeDilationSandevistanRechargeDuration` 19.5 s and `BerserkCooldownBase` 16.25 s are
  the real cooldowns (`SandevistanRechargeDuration`, `BerserkRechargeDuration` stay 0). The Zetatech Berserk
  cut logged `cooldown cut by 6s (4 melee kills), recharge 16.2s from BerserkCooldownBase`.
- The CSV now names these stats directly. `CooldownStat` / `ResolveStat` stay as a safety net.

### Fixed: Berserk duration perks did nothing, Berserk extensions far too big
- **Why:** the same Report showed `Berserk duration 3.0` with the Zetatech Berserk titled: exactly the
  titles' +3 s. `BerserkDurationBase` only held Chromepunk's own seconds; it is not the Berserk's duration.
  A running Berserk drains its charge at `BerserkChargesDecayRate` (2.272 per second, about 44 s for a full
  charge — see 0.0.9: really ~7 s). So "+N s" Berserk perks and the Berserk level bonus did nothing, and Berserk kill/landing
  extensions were divided by those few seconds instead of ~44 s (way too strong).
- **What:** Berserk "+seconds" (titles and levels) now slow the drain: the rate is multiplied by
  D / (D + extra), D = pool max / base rate (`ApplyBerserkSeconds`). Berserk extensions add
  seconds x drain rate of charge (`ExtendSeconds`). Report shows "Berserk full charge lasts N s".

## 0.0.7 internal beta

### Fixed: Sandevistan and Berserk cooldown perks did nothing
- **Why:** final testing (author, Nov 19). The debug log showed `cooldown cut skipped …: recharge stat
  reads 0`, and `Report()` showed `SandevistanRechargeDuration` and `BerserkRechargeDuration` at 0 with
  the OS equipped. So every cooldown perk (-15 % to -35 %) and the Zetatech Berserk cooldown cut were
  applied to stats the game doesn't use. (The Sandevistan duration stat is right: Report read 25.5–28.5 s,
  116.5 s with Sandevistan Customization's 100 s, and kill extensions logged "max duration 28.5s".)
- **What:** the game scripts never read these stats (the cooldown is computed natively), so instead of a
  third guess the mod now checks the candidates at run time and uses the first one with a value:
  Sandevistan `TimeDilationSandevistanRechargeDuration` → `SandevistanRechargeDuration` →
  `TimeDilationSandevistanCooldownBase`; Berserk `BerserkRechargeDuration` → `BerserkCooldownBase`
  (`OSEvoSystem.CooldownStat`, `ResolveStat`, `CooldownSeconds`). `Report()` prints every candidate and
  which one is in use; the debug log names the stat each cooldown perk was applied to.
- **To do after the next test:** write the confirmed stat names into the CSV.

## 0.0.6 internal beta

### Added: 17 of the 28 "later build" perks now work
- **Why:** next step toward 0.5 (shared/TODO.md). The 0.0.5 game log also showed two problems, fixed below.
- **What:**
  - New effect kind "event" for reactive perks (`OSEvoEffect.Event`, `OSEvoSystem` section "events"):
    kill extensions (Dynalar, Militech Berserk with its +5s cap, Zetatech Sandevistan mid-air kills),
    kill charge (Apogee, Falcon), headshot-kill stamina and charge (Apogee), early-deactivation refund
    (Warp Dancer), mid-air activation bonus (Zetatech Sandevistan), heal per kill when it ends
    (BioDyne, Militech Berserk), cooldown cut per melee kill (Zetatech Berserk), Superhero Landing
    extension (Moore Tech), RAM per spread hop (Biotech; Canto for Blackwall only).
    How: a running Sandevistan/Berserk drains its charge pool over its max duration, so extending by N
    seconds adds N / duration of a full pool (`ExtendSeconds`); a cooldown cut adds N / recharge time
    while it refills (`CooldownSeconds`). Pool changes use absolute points like the game's heal code.
  - Netdriver: "+25% upload speed through cameras" (upload condition 8, the game's own
    `PlayerStateMachine.IsControllingDevice` test).
  - Biotech: "-1 RAM for a Combat hack queued after a Control hack" (RAM condition 9, via
    `ScriptedPuppet.GetCurrentlyUploadingAction`).
  - Zetatech Sandevistan: "air dashes cost no stamina while active" via the game's
    `IsDodgeStaminaFree` flag, only while active and airborne.
  - CSV effects language extended (`up.camera`, `ram.afterctrl`, `ev.*`), documented in `tools/gen_osevo.py`.
- **Still later (11):** Arasaka/Netdriver/Rippler extra spreading and Raven's "spreadable" perks need
  quickhack record changes (TweakXL); Dynalar reload speed, Falcon stamina cost and Moore Tech landing
  radius need stats whose scale isn't visible in the game scripts; Moore Tech forced stagger and
  Zetatech Berserk air control need hooks not found yet.

### Spread targets: every target counts (kept as designed)
- **Why:** the game log showed one Synapse Burnout cast finishing 3-4 times in the same second. That is
  the author's multi-spread Synapse Burnout from Quickhacks Boost doing its job, not a bug: each target
  reached counts as a use and toward titles, as before. (An earlier 0.0.6 draft counted a spreading
  cast once; reverted on the author's call.)
- **What:** the same quickhack finishing again within 0.6 s is recognised as a spread hop only to
  trigger the per-spread RAM refunds (`OnUploadFinished`, `OnSpreadHop`). Counting is unchanged from 0.0.5.

### Fixed: bonuses rebuilt every few seconds
- **Why:** the game log showed "bonuses rebuilt" every few seconds with nothing changed: every jump
  and every Overclock rebuilt all stat modifiers.
- **What:** being airborne, in Overclock, or running a Sandevistan/Berserk only triggers a rebuild if an
  earned perk depends on it (`RefreshBonuses`, `NeedsCond`, `NeedsActive`).

### Found: where the debug log goes
- Codeware's `ModLog` writes to Cyber Engine Tweaks' `gamelog.log`, not `r6/logs`. Docs updated.

## 0.0.5 internal beta (Nov 2026)

### Changed: the title system is hidden again
- **Why:** 0.0.4 tested OK in game (decks, Sandevistans, Berserks, card, leveling). The author asked
  for the titles to be hidden again, like Weaponpunk's, and shown only once earned.
- **What:**
  - Tooltips list only EARNED titles with their perks. The next locked title, its goal and its
    progress are gone; the "netrunner titles" (any Tier 5++ deck) block only appears once one is
    earned. No stage numbers anywhere players can see them.
    (`OSEvoTooltip.StageLines`, `OSEvoTooltip.Lines`, `OSEvoText.TitleHeader`)
  - The OS card no longer shows the next title and its progress (`OSEvoCard.StageText` returns "").
    When a title is earned the card's highlighted line reads `TITLE EARNED: "…"`
    (`OSEvoText.TitleEarnedNotice`), and the on-screen message reads `<model> earned a title: "…"`.
  - Mod Settings: the "Tier 5++ stages" category is now "Secrets", "Hidden goal size (percent)",
    worded so the menu doesn't spoil anything. The field is still `goalScale`, so saved settings carry over.
  - README only hints at the hidden system. The full list moved to `SPOILERS.md`, which
    `tools/gen_osevo.py` now writes from the CSV.
  - Removed the unused `OSEvoText.StageHeader` and `OSEvoText.Progress`.
- Unchanged: the console `Report()` still shows every goal and its progress, for testers.

## 0.0.4 internal beta (Nov 2026)

### Fixed: Sandevistan and Berserk tooltips empty; "Cyberdeck" line blank
- **Why:** 0.0.3 tested in game: deck tooltips work. Sandevistans/Berserks still showed nothing, and
  on decks the "Cyberdeck" type line went blank.
- **What:**
  - The Cyberware screen draws Sandevistans and Berserks with the OLDER item tooltip
    (`ItemTooltipCommonController` / `ItemTooltipHeaderController`, itemTooltipController.swift).
    Hooks added for both: the level line under the type line, the stage details at the end of the
    description. The new-tooltip hooks stay for the inventory.
  - The type line holds a translation key; appending to the raw key broke the lookup. The key is
    now translated first (`OSEvoTooltip.AddLevelLine`).
  - The level line is two lines now, as requested: level and uses, then the bonus under it
    (`OSEvoText.LevelLine`).

## 0.0.3 internal beta (Nov 2026)

### Fixed: tooltips still empty on the Cyberware screen
- **Why:** 0.0.2 tested in game: card and leveling work, tooltips still showed nothing. 0.0.2 wrote
  into the deck tooltip's description box, which vanilla decks never use, so it isn't shown in that
  layout.
- **What:** only paths the game itself draws for operating systems are used now
  (`OSEvoTooltip.reds`, see the history note at its top):
  - the level line is appended to the item-type line ("Cyberdeck" / "Sandevistan"), the same way
    Weaponpunk shows its weapon level line;
  - deck stages are added as extra entries of the deck's own ability list (`CyberdeckTooltip.GetAbilities`),
    one bullet per stage with its perks and progress;
  - Sandevistan/Berserk stages go into the item tooltip's description (always present for them).
- **Debug log is on by default** in the beta builds, so each test leaves a trail in
  `r6/logs/redscript_rCURRENT.log`. Turn the default back off for 0.5.

## 0.0.2 internal beta (Nov 2026)

### Fixed: nothing visible in game
- **Why:** first test of 0.0.1 (it compiled and loaded cleanly) showed no card, no message and
  nothing in the tooltips. Three causes: 0.0.1 had no card at all, its messages only fire at a
  level-up (25 uses) or stage unlock, and its tooltip lines went into the weapon stat list, which
  the Cyberware screen doesn't use for operating systems.
- **What:**
  - New OS card (`OSEvoCard.reds`, adapted from Weaponpunk's `WLvlCard.reds`): on every
    Sandevistan/Berserk activation and finished upload. Right edge by default (Weaponpunk's card
    is middle left). New "OS card" settings: on/off, side, height, seconds.
  - Tooltip lines now go into the description text: `CyberdeckTooltip.UpdateLayout` /
    `NEW_UpdateLayout` for decks, `NewItemTooltipDescriptionModule.Update` / `NEW_Update` for
    Sandevistans and Berserks (`OSEvoTooltip.reds`). The stat-list hooks were removed.
  - BETA ONLY: a "Chromepunk 2077: OS Evolution 0.0.2 loaded" message once per session, so a tester
    can tell "not running" from "not counted yet" (`OSEvoSystem.Start`). Remove before 0.5.
- **Requirement added:** Codeware (for the card).

### Compatibility checked
- **Quickhacks Boost** (Nexus 10169): CET only, edits TweakDB records at startup (QuickHack.*,
  Attacks.*, BaseStatusEffect.*, the player's RAM regen pool, breach buffer). No script hooks,
  no player modifiers, so it stacks with this mod. Its record names confirmed the quickhack
  families this mod matches on (MemoryWipe, CommsNoise, Contagion, Overheat, Overload, Ping,
  CommsCallIn, BlackWall).
- **Sandevistan Customization – Tier 5+ / Tier 5++ All in One** (Nexus 9547): same pattern (CET,
  edits the Sandevistan item records only). Stacks.
- Quickhack name matching is now case-insensitive (`OSEvoEffect.MatchesName`): the game spells it
  both "BlackWall" and "Blackwall".

## 0.0.1 internal beta (Nov 2026)

First build. Everything below is new.

### Base leveling (every operating system)
- **What:** every cyberdeck, Sandevistan and Berserk, any tier, modded ones included, levels by use.
  Decks: one use per finished quickhack upload. Sandevistans/Berserks: one use per activation.
  Per level: +1 Max RAM (decks) or +0.25s duration. First level 25 uses, +15% per level, cap 20.
- **Why:** the author asked for a Weaponpunk-style base system next to the Tier 5++ stages.
- **Code:** `OSEvoSystem.reds`, section "base leveling". Levels are saved per model (first record
  seen + display name, like Weaponpunk). Bonuses are player stat modifiers, rebuilt in
  `RefreshBonuses`. Settings in `OSEvoConfig.reds`, category "Leveling".

### Tier 5++ stages
- **What:** 16 models × 3 stages + 3 universal deck stages (51 rows), from the design sheet.
- **Decisions taken while turning the sheet into code (agreed with the author):**
  - Perks are cumulative. Where the sheet's Stage 3 number read as a total, the stage numbers were
    split so the total matches (example: Militech Berserk duration +1 / +1 / +2 = +4s).
  - Stages unlock in order; progress toward later stages is banked from the start
    (`CheckStages` in `OSEvoSystem.reds`).
  - Arasaka Mk.5 Stage 1 discounted Reboot Optics (a Control hack) instead of Sonic Shock; fixed
    to Memory Wipe & Sonic Shock, Stage 2 adds another -1 to both.
  - Moore Tech Berserk does not need Fortified Ankles: the game allows Superhero Landings
    whenever Berserk is active (`locomotionTransitions.swift`, BerserkPlayerBuff check).
- **Live vs later:** 110 of 138 perk lines work in this build. The 28 marked `later` (refunds,
  kill-based duration extensions, extra spreading rules, landing radius, stamina perks) need
  their own hooks and show as "coming in a later build" in the tooltip.
- **Code:** data in `data/cyberware_5plusplus_titles.csv` → `tools/gen_osevo.py` →
  `OSEvoData.reds`. Hooks in `OSEvoHooks.reds`:
  - upload counting: `QuickHackUploadListener.SendUploadFinishedEvent`
  - upload speed: `BaseScriptableAction.GetActivationTime`
  - RAM cost: `BaseScriptableAction.GetCost`
  - hits, kills, damage perks: `DamageSystem.ProcessLocalizedDamage`
  - start: `PlayerPuppet.OnGameAttached`

### Not yet verified in game (see TESTING.md)
- Which player stats the 2.x Sandevistan/Berserk read for duration and cooldown
  (`TimeDilationSandevistanDuration`, `SandevistanRechargeDuration`, `BerserkDurationBase`,
  `BerserkRechargeDuration`). If one doesn't move in the `Report()` output, the CSV's `effects`
  column is where to switch it.
- Whether cyberware tooltips use the same tooltip controllers as weapons.
- Whether the quickhack action names contain the fragments used for per-hack perks
  (`MemoryWipe`, `CommsNoise`, `Contagion`, `Overheat`, `Overload`, `Ping`, `CommsCallIn`, `BlackWall`).
  Turn on Debug log: every finished upload logs its action name.
