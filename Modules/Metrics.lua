local _, Addon = ...

local Metrics = {}

local function now()
  return time()
end

function Metrics:OnInitialize()
  self.db = Addon.db.profile.session
  self.lastSnapshot = {
    currentValueCopper = self.db.lastComputed.currentValueCopper or 0,
    sessionGainedCopper = self.db.lastComputed.sessionGainedCopper or 0,
    goldPerHourCopper = self.db.lastComputed.goldPerHourCopper or 0,
    activeSeconds = self.db.lastComputed.activeSeconds or 0,
    updatedAt = self.db.lastComputed.updatedAt or 0,
  }
end

function Metrics:OnEnable()
  Addon:RegisterMessage("INVENTORY_COUNTS_UPDATED", self, "OnInputChanged")
  Addon:RegisterMessage("SESSION_STATE_CHANGED", self, "OnInputChanged")
  Addon:RegisterMessage("SESSION_GAIN_UPDATED", self, "OnInputChanged")
  Addon:RegisterMessage("TRACKED_ITEMS_CHANGED", self, "OnInputChanged")
  Addon:RegisterMessage("PRICE_SOURCE_CHANGED", self, "OnInputChanged")
  self:Recompute()
end

function Metrics:OnInputChanged()
  self:Recompute()
end

function Metrics:GetSnapshot(forceRefresh)
  if forceRefresh then
    self:Recompute()
  end
  return self.lastSnapshot
end

function Metrics:Recompute()
  local trackedItems = Addon:GetModule("TrackedItems")
  local inventoryTracker = Addon:GetModule("InventoryTracker")
  local pricingService = Addon:GetModule("PricingService")
  local sessionManager = Addon:GetModule("SessionManager")

  if not trackedItems or not inventoryTracker or not pricingService or not sessionManager then
    return self.lastSnapshot
  end

  local tracked = trackedItems:GetAll()
  local counts = inventoryTracker:GetCurrentCounts()
  local gained = self.db.gainedByItem or {}
  local currentValue = 0
  local sessionValue = 0

  for itemID, entry in pairs(tracked) do
    if entry.enabled ~= false then
      local price = pricingService:GetUnitPrice(itemID)
      local count = counts[itemID] or 0
      local gainedCount = gained[itemID] or 0
      currentValue = currentValue + (count * price)
      sessionValue = sessionValue + (gainedCount * price)
    end
  end

  local activeSeconds = sessionManager:GetActiveSeconds()
  local goldPerHour = 0
  if activeSeconds > 0 then
    goldPerHour = math.floor((sessionValue * 3600 / activeSeconds) + 0.5)
  end

  local snapshot = {
    currentValueCopper = currentValue,
    sessionGainedCopper = sessionValue,
    goldPerHourCopper = goldPerHour,
    activeSeconds = activeSeconds,
    updatedAt = now(),
  }

  self.lastSnapshot = snapshot
  self.db.lastComputed.currentValueCopper = snapshot.currentValueCopper
  self.db.lastComputed.sessionGainedCopper = snapshot.sessionGainedCopper
  self.db.lastComputed.goldPerHourCopper = snapshot.goldPerHourCopper
  self.db.lastComputed.activeSeconds = snapshot.activeSeconds
  self.db.lastComputed.updatedAt = snapshot.updatedAt

  Addon:SendMessage("METRICS_UPDATED", snapshot)
  return snapshot
end

Addon:RegisterModule("Metrics", Metrics)
