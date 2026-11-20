// Chromepunk 2077: OS Evolution - data classes for the model and stage table
// Copyright (C) 2026 the Chromepunk 2077 authors. Written with AI assistance.
//
// This program is free software: you can redistribute it and/or modify it under the terms of the
// GNU General Public License as published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version. It is distributed WITHOUT ANY WARRANTY. See the
// GNU General Public License for details: https://www.gnu.org/licenses/
//
// The table itself lives in OSEvoData.reds, which is GENERATED from
// data/cyberware_5plusplus_titles.csv by tools/gen_osevo.py. This file only defines the shapes.
//
// Codes (saved in players' saves, never renumber):
//   OS type:  1 Cyberdeck, 2 Sandevistan, 3 Berserk
//   Model:    1-7 decks, 11-15 Sandevistans, 21-24 Berserks, 100 = "any Tier 5++ deck" (universal)
//   Metric:   1 uploads, 2 uploads on any Tier 5++ deck, 3 kills while active, 4 best kill streak in
//             one activation, 5 headshot kills while active, 6 mid-air kills while active,
//             7 melee kills while active, 8 melee or close (<5m) kills while active,
//             9 enemies hit by Superhero Landings, 10 blunt or landing kills while active,
//             11 tenths of a second spent in Sandevistan time dilation, 12 activations in combat

// One effect of one stage. Which fields matter depends on `kind`.
public class OSEvoEffect {
  // 1 player stat, 2 upload speed, 3 RAM cost, 4 damage, 5 event (added 0.0.6)
  public let kind: Int32;
  // stats: 1 while equipped, 2 while active, 3 while active and airborne, 4 while Overclock runs
  // upload: 0 all, 1 category, 2 action name, 3 not in combat, 4 Overclock, 5 queued, 6 queue full,
  //         8 uploading through a camera or other controlled device (0.0.6)
  // RAM: 0 all, 1 category, 2 action name, 5 queued (percent), 7 device or vehicle hack,
  //      9 Combat hack on a target already receiving a Control hack (0.0.6)
  // damage: 1 airborne and active, 2 melee while active, 3 Superhero Landing
  // event (0.0.6, see OSEvoSystem "events"): 1 kill extends by seconds (value2 = cap per activation,
  //   0 = none), 2 kill adds percent of a full charge, 3 headshot kill restores stamina percent,
  //   4 headshot kill adds charge percent, 5 early deactivation refunds percent of the charge left,
  //   6 activated mid-air adds seconds, 7 heal percent per kill when the activation ends,
  //   8 melee kill shortens the next cooldown by seconds, 9 Superhero Landing hit extends by seconds,
  //   10 each spread hop refunds RAM (tokens: only for these quickhacks), 11 mid-air kill extends by seconds
  public let cond: Int32;
  public let stat: gamedataStatType;
  public let modType: gameStatModifierType;
  public let category: gamedataHackCategory;
  // action-name fragments, for example ["MemoryWipe", "CommsNoise"]
  public let tokens: array<String>;
  public let value: Float;
  public let value2: Float;   // events only: a cap (event 1)

  public static func Stat(cond: Int32, stat: gamedataStatType, modType: gameStatModifierType, value: Float) -> ref<OSEvoEffect> {
    let e = new OSEvoEffect();
    e.kind = 1;
    e.cond = cond;
    e.stat = stat;
    e.modType = modType;
    e.value = value;
    return e;
  }

  public static func Upload(cond: Int32, category: gamedataHackCategory, tokens: String, percent: Float) -> ref<OSEvoEffect> {
    let e = new OSEvoEffect();
    e.kind = 2;
    e.cond = cond;
    e.category = category;
    if StrLen(tokens) > 0 {
      e.tokens = StrSplit(tokens, "/");
    }
    e.value = percent;
    return e;
  }

  public static func Ram(cond: Int32, category: gamedataHackCategory, tokens: String, amount: Float) -> ref<OSEvoEffect> {
    let e = new OSEvoEffect();
    e.kind = 3;
    e.cond = cond;
    e.category = category;
    if StrLen(tokens) > 0 {
      e.tokens = StrSplit(tokens, "/");
    }
    e.value = amount;
    return e;
  }

  // 0.0.6: reactive perks (kill extensions, refunds, heals...). Handled in OSEvoSystem, section "events".
  public static func Event(cond: Int32, value: Float, value2: Float, tokens: String) -> ref<OSEvoEffect> {
    let e = new OSEvoEffect();
    e.kind = 5;
    e.cond = cond;
    e.value = value;
    e.value2 = value2;
    if StrLen(tokens) > 0 {
      e.tokens = StrSplit(tokens, "/");
    }
    return e;
  }

  public static func Damage(cond: Int32, percent: Float) -> ref<OSEvoEffect> {
    let e = new OSEvoEffect();
    e.kind = 4;
    e.cond = cond;
    e.value = percent;
    return e;
  }

  // True when the quickhack's action name contains one of this effect's fragments.
  // The game itself identifies Blackwall Gateway this way (baseDeviceActions: StrEndsWith(actionName, "BlackWall")).
  // Case-insensitive since 0.0.2: the game spells it both "BlackWall" and "Blackwall" (seen in
  // Quickhacks Boost's list of quickhack records), and a case slip would silently switch a perk off.
  public func MatchesName(actionName: String) -> Bool {
    let lowered = StrLower(actionName);
    let i = 0;
    while i < ArraySize(this.tokens) {
      if StrContains(lowered, StrLower(this.tokens[i])) {
        return true;
      }
      i += 1;
    }
    return false;
  }
}

public class OSEvoStage {
  public let model: Int32;
  public let stage: Int32;          // 1-3
  public let title: String;
  public let metric: Int32;
  public let threshold: Int32;      // as written in the CSV (seconds for metric 11)
  public let metricLabel: String;
  public let clauses: array<String>;
  public let live: array<Bool>;     // false = "coming in a later build"
  public let effects: array<ref<OSEvoEffect>>;

  public func Clause(text: String, isLive: Bool) -> Void {
    ArrayPush(this.clauses, text);
    ArrayPush(this.live, isLive);
  }

  public func Fx(e: ref<OSEvoEffect>) -> Void {
    ArrayPush(this.effects, e);
  }
}

public class OSEvoModel {
  public let code: Int32;
  public let name: String;
  public let osType: Int32;
  public let record: TweakDBID;     // the Tier 5++ record (TDBID.None() for the universal entry)
}

public class OSEvoDB {
  public let models: array<ref<OSEvoModel>>;
  public let stages: array<ref<OSEvoStage>>;

  public static func Create() -> ref<OSEvoDB> {
    let db = new OSEvoDB();
    OSEvoData.Build(db);
    return db;
  }

  public func AddModel(code: Int32, name: String, osType: Int32, record: TweakDBID) -> Void {
    let m = new OSEvoModel();
    m.code = code;
    m.name = name;
    m.osType = osType;
    m.record = record;
    ArrayPush(this.models, m);
  }

  public func AddStage(model: Int32, stage: Int32, title: String, metric: Int32, threshold: Int32, metricLabel: String) -> ref<OSEvoStage> {
    let s = new OSEvoStage();
    s.model = model;
    s.stage = stage;
    s.title = title;
    s.metric = metric;
    s.threshold = threshold;
    s.metricLabel = metricLabel;
    ArrayPush(this.stages, s);
    return s;
  }

  public func Model(code: Int32) -> ref<OSEvoModel> {
    let i = 0;
    while i < ArraySize(this.models) {
      if this.models[i].code == code {
        return this.models[i];
      }
      i += 1;
    }
    return null;
  }

  // The tracked model for a Tier 5++ record, or 0 when the record isn't one of them.
  public func CodeForRecord(record: TweakDBID) -> Int32 {
    let i = 0;
    while i < ArraySize(this.models) {
      if this.models[i].code != 100 && this.models[i].record == record {
        return this.models[i].code;
      }
      i += 1;
    }
    return 0;
  }

  public func Stage(model: Int32, stage: Int32) -> ref<OSEvoStage> {
    let i = 0;
    while i < ArraySize(this.stages) {
      if this.stages[i].model == model && this.stages[i].stage == stage {
        return this.stages[i];
      }
      i += 1;
    }
    return null;
  }

  // Does any stage of this model count this metric? Only those are saved, to keep saves small.
  public func UsesMetric(model: Int32, metric: Int32) -> Bool {
    let i = 0;
    while i < ArraySize(this.stages) {
      if this.stages[i].model == model && this.stages[i].metric == metric {
        return true;
      }
      i += 1;
    }
    return false;
  }
}
