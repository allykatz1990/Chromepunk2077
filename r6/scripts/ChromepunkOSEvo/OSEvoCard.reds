// Chromepunk 2077: OS Evolution - the on-screen OS card
// Copyright (C) 2026 the Chromepunk 2077 authors. Written with AI assistance.
//
// This program is free software: you can redistribute it and/or modify it under the terms of the
// GNU General Public License as published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version. It is distributed WITHOUT ANY WARRANTY. See the
// GNU General Public License for details: https://www.gnu.org/licenses/
//
// ADDED IN 0.0.2 (the author tested 0.0.1 and saw no feedback at all: 0.0.1 only had on-screen
// messages at level-ups and stage unlocks, which a few uses never reach).
// Adapted from Weaponpunk's weapon card (WLvlCard.reds): same drawing helpers, same HUD layer, same
// font. Shown when a Sandevistan/Berserk is activated and after every finished quickhack upload.
// Defaults to the RIGHT edge so it never sits on top of Weaponpunk's card (middle left).
// Needs Codeware (GameInstance.GetInkSystem / GetVirtualWindow come from it).

public class OSEvoCardHide extends DelayCallback {
  public let sys: wref<OSEvoSystem>;
  public let token: Int32;

  public func Call() -> Void {
    if IsDefined(this.sys) && this.sys.CardToken() == this.token {
      OSEvoCard.Remove();
    }
  }
}

public abstract class OSEvoCard {
  // Layout is in the HUD layer's own units (3840 x 2160 at every resolution), as in Weaponpunk.
  public static func Width() -> Float { return 760.0; }

  public static func Color(r: Float, g: Float, b: Float, a: Float) -> HDRColor {
    let c: HDRColor;
    c.Red = r;
    c.Green = g;
    c.Blue = b;
    c.Alpha = a;
    return c;
  }

  private static func Window() -> wref<inkCompoundWidget> {
    let layer = GameInstance.GetInkSystem().GetLayer(n"inkHUDLayer");
    if !IsDefined(layer) {
      return null;
    }
    return layer.GetVirtualWindow();
  }

  public static func Remove() -> Void {
    let win = OSEvoCard.Window();
    if !IsDefined(win) {
      return;
    }
    let old = win.GetWidgetByPathName(n"OSEvoCard");
    if IsDefined(old) {
      win.RemoveChild(old);
    }
  }

  private static func AddRect(parent: wref<inkCompoundWidget>, x: Float, y: Float, w: Float, h: Float, c: HDRColor) -> Void {
    let r = new inkRectangle();
    r.SetAnchor(inkEAnchor.TopLeft);
    r.SetMargin(x, y, 0.0, 0.0);
    r.SetSize(w, h);
    r.SetTintColor(c);
    r.SetOpacity(c.Alpha);
    r.Reparent(parent);
  }

  private static func AddText(parent: wref<inkCompoundWidget>, x: Float, y: Float, text: String, size: Int32, style: CName, c: HDRColor) -> Void {
    let t = new inkText();
    t.SetAnchor(inkEAnchor.TopLeft);
    t.SetMargin(x, y, 0.0, 0.0);
    t.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
    t.SetFontStyle(style);
    t.SetFontSize(size);
    t.SetTintColor(c);
    t.SetFitToContent(true);
    t.SetText(text);
    t.Reparent(parent);
  }

  // Shows the card for one operating system. notice: an extra highlighted line ("LEVEL UP", a
  // stage title...), "" for none.
  public static func Show(sys: ref<OSEvoSystem>, item: ItemID, notice: String) -> Void {
    if !IsDefined(sys) || !ItemID.IsValid(item) || !sys.Config().showCard {
      return;
    }
    let win = OSEvoCard.Window();
    if !IsDefined(win) {
      return;
    }
    OSEvoCard.Remove();
    let cfg = sys.Config();
    let w = OSEvoCard.Width();
    let code = sys.DB().CodeForRecord(ItemID.GetTDBID(item));
    let stageText = OSEvoCard.StageText(sys, code);
    // height: name 70 + level 50 + bar 40 + uses 44, then the optional lines
    let h = 204.0;
    if NotEquals(stageText, "") {
      h += 42.0;
    }
    if NotEquals(notice, "") {
      h += 46.0;
    }
    let root = new inkCanvas();
    root.SetName(n"OSEvoCard");
    root.SetSize(w, h);
    let cyan = OSEvoCard.Color(0.37, 0.96, 0.98, 1.0);    // cyberware cyan, so it reads apart from Weaponpunk's yellow
    let yellow = OSEvoCard.Color(0.99, 0.93, 0.04, 1.0);
    let white = OSEvoCard.Color(0.95, 0.95, 0.95, 1.0);
    let grey = OSEvoCard.Color(0.62, 0.65, 0.70, 1.0);
    OSEvoCard.AddRect(root, 0.0, 0.0, w, h, OSEvoCard.Color(0.03, 0.03, 0.04, 0.95));
    OSEvoCard.AddRect(root, w - 8.0, 0.0, 8.0, h, cyan);

    // name, with the Tier 5++ title in quotes after it
    let nameLine = OSEvoSystem.ModelName(item);
    if code > 0 {
      let title = sys.ShownTitle(code);
      if NotEquals(title, "") {
        nameLine = nameLine + " " + OSEvoText.TitleQuote(title);
      }
    }
    OSEvoCard.AddText(root, 30.0, 12.0, nameLine, StrLen(nameLine) > 30 ? 36 : 44, n"Semi-Bold", white);

    // level line and use bar (base leveling)
    let level = sys.LevelOf(item);
    let into: Int32;
    let need: Int32;
    sys.LevelProgress(item, into, need);
    let capped = cfg.levelCap > 0 && level >= cfg.levelCap;
    OSEvoCard.AddText(root, 30.0, 70.0, "OS LEVEL " + IntToString(level) + "    " + sys.LevelBonusText(item, level), 36, n"Medium", cyan);
    let barW = w - 60.0;
    let fill = capped ? 1.0 : MinF(1.0, Cast<Float>(into) / Cast<Float>(Max(1, need)));
    OSEvoCard.AddRect(root, 30.0, 124.0, barW, 10.0, OSEvoCard.Color(0.25, 0.26, 0.29, 1.0));
    if fill > 0.0 {
      OSEvoCard.AddRect(root, 30.0, 124.0, barW * fill, 10.0, cyan);
    }
    let usesText = capped ? "Max level" : IntToString(into) + " / " + IntToString(need) + (OSEvoSystem.OSType(item) == 1 ? " uploads" : " activations");
    OSEvoCard.AddText(root, 30.0, 142.0, usesText, 30, n"Medium", grey);

    let y = 190.0;
    if NotEquals(stageText, "") {
      OSEvoCard.AddText(root, 30.0, y, stageText, 30, n"Medium", white);
      y += 42.0;
    }
    if NotEquals(notice, "") {
      OSEvoCard.AddText(root, 30.0, y, notice, 32, n"Semi-Bold", yellow);
    }

    // place it: left or right edge, at the height set in Mod Settings (0 bottom, 100 top)
    let pct = Cast<Float>(Max(0, Min(100, cfg.cardHeight))) / 100.0;
    let top = (1.0 - pct) * MaxF(0.0, 2160.0 - h);
    if cfg.cardSide == 1 {
      root.SetAnchor(inkEAnchor.TopLeft);
      root.SetAnchorPoint(0.0, 0.0);
      root.SetMargin(96.0, top, 0.0, 0.0);
    } else {
      root.SetAnchor(inkEAnchor.TopRight);
      root.SetAnchorPoint(1.0, 0.0);
      root.SetMargin(0.0, top, 96.0, 0.0);
    }
    root.Reparent(win);

    let cb = new OSEvoCardHide();
    cb.sys = sys;
    cb.token = sys.NextCardToken();
    GameInstance.GetDelaySystem(sys.GetGameInstance()).DelayCallback(cb, cfg.cardSeconds, false);
  }

  // 0.0.5: always "" — the title system is hidden again (author's request), so the card no longer
  // shows the next title or its progress. Earned titles still show after the name, and a title
  // earned since the last card shows as the highlighted notice. Kept as a function (instead of
  // deleting the line from Show) so a "show progress" option is easy to add back later.
  private static func StageText(sys: ref<OSEvoSystem>, code: Int32) -> String {
    return "";
  }

}
