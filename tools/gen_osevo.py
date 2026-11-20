#!/usr/bin/env python3
"""Chromepunk 2077: OS Evolution - data generator.

Reads data/cyberware_5plusplus_titles.csv (the one file you edit) and writes
r6/scripts/ChromepunkOSEvo/OSEvoData.reds (never edit that by hand: it is overwritten).

Why a generator: redscript cannot read a CSV while the game runs, so the table is turned into
code at build time. The game's stat names and hack categories are written straight into the
script, so a typo in the CSV becomes a compile error in redscript instead of a silent no-op.

Run from the project folder:   python3 tools/gen_osevo.py
(also rewrites SPOILERS.md, the player-facing description of the hidden titles, since 0.0.5)

CSV columns used
  model_name, tweakdb_record_id, stage, title_name, unlock_metric, metric_key, unlock_threshold,
  perk_summary (clauses split by "; "), effects (one entry per clause, split by " | ")

Effects mini-language (one entry per perk clause; several effects in one clause are split by ",")
  later                         clause not live yet; the tooltip marks it "coming in a later build"
  stat.<Stat>+<v>               player stat, flat (+v), while the model is equipped
  stat.<Stat>%<p>               player stat, percent (+p%), while the model is equipped
                                (percent bonuses add up: +20% and +40% make +60%)
  active.<Stat>+v / %p          same, only while this Sandevistan/Berserk is active
  air.<Stat>+v / %p             same, only while active AND V is off the ground
  oc.<Stat>+v / %p              same, only while the deck's Overclock is running
  up.all <p>                    upload speed +p% for every quickhack
  up.cat.<HackCategory> <p>     ... for one category (CovertHack, ControlHack, DamageHack, UltimateHack)
  up.hack.<A>/<B> <p>           ... for quickhacks whose action name contains A or B
  up.undetected <p>             ... while V is not in combat
  up.oc <p>                     ... while Overclock is running
  up.queued <p>                 ... when the target is already busy with an upload (queued hack)
  up.queuefull <p>              ... when this hack fills the target's queue
  ram.all <n>                   RAM cost +n (negative = cheaper) for every quickhack
  ram.cat.<HackCategory> <n>    ... for one category
  ram.hack.<A>/<B> <n>          ... by action name
  ram.device <n>                ... for device and vehicle quickhacks
  ram.queuedpct <p>             RAM cost +p% (negative = cheaper) for queued quickhacks
  dmg.air <p>                   +p% damage on hits while airborne and active
  dmg.melee <p>                 +p% melee damage while active
  dmg.landing <p>               +p% Superhero Landing damage
  (0.0.6)
  up.camera <p>                 upload speed +p% while uploading through a camera / controlled device
  ram.afterctrl <n>             RAM cost +n for a Combat hack on a target already receiving a Control hack
  ev.kill.extend <s>[/cap]      each kill while active extends it by s seconds (optional cap per activation)
  ev.kill.charge <p>            each kill while active adds p% of a full charge
  ev.airkill.extend <s>         each mid-air kill while active extends it by s seconds
  ev.headkill.stamina <p>       each headshot kill while active restores p% stamina
  ev.headkill.charge <p>        each headshot kill while active adds p% charge
  ev.early.refund <p>           turning it off early gives back p% of the charge left
  ev.airstart.extend <s>        activating it mid-air adds s seconds
  ev.end.heal <p>               when it ends: heal p% per kill made during that activation
  ev.meleekill.cooldown <s>     each melee kill while active shortens the next cooldown by s seconds
  ev.landing.extend <s>         each enemy hit by a Superhero Landing extends it by s seconds
  ev.spread.ram <n>[/A/B]       each spread hop refunds n RAM (optionally only for quickhacks named A or B)
"""
import csv, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
SRC = os.path.join(ROOT, 'data', 'cyberware_5plusplus_titles.csv')
OUT = os.path.join(ROOT, 'r6', 'scripts', 'ChromepunkOSEvo', 'OSEvoData.reds')

# Metric codes are SAVED in players' saves (as model*100 + metric). Never renumber them.
METRICS = {
    'uploads': 1, 'uploads_global': 2, 'kills_active': 3, 'streak': 4,
    'headshot_kills_active': 5, 'airborne_kills_active': 6, 'melee_kills_active': 7,
    'close_kills_active': 8, 'landing_hits': 9, 'blunt_or_slam_kills_active': 10,
    'dilated_seconds': 11, 'activations': 12,
}
# Model codes are SAVED too. New models get new numbers; never reuse or renumber.
MODEL_CODES = {
    'Arasaka Mk.5': 1, 'Biotech Σ Mk.4': 2, 'Militech Canto Mk.6': 3, 'Militech Paraline Mk.5': 4,
    'NetWatch Netdriver Mk.1': 5, 'Raven Microcyber Mk.3': 6, 'Tetratronic Rippler Mk.5': 7,
    'Dynalar Sandevistan': 11, 'Militech "Apogee" Sandevistan': 12, 'Militech "Falcon" Sandevistan': 13,
    'QianT "Warp Dancer" Sandevistan': 14, 'Zetatech Sandevistan': 15,
    'BioDyne Berserk': 21, 'Militech Berserk': 22, 'Moore Tech Berserk': 23, 'Zetatech Berserk': 24,
    'ALL_TIER_5PP_CYBERDECKS': 100,
}
OS_TYPE = {'Cyberdeck': 1, 'Sandevistan': 2, 'Berserk': 3}
CATS = {'CovertHack', 'ControlHack', 'DamageHack', 'UltimateHack', 'DeviceHack', 'VehicleHack'}
UPCOND = {'all': 0, 'cat': 1, 'hack': 2, 'undetected': 3, 'oc': 4, 'queued': 5, 'queuefull': 6, 'camera': 8}
RAMCOND = {'all': 0, 'cat': 1, 'hack': 2, 'device': 7, 'queuedpct': 5, 'afterctrl': 9}
# 0.0.6 events; the codes are only used at run time (not saved), see OSEvoDB.reds
EVENTS = {'kill.extend': 1, 'kill.charge': 2, 'headkill.stamina': 3, 'headkill.charge': 4, 'early.refund': 5,
          'airstart.extend': 6, 'end.heal': 7, 'meleekill.cooldown': 8, 'landing.extend': 9, 'spread.ram': 10,
          'airkill.extend': 11}
STATSCOPE = {'stat': 1, 'active': 2, 'air': 3, 'oc': 4}
DMG = {'air': 1, 'melee': 2, 'landing': 3}


def rs(s):
    """A redscript string literal."""
    return '"' + s.replace('\\', '\\\\').replace('"', '\\"') + '"'


def num(v):
    f = float(v)
    return repr(f)  # always has a decimal point, which redscript Float literals need


def effect(e, where):
    """One effect token -> one line of redscript that adds it to stage `s`."""
    m = re.fullmatch(r'(stat|active|air|oc)\.([A-Za-z0-9_]+)([+%])(-?[0-9.]+)', e)
    if m:
        scope, stat, op, v = m.groups()
        if op == '+':
            return f's.Fx(OSEvoEffect.Stat({STATSCOPE[scope]}, gamedataStatType.{stat}, gameStatModifierType.Additive, {num(v)}));'
        return f's.Fx(OSEvoEffect.Stat({STATSCOPE[scope]}, gamedataStatType.{stat}, gameStatModifierType.AdditiveMultiplier, {num(float(v) / 100.0)}));'
    m = re.fullmatch(r'ev\.([a-z]+\.[a-z]+) (-?[0-9.]+)((?:/[A-Za-z0-9.]+)*)', e)
    if m and m.group(1) in EVENTS:
        extra = [x for x in m.group(3).split('/') if x]
        cap = 0.0
        tokens = []
        for x in extra:
            if re.fullmatch(r'[0-9.]+', x):
                cap = float(x)
            else:
                tokens.append(x)
        return f's.Fx(OSEvoEffect.Event({EVENTS[m.group(1)]}, {num(m.group(2))}, {num(cap)}, {rs("/".join(tokens))}));'
    m = re.fullmatch(r'up\.(all|undetected|oc|queued|queuefull|camera) (-?[0-9.]+)', e)
    if m:
        return f's.Fx(OSEvoEffect.Upload({UPCOND[m.group(1)]}, gamedataHackCategory.Invalid, "", {num(m.group(2))}));'
    m = re.fullmatch(r'up\.cat\.([A-Za-z]+) (-?[0-9.]+)', e)
    if m and m.group(1) in CATS:
        return f's.Fx(OSEvoEffect.Upload(1, gamedataHackCategory.{m.group(1)}, "", {num(m.group(2))}));'
    m = re.fullmatch(r'up\.hack\.([A-Za-z/]+) (-?[0-9.]+)', e)
    if m:
        return f's.Fx(OSEvoEffect.Upload(2, gamedataHackCategory.Invalid, {rs(m.group(1))}, {num(m.group(2))}));'
    m = re.fullmatch(r'ram\.(all|device|queuedpct|afterctrl) (-?[0-9.]+)', e)
    if m:
        return f's.Fx(OSEvoEffect.Ram({RAMCOND[m.group(1)]}, gamedataHackCategory.Invalid, "", {num(m.group(2))}));'
    m = re.fullmatch(r'ram\.cat\.([A-Za-z]+) (-?[0-9.]+)', e)
    if m and m.group(1) in CATS:
        return f's.Fx(OSEvoEffect.Ram(1, gamedataHackCategory.{m.group(1)}, "", {num(m.group(2))}));'
    m = re.fullmatch(r'ram\.hack\.([A-Za-z/]+) (-?[0-9.]+)', e)
    if m:
        return f's.Fx(OSEvoEffect.Ram(2, gamedataHackCategory.Invalid, {rs(m.group(1))}, {num(m.group(2))}));'
    m = re.fullmatch(r'dmg\.(air|melee|landing) (-?[0-9.]+)', e)
    if m:
        return f's.Fx(OSEvoEffect.Damage({DMG[m.group(1)]}, {num(m.group(2))}));'
    sys.exit(f'{where}: cannot read effect "{e}"')


def main():
    with open(SRC, encoding='utf-8') as f:
        rows = list(csv.DictReader(f))
    out = [
        '// Chromepunk 2077: OS Evolution - model and stage table',
        '// GENERATED by tools/gen_osevo.py from data/cyberware_5plusplus_titles.csv.',
        '// Do not edit this file by hand: change the CSV and run the generator again.',
        '// Copyright (C) 2026 the Chromepunk 2077 authors. Written with AI assistance. GPL-3.0-or-later.',
        '',
        'public abstract class OSEvoData {',
        '  public static func Build(db: ref<OSEvoDB>) -> Void {',
        '    let s: ref<OSEvoStage>;',
    ]
    seen = set()
    for i, r in enumerate(rows, start=2):
        where = f'CSV line {i}'
        name = r['model_name']
        code = MODEL_CODES.get(name)
        if code is None:
            sys.exit(f'{where}: unknown model "{name}" - give it a new code in MODEL_CODES')
        if name not in seen:
            seen.add(name)
            rec = r['tweakdb_record_id']
            rec_lit = f't{rs(rec)}' if rec.startswith('Items.') else 'TDBID.None()'
            shown = 'Any Tier 5++ Cyberdeck' if code == 100 else name
            out.append(f'    db.AddModel({code}, {rs(shown)}, {OS_TYPE[r["os_type"]]}, {rec_lit});')
        metric = METRICS.get(r['metric_key'])
        if metric is None:
            sys.exit(f'{where}: unknown metric_key "{r["metric_key"]}"')
        clauses = r['perk_summary'].split('; ')
        effects = r['effects'].split(' | ')
        if len(clauses) != len(effects):
            sys.exit(f'{where}: {len(clauses)} perk clauses but {len(effects)} effect entries')
        out.append(f'    s = db.AddStage({code}, {int(r["stage"])}, {rs(r["title_name"])}, {metric}, '
                   f'{int(float(r["unlock_threshold"]))}, {rs(r["unlock_metric"])});')
        for c, e in zip(clauses, effects):
            live = e.strip() != 'later'
            out.append(f'    s.Clause({rs(c)}, {"true" if live else "false"});')
            if live:
                for one in e.split(','):
                    out.append('    ' + effect(one.strip(), where))
    out += ['  }', '}', '']
    with open(OUT, 'w', encoding='utf-8', newline='\n') as f:
        f.write('\n'.join(out))
    print(f'wrote {OUT}: {len(seen)} models, {len(rows)} stages')
    write_spoilers(rows)


# 0.0.5: the title system is hidden from players again, so its full description lives in
# SPOILERS.md (like Weaponpunk's). Generated from the same CSV so it can never drift from the code.
SPOILERS = os.path.join(ROOT, 'SPOILERS.md')


def write_spoilers(rows):
    out = ['# SPOILERS: the hidden titles', '',
           '**Don\'t read this if you want to discover them in game.** Generated by `tools/gen_osevo.py`',
           'from `data/cyberware_5plusplus_titles.csv`; edit the CSV, not this file.', '',
           'Only Tier 5++ operating systems can earn titles. Each model has three, earned in order.',
           'Progress toward a later one counts from the start, so a feat pulled off early is kept and the',
           'title unlocks right after the one before it. Perks add up. An earned title shows after the',
           'item\'s name and in its tooltip; nothing shows before that. "Hidden goal size" in Mod Settings',
           'scales every goal below.', '']
    current = None
    for r in rows:
        name = 'Any Tier 5++ cyberdeck (netrunner titles)' if r['model_name'] == 'ALL_TIER_5PP_CYBERDECKS' else r['model_name']
        if name != current:
            current = name
            out += [f'## {name}', '', '| # | Title | Goal | Perks |', '|---|---|---|---|']
        perks = []
        for c, e in zip(r['perk_summary'].split('; '), r['effects'].split(' | ')):
            perks.append(c + (' *(later build)*' if e.strip() == 'later' else ''))
        goal = f"{int(float(r['unlock_threshold']))} · {r['unlock_metric']}"
        out.append(f"| {r['stage']} | {r['title_name']} | {goal} | {'<br>'.join(p.replace('|', '/') for p in perks)} |")
        if r['stage'] == '3':
            out.append('')
    with open(SPOILERS, 'w', encoding='utf-8', newline='\n') as f:
        f.write('\n'.join(out) + '\n')
    print(f'wrote {SPOILERS}')


if __name__ == '__main__':
    main()
