local _, Addon = ...

local PricingService = {}

local function nowSeconds()
  return GetTime()
end

function PricingService:OnInitialize()
  self.cache = {}
end

function PricingService:OnEnable()
  Addon:RegisterMessage("TRACKED_ITEMS_CHANGED", self, "OnTrackedItemsChanged")
end

function PricingService:OnTrackedItemsChanged(_, itemID)
  if itemID then
    self.cache[itemID] = nil
  else
    self.cache = {}
  end
  Addon:SendMessage("PRICE_SOURCE_CHANGED")
end

function PricingService:InvalidateCache(itemID)
  if itemID then
    self.cache[itemID] = nil
  else
    self.cache = {}
  end
  Addon:SendMessage("PRICE_SOURCE_CHANGED")
end

function PricingService:IsTSMEnabled()
  return Addon.db.global.useTSM == true
end

function PricingService:SetTSMEnabled(enabled)
  Addon.db.global.useTSM = enabled == true
  self:InvalidateCache()
end

function PricingService:GetUnitPrice(itemID)
  itemID = tonumber(itemID)
  if not itemID then
    return 0, "NONE"
  end
  itemID = math.floor(itemID)

  local ttl = tonumber(Addon.db.global.priceCacheTTLSeconds) or 60
  ttl = math.max(1, math.floor(ttl))
  local current = nowSeconds()
  local cached = self.cache[itemID]
  if cached and cached.expiresAt > current then
    return cached.price, cached.source
  end

  local price
  local source = "NONE"
  local tsmProvider = Addon:GetModule("TSMPriceProvider")
  local manualProvider = Addon:GetModule("ManualPriceProvider")

  if self:IsTSMEnabled() and tsmProvider and tsmProvider:IsAvailable() then
    price = tsmProvider:GetPrice(itemID)
    if price and price > 0 then
      source = "TSM"
    end
  end

  if not price and manualProvider then
    price = manualProvider:GetPrice(itemID)
    if price and price > 0 then
      source = "MANUAL"
    end
  end

  if not price then
    price = 0
    source = "NONE"
  end

  self.cache[itemID] = {
    price = price,
    source = source,
    expiresAt = current + ttl,
  }

  return price, source
end

Addon:RegisterModule("PricingService", PricingService)
