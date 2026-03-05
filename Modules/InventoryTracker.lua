local _, Addon = ...

local InventoryTracker = {}

local function countKeys(map)
  local count = 0
  if type(map) ~= "table" then
    return 0
  end
  for _ in pairs(map) do
    count = count + 1
  end
  return count
end

local function sumValues(map)
  local sum = 0
  if type(map) ~= "table" then
    return 0
  end
  for _, value in pairs(map) do
    sum = sum + (tonumber(value) or 0)
  end
  return sum
end

local function addUniqueNumber(list, set, value)
  value = tonumber(value)
  if not value then
    return
  end

  value = math.floor(value)
  if value < 0 or set[value] then
    return
  end

  set[value] = true
  list[#list + 1] = value
end

local function joinNumberList(values)
  local parts = {}
  for i = 1, #values do
    parts[i] = tostring(values[i])
  end
  return table.concat(parts, ",")
end

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
  self.bagIDSet = {}
  self.reagentBagID = nil
end

function InventoryTracker:OnEnable()
  self:BuildBagList()
  Addon:RegisterEvent("BAG_UPDATE_DELAYED", self, "OnBagUpdateDelayed")
  Addon:RegisterEvent("BAG_UPDATE", self, "OnBagUpdate")
  Addon:RegisterEvent("LOOT_OPENED", self, "OnLootOpened")
  Addon:RegisterMessage("TRACKED_ITEMS_CHANGED", self, "OnTrackedItemsChanged")
  Addon:RegisterMessage("SESSION_STARTED", self, "OnSessionStarted")
  Addon:RegisterMessage("SESSION_RESUMED", self, "OnSessionResumed")
  Addon:RegisterMessage("SESSION_RESET", self, "OnSessionReset")
  Addon:Debug(string.format(
    "[InventoryTracker] enabled, bagIDs=%s reagentBagID=%s",
    joinNumberList(self.bagIDs),
    tostring(self.reagentBagID)
  ))
  self:RequestScan("enable")
end

function InventoryTracker:BuildBagList()
  local minBagID = BACKPACK_CONTAINER or 0
  local maxBagID = NUM_BAG_SLOTS or 4
  local bagIDs = {}
  local bagIDSet = {}
  local reagentBagID

  for bagID = minBagID, maxBagID do
    addUniqueNumber(bagIDs, bagIDSet, bagID)
  end

  if type(REAGENTBAG_CONTAINER) == "number" then
    reagentBagID = REAGENTBAG_CONTAINER
  elseif type(Enum) == "table"
      and type(Enum.BagIndex) == "table"
      and type(Enum.BagIndex.ReagentBag) == "number" then
    reagentBagID = Enum.BagIndex.ReagentBag
  elseif maxBagID < 5 and getContainerNumSlots(5) > 0 then
    -- Retail fallback when constants are unavailable but bag 5 exists.
    reagentBagID = 5
  end

  addUniqueNumber(bagIDs, bagIDSet, reagentBagID)

  self.bagIDs = bagIDs
  self.bagIDSet = bagIDSet
  self.reagentBagID = reagentBagID
  Addon:Debug(string.format(
    "[InventoryTracker] BuildBagList bagIDs=%s reagentBagID=%s",
    joinNumberList(self.bagIDs),
    tostring(self.reagentBagID)
  ))
end

function InventoryTracker:OnBagUpdateDelayed()
  Addon:Debug("[InventoryTracker] event BAG_UPDATE_DELAYED")
  self:RequestScan("bag_update")
end

function InventoryTracker:OnBagUpdate(_, bagID)
  bagID = tonumber(bagID)
  if not bagID then
    return
  end

  if self.reagentBagID and bagID == self.reagentBagID then
    Addon:Debug(string.format("[InventoryTracker] event BAG_UPDATE reagent bagID=%d", bagID))
    self:RequestScan("bag_update_reagent")
  end
end

function InventoryTracker:OnLootOpened()
  Addon:Debug("[InventoryTracker] event LOOT_OPENED")
  self:RequestScan("loot_opened")
end

function InventoryTracker:OnTrackedItemsChanged()
  Addon:Debug("[InventoryTracker] message TRACKED_ITEMS_CHANGED")
  self:RequestScan("tracked_items_changed")
end

function InventoryTracker:OnSessionStarted()
  Addon:Debug("[InventoryTracker] message SESSION_STARTED -> capture baseline")
  self:CaptureBaseline()
end

function InventoryTracker:OnSessionResumed()
  Addon:Debug("[InventoryTracker] message SESSION_RESUMED -> capture baseline")
  self:CaptureBaseline()
end

function InventoryTracker:OnSessionReset()
  Addon:Debug("[InventoryTracker] message SESSION_RESET -> capture baseline")
  self:CaptureBaseline()
end

function InventoryTracker:GetCurrentCounts()
  return self.currentCounts
end

function InventoryTracker:RequestScan(reason)
  if self.scanPending then
    Addon:Debug(string.format("[InventoryTracker] scan already pending, skip reason=%s", tostring(reason)))
    return
  end

  self.scanPending = true
  local debounce = self.constants.BAG_SCAN_DEBOUNCE or 0.15
  Addon:Debug(string.format("[InventoryTracker] queue scan reason=%s debounce=%.2fs", tostring(reason), debounce))

  C_Timer.After(debounce, function()
    self.scanPending = false
    Addon:Debug(string.format("[InventoryTracker] run scan reason=%s", tostring(reason)))
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
  Addon:Debug(string.format(
    "[InventoryTracker] baseline captured tracked=%d totalQty=%d",
    countKeys(counts),
    sumValues(counts)
  ))
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
  local previousCounts = self.db.lastBagCounts or {}
  local counts = self:ScanTrackedItems()
  local changedItems = 0

  for itemID, newCount in pairs(counts) do
    local oldCount = previousCounts[itemID] or 0
    if newCount ~= oldCount then
      changedItems = changedItems + 1
    end
  end

  for itemID in pairs(previousCounts) do
    if counts[itemID] == nil then
      changedItems = changedItems + 1
    end
  end

  if applyDeltas then
    self:ApplySessionDeltas(counts)
  end

  self.currentCounts = self.tableUtil:CopyMap(counts)
  self.db.lastBagCounts = self.tableUtil:CopyMap(counts)
  Addon:Debug(string.format(
    "[InventoryTracker] scan done reason=%s tracked=%d changed=%d totalQty=%d applyDeltas=%s",
    tostring(reason),
    countKeys(counts),
    changedItems,
    sumValues(counts),
    tostring(applyDeltas == true)
  ))
  Addon:SendMessage("INVENTORY_COUNTS_UPDATED", self.currentCounts, reason)
end

Addon:RegisterModule("InventoryTracker", InventoryTracker)
