local _, Addon = ...

local Constants = {
  SESSION_STATES = {
    IDLE = "IDLE",
    RUNNING = "RUNNING",
    PAUSED = "PAUSED",
    STOPPED = "STOPPED",
  },
  COPPER_PER_SILVER = 100,
  SILVER_PER_GOLD = 100,
  COPPER_PER_GOLD = 10000,
  BAG_SCAN_DEBOUNCE = 0.15,
  HUD_REFRESH_INTERVAL = 0.5,
}

Addon:RegisterModule("Constants", Constants)
