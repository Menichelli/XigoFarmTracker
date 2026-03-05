local _, Addon = ...

local EasterEgg = {}

local TARGET_NAME = "Rosebomb"
local WHISPER_MESSAGE = "BAU BAU"

function EasterEgg:OnInitialize()
  self.lastTargetGUID = nil
end

function EasterEgg:OnEnable()
  Addon:RegisterEvent("PLAYER_TARGET_CHANGED", self, "OnPlayerTargetChanged")
end

function EasterEgg:OnPlayerTargetChanged()
  local targetGUID = UnitGUID("target")
  if targetGUID == self.lastTargetGUID then
    return
  end

  self.lastTargetGUID = targetGUID
  if not targetGUID then
    return
  end

  if not UnitIsPlayer("target") then
    return
  end

  local targetName = UnitName("target")
  if targetName ~= TARGET_NAME then
    return
  end

  local whisperTarget = GetUnitName and GetUnitName("target", true) or targetName
  if not whisperTarget or whisperTarget == "" then
    return
  end

  SendChatMessage(WHISPER_MESSAGE, "WHISPER", nil, whisperTarget)
end

Addon:RegisterModule("EasterEgg", EasterEgg)
