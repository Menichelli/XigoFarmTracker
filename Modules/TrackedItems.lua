local _, Addon = ...

local TrackedItems = {}

local function normalizeItemID(itemID)
  itemID = tonumber(itemID)
  if not itemID then
    return nil
  end

  itemID = math.floor(itemID)
  if itemID <= 0 then
    return nil
  end

  return itemID
end

function TrackedItems:OnInitialize()
  self.db = Addon.db.profile.trackedItems
end

function TrackedItems:OnEnable()
  Addon:RegisterEvent("GET_ITEM_INFO_RECEIVED", self, "OnGetItemInfoReceived")
end

function TrackedItems:OnGetItemInfoReceived(_, itemID, success)
  if success and self.db[itemID] then
    Addon:SendMessage("TRACKED_ITEMS_CHANGED", itemID)
  end
end

function TrackedItems:GetAll()
  return self.db
end

function TrackedItems:IsTracked(itemID)
  itemID = normalizeItemID(itemID)
  if not itemID then
    return false
  end

  local entry = self.db[itemID]
  return entry ~= nil and entry.enabled ~= false
end

function TrackedItems:Add(itemID, manualPriceCopper)
  itemID = normalizeItemID(itemID)
  if not itemID then
    return nil, "Invalid itemID"
  end

  local entry = self.db[itemID]
  if not entry then
    entry = {
      enabled = true,
      manualPriceCopper = 0,
    }
    self.db[itemID] = entry
  end

  entry.enabled = true

  if manualPriceCopper ~= nil then
    manualPriceCopper = tonumber(manualPriceCopper)
    if not manualPriceCopper or manualPriceCopper < 0 then
      return nil, "Invalid manual price"
    end
    entry.manualPriceCopper = math.floor(manualPriceCopper + 0.5)
  end

  Addon:SendMessage("TRACKED_ITEMS_CHANGED", itemID)
  return itemID
end

function TrackedItems:Remove(itemID)
  itemID = normalizeItemID(itemID)
  if not itemID then
    return false, "Invalid itemID"
  end

  if not self.db[itemID] then
    return false, "Item is not tracked"
  end

  self.db[itemID] = nil
  Addon:SendMessage("TRACKED_ITEMS_CHANGED", itemID)
  return true
end

function TrackedItems:SetManualPrice(itemID, manualPriceCopper)
  itemID = normalizeItemID(itemID)
  if not itemID then
    return false, "Invalid itemID"
  end

  local entry = self.db[itemID]
  if not entry then
    return false, "Item is not tracked"
  end

  manualPriceCopper = tonumber(manualPriceCopper)
  if not manualPriceCopper or manualPriceCopper < 0 then
    return false, "Invalid manual price"
  end

  entry.manualPriceCopper = math.floor(manualPriceCopper + 0.5)
  Addon:SendMessage("TRACKED_ITEMS_CHANGED", itemID)
  return true
end

Addon:RegisterModule("TrackedItems", TrackedItems)
