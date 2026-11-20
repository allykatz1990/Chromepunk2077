// Chromepunk 2077: OS Evolution - settings
// Copyright (C) 2026 the Chromepunk 2077 authors. Written with AI assistance.
//
// This program is free software: you can redistribute it and/or modify it under the terms of the
// GNU General Public License as published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version. It is distributed WITHOUT ANY WARRANTY. See the
// GNU General Public License for details: https://www.gnu.org/licenses/
//
// Settings appear in Mod Settings (and the Mod Configuration Menu) when that mod is installed.
// Without it the defaults below apply. Every number here is a starting value to be tuned in testing.
// Text is plain English for v0.0.1; it moves to translation keys (like Weaponpunk's) before 0.5.

public class OSEvoConfig {
  // ---------------------------------------------------------------- general
  @runtimeProperty("ModSettings.mod", "Chromepunk 2077: OS Evolution")
  @runtimeProperty("ModSettings.category", "General")
  @runtimeProperty("ModSettings.displayName", "Enabled")
  @runtimeProperty("ModSettings.description", "Turns the whole mod on or off. Off: nothing is counted and every bonus is removed until you turn it back on. Progress is kept.")
  public let enabled: Bool = true;

  @runtimeProperty("ModSettings.mod", "Chromepunk 2077: OS Evolution")
  @runtimeProperty("ModSettings.category", "General")
  @runtimeProperty("ModSettings.displayName", "On-screen messages")
  @runtimeProperty("ModSettings.description", "Show a message when an operating system levels up or reaches a new stage.")
  public let notifications: Bool = true;

  @runtimeProperty("ModSettings.mod", "Chromepunk 2077: OS Evolution")
  @runtimeProperty("ModSettings.category", "General")
  @runtimeProperty("ModSettings.displayName", "Details in tooltips")
  @runtimeProperty("ModSettings.description", "List the level, its bonus and any earned title's perks in the operating system's tooltip. Off: only the level line and the title after the name.")
  public let tooltipDetails: Bool = true;

  // ---------------------------------------------------------------- OS card (added in 0.0.2)
  // The card shows when a Sandevistan/Berserk is activated and after each finished quickhack upload.
  // It defaults to the RIGHT edge so it never covers Weaponpunk's weapon card (middle left).
  @runtimeProperty("ModSettings.mod", "Chromepunk 2077: OS Evolution")
  @runtimeProperty("ModSettings.category", "OS card")
  @runtimeProperty("ModSettings.displayName", "Show the OS card")
  @runtimeProperty("ModSettings.description", "Show a card with the operating system's level, uses and next stage when you activate a Sandevistan or Berserk, or finish a quickhack upload.")
  public let showCard: Bool = true;

  @runtimeProperty("ModSettings.mod", "Chromepunk 2077: OS Evolution")
  @runtimeProperty("ModSettings.category", "OS card")
  @runtimeProperty("ModSettings.displayName", "Card side")
  @runtimeProperty("ModSettings.description", "1 = left edge, 2 = right edge. Right keeps it clear of Weaponpunk's weapon card.")
  @runtimeProperty("ModSettings.step", "1")
  @runtimeProperty("ModSettings.min", "1")
  @runtimeProperty("ModSettings.max", "2")
  public let cardSide: Int32 = 2;

  @runtimeProperty("ModSettings.mod", "Chromepunk 2077: OS Evolution")
  @runtimeProperty("ModSettings.category", "OS card")
  @runtimeProperty("ModSettings.displayName", "Card height")
  @runtimeProperty("ModSettings.description", "Where the card sits on screen: 0 = bottom, 100 = top.")
  @runtimeProperty("ModSettings.step", "1")
  @runtimeProperty("ModSettings.min", "0")
  @runtimeProperty("ModSettings.max", "100")
  public let cardHeight: Int32 = 50;

  @runtimeProperty("ModSettings.mod", "Chromepunk 2077: OS Evolution")
  @runtimeProperty("ModSettings.category", "OS card")
  @runtimeProperty("ModSettings.displayName", "Card seconds")
  @runtimeProperty("ModSettings.description", "How long the card stays on screen.")
  @runtimeProperty("ModSettings.step", "0.5")
  @runtimeProperty("ModSettings.min", "1.0")
  @runtimeProperty("ModSettings.max", "10.0")
  public let cardSeconds: Float = 4.0;

  // ---------------------------------------------------------------- base leveling (every OS, every tier)
  @runtimeProperty("ModSettings.mod", "Chromepunk 2077: OS Evolution")
  @runtimeProperty("ModSettings.category", "Leveling (every operating system)")
  @runtimeProperty("ModSettings.displayName", "Leveling on")
  @runtimeProperty("ModSettings.description", "Every cyberdeck, Sandevistan and Berserk levels up as you use it. Decks count finished quickhack uploads; Sandevistans and Berserks count activations.")
  public let leveling: Bool = true;

  @runtimeProperty("ModSettings.mod", "Chromepunk 2077: OS Evolution")
  @runtimeProperty("ModSettings.category", "Leveling (every operating system)")
  @runtimeProperty("ModSettings.displayName", "Uses for level 1")
  @runtimeProperty("ModSettings.description", "How many uses the first level takes.")
  @runtimeProperty("ModSettings.step", "5")
  @runtimeProperty("ModSettings.min", "5")
  @runtimeProperty("ModSettings.max", "200")
  public let firstLevelUses: Int32 = 25;

  @runtimeProperty("ModSettings.mod", "Chromepunk 2077: OS Evolution")
  @runtimeProperty("ModSettings.category", "Leveling (every operating system)")
  @runtimeProperty("ModSettings.displayName", "Extra uses per level (percent)")
  @runtimeProperty("ModSettings.description", "Each level takes this much more than the one before. 15 means +15% per level.")
  @runtimeProperty("ModSettings.step", "1")
  @runtimeProperty("ModSettings.min", "0")
  @runtimeProperty("ModSettings.max", "50")
  public let levelGrowth: Int32 = 15;

  @runtimeProperty("ModSettings.mod", "Chromepunk 2077: OS Evolution")
  @runtimeProperty("ModSettings.category", "Leveling (every operating system)")
  @runtimeProperty("ModSettings.displayName", "Level cap")
  @runtimeProperty("ModSettings.description", "Highest level an operating system can reach. 0 = no cap (the bonus keeps growing with every level).")
  @runtimeProperty("ModSettings.step", "1")
  @runtimeProperty("ModSettings.min", "0")
  @runtimeProperty("ModSettings.max", "100")
  public let levelCap: Int32 = 20;

  @runtimeProperty("ModSettings.mod", "Chromepunk 2077: OS Evolution")
  @runtimeProperty("ModSettings.category", "Leveling (every operating system)")
  @runtimeProperty("ModSettings.displayName", "Cyberdeck: Max RAM per level")
  @runtimeProperty("ModSettings.description", "Max RAM a cyberdeck gains for each level.")
  @runtimeProperty("ModSettings.step", "1")
  @runtimeProperty("ModSettings.min", "0")
  @runtimeProperty("ModSettings.max", "5")
  public let ramPerLevel: Int32 = 1;

  @runtimeProperty("ModSettings.mod", "Chromepunk 2077: OS Evolution")
  @runtimeProperty("ModSettings.category", "Leveling (every operating system)")
  @runtimeProperty("ModSettings.displayName", "Sandevistan / Berserk: seconds per level")
  @runtimeProperty("ModSettings.description", "Extra duration a Sandevistan or Berserk gains for each level, in seconds.")
  @runtimeProperty("ModSettings.step", "0.05")
  @runtimeProperty("ModSettings.min", "0.0")
  @runtimeProperty("ModSettings.max", "1.0")
  public let secondsPerLevel: Float = 0.25;

  // ---------------------------------------------------------------- hidden titles (Tier 5++)
  // 0.0.5: worded so the menu doesn't spoil the hidden title system (same approach as Weaponpunk's
  // generic labels). The field name stays goalScale so saved settings keep working.
  @runtimeProperty("ModSettings.mod", "Chromepunk 2077: OS Evolution")
  @runtimeProperty("ModSettings.category", "Secrets")
  @runtimeProperty("ModSettings.displayName", "Hidden goal size (percent)")
  @runtimeProperty("ModSettings.description", "Scales how much it takes to discover the mod's hidden rewards. 100 = as designed, 50 = half, 200 = double.")
  @runtimeProperty("ModSettings.step", "5")
  @runtimeProperty("ModSettings.min", "25")
  @runtimeProperty("ModSettings.max", "400")
  public let goalScale: Int32 = 100;

  // ---------------------------------------------------------------- debug
  @runtimeProperty("ModSettings.mod", "Chromepunk 2077: OS Evolution")
  @runtimeProperty("ModSettings.category", "Debug")
  @runtimeProperty("ModSettings.displayName", "Debug log")
  // 0.0.9: the text pointed testers at the redscript log, but ModLog writes to Cyber Engine Tweaks'
  // game log (seen in the author's settings screenshot, Nov 19). Text only, no behaviour change.
  @runtimeProperty("ModSettings.description", "Write what the mod counts and applies to the game log (bin/x64/plugins/cyber_engine_tweaks/gamelog.log, search ChromepunkOSEvo). For testers.")
  // 0.5: off by default for the public release (it was on from 0.0.3 so every beta test left a trail).
  // Players reporting a bug turn it on in Mod Settings and send gamelog.log.
  public let debugLog: Bool = false;
}

// Mod Settings is optional: one of these two versions is picked at compile time.
@if(ModuleExists("ModSettingsModule"))
public func OSEvoRegisterSettings(config: ref<OSEvoConfig>) -> Void {
  ModSettings.RegisterListenerToClass(config);
}

@if(!ModuleExists("ModSettingsModule"))
public func OSEvoRegisterSettings(config: ref<OSEvoConfig>) -> Void {}
