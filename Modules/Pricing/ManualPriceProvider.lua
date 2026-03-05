local _, Addon = ...

local ManualPriceProvider = {}

function ManualPriceProvider:GetPrice(itemID)
  local trackedItems = Addon:GetModule("TrackedItems")
  if not trackedItems then
    return nil
  end

  local entry = trackedItems:GetAll()[itemID]
  if not entry then
    return nil
  end

  local price = tonumber(entry.manualPriceCopper)
  if not price or price <= 0 then
    return nil
  end

  return math.floor(price + 0.5)
end

Addon:RegisterModule("ManualPriceProvider", ManualPriceProvider)
