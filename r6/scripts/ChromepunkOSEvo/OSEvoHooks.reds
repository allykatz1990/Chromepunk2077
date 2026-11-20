// Chromepunk 2077: OS Evolution - hooks into the game
// Copyright (C) 2026 the Chromepunk 2077 authors. Written with AI assistance.
//
// This program is free software: you can redistribute it and/or modify it under the terms of the
// GNU General Public License as published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version. It is distributed WITHOUT ANY WARRANTY. See the
// GNU General Public License for details: https://www.gnu.org/licenses/
//
// Every hook WRAPS the original function (wrappedMethod is always called), so other mods' changes
// to the same functions still run. Where each one lives in the game's scripts is noted so the next
// maintainer can re-check them after a game patch.

// ---- start the tick once the player exists (after every load too)
// cyberpunk/player/player.swift: PlayerPuppet.OnGameAttached
@wrapMethod(PlayerPuppet)
protected cb func OnGameAttached() -> Bool {
  let result = wrappedMethod();
  let sys = OSEvoSystem.Get(this.GetGame());
  if IsDefined(sys) {
    sys.Start();
  }
  return result;
}

// ---- a quickhack upload by the player finished (one call per finished upload, NPCs and devices)
// cyberpunk/managers/rpgManager.swift: QuickHackUploadListener.SendUploadFinishedEvent.
// The game itself checks m_action.GetExecutor().IsPlayer() in this function, so we do the same.
@wrapMethod(QuickHackUploadListener)
protected final func SendUploadFinishedEvent() -> Void {
  wrappedMethod();
  if IsDefined(this.m_action) {
    let executor = this.m_action.GetExecutor();
    if IsDefined(executor) && executor.IsPlayer() {
      let sys = OSEvoSystem.Get(this.m_gameInstance);
      if IsDefined(sys) {
        sys.OnUploadFinished(this.m_action);
      }
    }
  }
}

// ---- upload time of a quickhack (shown in the quickhack menu and used for the real upload)
// cyberpunk/devices/core/baseDeviceActions.swift: BaseScriptableAction.GetActivationTime.
// Subclasses call super, so this one wrap covers NPC, device and vehicle quickhacks.
@wrapMethod(BaseScriptableAction)
public func GetActivationTime() -> Float {
  let time = wrappedMethod();
  if time <= 0.0 {
    return time;
  }
  let executor = this.GetExecutor();
  if !IsDefined(executor) || !executor.IsPlayer() {
    return time;   // NPC netrunners hacking V are left alone
  }
  let sys = OSEvoSystem.Get(executor.GetGame());
  if !IsDefined(sys) {
    return time;
  }
  let bonus = sys.UploadBonus(this);
  if bonus > 0.0 {
    return time / (1.0 + bonus / 100.0);
  }
  return time;
}

// ---- RAM cost of a quickhack
// cyberpunk/devices/core/baseDeviceActions.swift: BaseScriptableAction.GetCost (ScriptableDeviceAction
// overrides it with `return super.GetCost()`, so the wrap applies there too).
@wrapMethod(BaseScriptableAction)
public func GetCost() -> Int32 {
  let cost = wrappedMethod();
  if cost <= 0 {
    return cost;
  }
  let executor = this.GetExecutor();
  if !IsDefined(executor) || !executor.IsPlayer() {
    return cost;
  }
  let sys = OSEvoSystem.Get(executor.GetGame());
  if !IsDefined(sys) {
    return cost;
  }
  return sys.AdjustCost(this, cost);
}

// ---- every hit the player lands (damage perks, and kills while a Sandevistan/Berserk runs)
// cyberpunk/damage/damageSystem.swift: DamageSystem.ProcessLocalizedDamage. Weaponpunk wraps the
// same function; both wraps run, each multiplies the hit by its own bonus.
@wrapMethod(DamageSystem)
private final func ProcessLocalizedDamage(hitEvent: ref<gameHitEvent>) -> Void {
  let instigator = hitEvent.attackData.GetInstigator();
  if IsDefined(instigator) && instigator.IsPlayer() && IsDefined(hitEvent.target) && !hitEvent.target.IsPlayer() {
    let sys = OSEvoSystem.Get(instigator.GetGame());
    if IsDefined(sys) {
      // before the original runs, so the damage multiplier is part of this hit's damage
      sys.OnPlayerHit(hitEvent);
    }
  }
  wrappedMethod(hitEvent);
}
