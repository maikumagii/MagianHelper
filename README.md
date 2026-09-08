# MagianHelper

MagianHelper is a Windower 4 addon for working on Magian weaponskill trials. Pick a weaponskill and an enemy HP percentage, and it will use that WS when your engaged target reaches that percentage or lower.

For example, you can have it use Atonement once your target drops to 25% HP. It checks every half second and waits until you have at least 1,000 TP. You still need to be in range and able to use the weaponskill normally.

## Getting started

Download `MagianHelper.lua` and place it in your Windower folder at `addons/MagianHelper/MagianHelper.lua`. Then load it in game:

```text
//lua load MagianHelper
```

The shorthand for MagianHelper is `mh`. To use Atonement at 25% enemy HP, enter:

```text
//mh set ws Atonement
//mh set hp 25
//mh start
```

MagianHelper starts paused whenever you load it. The default HP threshold is 100%, so set a lower value if you want to save TP until the enemy is closer to dying.

When you're finished, use `//mh pause`. Your WS and HP settings stay in place until you reload or unload the addon; they aren't saved between sessions. Logging out also pauses it.

## Commands

| Command | What it does |
| --- | --- |
| `//mh set ws <name>` | Choose a weaponskill, such as `//mh set ws King's Justice`. |
| `//mh set hp <1-100>` | Choose the enemy HP percentage at which to start using your WS. |
| `//mh set am3 <on/off>` | Enable or disable Mythic Aftermath Lv.3 maintenance (default: off). |
| `//mh set am3 <seconds>` | Set when to start saving TP before AM3 expires (default: 15 seconds). Does not enable or disable maintenance. |
| `//mh start` | Start watching your engaged target. |
| `//mh pause` | Stop using weaponskills automatically. |
| `//mh info` | Show your selected WS, HP threshold, and AM3 settings. |
| `//mh debug` | Explain what is blocking a WS and show AM3 buff status. |
| `//mh set ws auto` | Let your equipped weapon choose the WS again. |
| `//mh` | Show help and settings. |

Use the full English weaponskill name. Capitalization doesn't matter, and quotes around names with spaces are optional.

## Let your weapon choose the WS

If you have a Mythic or Relic weapon equipped, you can skip setting a WS. For example, with Burtgang in your main hand:

```text
//mh set hp 25
//mh start
```

MagianHelper will choose Atonement for you. Automatic selection covers all 20 Mythic weapons and all 14 Relic weapons with an associated weaponskill, including ranged weapons. Other examples are Conqueror with King's Justice, Nirvana with Garland of Bliss, and Annihilator with Coronach.

Your own WS choice always takes priority. Otherwise, MagianHelper checks your main hand first, then your ranged slot, and follows equipment changes as you play. If both slots have a supported weapon, choose the ranged WS yourself when you want to work on that trial. Offhand weapons don't affect the choice.

Use `//mh info` to see which WS it has selected. If it shows `not set`, choose one with `//mh set ws <name>` before starting. If the chosen WS isn't currently available to you, MagianHelper waits.

Empyrean weapons aren't included because their upgrade trials use different objectives. Ergon weapons, Vigil weapons, and unfinished weapon precursors also need a manual WS choice. Shields and instruments have no associated WS, and self-targeting weaponskills aren't supported.

## Maintain Mythic AM3

If you're working on a Mythic, MagianHelper can help keep Aftermath Lv.3 (AM3) up while you work on your trial. It's off by default. To turn it on, equip your Mythic and enter:

```text
//mh set am3 on
//mh start
```

MagianHelper will first save up to 3,000 TP and use your Mythic's WS to get AM3, even if the enemy is still above your chosen HP percentage. Once AM3 is up, it goes back to using your selected WS at your usual HP threshold.

By default, it starts saving TP again when AM3 has 15 seconds left. If you'd like a little more time to build TP, you can change that:

```text
//mh set am3 20
```

With this setting, normal WS use continues until AM3 has 20 seconds left. Then MagianHelper holds your TP until the buff wears off. Even if you reach 3,000 TP with 10 seconds remaining, it waits. Once AM3 is gone and you have 3,000 TP, it uses your Mythic's WS again without waiting for the enemy's HP to drop.

You can use any whole number of seconds, including `0` if you only want to start saving after AM3 expires. Setting the number doesn't turn AM3 maintenance on; use `//mh set am3 on` for that. To turn it off, use `//mh set am3 off`. These settings last until you reload the addon.

MagianHelper watches the buff itself to tell when it will wear off. If you load the addon while AM3 is already up, it may hold TP until the game supplies its remaining duration.

This works with the Mythics listed above, equipped in your main hand or ranged slot. If both slots have a Mythic, the main-hand weapon takes priority. You can still choose a different WS for your trial; MagianHelper only switches to the Mythic's WS when it needs to apply AM3. Without a Mythic equipped, it follows your normal WS and HP settings.

## A few things to keep in mind

MagianHelper keeps using your WS as TP becomes available while the target stays at or below your chosen HP percentage. It doesn't stop after one WS per enemy. If an attempt fails because you're out of range or busy with another action, it can try again on the next check. Ranged weaponskills also need suitable ammunition, and you must remain engaged.

For finishing-blow trials, you'll need to find an HP threshold that works for your damage and the enemies you're fighting. MagianHelper doesn't read your active trial, count progress, or guarantee that your WS lands the killing blow. Check your trial's requirements and choose a different WS manually if needed.
