# Dispeller_CoA

Party and raid dispel grid for **Project Ascension — Conquest of Azeroth** (WotLK 3.3.5 client, Interface 30300).

Shows who has a magic, poison, disease, curse, or **bleed** you can remove. Click the square to cleanse. Cures are detected from your CoA spellbook (IDs and tooltips). The catalog only lists confirmed Conquest of Azeroth spells.

## Install

1. Copy this folder so the path is:

   `<Ascension WoW>/Interface/AddOns/Dispeller_CoA/Dispeller_CoA.toc`

   Find the client folder from the Ascension Launcher: **Settings → Installation Folder**.

2. At character select, open **AddOns** and enable **Dispeller_CoA**.
3. Log in and `/reload` after updates.

Do not nest an extra folder (`AddOns/Dispeller_CoA/Dispeller_CoA/...`).

## Use

- **Alt-drag** the small handle above the first square to move the grid.
- **Left click** — first enabled type you can cure (default Magic).
- **Right click** — second type.
- **Shift-left / Shift-right** — third / fourth.
- **Ctrl-left** — fifth type (Bleed, if it is last in your priority).
- **Middle click** — target that unit.
- **Ctrl-middle** — focus that unit.

Colors: red / blue / orange / gold / magenta match those click slots. Faded = out of range. Dark green = nothing you can cure. Purple = too far to scan. Black = blacklisted (LoS / immune). Grey = unit gone.

Bleeds are a physical mechanic, not Magic/Poison/Disease/Curse. They are detected from a `Bleed` type if the server sets one, the word “bleed” in the aura name, or a one-time tooltip check for wound-like names. CoA **Stoneform** (`1120594`) is a self-only poison/disease/bleed remove. Templar **Rebuke** (`525051`) cleanses magic, poison, and disease.

`/dcoa` opens options.

| Command | What it does |
| --- | --- |
| `/dcoa` or `/dcoa options` | Options panel |
| `/dcoa show` / `/dcoa hide` | Show or hide the grid |
| `/dcoa reset` | Reset MUF and live-list positions |
| `/dcoa dump` | Print `UnitClass` and detected cure spells |
| `/dcoa prio` | Toggle target (or a name) on the priority list |
| `/dcoa prio list` | Print the priority list |
| `/dcoa skip` | Toggle target (or a name) on the skip list |
| `/dcoa skip list` | Print the skip list |

## In-game checklist (Vol'jin)

Run this after install. `/dcoa dump` is the first thing to check.

1. Log a healer (Sun Cleric, Witch Doctor, Starcaller, or Primalist) and a non-healer that still has a baseline dispel.
2. `/dcoa dump` — class token and at least one of Magic / Curse / Poison / Disease / Bleed mapped to a real spell name.
3. In a party, get each of the four dispel types plus a bleed applied. The matching square should change color and a click should remove that type. Stoneform only lights the **player** square.
4. Walk out of range — the square should fade. Stand behind a wall and click — the square should go black for a few seconds.
5. Enter combat, then click a square. The cleanse should still fire (secure buttons were set before combat).
6. Join a 10 or 25 raid. Grid should grow (5 per row). Toggle pets in options. `/dcoa skip` a name and confirm they disappear. `/dcoa prio` a name and confirm they sort earlier.

If dump shows no spells, use the options panel to confirm type toggles, then `/dcoa dump` again after learning the cleanse. Unknown CoA spell names are picked up from the tooltip on the next spellbook scan.

## Performance

- Roster rebuilds only on party/raid/focus/pet events.
- `UNIT_AURA` scans **one** unit, not the whole raid.
- Spellbook + tooltip parse is debounced (0.4s) on `SPELLS_CHANGED`.
- `OnUpdate` runs only while someone is afflicted, at 0.18s, for range/cooldown tint.
- Secure attributes and vertex colors are written only when they change.
- Tables for roster rows, unit status, and sort scratch are reused.

## Notes

Decursive was used only as a UX reference. This addon is original code and is not a Decursive fork.
