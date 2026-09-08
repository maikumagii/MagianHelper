# MagianHelper

A Windower 4 addon that attempts a weaponskill against your engaged target when its HP is at or below your threshold.

## Install

Copy `MagianHelper.lua` into `Windower4/addons/MagianHelper/`, then run:

```text
//lua load MagianHelper
//mh set ws Atonement
//mh set hp 25
//mh start
```

Use `//mh pause` to stop. The addon starts paused, with a 100% HP threshold. Settings are held in memory and reset on reload.

## Commands

| Command | Effect |
| --- | --- |
| `//mh set ws <weaponskill name>` | Set an explicit WS, overriding automatic selection. Names are case insensitive; quotes around multiword names are optional. |
| `//mh set hp <1-100>` | Set the inclusive HP percentage threshold. |
| `//mh start` | Turn `state` on; requires an explicit WS or a recognized main-hand/ranged weapon. |
| `//mh pause` | Turn `state` off. |
| `//mh info` | Display the current WS (manual or automatically selected) and HP threshold. Shows `not set` when no WS can be selected. |

`//mh` displays help and settings. `//mh set ws auto` clears the explicit WS and restores automatic selection.

## Behavior

- Checks once per second while running, starting one second after `start`.
- Requires you to be engaged, alive, and have at least 1,000 TP, with a living, valid NPC target at or below the threshold.
- Checks that the selected WS is in your currently available weaponskill list before sending the command.
- Continues attempting once per second while these conditions hold. This is not limited to one WS per enemy. A failed attempt (for example, out of range or during another action) can be retried on the next check. Normal game restrictions still apply.
- Pausing stops further attempts; it cannot retract a command already sent. Logging out also pauses the addon.
- Automatic selection supports **all 20 Mythic weapons and 14 Relic weapons** with associated weaponskills. It rechecks the equipped items and their actual inventory/wardrobe bags, so weapon swaps are respected.
- Selection priority: **explicit WS → mapped main-hand weapon → mapped ranged weapon**. Offhand weapons are ignored. If both main and ranged are mapped, use an explicit WS to choose the ranged trial. If the chosen WS is unavailable, the addon waits; it does not substitute a different WS.
- Ranged weaponskills still require engagement and suitable ammunition under the game's normal rules. Self-targeting weaponskills are not supported.
- Add more mappings to `weapon_defaults` near the top of the Lua file using exact English item and WS names. An explicit WS always takes priority, even after changing weapons.

## Automatic weapon coverage

The complete `weapon_defaults` table is near the top of `MagianHelper.lua`. Examples include Conqueror → King's Justice, Nirvana → Garland of Bliss, Death Penalty → Leaden Salute, Excalibur → Knights of Round, and Annihilator → Coronach.

Names match all upgrade stages that retain the same Windower English item name. The Relic shield and instrument (Aegis and Gjallarhorn) have no associated WS and are omitted. Empyrean weapons, Ergon weapons, Vigil weapons, unfinished Relic precursors, and earlier Magian/Walk of Echoes weapons are not automatically mapped.

This selects the weapon's signature WS, not a WS inferred from your active trial. Relic/Mythic upgrades include WS-use and WS-finishing-blow trials. Empyrean weapons are excluded because their upgrade trials use different objectives. Set a different WS manually when your trial calls for one. The addon does not track trial progress or guarantee a finishing blow.

Weapon/WS associations: [Square Enix's weapon upgrade tables](https://forum.square-enix.com/ffxi/threads/19515) and the [Mythic weapon list](https://ffxiclopedia.fandom.com/wiki/Category:Mythic_Weapons). Trial background: [Empyrean weapons](https://www.bg-wiki.com/ffxi/Category:Empyrean_Weapons).

## Validation

Run the mocked behavior checks from this folder with `lua tests/test_magianhelper.lua`. Actual combat execution still needs an in-game check on Windower 4.

API references: [Windower FFXI functions](https://github.com/Windower/Lua/wiki/FFXI-Functions), [Windower events](https://github.com/Windower/Lua/wiki/Events), and [weaponskill resources](https://github.com/Windower/Resources/blob/master/resources_data/weapon_skills.lua).
