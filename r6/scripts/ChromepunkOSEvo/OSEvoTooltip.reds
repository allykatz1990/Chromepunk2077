// Chromepunk 2077: OS Evolution - tooltips: title after the name, level line, stages and progress
// Copyright (C) 2026 the Chromepunk 2077 authors. Written with AI assistance.
//
// This program is free software: you can redistribute it and/or modify it under the terms of the
// GNU General Public License as published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version. It is distributed WITHOUT ANY WARRANTY. See the
// GNU General Public License for details: https://www.gnu.org/licenses/
//
// History, so the next maintainer doesn't repeat it:
//  - 0.0.1 put lines into the weapon stat list (Weaponpunk's hooks). Nothing showed for cyberware.
//  - 0.0.2 put them into the description text. Still nothing on the Cyberware screen: vanilla decks
//    have no description, and in the deck tooltip's layout that text box never shows.
//  - 0.0.3 (this file) uses only paths that the game itself draws for operating systems:
//      * the LEVEL LINE is appended to the item-type line ("Cyberdeck", "Sandevistan"), the same
//        trick Weaponpunk uses for its weapon level line, which is proven in game;
//      * the STAGES on decks are added as extra entries of the deck's own ability list
//        (CyberdeckTooltip.GetAbilities), so the game draws them with its own bullet widget;
//      * the STAGES on Sandevistans/Berserks go at the end of the item description (the lore text
//        at the bottom of the tooltip).
//  - 0.0.3 tested: decks work. Sandevistans/Berserks showed nothing: the Cyberware screen draws them
//    with the OLDER item tooltip (ItemTooltipCommonController + ItemTooltipHeaderController in
//    cyberpunk/UI/tooltips/itemTooltipController.swift), not NewItemTooltipCommonController. Hooks
//    for both are kept, so the inventory (new tooltip) and the Cyberware screen (old one) both work.
// Which tooltip the Cyberware screen uses: ripperdoc.swift ShowCWTooltip picks n"cyberdeckTooltip"
// for items tagged Cyberdeck and n"itemTooltip" otherwise, both through UIInventoryItemTooltipWrapper
// (the NEW_ code path).

public abstract class OSEvoTooltip {
  // The name line gets the newest stage title after it, for example: Militech Berserk "Bloodthirsty".
  public static func AddTitle(nameText: inkTextRef, item: ItemID) -> Void {
    let sys = OSEvoSystem.Get(GetGameInstance());
    if !IsDefined(sys) || !sys.Config().enabled || !ItemID.IsValid(item) {
      return;
    }
    let code = sys.DB().CodeForRecord(ItemID.GetTDBID(item));
    if code <= 0 {
      return;
    }
    let title = sys.ShownTitle(code);
    if Equals(title, "") {
      return;
    }
    let quoted = OSEvoText.TitleQuote(title);
    let name = inkTextRef.GetText(nameText);
    if !StrContains(name, quoted) {
      inkTextRef.SetText(nameText, name + " " + quoted);
    }
  }

  // "OS level 3 - 12 / 33 uses - +3 Max RAM", or "" (not an operating system, or leveling off).
  public static func LevelLine(item: ItemID) -> String {
    let sys = OSEvoSystem.Get(GetGameInstance());
    if !IsDefined(sys) || !sys.Config().enabled || !sys.Config().leveling || !ItemID.IsValid(item) || OSEvoSystem.OSType(item) == 0 {
      return "";
    }
    let into: Int32;
    let need: Int32;
    sys.LevelProgress(item, into, need);
    let level = sys.LevelOf(item);
    let capped = sys.Config().levelCap > 0 && level >= sys.Config().levelCap;
    return OSEvoText.LevelLine(level, into, need, capped, sys.LevelBonusText(item, level));
  }

  // Appends the level line under the item-type text, once (tooltips can update more than once).
  // The type text is often a translation KEY, not the words ("Cyberdeck" on the deck tooltip). 0.0.3's
  // first build appended to the raw key, the lookup then failed and "Cyberdeck" showed blank. So the
  // key is translated first (the way Weaponpunk does: GetLocalizedText(key) + suffix); plain text,
  // which has no translation, is kept as it is.
  public static func AddLevelLine(typeText: inkTextRef, item: ItemID) -> Void {
    let line = OSEvoTooltip.LevelLine(item);
    if Equals(line, "") {
      return;
    }
    let current = inkTextRef.GetText(typeText);
    if StrContains(current, line) {
      return;
    }
    let shown = GetLocalizedText(current);
    if StrLen(shown) == 0 {
      shown = current;
    }
    inkTextRef.SetText(typeText, shown + "\n" + line);
  }

  // The stage details grouped one entry per stage (header, its perks, progress), for the deck's
  // ability bullets. Empty when "Details in tooltips" is off or the item isn't a Tier 5++ model.
  public static func StageBlocks(item: ItemID) -> array<String> {
    let blocks: array<String>;
    let lines = OSEvoTooltip.Lines(item);
    let current = "";
    let i = 0;
    while i < ArraySize(lines) {
      let line = lines[i];
      // a line that isn't indented starts a new block (stage headers and the universal header)
      if !StrBeginsWith(line, " ") {
        if NotEquals(current, "") {
          ArrayPush(blocks, current);
        }
        current = line;
      } else {
        current = current + "\n" + line;
      }
      i += 1;
    }
    if NotEquals(current, "") {
      ArrayPush(blocks, current);
    }
    return blocks;
  }

  // Appends the stage details to a description text, once.
  public static func AppendStages(desc: inkTextRef, item: ItemID) -> Void {
    let blocks = OSEvoTooltip.StageBlocks(item);
    if ArraySize(blocks) == 0 {
      return;
    }
    let text = "";
    let i = 0;
    while i < ArraySize(blocks) {
      text = text + "\n" + blocks[i];
      i += 1;
    }
    let current = inkTextRef.GetText(desc);
    if !StrContains(current, text) {
      inkTextRef.SetText(desc, current + "\n" + text);
    }
  }

  // Stage lines: headers (not indented), perks and progress (indented). Empty for anything that
  // isn't a Tier 5++ operating system.
  public static func Lines(item: ItemID) -> array<String> {
    let lines: array<String>;
    let sys = OSEvoSystem.Get(GetGameInstance());
    if !IsDefined(sys) || !sys.Config().enabled || !ItemID.IsValid(item) || OSEvoSystem.OSType(item) == 0 {
      return lines;
    }
    // the level line is not part of this list since 0.0.3: it goes on the item-type line
    if !sys.Config().tooltipDetails {
      return lines;
    }
    let code = sys.DB().CodeForRecord(ItemID.GetTDBID(item));
    if code <= 0 {
      return lines;
    }
    OSEvoTooltip.StageLines(sys, code, lines);
    // 0.0.5: the universal deck titles stay hidden too, until the first one is earned
    let m = sys.DB().Model(code);
    if IsDefined(m) && m.osType == 1 && sys.StageOf(100) > 0 {
      ArrayPush(lines, OSEvoText.UniversalHeader());
      OSEvoTooltip.StageLines(sys, 100, lines);
    }
    return lines;
  }

  // EARNED titles only, each with its perks.
  // 0.0.5 (author's request after 0.0.4 tested OK): the title system is hidden again, like
  // Weaponpunk's. Until 0.0.4 this also listed the next locked stage with its title, goal and
  // progress; that is gone, so nothing in game hints at a title before it is earned. Stage numbers
  // are not shown either (they would tell the player more stages exist). The goals and progress are
  // still in the console Report() for testers and in SPOILERS.md.
  private static func StageLines(sys: ref<OSEvoSystem>, code: Int32, out lines: array<String>) -> Void {
    let reached = sys.StageOf(code);
    let st = 1;
    while st <= reached {
      let s = sys.DB().Stage(code, st);
      if IsDefined(s) {
        ArrayPush(lines, OSEvoText.TitleHeader(s.title));
        let k = 0;
        while k < ArraySize(s.clauses) {
          ArrayPush(lines, OSEvoText.Clause(s.clauses[k], s.live[k]));
          k += 1;
        }
      }
      st += 1;
    }
  }
}


// ---- item tooltip: Sandevistans and Berserks on the Cyberware screen, every OS in the inventory
// cyberpunk/UI/tooltips/newTooltip/newItemTooltip.swift: NewItemTooltipHeaderController
@wrapMethod(NewItemTooltipHeaderController)
public func Update(data: ref<MinimalItemTooltipData>) -> Void {
  wrappedMethod(data);
  if IsDefined(data) {
    OSEvoTooltip.AddTitle(this.m_itemNameText, data.itemID);
    OSEvoTooltip.AddLevelLine(this.m_itemTypeText, data.itemID);
  }
}

@wrapMethod(NewItemTooltipHeaderController)
public final func NEW_Update(data: wref<UIInventoryItem>, comparisonData: wref<UIInventoryItemComparisonManager>) -> Void {
  wrappedMethod(data, comparisonData);
  if IsDefined(data) {
    OSEvoTooltip.AddTitle(this.m_itemNameText, data.GetID());
    OSEvoTooltip.AddLevelLine(this.m_itemTypeText, data.GetID());
  }
}

// the description module (gameplay text): stage details for Sandevistans and Berserks
@wrapMethod(NewItemTooltipDescriptionModule)
public func Update(data: ref<MinimalItemTooltipData>) -> Void {
  wrappedMethod(data);
  if IsDefined(data) {
    OSEvoTooltip.AppendStages(this.m_descriptionText, data.itemID);
  }
}

@wrapMethod(NewItemTooltipDescriptionModule)
public func NEW_Update(data: wref<UIInventoryItem>) -> Void {
  wrappedMethod(data);
  if IsDefined(data) {
    OSEvoTooltip.AppendStages(this.m_descriptionText, data.GetID());
  }
}

// ---- cyberdeck tooltip (Cyberware screen, ripperdocs)
// cyberpunk/UI/tooltips/cyberdeckTooltip.swift. Title and level line after the layout is built...
@wrapMethod(CyberdeckTooltip)
protected final func UpdateLayout() -> Void {
  wrappedMethod();
  if IsDefined(this.m_data) {
    let item = InventoryItemData.GetID(this.m_data.inventoryItemData);
    OSEvoTooltip.AddTitle(this.m_itemNameText, item);
    OSEvoTooltip.AddLevelLine(this.m_itemTypeText, item);
  }
}

@wrapMethod(CyberdeckTooltip)
protected final func NEW_UpdateLayout() -> Void {
  wrappedMethod();
  if IsDefined(this.m_itemData) {
    let item = this.m_itemData.GetID();
    OSEvoTooltip.AddTitle(this.m_itemNameText, item);
    OSEvoTooltip.AddLevelLine(this.m_itemTypeText, item);
  }
}

// ...and the stage details as extra entries of the deck's ability list. UpdateAbilities sizes the
// list to whatever this returns and draws every entry with the game's own bullet widget
// (CyberdeckStatController.Setup shows `Description`), so nothing here builds UI by hand.
@wrapMethod(CyberdeckTooltip)
protected final func GetAbilities(itemData: ref<gameItemData>, itemRecord: wref<Item_Record>) -> array<InventoryItemAbility> {
  let abilities = wrappedMethod(itemData, itemRecord);
  if !IsDefined(itemData) {
    return abilities;
  }
  let blocks = OSEvoTooltip.StageBlocks(itemData.GetID());
  let i = 0;
  while i < ArraySize(blocks) {
    ArrayPush(abilities, new InventoryItemAbility(n"", "", blocks[i], new UILocalizationDataPackage()));
    i += 1;
  }
  return abilities;
}

// ---- older item tooltip: what the Cyberware screen uses for Sandevistans and Berserks (added 0.0.3)
// cyberpunk/UI/tooltips/itemTooltipController.swift: ItemTooltipHeaderController (name, tier, type)
@wrapMethod(ItemTooltipHeaderController)
public func Update(data: ref<MinimalItemTooltipData>) -> Void {
  wrappedMethod(data);
  if IsDefined(data) {
    OSEvoTooltip.AddTitle(this.m_itemNameText, data.itemID);
    OSEvoTooltip.AddLevelLine(this.m_itemTypeText, data.itemID);
  }
}

@wrapMethod(ItemTooltipHeaderController)
public func NEW_Update(data: wref<UIInventoryItem>) -> Void {
  wrappedMethod(data);
  if IsDefined(data) {
    OSEvoTooltip.AddTitle(this.m_itemNameText, data.GetID());
    OSEvoTooltip.AddLevelLine(this.m_itemTypeText, data.GetID());
  }
}

// ItemTooltipCommonController: the stage details go at the end of the description (the lore text at
// the bottom). The wrapper is shown even if the item had no description of its own.
@wrapMethod(ItemTooltipCommonController)
protected func UpdateLayout() -> Void {
  wrappedMethod();
  if IsDefined(this.m_data) && ArraySize(OSEvoTooltip.StageBlocks(this.m_data.itemID)) > 0 {
    OSEvoTooltip.AppendStages(this.m_descriptionText, this.m_data.itemID);
    inkWidgetRef.SetVisible(this.m_descriptionWrapper, true);
  }
}

@wrapMethod(ItemTooltipCommonController)
private final func NEW_UpdateLayout() -> Void {
  wrappedMethod();
  if IsDefined(this.m_itemData) && ArraySize(OSEvoTooltip.StageBlocks(this.m_itemData.GetID())) > 0 {
    OSEvoTooltip.AppendStages(this.m_descriptionText, this.m_itemData.GetID());
    inkWidgetRef.SetVisible(this.m_descriptionWrapper, true);
  }
}
