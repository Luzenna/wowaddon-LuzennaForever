# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

LuzennaForever is a personal World of Warcraft addon (pure Lua, no build step, no tests, no linter, not a git repo). It lives directly in the game's `Interface/AddOns` folder, so editing a file *is* deploying it. To try a change: `/reload` in game. Check errors with `/luz errors` (the addon's own log) or BugSack.

Slash commands: `/luz` (settings), `/luz sort`, `/luz errors`, `/luz forget <name>` (drop an alt from the tracker).

## Architecture

`LuzennaForever.toc` sets load order: `Errors → Core → Bags → Tracker`. Every file starts with `local ADDON_NAME, ns = ...` and exposes its module as `ns.<Module>` (`ns.Errors`, `ns.Bags`, `ns.Tracker`). Modules reach each other only through `ns`, and guard optional ones (`if ns.Bags then ...`).

- **Core.lua** owns the lifecycle and everything shared: `ns.defaults`, the recursive `Merge` of defaults into the `LuzennaForeverDB` SavedVariable, the Settings page (`Settings.RegisterVerticalLayoutCategory`), the minimap button, and the `/luz` dispatcher. Init order matters: on `ADDON_LOADED` it sets `ns.db`, then `Errors.Init`, settings, minimap button; on `PLAYER_LOGIN` it calls `Errors.OnLogin`, `Bags.Init`, `Tracker.Init` (these need the game's UI/bag data to exist).
- **Adding a setting:** put the default in `ns.defaults` (Core.lua), add a `Checkbox(...)` in `RegisterSettings`. The `Checkbox` helper finds the default by matching the table against `ns.db` sections, so the table passed must be a direct `ns.db.<section>` table.
- **Errors.lua** wraps (does not replace) the current error handler, keeps only errors whose text contains `"LuzennaForever"` (last 20, in `db.errors.list`), and buffers errors that occur before the DB loads. It drives the red badge on the minimap button via `ns.SetErrorBadge`.
- **Bags.lua** doesn't create a bag; it hooks Blizzard's combined bag frame (`ContainerFrameCombinedBags`): drag-to-move with saved position, a gear menu, visual-only reverse order by mirroring item-button positions, and merging the reagent bag into it. It uses `hooksecurefunc` and looks up frame/method names defensively, because it was written without Blizzard's UI source. Layout changes are skipped in combat (`InCombatLockdown`).
- **Tracker.lua** snapshots each character's bags/bank/worn items per `Name-Realm` into the DB (events: `BAG_UPDATE_DELAYED`, `PLAYER_EQUIPMENT_CHANGED`, bank events) and appends other characters' counts to item tooltips.

## Conventions worth knowing

- Retail "secret values" are handled everywhere game data is read: use the file-local `issecretvalue = issecretvalue or function() return false end` and check before comparing, concatenating, or indexing values from game APIs (see Tracker).
- Code is commented sparingly, with sentence-style comments explaining *why*; keep new comments in that style. Section dividers are `-----` lines with a title.
