// Chromepunk 2077: OS Evolution - core system: base leveling, Tier 5++ stages, bonuses
// Copyright (C) 2026 the Chromepunk 2077 authors. Written with AI assistance.
//
// This program is free software: you can redistribute it and/or modify it under the terms of the
// GNU General Public License as published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version. It is distributed WITHOUT ANY WARRANTY. See the
// GNU General Public License for details: https://www.gnu.org/licenses/
//
// How it works
//  - Base leveling (every operating system, every tier, modded ones too): each OS MODEL has a use
//    count. A model is identified by its display name, so all tiers of a deck share one level, the
//    same way Weaponpunk keys weapons. Decks count finished quickhack uploads; Sandevistans and
//    Berserks count activations. Each level gives decks Max RAM and Sandevistans/Berserks duration.
//  - Tier 5++ stages (16 models, see OSEvoData.reds): each model has three stages with titles and
//    perks. Stages unlock IN ORDER. Every goal's counter runs from the start, so a goal met early
//    (a 15-kill streak before Stage 1) is banked and unlocks the moment the stage before it does.
//  - Perks add up: Stage 3 on top of Stages 1 and 2. The universal deck titles stack on top of the
//    model's own titles whenever any Tier 5++ deck is equipped.
//  - A short repeating check (the "tick", 4 times a second, real time) notices what is equipped,
//    whether a Sandevistan or Berserk is running, whether V is airborne or in Overclock, and keeps
//    the player's stat modifiers in step. Upload speed, RAM cost and damage perks are applied where
//    the game computes them (see OSEvoHooks.reds).
//  - Several operating systems can be equipped at once with CyberwareEx; every equipped one counts.
//
// Console checks (Cyber Engine Tweaks):
//   Game.GetScriptableSystemsContainer():Get("OSEvoSystem"):Report()
//   Game.GetScriptableSystemsContainer():Get("OSEvoSystem"):CheatMetric("kills_active", 50)
//   Game.GetScriptableSystemsContainer():Get("OSEvoSystem"):CheatUses(100)
//   Game.GetScriptableSystemsContainer():Get("OSEvoSystem"):ResetAll()

public class OSEvoTickCallback extends DelayCallback {
  public let sys: wref<OSEvoSystem>;
  public let instance: Int32;

  public func Call() -> Void {
    if IsDefined(this.sys) {
      this.sys.Tick(this.instance);
    }
  }
}

public class OSEvoSweepCallback extends DelayCallback {
  public let sys: wref<OSEvoSystem>;

  public func Call() -> Void {
    if IsDefined(this.sys) {
      this.sys.Sweep();
    }
  }
}

// A victim hit while a Sandevistan or Berserk was running, waiting to see if it dies.
public class OSEvoPending {
  public let victim: wref<ScriptedPuppet>;
  public let victimID: EntityID;
  public let time: Float;
  public let code: Int32;        // Tier 5++ model that was active (0 = none, then nothing to count)
  public let osType: Int32;      // 2 Sandevistan, 3 Berserk
  public let activation: Int32;  // which activation it was hit in (for streaks)
  public let head: Bool;
  public let airborne: Bool;
  public let melee: Bool;
  public let close: Bool;
  public let blunt: Bool;
  public let landing: Bool;
}

public class OSEvoSystem extends ScriptableSystem {
  // ---- saved with the game save
  // Stage progress: key = model code * 100 + metric code (metric 99 = stage reached).
  private persistent let m_keys: array<Int32>;
  private persistent let m_vals: array<Int32>;
  // Base leveling: one entry per OS model (first record seen; the model is its display name).
  private persistent let m_lvlRecords: array<TweakDBID>;
  private persistent let m_lvlUses: array<Int32>;

  // ---- runtime only (rebuilt after every load)
  private let m_db: ref<OSEvoDB>;
  private let m_config: ref<OSEvoConfig>;
  private let m_instanceID: Int32;
  private let m_tickRunning: Bool;
  private let m_lastTickReal: Float;
  private let m_tickCount: Int32;
  private let m_equipped: array<ItemID>;       // everything in the OS slot(s)
  private let m_codes: array<Int32>;           // tracked Tier 5++ models among them
  private let m_anyDeck5pp: Bool;
  private let m_sandyOn: Bool;
  private let m_berserkOn: Bool;
  private let m_sandyAct: Int32;               // activation counters, for streaks
  private let m_berserkAct: Int32;
  private let m_sandyStreak: Int32;
  private let m_berserkStreak: Int32;
  private let m_airborne: Bool;
  private let m_overclock: Bool;
  private let m_dilatedAcc: Float;             // part of a tenth of a second not yet saved
  private let m_signature: String;             // what the applied modifiers were built for
  private let m_statsEntity: EntityID;          // the player the modifiers sit on
  // 0.0.8: Berserk "+seconds" collected during a rebuild, applied as a slower charge drain (see
  // ApplyBerserkSeconds). BerserkDurationBase turned out not to be the Berserk's duration in 2.x.
  private let m_berserkExtraSeconds: Float;
  private let m_mods: array<ref<gameStatModifierData>>;
  private let m_hackFx: array<ref<OSEvoEffect>>;   // upload and RAM perks currently in force
  private let m_dmgFx: array<ref<OSEvoEffect>>;    // damage perks currently in force...
  private let m_dmgFxType: array<Int32>;           // ...and the OS type each belongs to
  // 0.0.6 events (reactive perks): the event effects in force and the OS type each belongs to
  private let m_evFx: array<ref<OSEvoEffect>>;
  private let m_evFxType: array<Int32>;
  // per-activation bookkeeping for events, index 2 = Sandevistan, 3 = Berserk (0, 1 unused)
  private let m_actKills: array<Int32>;
  private let m_actMeleeKills: array<Int32>;
  private let m_actExtended: array<Float>;          // seconds added by capped kill extensions
  private let m_lastCharge: array<Float>;           // charge percent seen on the last tick while active
  // 0.0.9: when this activation started (real time) and the charge it started with, so the ending can
  // log how long it really ran. The 0.0.8 test showed "full charge lasts 10.2s" while the runs took
  // 12s: the game waits a moment before the charge starts to drain (BerserkChargesDecayStartDelay?).
  // Measured times settle that instead of guessing.
  private let m_actStart: array<Float>;
  private let m_actStartCharge: array<Float>;
  // Spread-hop detection (0.0.6): one cast that spreads finishes once per target within the same
  // second. Every finish still counts as a use (see OnUploadFinished); this only spots the extra
  // targets for the per-spread RAM refunds.
  private let m_lastUploadName: String;
  private let m_lastUploadTime: Float;
  private let m_pending: array<ref<OSEvoPending>>;
  private let m_sweepQueued: Bool;
  private let m_counted: array<EntityID>;
  private let m_lastLandingVictim: EntityID;
  private let m_lastLandingTime: Float;
  private let m_stageNotice: String;           // set when a stage unlocks, shown on the next card
  private let m_cardToken: Int32;              // the OS card's hide timer only removes its own card
  private let m_announced: Bool;               // "loaded" line written once per session (debug log only since 0.5)

  public static func Version() -> String {
    return "0.5";
  }

  public func NextCardToken() -> Int32 {
    this.m_cardToken += 1;
    return this.m_cardToken;
  }

  public func CardToken() -> Int32 {
    return this.m_cardToken;
  }

  public static func Get(game: GameInstance) -> ref<OSEvoSystem> {
    return GameInstance.GetScriptableSystemsContainer(game).Get(n"OSEvoSystem") as OSEvoSystem;
  }

  private func OnAttach() -> Void {
    this.m_instanceID = RandRange(1, 2000000000);
    this.EnsureSlots();   // 0.0.6: per-activation arrays for the event perks
  }

  // Loading a save creates a fresh copy of this system, but callbacks queued by the earlier copy
  // can still fire. Only the live copy may act (same guard as Weaponpunk).
  private func IsLive() -> Bool {
    let live = OSEvoSystem.Get(this.GetGameInstance());
    return IsDefined(live) && live.m_instanceID == this.m_instanceID;
  }

  public func Config() -> ref<OSEvoConfig> {
    if !IsDefined(this.m_config) {
      this.m_config = new OSEvoConfig();
      OSEvoRegisterSettings(this.m_config);
    }
    return this.m_config;
  }

  public func DB() -> ref<OSEvoDB> {
    if !IsDefined(this.m_db) {
      this.m_db = OSEvoDB.Create();
    }
    return this.m_db;
  }

  private func Log(text: String) -> Void {
    if this.Config().debugLog {
      ModLog(n"ChromepunkOSEvo", text);
    }
  }

  private func Now() -> Float {
    return EngineTime.ToFloat(GameInstance.GetEngineTime(this.GetGameInstance()));
  }

  // The game's own on-screen message (same as Weaponpunk's level-up message).
  public func Notify(text: String) -> Void {
    if !this.Config().notifications {
      return;
    }
    let msg: SimpleScreenMessage;
    msg.isShown = true;
    msg.duration = 4.0;
    msg.message = text;
    let bb = GameInstance.GetBlackboardSystem(this.GetGameInstance()).Get(GetAllBlackboardDefs().UI_Notifications);
    if IsDefined(bb) {
      bb.SetVariant(GetAllBlackboardDefs().UI_Notifications.OnscreenMessage, ToVariant(msg), true);
    }
  }

  // ================================================================ saved numbers
  private func KeyIndex(key: Int32) -> Int32 {
    let i = 0;
    while i < ArraySize(this.m_keys) {
      if this.m_keys[i] == key {
        return i;
      }
      i += 1;
    }
    return -1;
  }

  public func Value(code: Int32, metric: Int32) -> Int32 {
    let i = this.KeyIndex(code * 100 + metric);
    return i >= 0 ? this.m_vals[i] : 0;
  }

  private func SetValue(code: Int32, metric: Int32, value: Int32) -> Void {
    let key = code * 100 + metric;
    let i = this.KeyIndex(key);
    if i >= 0 {
      this.m_vals[i] = value;
    } else {
      ArrayPush(this.m_keys, key);
      ArrayPush(this.m_vals, value);
    }
  }

  public func StageOf(code: Int32) -> Int32 {
    return this.Value(code, 99);
  }

  // Adds to a stage counter (only for metrics this model's stages use), then checks for unlocks.
  public func AddMetric(code: Int32, metric: Int32, amount: Int32) -> Void {
    if code <= 0 || amount == 0 || !this.DB().UsesMetric(code, metric) {
      return;
    }
    this.SetValue(code, metric, this.Value(code, metric) + amount);
    this.CheckStages(code);
  }

  // Kill streaks keep the best streak ever reached in one activation.
  private func RaiseMetric(code: Int32, metric: Int32, value: Int32) -> Void {
    if code <= 0 || !this.DB().UsesMetric(code, metric) {
      return;
    }
    if value > this.Value(code, metric) {
      this.SetValue(code, metric, value);
      this.CheckStages(code);
    }
  }

  // The goal for a stage, after the "Stage goal size" setting. Metric 11 is saved in tenths of a second.
  public func Goal(s: ref<OSEvoStage>) -> Int32 {
    let scaled = Max(1, RoundF(Cast<Float>(s.threshold) * Cast<Float>(this.Config().goalScale) / 100.0));
    return s.metric == 11 ? scaled * 10 : scaled;
  }

  // Unlocks stages in order. A goal already met (banked) unlocks right after the stage before it.
  private func CheckStages(code: Int32) -> Void {
    let changed = false;
    let stage = this.StageOf(code);
    while stage < 3 {
      let next = this.DB().Stage(code, stage + 1);
      if !IsDefined(next) || this.Value(code, next.metric) < this.Goal(next) {
        break;
      }
      stage += 1;
      this.SetValue(code, 99, stage);
      changed = true;
      let m = this.DB().Model(code);
      this.Notify(OSEvoText.StageReached(IsDefined(m) ? m.name : "", stage, next.title));
      // 0.0.5: worded as a title, not a numbered stage (hidden title system)
      this.m_stageNotice = OSEvoText.TitleEarnedNotice(next.title);
      this.Log("stage " + IntToString(stage) + " reached: " + (IsDefined(m) ? m.name : IntToString(code)) + " \"" + next.title + "\"");
    }
    if changed {
      this.m_signature = "";   // rebuild the bonuses on the next tick
    }
  }

  // The title shown after the item name: the newest stage's title, "" before Stage 1.
  public func ShownTitle(code: Int32) -> String {
    let stage = this.StageOf(code);
    if stage <= 0 {
      return "";
    }
    let s = this.DB().Stage(code, stage);
    return IsDefined(s) ? s.title : "";
  }

  // ================================================================ base leveling
  public static func OSType(item: ItemID) -> Int32 {
    let kind = TweakDBInterface.GetCName(ItemID.GetTDBID(item) + t".cyberwareType", n"None");
    if Equals(kind, n"Cyberdeck") {
      return 1;
    }
    if Equals(kind, n"Sandevistan") {
      return 2;
    }
    if Equals(kind, n"Berserk") {
      return 3;
    }
    return 0;
  }

  public static func ModelKey(id: TweakDBID) -> CName {
    let rec = TweakDBInterface.GetItemRecord(id);
    return IsDefined(rec) ? rec.DisplayName() : n"";
  }

  public static func ModelName(item: ItemID) -> String {
    let rec = TweakDBInterface.GetItemRecord(ItemID.GetTDBID(item));
    if IsDefined(rec) {
      let text = GetLocalizedTextByKey(rec.DisplayName());
      if StrLen(text) > 0 {
        return text;
      }
    }
    return TDBID.ToStringDEBUG(ItemID.GetTDBID(item));
  }

  // Index of this item's model in the leveling arrays, or -1.
  private func LevelIndex(item: ItemID) -> Int32 {
    let id = ItemID.GetTDBID(item);
    let key = OSEvoSystem.ModelKey(id);
    let i = 0;
    while i < ArraySize(this.m_lvlRecords) {
      if this.m_lvlRecords[i] == id {
        return i;
      }
      if IsNameValid(key) && Equals(OSEvoSystem.ModelKey(this.m_lvlRecords[i]), key) {
        return i;
      }
      i += 1;
    }
    return -1;
  }

  public func UsesOf(item: ItemID) -> Int32 {
    let i = this.LevelIndex(item);
    return i >= 0 ? this.m_lvlUses[i] : 0;
  }

  // Uses needed to go from `level` to `level + 1`.
  public func LevelCost(level: Int32) -> Int32 {
    let cfg = this.Config();
    let growth = 1.0 + Cast<Float>(cfg.levelGrowth) / 100.0;
    return Max(1, RoundF(Cast<Float>(cfg.firstLevelUses) * PowF(growth, Cast<Float>(level))));
  }

  public func LevelFromUses(uses: Int32) -> Int32 {
    let cap = this.Config().levelCap;
    let level = 0;
    let left = uses;
    while left >= this.LevelCost(level) {
      left -= this.LevelCost(level);
      level += 1;
      if cap > 0 && level >= cap {
        return cap;
      }
      if level >= 1000 {
        return level;   // safety stop for absurd settings
      }
    }
    return level;
  }

  public func LevelOf(item: ItemID) -> Int32 {
    return this.LevelFromUses(this.UsesOf(item));
  }

  // Uses into the current level, and the uses that level needs (for the tooltip).
  public func LevelProgress(item: ItemID, out into: Int32, out need: Int32) -> Void {
    let level = this.LevelOf(item);
    let spent = 0;
    let l = 0;
    while l < level {
      spent += this.LevelCost(l);
      l += 1;
    }
    into = this.UsesOf(item) - spent;
    need = this.LevelCost(level);
  }

  // Returns the card notice for this use: "LEVEL n" on a level-up, "" otherwise.
  public func AddUse(item: ItemID, amount: Int32) -> String {
    if !this.Config().leveling || !ItemID.IsValid(item) || OSEvoSystem.OSType(item) == 0 {
      return "";
    }
    let before = this.LevelOf(item);
    let i = this.LevelIndex(item);
    if i < 0 {
      ArrayPush(this.m_lvlRecords, ItemID.GetTDBID(item));
      ArrayPush(this.m_lvlUses, 0);
      i = ArraySize(this.m_lvlUses) - 1;
    }
    this.m_lvlUses[i] += amount;
    let after = this.LevelOf(item);
    if after > before {
      this.Notify(OSEvoText.LevelReached(OSEvoSystem.ModelName(item), after, this.LevelBonusText(item, after)));
      this.Log("level " + IntToString(after) + ": " + OSEvoSystem.ModelName(item));
      this.m_signature = "";
      return "LEVEL UP: " + IntToString(after);
    }
    return "";
  }

  // "+4 Max RAM" or "+1.00s duration" for a given level.
  public func LevelBonusText(item: ItemID, level: Int32) -> String {
    let cfg = this.Config();
    if OSEvoSystem.OSType(item) == 1 {
      return OSEvoText.RamBonus(cfg.ramPerLevel * level);
    }
    return OSEvoText.SecondsBonus(cfg.secondsPerLevel * Cast<Float>(level));
  }

  // ================================================================ the tick
  // Started when the player is attached (OSEvoHooks: PlayerPuppet.OnGameAttached).
  public func Start() -> Void {
    if this.m_tickRunning {
      return;
    }
    this.m_tickRunning = true;
    this.m_lastTickReal = this.Now();
    this.QueueTick();
    // 0.5: the beta "<mod> <version> loaded" on-screen message (0.0.2, proof the tick started) is gone
    // for the public release. The debug log still records the start; the hidden system should not
    // announce the mod on every load.
    if !this.m_announced {
      this.m_announced = true;
      this.Log("Chromepunk 2077: OS Evolution " + OSEvoSystem.Version() + " loaded");
    }
  }

  private func QueueTick() -> Void {
    let cb = new OSEvoTickCallback();
    cb.sys = this;
    cb.instance = this.m_instanceID;
    // false = real time, so slow motion does not slow the tick down
    GameInstance.GetDelaySystem(this.GetGameInstance()).DelayCallback(cb, 0.25, false);
  }

  public func Tick(instance: Int32) -> Void {
    if instance != this.m_instanceID || !this.IsLive() {
      return;   // a callback from before a load: let it die
    }
    let game = this.GetGameInstance();
    let player = GetPlayer(game);
    let now = this.Now();
    let dt = MinF(1.0, MaxF(0.0, now - this.m_lastTickReal));
    this.m_lastTickReal = now;
    if IsDefined(player) {
      this.m_tickCount += 1;
      // what is equipped: every tick is cheap enough (a handful of slots)
      this.ReadEquipped(player);
      // Sandevistan / Berserk running?
      let sandy = StatusEffectSystem.ObjectHasStatusEffectOfType(player, gamedataStatusEffectType.Sandevistan);
      let berserk = StatusEffectSystem.ObjectHasStatusEffectOfType(player, gamedataStatusEffectType.Berserk);
      if sandy && !this.m_sandyOn {
        this.OnActivated(player, 2);
      }
      if berserk && !this.m_berserkOn {
        this.OnActivated(player, 3);
      }
      // 0.0.6: endings run the "when it ends" perks (early refund, heals, cooldown cuts)
      if !sandy && this.m_sandyOn {
        this.OnDeactivated(player, 2);
      }
      if !berserk && this.m_berserkOn {
        this.OnDeactivated(player, 3);
      }
      this.m_sandyOn = sandy;
      this.m_berserkOn = berserk;
      // remember the charge while running: by the time the ending is seen, the "turned off early"
      // test needs the charge from just before (a charge run down to empty ends near 0)
      if sandy {
        this.m_lastCharge[2] = this.ChargePercent(player, 2);
      }
      if berserk {
        this.m_lastCharge[3] = this.ChargePercent(player, 3);
      }
      // Falcon's goal: real seconds spent in Sandevistan time dilation, saved in tenths
      if sandy && this.Config().enabled {
        let code = this.ActiveCode(2);
        if code > 0 && this.DB().UsesMetric(code, 11) {
          this.m_dilatedAcc += dt * 10.0;
          let whole = FloorF(this.m_dilatedAcc);
          if whole > 0 {
            this.m_dilatedAcc -= Cast<Float>(whole);
            this.AddMetric(code, 11, whole);
          }
        }
      }
      this.m_airborne = !player.GetPlayerStateMachineBlackboard().GetBool(GetAllBlackboardDefs().PlayerStateMachine.IsOnGround);
      this.m_overclock = QuickHackableHelper.IsOverclockedStateActive(player);
      this.RefreshBonuses(player);
    }
    this.QueueTick();
  }

  private func ReadEquipped(player: ref<PlayerPuppet>) -> Void {
    ArrayClear(this.m_equipped);
    ArrayClear(this.m_codes);
    this.m_anyDeck5pp = false;
    let data = EquipmentSystem.GetData(player);
    if !IsDefined(data) {
      return;
    }
    let n = data.GetNumberOfSlots(gamedataEquipmentArea.SystemReplacementCW, true);
    let i = 0;
    while i < n {
      let item = data.GetItemInEquipSlot(gamedataEquipmentArea.SystemReplacementCW, i);
      if ItemID.IsValid(item) {
        ArrayPush(this.m_equipped, item);
        let code = this.DB().CodeForRecord(ItemID.GetTDBID(item));
        if code > 0 {
          ArrayPush(this.m_codes, code);
          if code < 10 {
            this.m_anyDeck5pp = true;
          }
        }
      }
      i += 1;
    }
  }

  // The equipped Tier 5++ model of an OS type (2 Sandevistan, 3 Berserk), or 0.
  public func ActiveCode(osType: Int32) -> Int32 {
    let i = 0;
    while i < ArraySize(this.m_codes) {
      let m = this.DB().Model(this.m_codes[i]);
      if IsDefined(m) && m.osType == osType {
        return m.code;
      }
      i += 1;
    }
    return 0;
  }

  // The equipped item of an OS type (any tier), for base leveling.
  private func EquippedOfType(osType: Int32) -> ItemID {
    let none: ItemID;
    let i = 0;
    while i < ArraySize(this.m_equipped) {
      if OSEvoSystem.OSType(this.m_equipped[i]) == osType {
        return this.m_equipped[i];
      }
      i += 1;
    }
    return none;
  }

  private func OnActivated(player: ref<PlayerPuppet>, osType: Int32) -> Void {
    if osType == 2 {
      this.m_sandyAct += 1;
      this.m_sandyStreak = 0;
    } else {
      this.m_berserkAct += 1;
      this.m_berserkStreak = 0;
    }
    // 0.0.6: fresh per-activation counters for the event perks
    this.EnsureSlots();
    this.m_lastCharge[osType] = 100.0;
    // 0.0.9: start time and charge, for the "ran N s" line when it ends (see OnDeactivated)
    this.m_actStart[osType] = this.Now();
    this.m_actStartCharge[osType] = this.ChargePercent(player, osType);
    this.m_actKills[osType] = 0;
    this.m_actMeleeKills[osType] = 0;
    this.m_actExtended[osType] = 0.0;
    if !this.Config().enabled {
      return;
    }
    // event 6: activated mid-air (Zetatech Sandevistan)
    let airborne = !player.GetPlayerStateMachineBlackboard().GetBool(GetAllBlackboardDefs().PlayerStateMachine.IsOnGround);
    if airborne {
      let extra = this.EventSum(osType, 6);
      if extra > 0.0 {
        this.ExtendSeconds(player, osType, extra, "mid-air activation");
      }
    }
    let item = this.EquippedOfType(osType);
    let notice = this.AddUse(item, 1);
    let code = this.ActiveCode(osType);
    if code > 0 && player.IsInCombat() {
      this.AddMetric(code, 12, 1);
    }
    this.ShowCard(item, notice);
    this.Log((osType == 2 ? "Sandevistan" : "Berserk") + " activated" + (player.IsInCombat() ? " in combat" : ""));
  }

  // ================================================================ bonuses
  // Rebuilds the player's stat modifiers whenever anything they depend on has changed.
  private func RefreshBonuses(player: ref<PlayerPuppet>) -> Void {
    let cfg = this.Config();
    let sig = (cfg.enabled ? "1" : "0") + (cfg.leveling ? "1" : "0") + IntToString(cfg.ramPerLevel) + FloatToString(cfg.secondsPerLevel)
      + IntToString(cfg.levelCap) + IntToString(cfg.firstLevelUses) + IntToString(cfg.levelGrowth)
      // 0.0.6: a condition only enters the signature if an earned perk depends on it. Before, every jump
      // (airborne) and every Overclock rebuilt all modifiers; the CET game log showed rebuilds every few
      // seconds that changed nothing.
      + (this.m_sandyOn && this.NeedsActive(2) ? "S" : "-") + (this.m_berserkOn && this.NeedsActive(3) ? "B" : "-")
      + (this.m_airborne && this.NeedsCond(3) ? "A" : "-") + (this.m_overclock && this.NeedsCond(4) ? "O" : "-");
    let i = 0;
    while i < ArraySize(this.m_equipped) {
      sig = sig + "|" + TDBID.ToStringDEBUG(ItemID.GetTDBID(this.m_equipped[i])) + ":" + IntToString(this.LevelOf(this.m_equipped[i]));
      i += 1;
    }
    i = 0;
    while i < ArraySize(this.m_codes) {
      sig = sig + "#" + IntToString(this.m_codes[i]) + ":" + IntToString(this.StageOf(this.m_codes[i]));
      i += 1;
    }
    sig = sig + "#U" + IntToString(this.StageOf(100));
    if Equals(sig, this.m_signature) && this.m_statsEntity == player.GetEntityID() {
      return;
    }
    this.m_signature = sig;
    this.RemoveBonuses();
    this.m_berserkExtraSeconds = 0.0;
    this.m_statsEntity = player.GetEntityID();
    if !cfg.enabled {
      return;
    }
    let stats = GameInstance.GetStatsSystem(this.GetGameInstance());
    // base leveling
    if cfg.leveling {
      i = 0;
      while i < ArraySize(this.m_equipped) {
        let item = this.m_equipped[i];
        let level = this.LevelOf(item);
        let osType = OSEvoSystem.OSType(item);
        if level > 0 {
          if osType == 1 && cfg.ramPerLevel > 0 {
            this.AddMod(stats, RPGManager.CreateStatModifier(gamedataStatType.Memory, gameStatModifierType.Additive, Cast<Float>(cfg.ramPerLevel * level)));
          }
          if osType == 2 && cfg.secondsPerLevel > 0.0 {
            this.AddMod(stats, RPGManager.CreateStatModifier(gamedataStatType.TimeDilationSandevistanDuration, gameStatModifierType.Additive, cfg.secondsPerLevel * Cast<Float>(level)));
          }
          if osType == 3 && cfg.secondsPerLevel > 0.0 {
            // 0.0.8: collected and applied as a slower drain (ApplyBerserkSeconds), not BerserkDurationBase
            this.m_berserkExtraSeconds += cfg.secondsPerLevel * Cast<Float>(level);
          }
        }
        i += 1;
      }
    }
    // Tier 5++ stage perks
    i = 0;
    while i < ArraySize(this.m_codes) {
      this.ApplyModel(stats, this.m_codes[i]);
      i += 1;
    }
    if this.m_anyDeck5pp {
      this.ApplyModel(stats, 100);
    }
    this.ApplyBerserkSeconds(stats);
    this.Log("bonuses rebuilt: " + IntToString(ArraySize(this.m_mods)) + " stat modifiers, "
      + IntToString(ArraySize(this.m_hackFx)) + " quickhack perks, " + IntToString(ArraySize(this.m_dmgFx)) + " damage perks, "
      + IntToString(ArraySize(this.m_evFx)) + " event perks");
  }

  private func ApplyModel(stats: ref<StatsSystem>, code: Int32) -> Void {
    let m = this.DB().Model(code);
    if !IsDefined(m) {
      return;
    }
    let active = (m.osType == 2 && this.m_sandyOn) || (m.osType == 3 && this.m_berserkOn);
    let reached = this.StageOf(code);
    let st = 1;
    while st <= reached {
      let s = this.DB().Stage(code, st);
      if IsDefined(s) {
        let k = 0;
        while k < ArraySize(s.effects) {
          let e = s.effects[k];
          if e.kind == 1 {
            let on = e.cond == 1
              || (e.cond == 2 && active)
              || (e.cond == 3 && active && this.m_airborne)
              || (e.cond == 4 && m.osType == 1 && this.m_overclock);
            if on && Equals(e.stat, gamedataStatType.BerserkDurationBase) && Equals(e.modType, gameStatModifierType.Additive) {
              // 0.0.8: Berserk "+N s max duration" perks are collected and applied as a slower drain
              this.m_berserkExtraSeconds += e.value;
              on = false;
            }
            if on {
              // 0.0.7: cooldown perks are written against SandevistanRechargeDuration /
              // BerserkRechargeDuration in the CSV; the stat that really holds the cooldown is found
              // at run time (see CooldownStat), since both of those read 0 in game.
              this.AddMod(stats, RPGManager.CreateStatModifier(this.ResolveStat(e.stat), e.modType, e.value));
            }
          } else {
            if e.kind == 4 {
              ArrayPush(this.m_dmgFx, e);
              ArrayPush(this.m_dmgFxType, m.osType);
            } else {
              if e.kind == 5 {
                ArrayPush(this.m_evFx, e);
                ArrayPush(this.m_evFxType, m.osType);
              } else {
                ArrayPush(this.m_hackFx, e);
              }
            }
          }
          k += 1;
        }
      }
      st += 1;
    }
  }

  // 0.0.8: Berserk duration. Final testing showed BerserkDurationBase only held Chromepunk's own +3 s
  // (Report: "Berserk duration 3.0" with the Zetatech Berserk's titles), so it is not the Berserk's
  // duration in 2.x. A running Berserk drains its charge pool at BerserkChargesDecayRate (Report: 2.272
  // per second, ~44 s for a full pool). So "+X seconds" = drain slower: the full pool lasts D = max / rate
  // seconds; to last D + X the rate is multiplied by D / (D + X). The base rate is read here, after the
  // old modifiers were removed, so the multiplier never compounds.
  private func ApplyBerserkSeconds(stats: ref<StatsSystem>) -> Void {
    if this.m_berserkExtraSeconds <= 0.0 {
      return;
    }
    let sid = Cast<StatsObjectID>(this.m_statsEntity);
    let rate = stats.GetStatValue(sid, gamedataStatType.BerserkChargesDecayRate);
    if rate <= 0.0 {
      this.Log("Berserk duration bonus skipped: BerserkChargesDecayRate reads 0");
      return;
    }
    let full = this.BerserkPoolMax();
    let duration = full / rate;
    let mult = duration / (duration + this.m_berserkExtraSeconds);
    this.AddMod(stats, RPGManager.CreateStatModifier(gamedataStatType.BerserkChargesDecayRate, gameStatModifierType.Multiplier, mult));
    this.Log("Berserk duration +" + FloatToStringPrec(this.m_berserkExtraSeconds, 2) + "s: " + FloatToStringPrec(duration, 1) + "s -> "
      + FloatToStringPrec(duration + this.m_berserkExtraSeconds, 1) + "s");
  }

  private func BerserkPoolMax() -> Float {
    let max = GameInstance.GetStatPoolsSystem(this.GetGameInstance()).GetStatPoolMaxPointValue(Cast<StatsObjectID>(this.m_statsEntity), gamedataStatPoolType.BerserkCharge);
    return max > 0.0 ? max : 100.0;
  }

  private func AddMod(stats: ref<StatsSystem>, mod: ref<gameStatModifierData>) -> Void {
    stats.AddModifier(Cast<StatsObjectID>(this.m_statsEntity), mod);
    ArrayPush(this.m_mods, mod);
  }

  private func RemoveBonuses() -> Void {
    let stats = GameInstance.GetStatsSystem(this.GetGameInstance());
    let i = 0;
    while i < ArraySize(this.m_mods) {
      stats.RemoveModifier(Cast<StatsObjectID>(this.m_statsEntity), this.m_mods[i]);
      i += 1;
    }
    ArrayClear(this.m_mods);
    ArrayClear(this.m_hackFx);
    ArrayClear(this.m_dmgFx);
    ArrayClear(this.m_dmgFxType);
    ArrayClear(this.m_evFx);
    ArrayClear(this.m_evFxType);
  }

  // ================================================================ quickhacks
  // Called from OSEvoHooks when the game works out a quickhack's upload time. Returns the total
  // upload speed bonus in percent (the time is divided by 1 + bonus / 100).
  public func UploadBonus(action: ref<BaseScriptableAction>) -> Float {
    if ArraySize(this.m_hackFx) == 0 || !this.Config().enabled {
      return 0.0;
    }
    let total = 0.0;
    let i = 0;
    while i < ArraySize(this.m_hackFx) {
      let e = this.m_hackFx[i];
      if e.kind == 2 && this.HackCondition(e, action) {
        total += e.value;
      }
      i += 1;
    }
    return total;
  }

  // Called from OSEvoHooks when the game works out a quickhack's RAM cost.
  public func AdjustCost(action: ref<BaseScriptableAction>, cost: Int32) -> Int32 {
    if cost <= 0 || ArraySize(this.m_hackFx) == 0 || !this.Config().enabled {
      return cost;
    }
    let flat = 0.0;
    let pct = 0.0;
    let i = 0;
    while i < ArraySize(this.m_hackFx) {
      let e = this.m_hackFx[i];
      if e.kind == 3 && this.HackCondition(e, action) {
        if e.cond == 5 {
          pct += e.value;
        } else {
          flat += e.value;
        }
      }
      i += 1;
    }
    if flat == 0.0 && pct == 0.0 {
      return cost;
    }
    let result = Cast<Float>(cost) * (1.0 + pct / 100.0) + flat;
    // a quickhack that cost RAM always costs at least 1
    return Max(1, CeilF(result));
  }

  private func HackCondition(e: ref<OSEvoEffect>, action: ref<BaseScriptableAction>) -> Bool {
    let rec = action.GetObjectActionRecord();
    let category = gamedataHackCategory.Invalid;
    if IsDefined(rec) && IsDefined(rec.HackCategory()) {
      category = rec.HackCategory().Type();
    }
    switch e.cond {
      case 0:
        return true;
      case 1:
        return Equals(category, e.category);
      case 2:
        return e.MatchesName(NameToString(action.actionName));
      case 3:
        return !this.PlayerInCombat();
      case 4:
        return this.m_overclock;
      case 5:
        return this.TargetQueue(action) >= 1;
      case 6:
        return this.TargetQueueFull(action);
      case 7:
        return Equals(category, gamedataHackCategory.DeviceHack) || Equals(category, gamedataHackCategory.VehicleHack)
          || !IsDefined(GameInstance.FindEntityByID(this.GetGameInstance(), action.GetRequesterID()) as ScriptedPuppet);
      case 8:
        // 0.0.6: through a camera or other device V controls. The game's own camera perk tests this flag
        // (scanner_chunks.swift, PlayerStateMachine.IsControllingDevice).
        return this.PlayerControllingDevice();
      case 9:
        // 0.0.6: a Combat hack onto a target that is already receiving a Control hack
        return Equals(category, gamedataHackCategory.DamageHack) && this.TargetUploadingCategory(action, gamedataHackCategory.ControlHack);
    }
    return false;
  }

  private func PlayerControllingDevice() -> Bool {
    let player = GetPlayer(this.GetGameInstance());
    return IsDefined(player) && player.GetPlayerStateMachineBlackboard().GetBool(GetAllBlackboardDefs().PlayerStateMachine.IsControllingDevice);
  }

  // Is the target busy receiving a quickhack of this category? (ScriptedPuppet.GetCurrentlyUploadingAction)
  private func TargetUploadingCategory(action: ref<BaseScriptableAction>, category: gamedataHackCategory) -> Bool {
    let target = GameInstance.FindEntityByID(this.GetGameInstance(), action.GetRequesterID()) as ScriptedPuppet;
    if !IsDefined(target) {
      return false;
    }
    let current = target.GetCurrentlyUploadingAction();
    if !IsDefined(current) {
      return false;
    }
    let rec = current.GetObjectActionRecord();
    return IsDefined(rec) && IsDefined(rec.HackCategory()) && Equals(rec.HackCategory().Type(), category);
  }

  private func PlayerInCombat() -> Bool {
    let player = GetPlayer(this.GetGameInstance());
    return IsDefined(player) && player.IsInCombat();
  }

  // How many uploads the target already has running or queued.
  private func TargetQueue(action: ref<BaseScriptableAction>) -> Int32 {
    let target = GameInstance.FindEntityByID(this.GetGameInstance(), action.GetRequesterID()) as ScriptedPuppet;
    return IsDefined(target) ? target.GetDeviceActionQueueSize() : 0;
  }

  // Same test the game uses for its own "last slot in the queue" perk (Intelligence_Master_Perk_1).
  private func TargetQueueFull(action: ref<BaseScriptableAction>) -> Bool {
    let target = GameInstance.FindEntityByID(this.GetGameInstance(), action.GetRequesterID()) as ScriptedPuppet;
    return IsDefined(target) && target.GetDeviceActionQueueSize() >= target.GetDeviceActionMaxQueueSize() - 1;
  }

  // A quickhack upload by the player has finished (OSEvoHooks).
  public func OnUploadFinished(action: ref<BaseScriptableAction>) -> Void {
    if !this.Config().enabled {
      return;
    }
    // Every finished upload counts as a use, INCLUDING each extra target a spreading quickhack reaches.
    // 0.0.6 briefly counted a spreading cast only once; the author's call: spreading to more targets
    // (e.g. a multi-spread Synapse Burnout set up in Quickhacks Boost) is meant to earn more, so 0.0.6
    // went back to counting every target. The same quickhack finishing again within 0.6 s is still
    // recognised as a spread hop, but only to trigger the per-spread RAM refunds (Biotech, Canto).
    let name = NameToString(action.actionName);
    let now = this.Now();
    if Equals(name, this.m_lastUploadName) && now - this.m_lastUploadTime < 0.6 {
      this.OnSpreadHop(name);
    }
    this.m_lastUploadName = name;
    this.m_lastUploadTime = now;
    let deck: ItemID;
    let notice = "";
    let i = 0;
    while i < ArraySize(this.m_equipped) {
      if OSEvoSystem.OSType(this.m_equipped[i]) == 1 {
        let n = this.AddUse(this.m_equipped[i], 1);
        if !ItemID.IsValid(deck) {
          deck = this.m_equipped[i];
          notice = n;
        }
      }
      i += 1;
    }
    i = 0;
    while i < ArraySize(this.m_codes) {
      if this.m_codes[i] < 10 {
        this.AddMetric(this.m_codes[i], 1, 1);
      }
      i += 1;
    }
    if this.m_anyDeck5pp {
      this.AddMetric(100, 2, 1);
    }
    this.ShowCard(deck, notice);
    this.Log("upload finished: " + NameToString(action.actionName));
  }

  // ================================================================ hits and kills
  // Every hit the player lands (OSEvoHooks). Applies damage perks and remembers the victim while a
  // Sandevistan or Berserk is running, so its death can be counted.
  public func OnPlayerHit(hitEvent: ref<gameHitEvent>) -> Void {
    if !this.Config().enabled {
      return;
    }
    let game = this.GetGameInstance();
    let player = GetPlayer(game);
    if !IsDefined(player) {
      return;
    }
    let sandy = StatusEffectSystem.ObjectHasStatusEffectOfType(player, gamedataStatusEffectType.Sandevistan);
    let berserk = StatusEffectSystem.ObjectHasStatusEffectOfType(player, gamedataStatusEffectType.Berserk);
    if !sandy && !berserk {
      return;
    }
    let attackType = hitEvent.attackData.GetAttackType();
    let melee = AttackData.IsMelee(attackType);
    let landing = false;
    let attackRecord = hitEvent.attackData.GetAttackDefinition().GetRecord() as Attack_GameEffect_Record;
    if IsDefined(attackRecord) && Equals(attackRecord.EffectName(), n"superheroLanding") {
      landing = true;
    }
    let airborne = !player.GetPlayerStateMachineBlackboard().GetBool(GetAllBlackboardDefs().PlayerStateMachine.IsOnGround);
    // damage perks
    let mult = 1.0;
    let i = 0;
    while i < ArraySize(this.m_dmgFx) {
      let e = this.m_dmgFx[i];
      let mine = (this.m_dmgFxType[i] == 2 && sandy) || (this.m_dmgFxType[i] == 3 && berserk);
      if mine {
        if (e.cond == 1 && airborne) || (e.cond == 2 && melee) || (e.cond == 3 && landing) {
          mult += e.value / 100.0;
        }
      }
      i += 1;
    }
    if mult > 1.0 {
      hitEvent.attackComputed.MultAttackValue(mult);
    }
    let victim = hitEvent.target as ScriptedPuppet;
    if !IsDefined(victim) || OSEvoSystem.IsCivilian(victim) {
      return;
    }
    let osType = sandy ? 2 : 3;
    let code = this.ActiveCode(osType);
    if code <= 0 {
      return;   // no Tier 5++ model running: nothing to count
    }
    let now = this.Now();
    // Superhero Landing hits count once per enemy per landing
    if landing && osType == 3 {
      if !(this.m_lastLandingVictim == victim.GetEntityID() && now - this.m_lastLandingTime < 1.0) {
        this.AddMetric(code, 9, 1);
        // 0.0.6 event 9: each enemy hit by a Superhero Landing extends the Berserk (Moore Tech)
        let landingExtra = this.EventSum(3, 9);
        if landingExtra > 0.0 {
          this.ExtendSeconds(player, 3, landingExtra, "Superhero Landing hit");
        }
      }
      this.m_lastLandingVictim = victim.GetEntityID();
      this.m_lastLandingTime = now;
    }
    let p = new OSEvoPending();
    p.victim = victim;
    p.victimID = victim.GetEntityID();
    p.time = now;
    p.code = code;
    p.osType = osType;
    p.activation = osType == 2 ? this.m_sandyAct : this.m_berserkAct;
    p.head = OSEvoSystem.IsHeadHit(hitEvent);
    p.airborne = airborne;
    p.melee = melee;
    p.close = melee || Vector4.Distance(player.GetWorldPosition(), victim.GetWorldPosition()) < 5.0;
    let weapon = hitEvent.attackData.GetWeapon();
    p.blunt = IsDefined(weapon) && weapon.IsBlunt();
    p.landing = landing;
    // the latest hit on a victim decides what its death counts as
    let k = ArraySize(this.m_pending) - 1;
    while k >= 0 {
      if this.m_pending[k].victimID == p.victimID {
        ArrayErase(this.m_pending, k);
      }
      k -= 1;
    }
    ArrayPush(this.m_pending, p);
    this.QueueSweep();
  }

  public static func IsCivilian(victim: ref<ScriptedPuppet>) -> Bool {
    return victim.IsCharacterCivilian() || victim.IsCrowd();
  }

  // Same head-hit test as Weaponpunk: the headshot flag, or the body part hit (bosses hide the flag).
  public static func IsHeadHit(hitEvent: ref<gameHitEvent>) -> Bool {
    if hitEvent.attackData.HasFlag(hitFlag.Headshot) {
      return true;
    }
    let shapes = hitEvent.hitRepresentationResult.hitShapes;
    if ArraySize(shapes) > 0 {
      let data = DamageSystemHelper.GetHitShapeUserDataBase(shapes[0]);
      return IsDefined(data) && HitShapeUserDataBase.IsHitReactionZoneHead(data);
    }
    return false;
  }

  private func QueueSweep() -> Void {
    if this.m_sweepQueued {
      return;
    }
    let cb = new OSEvoSweepCallback();
    cb.sys = this;
    GameInstance.GetDelaySystem(this.GetGameInstance()).DelayCallback(cb, 0.25, false);
    this.m_sweepQueued = true;
  }

  // Looks at every remembered victim: counts the ones taken down, forgets the ones hit too long ago.
  // "Taken down" includes non-lethal (blunt weapons knock enemies out rather than kill them).
  public func Sweep() -> Void {
    this.m_sweepQueued = false;
    if !this.IsLive() {
      return;
    }
    let now = this.Now();
    let keep: array<ref<OSEvoPending>>;
    let i = 0;
    while i < ArraySize(this.m_pending) {
      let p = this.m_pending[i];
      if IsDefined(p.victim) {
        if !ScriptedPuppet.IsAlive(p.victim) || ScriptedPuppet.IsDefeated(p.victim) || ScriptedPuppet.IsUnconscious(p.victim) {
          this.OnKill(p);
        } else {
          if now - p.time < 6.0 {
            ArrayPush(keep, p);
          }
        }
      }
      i += 1;
    }
    this.m_pending = keep;
    if ArraySize(this.m_pending) > 0 {
      this.QueueSweep();
    }
  }

  private func OnKill(p: ref<OSEvoPending>) -> Void {
    if ArrayContains(this.m_counted, p.victimID) {
      return;
    }
    ArrayPush(this.m_counted, p.victimID);
    if ArraySize(this.m_counted) > 64 {
      ArrayErase(this.m_counted, 0);
    }
    let code = p.code;
    this.AddMetric(code, 3, 1);
    // streak: only while the same activation is still the current one
    if p.osType == 2 && p.activation == this.m_sandyAct {
      this.m_sandyStreak += 1;
      this.RaiseMetric(code, 4, this.m_sandyStreak);
    }
    if p.osType == 3 && p.activation == this.m_berserkAct {
      this.m_berserkStreak += 1;
      this.RaiseMetric(code, 4, this.m_berserkStreak);
    }
    if p.head {
      this.AddMetric(code, 5, 1);
    }
    if p.airborne {
      this.AddMetric(code, 6, 1);
    }
    if p.melee {
      this.AddMetric(code, 7, 1);
    }
    if p.close {
      this.AddMetric(code, 8, 1);
    }
    if p.blunt || p.landing {
      this.AddMetric(code, 10, 1);
    }
    this.OnKillEvents(p);
    this.Log("kill counted for model " + IntToString(code) + (p.head ? " [head]" : "") + (p.airborne ? " [air]" : "")
      + (p.melee ? " [melee]" : "") + (p.blunt ? " [blunt]" : "") + (p.landing ? " [landing]" : ""));
  }

  // The OS card (OSEvoCard.reds). A stage unlocked since the last card wins over a level-up notice,
  // since it is the rarer event.
  private func ShowCard(item: ItemID, levelNotice: String) -> Void {
    if !ItemID.IsValid(item) {
      return;
    }
    let notice = levelNotice;
    if NotEquals(this.m_stageNotice, "") {
      notice = this.m_stageNotice;
      this.m_stageNotice = "";
    }
    OSEvoCard.Show(this, item, notice);
  }

  // ================================================================ events (0.0.6)
  // Reactive perks: kill extensions, refunds, heals, cooldown cuts, RAM per spread.
  // How duration works in 2.x: a running Sandevistan/Berserk drains its charge pool
  // (SandevistanCharge / BerserkCharge) from full to empty over its max duration, and the pool refills
  // over the recharge time ("cooldown"). So "extend by N seconds" = add N / duration of a full pool,
  // and "shorten the cooldown by N seconds" = add N / recharge time of a full pool while it refills.
  // Pool changes use absolute points (percent x the pool's max), the way the game's own heal code does.

  // The per-activation arrays have 4 slots (index 2 = Sandevistan, 3 = Berserk), created in OnAttach.
  private func EnsureSlots() -> Void {
    while ArraySize(this.m_actKills) < 4 {
      ArrayPush(this.m_actKills, 0);
      ArrayPush(this.m_actMeleeKills, 0);
      ArrayPush(this.m_actExtended, 0.0);
      ArrayPush(this.m_lastCharge, 0.0);
      ArrayPush(this.m_actStart, 0.0);        // 0.0.9, see the field
      ArrayPush(this.m_actStartCharge, 0.0);
    }
  }

  // Sum of the values of every event perk of this kind belonging to an OS type in force now.
  private func EventSum(osType: Int32, cond: Int32) -> Float {
    let total = 0.0;
    let i = 0;
    while i < ArraySize(this.m_evFx) {
      if this.m_evFxType[i] == osType && this.m_evFx[i].cond == cond {
        total += this.m_evFx[i].value;
      }
      i += 1;
    }
    return total;
  }

  // Does an earned stat perk depend on this condition? (keeps RefreshBonuses from rebuilding needlessly)
  private func NeedsCond(cond: Int32) -> Bool {
    let i = 0;
    while i <= ArraySize(this.m_codes) {
      let code = i < ArraySize(this.m_codes) ? this.m_codes[i] : (this.m_anyDeck5pp ? 100 : 0);
      let st = 1;
      while code > 0 && st <= this.StageOf(code) {
        let s = this.DB().Stage(code, st);
        if IsDefined(s) {
          let k = 0;
          while k < ArraySize(s.effects) {
            if s.effects[k].kind == 1 && s.effects[k].cond == cond {
              return true;
            }
            k += 1;
          }
        }
        st += 1;
      }
      i += 1;
    }
    return false;
  }

  // Is there an earned "while active" or "airborne and active" perk on the equipped model of this type?
  private func NeedsActive(osType: Int32) -> Bool {
    let code = this.ActiveCode(osType);
    let st = 1;
    while code > 0 && st <= this.StageOf(code) {
      let s = this.DB().Stage(code, st);
      if IsDefined(s) {
        let k = 0;
        while k < ArraySize(s.effects) {
          if s.effects[k].kind == 1 && (s.effects[k].cond == 2 || s.effects[k].cond == 3) {
            return true;
          }
          k += 1;
        }
      }
      st += 1;
    }
    return false;
  }

  private func ChargePool(osType: Int32) -> gamedataStatPoolType {
    return osType == 2 ? gamedataStatPoolType.SandevistanCharge : gamedataStatPoolType.BerserkCharge;
  }

  private func ChargePercent(player: ref<PlayerPuppet>, osType: Int32) -> Float {
    return GameInstance.GetStatPoolsSystem(this.GetGameInstance()).GetStatPoolValue(Cast<StatsObjectID>(player.GetEntityID()), this.ChargePool(osType), true);
  }

  // Adds a percentage of a pool's maximum (negative takes away).
  private func PoolAddPercent(player: ref<PlayerPuppet>, pool: gamedataStatPoolType, percent: Float) -> Void {
    let pools = GameInstance.GetStatPoolsSystem(this.GetGameInstance());
    let oid = Cast<StatsObjectID>(player.GetEntityID());
    let max = pools.GetStatPoolMaxPointValue(oid, pool);
    if max <= 0.0 || percent == 0.0 {
      return;
    }
    pools.RequestChangingStatPoolValue(oid, pool, max * percent / 100.0, player, false, false);
  }

  // 0.0.7: which stat holds the cooldown ("recharge") of a Sandevistan (2) or Berserk (3).
  // Final testing showed SandevistanRechargeDuration and BerserkRechargeDuration both read 0 in 2.x,
  // so every cooldown perk did nothing. The scripts never read these stats (the cooldown is computed
  // natively), so instead of guessing again the mod checks the candidates in order and uses the first
  // one that has a value on the player. Report() prints them all; the debug log names the one used.
  // Once confirmed in game, the CSV can name the right stat and this can stay as a safety net.
  public func CooldownStat(osType: Int32) -> gamedataStatType {
    let candidates: array<gamedataStatType>;
    if osType == 2 {
      candidates = [gamedataStatType.TimeDilationSandevistanRechargeDuration, gamedataStatType.SandevistanRechargeDuration, gamedataStatType.TimeDilationSandevistanCooldownBase];
    } else {
      candidates = [gamedataStatType.BerserkRechargeDuration, gamedataStatType.BerserkCooldownBase];
    }
    let player = GetPlayer(this.GetGameInstance());
    if IsDefined(player) {
      let stats = GameInstance.GetStatsSystem(this.GetGameInstance());
      let sid = Cast<StatsObjectID>(player.GetEntityID());
      let i = 0;
      while i < ArraySize(candidates) {
        if stats.GetStatValue(sid, candidates[i]) > 0.0 {
          return candidates[i];
        }
        i += 1;
      }
    }
    return candidates[0];
  }

  // Maps the CSV's cooldown stats to the one found in game (other stats pass through unchanged).
  private func ResolveStat(stat: gamedataStatType) -> gamedataStatType {
    if Equals(stat, gamedataStatType.SandevistanRechargeDuration) {
      let s2 = this.CooldownStat(2);
      this.Log("Sandevistan cooldown perk applied to " + EnumValueToString("gamedataStatType", Cast<Int64>(EnumInt(s2))));
      return s2;
    }
    if Equals(stat, gamedataStatType.BerserkRechargeDuration) {
      let s3 = this.CooldownStat(3);
      this.Log("Berserk cooldown perk applied to " + EnumValueToString("gamedataStatType", Cast<Int64>(EnumInt(s3))));
      return s3;
    }
    return stat;
  }

  // Extends a running Sandevistan/Berserk by some seconds.
  private func ExtendSeconds(player: ref<PlayerPuppet>, osType: Int32, seconds: Float, why: String) -> Void {
    // 0.0.8: a Berserk's charge drains at BerserkChargesDecayRate points per second (see
    // ApplyBerserkSeconds), so N seconds = N x that rate in points. Until 0.0.8 this divided by
    // BerserkDurationBase (only Chromepunk's own few seconds), which made every Berserk extension far
    // too big.
    if osType == 3 {
      let rate = GameInstance.GetStatsSystem(this.GetGameInstance()).GetStatValue(Cast<StatsObjectID>(player.GetEntityID()), gamedataStatType.BerserkChargesDecayRate);
      if rate <= 0.0 {
        this.Log("extend skipped (" + why + "): BerserkChargesDecayRate reads 0");
        return;
      }
      GameInstance.GetStatPoolsSystem(this.GetGameInstance()).RequestChangingStatPoolValue(Cast<StatsObjectID>(player.GetEntityID()), gamedataStatPoolType.BerserkCharge, seconds * rate, player, false, false);
      this.Log("extended by " + FloatToStringPrec(seconds, 2) + "s (" + why + "), Berserk drain " + FloatToStringPrec(rate, 3) + "/s, full charge "
        + FloatToStringPrec(this.BerserkPoolMax() / rate, 1) + "s");
      return;
    }
    let stat = gamedataStatType.TimeDilationSandevistanDuration;
    let duration = GameInstance.GetStatsSystem(this.GetGameInstance()).GetStatValue(Cast<StatsObjectID>(player.GetEntityID()), stat);
    if duration <= 0.0 {
      this.Log("extend skipped (" + why + "): max duration stat reads 0");
      return;
    }
    this.PoolAddPercent(player, this.ChargePool(osType), seconds / duration * 100.0);
    this.Log("extended by " + FloatToStringPrec(seconds, 2) + "s (" + why + "), max duration " + FloatToStringPrec(duration, 1) + "s");
  }

  // Shortens the cooldown (the refill after it ends) by some seconds.
  private func CooldownSeconds(player: ref<PlayerPuppet>, osType: Int32, seconds: Float, why: String) -> Void {
    let stat = this.CooldownStat(osType);
    let recharge = GameInstance.GetStatsSystem(this.GetGameInstance()).GetStatValue(Cast<StatsObjectID>(player.GetEntityID()), stat);
    if recharge <= 0.0 {
      this.Log("cooldown cut skipped (" + why + "): no cooldown stat has a value (see Report)");
      return;
    }
    this.PoolAddPercent(player, this.ChargePool(osType), seconds / recharge * 100.0);
    this.Log("cooldown cut by " + FloatToStringPrec(seconds, 2) + "s (" + why + "), recharge " + FloatToStringPrec(recharge, 1) + "s from " + EnumValueToString("gamedataStatType", Cast<Int64>(EnumInt(stat))));
  }

  // A counted kill (from Sweep/OnKill). Extensions only apply while the same activation still runs:
  // a death noticed after it ended (the sweep checks 4 times a second) must not refill the charge.
  private func OnKillEvents(p: ref<OSEvoPending>) -> Void {
    if ArraySize(this.m_evFx) == 0 {
      return;
    }
    let player = GetPlayer(this.GetGameInstance());
    if !IsDefined(player) {
      return;
    }
    let osType = p.osType;
    let current = osType == 2 ? this.m_sandyAct : this.m_berserkAct;
    let running = osType == 2 ? this.m_sandyOn : this.m_berserkOn;
    if p.activation != current {
      return;
    }
    // counted toward the "when it ends" perks even if the death is seen a moment after the end
    this.EnsureSlots();
    this.m_actKills[osType] += 1;
    if p.melee {
      this.m_actMeleeKills[osType] += 1;
    }
    if !running {
      return;
    }
    let i = 0;
    while i < ArraySize(this.m_evFx) {
      let e = this.m_evFx[i];
      if this.m_evFxType[i] == osType {
        // 1: each kill extends by seconds, with an optional cap per activation (Militech Berserk: +5s)
        if e.cond == 1 {
          let amount = e.value;
          if e.value2 > 0.0 {
            amount = MinF(amount, e.value2 - this.m_actExtended[osType]);
          }
          if amount > 0.0 {
            this.m_actExtended[osType] += amount;
            this.ExtendSeconds(player, osType, amount, "kill");
          }
        }
        // 11: mid-air kill extends by seconds (Zetatech Sandevistan)
        if e.cond == 11 && p.airborne {
          this.ExtendSeconds(player, osType, e.value, "mid-air kill");
        }
        // 2: kill adds a percentage of a full charge (Apogee, Falcon "kill duration extension")
        if e.cond == 2 {
          this.PoolAddPercent(player, this.ChargePool(osType), e.value);
          this.Log("kill charge +" + FloatToStringPrec(e.value, 0) + "%");
        }
        // 3 / 4: headshot kill restores stamina / adds charge (Apogee)
        if e.cond == 3 && p.head {
          this.PoolAddPercent(player, gamedataStatPoolType.Stamina, e.value);
          this.Log("headshot kill: stamina +" + FloatToStringPrec(e.value, 0) + "%");
        }
        if e.cond == 4 && p.head {
          this.PoolAddPercent(player, this.ChargePool(osType), e.value);
          this.Log("headshot kill: charge +" + FloatToStringPrec(e.value, 0) + "%");
        }
      }
      i += 1;
    }
  }

  // A Sandevistan/Berserk just ended (seen by the tick).
  private func OnDeactivated(player: ref<PlayerPuppet>, osType: Int32) -> Void {
    // 0.0.9: how long it really ran (real time, +/- the 0.25s tick) and the charge it started with.
    // A run started below full charge is short by design: the game lets it start on whatever charge
    // is there. Logged before the early return so it shows even with no event perks.
    this.EnsureSlots();
    this.Log((osType == 2 ? "Sandevistan" : "Berserk") + " ran " + FloatToStringPrec(this.Now() - this.m_actStart[osType], 1)
      + "s, started at " + FloatToStringPrec(this.m_actStartCharge[osType], 0) + "% charge");
    if !this.Config().enabled || ArraySize(this.m_evFx) == 0 {
      return;
    }
    // 5: turned off early: give back a share of the charge that was left (Warp Dancer). "Early" =
    // more than 2% charge left on the last tick it was running (a run to empty ends near 0).
    this.EnsureSlots();
    let left = this.m_lastCharge[osType];
    let refund = this.EventSum(osType, 5);
    if refund > 0.0 && left > 2.0 {
      this.PoolAddPercent(player, this.ChargePool(osType), left * refund / 100.0);
      this.Log("early deactivation: refunded " + FloatToStringPrec(left * refund / 100.0, 1) + "% charge");
    }
    // 7: heal a percentage per kill made during this activation (BioDyne 10%, Militech 25%), max 100%
    let heal = this.EventSum(osType, 7) * Cast<Float>(this.m_actKills[osType]);
    if heal > 0.0 {
      this.PoolAddPercent(player, gamedataStatPoolType.Health, MinF(100.0, heal));
      this.Log("ended after " + IntToString(this.m_actKills[osType]) + " kills: healed " + FloatToStringPrec(MinF(100.0, heal), 0) + "%");
    }
    // 8: each melee kill shortens the next cooldown (Zetatech Berserk)
    let cut = this.EventSum(osType, 8) * Cast<Float>(this.m_actMeleeKills[osType]);
    if cut > 0.0 {
      this.CooldownSeconds(player, osType, cut, IntToString(this.m_actMeleeKills[osType]) + " melee kills");
    }
  }

  // 10: a quickhack reached one more target (spread hop, see OnUploadFinished): refund RAM
  // (Biotech: any quickhack, Canto: Blackwall Gateway only).
  private func OnSpreadHop(actionName: String) -> Void {
    let player = GetPlayer(this.GetGameInstance());
    if !IsDefined(player) {
      return;
    }
    let ram = 0.0;
    let i = 0;
    while i < ArraySize(this.m_evFx) {
      let e = this.m_evFx[i];
      if this.m_evFxType[i] == 1 && e.cond == 10 && (ArraySize(e.tokens) == 0 || e.MatchesName(actionName)) {
        ram += e.value;
      }
      i += 1;
    }
    if ram > 0.0 {
      GameInstance.GetStatPoolsSystem(this.GetGameInstance()).RequestChangingStatPoolValue(Cast<StatsObjectID>(player.GetEntityID()), gamedataStatPoolType.Memory, ram, player, false, false);
    }
    this.Log("spread hop: " + actionName + (ram > 0.0 ? ", refunded " + FloatToStringPrec(ram, 0) + " RAM" : ""));
  }

  // ================================================================ console (Cyber Engine Tweaks)
  public func Report() -> String {
    let text = "Chromepunk OS Evolution\n";
    let i = 0;
    while i < ArraySize(this.m_equipped) {
      let item = this.m_equipped[i];
      let into: Int32;
      let need: Int32;
      this.LevelProgress(item, into, need);
      text = text + "- " + OSEvoSystem.ModelName(item) + " (" + TDBID.ToStringDEBUG(ItemID.GetTDBID(item)) + "): level "
        + IntToString(this.LevelOf(item)) + ", " + IntToString(into) + " / " + IntToString(need) + " uses, " + this.LevelBonusText(item, this.LevelOf(item)) + "\n";
      i += 1;
    }
    i = 0;
    while i < ArraySize(this.m_codes) {
      text = text + this.ReportModel(this.m_codes[i]);
      i += 1;
    }
    if this.m_anyDeck5pp {
      text = text + this.ReportModel(100);
    }
    text = text + "stat modifiers applied: " + IntToString(ArraySize(this.m_mods)) + ", quickhack perks: " + IntToString(ArraySize(this.m_hackFx))
      + ", damage perks: " + IntToString(ArraySize(this.m_dmgFx)) + ", event perks: " + IntToString(ArraySize(this.m_evFx)) + "\n";
    let player = GetPlayer(this.GetGameInstance());
    if IsDefined(player) {
      let stats = GameInstance.GetStatsSystem(this.GetGameInstance());
      let sid = Cast<StatsObjectID>(player.GetEntityID());
      text = text + "Max RAM " + FloatToString(stats.GetStatValue(sid, gamedataStatType.Memory))
        + ", queue " + FloatToString(stats.GetStatValue(sid, gamedataStatType.QuickHackQueueSize))
        + ", spread targets " + FloatToString(stats.GetStatValue(sid, gamedataStatType.QuickHackSpreadNumber))
        + ", spread distance " + FloatToString(stats.GetStatValue(sid, gamedataStatType.QuickHackSpreadDistance))
        + ", Sandevistan duration " + FloatToString(stats.GetStatValue(sid, gamedataStatType.TimeDilationSandevistanDuration))
        // 0.0.8: the Berserk's real duration = charge pool max / drain rate (see ApplyBerserkSeconds)
        + ", Berserk full charge lasts " + FloatToStringPrec(this.BerserkPoolMax() / MaxF(0.001, stats.GetStatValue(sid, gamedataStatType.BerserkChargesDecayRate)), 1) + "s"
        // 0.0.9: the rest of the drain picture, to explain any gap between that and a measured run
        + " (pool max " + FloatToStringPrec(this.BerserkPoolMax(), 2)
        + ", drain start delay " + FloatToString(stats.GetStatValue(sid, gamedataStatType.BerserkChargesDecayStartDelay))
        + ", drain rate mult " + FloatToString(stats.GetStatValue(sid, gamedataStatType.BerserkChargesDecayRateMult)) + ")"
        // 0.0.7: every cooldown candidate (see CooldownStat), to confirm which one the game uses
        + "\ncooldown candidates: TimeDilationSandevistanRechargeDuration " + FloatToString(stats.GetStatValue(sid, gamedataStatType.TimeDilationSandevistanRechargeDuration))
        + ", SandevistanRechargeDuration " + FloatToString(stats.GetStatValue(sid, gamedataStatType.SandevistanRechargeDuration))
        + ", TimeDilationSandevistanCooldownBase " + FloatToString(stats.GetStatValue(sid, gamedataStatType.TimeDilationSandevistanCooldownBase))
        + ", BerserkRechargeDuration " + FloatToString(stats.GetStatValue(sid, gamedataStatType.BerserkRechargeDuration))
        + ", BerserkCooldownBase " + FloatToString(stats.GetStatValue(sid, gamedataStatType.BerserkCooldownBase))
        + ", BerserkChargesDecayRate " + FloatToString(stats.GetStatValue(sid, gamedataStatType.BerserkChargesDecayRate))
        + "\nin use: Sandevistan " + EnumValueToString("gamedataStatType", Cast<Int64>(EnumInt(this.CooldownStat(2))))
        + ", Berserk " + EnumValueToString("gamedataStatType", Cast<Int64>(EnumInt(this.CooldownStat(3))))
        + ", crit chance " + FloatToString(stats.GetStatValue(sid, gamedataStatType.CritChance)) + "\n";
    }
    ModLog(n"ChromepunkOSEvo", text);
    return text;
  }

  private func ReportModel(code: Int32) -> String {
    let m = this.DB().Model(code);
    let text = "  " + (IsDefined(m) ? m.name : IntToString(code)) + ": stage " + IntToString(this.StageOf(code)) + "\n";
    let st = 1;
    while st <= 3 {
      let s = this.DB().Stage(code, st);
      if IsDefined(s) {
        // metric 11 (seconds in slow motion) is saved in tenths: shown in seconds
        let div = s.metric == 11 ? 10 : 1;
        text = text + "    stage " + IntToString(st) + " \"" + s.title + "\": " + IntToString(this.Value(code, s.metric) / div) + " / " + IntToString(this.Goal(s) / div)
          + " (" + s.metricLabel + ")\n";
      }
      st += 1;
    }
    return text;
  }

  // Adds to a stage counter of every equipped Tier 5++ model that uses it. Metric names as in the CSV.
  public func CheatMetric(metricKey: String, amount: Int32) -> String {
    let metric = OSEvoSystem.MetricCode(metricKey);
    if metric == 0 {
      return "unknown metric: " + metricKey;
    }
    let i = 0;
    while i < ArraySize(this.m_codes) {
      this.AddMetric(this.m_codes[i], metric, metric == 11 ? amount * 10 : amount);
      i += 1;
    }
    if this.m_anyDeck5pp {
      this.AddMetric(100, metric, amount);
    }
    return this.Report();
  }

  // Adds uses to every equipped operating system (base leveling).
  public func CheatUses(amount: Int32) -> String {
    let i = 0;
    while i < ArraySize(this.m_equipped) {
      this.AddUse(this.m_equipped[i], amount);
      i += 1;
    }
    return this.Report();
  }

  // Wipes all progress (levels and stages). For testers.
  public func ResetAll() -> String {
    ArrayClear(this.m_keys);
    ArrayClear(this.m_vals);
    ArrayClear(this.m_lvlRecords);
    ArrayClear(this.m_lvlUses);
    this.m_signature = "";
    return "Chromepunk OS Evolution: all progress reset";
  }

  // Metric names as in the CSV's metric_key column -> saved metric codes.
  public static func MetricCode(key: String) -> Int32 {
    let names: array<String> = ["uploads", "uploads_global", "kills_active", "streak", "headshot_kills_active", "airborne_kills_active", "melee_kills_active", "close_kills_active", "landing_hits", "blunt_or_slam_kills_active", "dilated_seconds", "activations"];
    let i = 0;
    while i < ArraySize(names) {
      if Equals(names[i], key) {
        return i + 1;
      }
      i += 1;
    }
    return 0;
  }
}
