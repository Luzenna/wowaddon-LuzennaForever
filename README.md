# LuzennaForever

A small personal quality-of-life addon for World of Warcraft.

- **One-bag tweaks.** Drag the combined bag anywhere (position is saved), reverse the slot order (visual only, nothing moves), sort from a gear menu on the bag, and optionally fold the reagent bag into it with a faint pink tint on its slots.
- **Alt inventory tracking.** Remembers what each character carries in bags, bank and worn gear, and adds your other characters' counts to item tooltips, e.g. `Name: 12 (bags 4, bank 8)`. A character's bank count is as of their last bank visit.
- **Error log.** Keeps the last 20 Lua errors that come from this addon, shows a red dot on the minimap button, and lets you copy them from a window. Other addons' errors are not recorded.
- **Minimap button.** The one entry point for every setting: click to open the settings page, drag to move it.

## Install

Copy this folder to `World of Warcraft\<version>\Interface\AddOns\LuzennaForever` and restart the game or `/reload`.

## Commands

| Command | What it does |
| --- | --- |
| `/luz` | Open the settings page (Options > AddOns > LuzennaForever) |
| `/luz sort` | Sort the bags |
| `/luz errors` | Show the error log |
| `/luz forget <name>` | Remove a character from the alt tracker |

## License

Free to use for yourself in the game. Copying, redistributing or including it in other projects needs a paid license; see [LICENSE](LICENSE).
