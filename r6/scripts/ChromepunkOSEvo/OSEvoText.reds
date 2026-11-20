// Chromepunk 2077: OS Evolution - player-facing text
// Copyright (C) 2026 the Chromepunk 2077 authors. Written with AI assistance. GPL-3.0-or-later.
//
// Every sentence the mod shows is built here, so translations only need to touch this file.
// v0.0.1 is English only; before the 0.5 release these move to Codeware localization keys the
// same way Weaponpunk does it (WLvlLang.reds), so translation add-ons can plug in.

public abstract class OSEvoText {
  // 0.0.5: no stage number in player-facing text (the title system is hidden; a number would
  // tell the player more titles exist). The `stage` parameter stays for the debug log and callers.
  public static func StageReached(model: String, stage: Int32, title: String) -> String {
    return model + " earned a title: \"" + title + "\"";
  }

  // Card notice when a title is earned.
  public static func TitleEarnedNotice(title: String) -> String {
    return "TITLE EARNED: \"" + title + "\"";
  }

  // Tooltip header of an earned title (0.0.5: replaces StageHeader in tooltips).
  public static func TitleHeader(title: String) -> String {
    return "\"" + title + "\"";
  }

  public static func LevelReached(model: String, level: Int32, bonus: String) -> String {
    return model + " reached level " + IntToString(level) + " (" + bonus + ")";
  }

  public static func RamBonus(amount: Int32) -> String {
    return "+" + IntToString(amount) + " Max RAM";
  }

  public static func SecondsBonus(seconds: Float) -> String {
    return "+" + FloatToStringPrec(seconds, 2) + "s duration";
  }

  public static func TitleQuote(title: String) -> String {
    return "\"" + title + "\"";
  }

  // Tooltip lines ------------------------------------------------------------
  // (0.0.5: StageHeader and Progress removed: locked titles and their progress are never shown now)
  // Two lines since 0.0.3 (requested after the first look in game): the level and uses on the first,
  // the bonus it gives on the second.
  public static func LevelLine(level: Int32, into: Int32, need: Int32, capped: Bool, bonus: String) -> String {
    if capped {
      return "OS level " + IntToString(level) + " (max)\n" + bonus;
    }
    return "OS level " + IntToString(level) + " - " + IntToString(into) + " / " + IntToString(need) + " uses\n" + bonus;
  }

  public static func Clause(text: String, isLive: Bool) -> String {
    return "   " + text + (isLive ? "" : " (coming in a later build)");
  }

  public static func UniversalHeader() -> String {
    return "Netrunner titles (any Tier 5++ deck)";
  }
}
