local _, Addon = ...

local TSMPriceProvider = {}

local function roundPrice(value)
  value = tonumber(value)
  if not value or value <= 0 then
    return nil
  end
  return math.floor(value + 0.5)
end

function TSMPriceProvider:OnInitialize()
  self.isAvailable = self:DetectAvailability()
end

function TSMPriceProvider:OnEnable()
  Addon:RegisterEvent("ADDON_LOADED", self, "OnAddonLoaded")
end

function TSMPriceProvider:OnAddonLoaded(_, loadedAddonName)
  if loadedAddonName ~= "TradeSkillMaster" then
    return
  end

  self.isAvailable = self:DetectAvailability()
  Addon:SendMessage("PRICE_SOURCE_CHANGED")
end

function TSMPriceProvider:DetectAvailability()
  if type(_G.TSM_API) == "table" and type(_G.TSM_API.GetCustomPriceValue) == "function" then
    return true
  end
  if type(_G.TSM_API_FOUR) == "table" then
    local cp = _G.TSM_API_FOUR.CustomPrice
    if type(cp) == "table" and type(cp.GetValue) == "function" then
      return true
    end
  end
  return false
end

function TSMPriceProvider:IsAvailable()
  self.isAvailable = self:DetectAvailability()
  return self.isAvailable
end

function TSMPriceProvider:GetPrice(itemID)
  if not self:IsAvailable() then
    return nil
  end

  local itemString = "i:" .. tostring(itemID)

  if type(_G.TSM_API) == "table" and type(_G.TSM_API.GetCustomPriceValue) == "function" then
    local ok, value = pcall(_G.TSM_API.GetCustomPriceValue, "dbmarket", itemString)
    if ok then
      value = roundPrice(value)
      if value then
        return value
      end
    end

    ok, value = pcall(_G.TSM_API.GetCustomPriceValue, "dbminbuyout", itemString)
    if ok then
      return roundPrice(value)
    end
  end

  if type(_G.TSM_API_FOUR) == "table" then
    local customPrice = _G.TSM_API_FOUR.CustomPrice
    if type(customPrice) == "table" and type(customPrice.GetValue) == "function" then
      local ok, value = pcall(customPrice.GetValue, "dbmarket", itemString)
      if ok then
        value = roundPrice(value)
        if value then
          return value
        end
      end
    end
  end

  return nil
end

Addon:RegisterModule("TSMPriceProvider", TSMPriceProvider)
