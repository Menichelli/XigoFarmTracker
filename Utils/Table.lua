local _, Addon = ...

local TableUtil = {}

function TableUtil:CopyMap(source)
  local result = {}
  if type(source) ~= "table" then
    return result
  end

  for k, v in pairs(source) do
    result[k] = v
  end
  return result
end

function TableUtil:SortedNumericKeys(map)
  local keys = {}
  if type(map) ~= "table" then
    return keys
  end

  for k in pairs(map) do
    if type(k) == "number" then
      keys[#keys + 1] = k
    end
  end

  table.sort(keys)
  return keys
end

Addon:RegisterModule("TableUtil", TableUtil)
