local _, Addon = ...

local Money = {}

function Money:FormatCopper(value)
  local constants = Addon:GetModule("Constants")
  local copperPerSilver = constants.COPPER_PER_SILVER
  local copperPerGold = constants.COPPER_PER_GOLD
  local sign = ""

  value = tonumber(value) or 0
  value = math.floor(value + 0.5)

  if value < 0 then
    sign = "-"
    value = math.abs(value)
  end

  local gold = math.floor(value / copperPerGold)
  local silver = math.floor((value % copperPerGold) / copperPerSilver)
  local copper = value % copperPerSilver

  if gold > 0 then
    return string.format("%s%dg %02ds %02dc", sign, gold, silver, copper)
  end
  if silver > 0 then
    return string.format("%s%ds %02dc", sign, silver, copper)
  end
  return string.format("%s%dc", sign, copper)
end

-- Parses input as gold (decimal accepted), then converts to copper.
function Money:ParseGoldToCopper(text)
  local numeric = tonumber(text)
  if not numeric then
    return nil
  end

  local constants = Addon:GetModule("Constants")
  return math.max(0, math.floor((numeric * constants.COPPER_PER_GOLD) + 0.5))
end

Addon:RegisterModule("MoneyUtil", Money)
