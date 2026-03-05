local _, Addon = ...

local InventoryTracker = {}

local function getContainerNumSlots(bagID)
  if C_Container and C_Container.GetContainerNumSlots then
    return C_Container.GetContainerNumSlots(bagID) or 0
  end
  if GetContainerNumSlots then
    return GetContainerNumSlots(bagID) or 0
  end
  return 0
end

local function getContainerItemInfo(bagID, slotID)
  if C_Container and C_Container.GetContainerItemInfo then
    local info = C_Container.GetContainerItemInfo(bagID, slotID)
    if info then
      return info.itemID, info.stackCount or info.count or 0
    end
    return nil, 0
  end

  if GetContainerItemID and GetContainerItemInfo then
    local itemID = GetContainerItemID(bagID, slotID)
    local _, itemCount = GetContainerItemInfo(bagID, slotID)
    return itemID, itemCount or 0
  end

  return nil, 0
end

function InventoryTracker:OnInitialize()
  self.constants = Addon:GetModule("Constants")
  self.tableUtil = Addon:GetModule("TableUtil")
  self.db = Addon.db.profile.session
  self.scanPending = false
  self.currentCounts = self.tableUtil:CopyMap(self.db.lastBagCounts or {})
  self.bagIDs = {}
end

function InventoryTracker:OnEnable()
  self:BuildBagList()
  Addon:RegisterEvent("BAG_UPDATE_DELAYED", self, "OnBagUpdateDelayed")
  Addon:RegisterMessage("TRACKED_ITEMS_CHANGED", self, "OnTrackedItemsChanged")
  Addon:RegisterMessage("SESSION_STARTED", self, "OnSessionStarted")
  Addon:RegisterMessage("SESSION_RESUMED", self, "OnSessionResumed")
  Addon:RegisterMessage("SESSION_RESET", self, "OnSessionReset")
  self:RequestScan("enable")
end

function InventoryTracker:BuildBagList()
  local minBagID = BACKPACK_CONTAINER or 0
  local maxBagID = NUM_BAG_SLOTS or 4
  local bagIDs = {}

  for bagID = minBagID, maxBagID do
    bagIDs[#bagIDs + 1] = bagID
  end

  if type(REAGENTBAG_CONTAINER) == "number" and REAGENTBAG_CONTAINER > maxBagID then
    bagIDs[#bagIDs + 1] = REAGENTBAG_CONTAINER
  end

  self.bagIDs = bagIDs
end

function InventoryTracker:OnBagUpdateDelayed()
  self:RequestScan("bag_update")
end

function InventoryTracker:OnTrackedItemsChanged()
  self:RequestScan("tracked_items_changed")
end

function InventoryTracker:OnSessionStarted()
  self:CaptureBaseline()
end

function InventoryTracker:OnSessionResumed()
  self:CaptureBaseline()
end

function InventoryTracker:OnSessionReset()
  self:CaptureBaseline()
end

function InventoryTracker:GetCurrentCounts()
  return self.currentCounts
end

function InventoryTracker:RequestScan(reason)
  if self.scanPending then
    return
  end

  self.scanPending = true
  local debounce = self.constants.BAG_SCAN_DEBOUNCE or 0.15

  C_Timer.After(debounce, function()
    self.scanPending = false
    self:PerformScan(reason, true)
  end)
end

function InventoryTracker:ScanTrackedItems()
  local trackedItems = Addon:GetModule("TrackedItems")
  local tracked = trackedItems and trackedItems:GetAll() or {}
  local counts = {}

  for itemID, entry in pairs(tracked) do
    if entry.enabled ~= false then
      counts[itemID] = 0
    end
  end

  if not next(counts) then
    return counts
  end

  for i = 1, #self.bagIDs do
    local bagID = self.bagIDs[i]
    local numSlots = getContainerNumSlots(bagID)
    for slotID = 1, numSlots do
      local itemID, stackCount = getContainerItemInfo(bagID, slotID)
      if itemID and counts[itemID] ~= nil then
        counts[itemID] = counts[itemID] + (stackCount or 0)
      end
    end
  end

  return counts
end

function InventoryTracker:CaptureBaseline()
  local counts = self:ScanTrackedItems()
  self.currentCounts = self.tableUtil:CopyMap(counts)
  self.db.baselineBagCounts = self.tableUtil:CopyMap(counts)
  self.db.lastBagCounts = self.tableUtil:CopyMap(counts)
  Addon:SendMessage("INVENTORY_COUNTS_UPDATED", self.currentCounts, "baseline")
end

function InventoryTracker:ApplySessionDeltas(newCounts)
  local sessionManager = Addon:GetModule("SessionManager")
  local previousCounts = self.db.lastBagCounts or {}

  for itemID, newCount in pairs(newCounts) do
    local oldCount = previousCounts[itemID] or 0
    local delta = newCount - oldCount
    if delta ~= 0 and sessionManager then
      sessionManager:RecordDelta(itemID, delta)
    end
  end
end

function InventoryTracker:PerformScan(reason, applyDeltas)
  local counts = self:ScanTrackedItems()
  if applyDeltas then
    self:ApplySessionDeltas(counts)
  end

  self.currentCounts = self.tableUtil:CopyMap(counts)
  self.db.lastBagCounts = self.tableUtil:CopyMap(counts)
  Addon:SendMessage("INVENTORY_COUNTS_UPDATED", self.currentCounts, reason)
end

Addon:RegisterModule("InventoryTracker", InventoryTracker)
