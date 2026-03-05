# XigoFarmTracker

`XigoFarmTracker` is a World of Warcraft Retail addon (Midnight / 12.x) to track farming sessions and estimate value in real time.

## Features

- Session lifecycle: `start`, `pause`, `resume`, `stop`, `reset`
- User-defined tracked items (by `itemID`)
- Real-time metrics:
  - Current tracked value in bags
  - Session gained value
  - Estimated gold per hour
- Pricing source:
  - Use TSM API when available
  - Fallback to manual per-item prices (in copper)
- UI:
  - Movable HUD
  - Options panel
  - Slash commands
- Persistence:
  - SavedVariables via `XigoFarmTrackerDB`
  - Session state survives relog/reload safely

## Requirements

- World of Warcraft Retail (Midnight / 12.x)
- Optional: TradeSkillMaster (`TradeSkillMaster`) for automatic pricing

## Installation

1. Copy this folder to your WoW AddOns directory:
   - `_retail_/Interface/AddOns/XigoFarmTracker`
2. Ensure the folder contains `XigoFarmTracker.toc`.
3. Restart WoW or run `/reload`.
4. Enable `XigoFarmTracker` in the AddOns list.

## Quick Start

1. Open options with `/xft options`
2. Add tracked items (item IDs) and optional manual price
3. Start a session with `/xft start`
4. Farm as usual
5. Pause/resume/stop as needed

## Slash Commands

- `/xft`
- `/xft help`
- `/xft start`
- `/xft pause`
- `/xft resume`
- `/xft stop`
- `/xft reset`
- `/xft add <itemID> [priceGold]`
- `/xft remove <itemID>`
- `/xft price <itemID> <priceGold>`
- `/xft list`
- `/xft lock`
- `/xft unlock`
- `/xft toggle`
- `/xft show`
- `/xft hide`
- `/xft options`
- `/xft debug on|off`

Examples:

- `/xft add 124124 3.5` (tracks item 124124, manual price 3.5g)
- `/xft price 124124 5` (sets manual price to 5g)

## Pricing Behavior

- If `useTSM` is enabled and TSM API is available:
  - Tries TSM custom price (`dbmarket`, then `dbminbuyout`)
- If no valid TSM price is found:
  - Uses manual price from tracked item configuration
- If neither source returns a value:
  - Price defaults to `0`

## UI Overview

- HUD:
  - Displays session state, current bag value, session gain, and gold/hour
  - Draggable when unlocked
- Options Panel:
  - Enable/disable TSM pricing
  - Toggle debug logging
  - Lock/unlock HUD
  - Session control buttons
  - Add/update/remove tracked items

## SavedVariables

Saved in global variable:

- `XigoFarmTrackerDB`

Main structure:

- `schemaVersion`
- `global`
  - `useTSM`
  - `priceCacheTTLSeconds`
  - `debug`
- `profile`
  - `trackedItems`
  - `ui.hud`
  - `session`
  - `history`

## Architecture

- `Core.lua`
  - Addon bootstrap
  - Module registry (`RegisterModule`, `GetModule`)
  - Event dispatch
  - Internal message bus
  - Debug/print helpers
- `Utils/`
  - `Constants.lua`
  - `Table.lua`
  - `Money.lua`
- `Modules/`
  - `TrackedItems.lua`
  - `SessionManager.lua`
  - `InventoryTracker.lua`
  - `Metrics.lua`
  - `Pricing/ManualPriceProvider.lua`
  - `Pricing/TSMPriceProvider.lua`
  - `Pricing/PricingService.lua`
- `UI/`
  - `HUD.lua`
  - `OptionsPanel.lua`
  - `SlashCommands.lua`

## Events Used

- `ADDON_LOADED`
- `PLAYER_LOGIN`
- `PLAYER_LOGOUT`
- `BAG_UPDATE_DELAYED`
- `GET_ITEM_INFO_RECEIVED`

## Performance and Robustness

- Inventory scans are event-driven (`BAG_UPDATE_DELAYED`) with debounce.
- No aggressive bag polling loop.
- Pricing is cached with TTL.
- Session state and computed metrics are persisted in SavedVariables.
- Session time excludes offline time after relog/reload.

## Development Notes

- Addon code and UI text are in English.
- No global namespace pollution for addon internals (single local addon table pattern).
- Optional dependency declared in TOC:
  - `## OptionalDeps: TradeSkillMaster`
