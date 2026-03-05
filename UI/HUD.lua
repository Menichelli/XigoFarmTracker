local _, Addon = ...

local HUD = {}

function HUD:OnInitialize()
  self.money = Addon:GetModule("MoneyUtil")
  self.constants = Addon:GetModule("Constants")
  self.db = Addon.db.profile.ui.hud
  self.frame = nil
  self.elapsed = 0
end

function HUD:OnEnable()
  self:CreateFrame()
  Addon:RegisterMessage("METRICS_UPDATED", self, "OnMetricsUpdated")
  Addon:RegisterMessage("SESSION_STATE_CHANGED", self, "OnSessionStateChanged")
  self:Refresh(true)
end

function HUD:CreateFrame()
  if self.frame then
    return
  end

  local frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
  frame:SetSize(250, 96)
  frame:SetClampedToScreen(true)
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 14,
    insets = {
      left = 4,
      right = 4,
      top = 4,
      bottom = 4,
    },
  })
  frame:SetBackdropColor(0, 0, 0, 0.8)

  frame:SetScript("OnDragStart", function(hudFrame)
    if self.db.locked then
      return
    end
    hudFrame:StartMoving()
  end)

  frame:SetScript("OnDragStop", function(hudFrame)
    hudFrame:StopMovingOrSizing()
    self:SavePosition()
  end)

  frame:SetScript("OnUpdate", function(_, delta)
    self.elapsed = self.elapsed + delta
    if self.elapsed >= (self.constants.HUD_REFRESH_INTERVAL or 0.5) then
      self.elapsed = 0
      self:Refresh(true)
    end
  end)

  local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetPoint("TOPLEFT", 10, -10)
  title:SetText("XigoFarmTracker")

  local stateText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  stateText:SetPoint("TOPRIGHT", -10, -12)
  stateText:SetJustifyH("RIGHT")

  local currentText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  currentText:SetPoint("TOPLEFT", 10, -34)
  currentText:SetJustifyH("LEFT")

  local gainedText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  gainedText:SetPoint("TOPLEFT", 10, -52)
  gainedText:SetJustifyH("LEFT")

  local gphText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  gphText:SetPoint("TOPLEFT", 10, -70)
  gphText:SetJustifyH("LEFT")

  frame.titleText = title
  frame.stateText = stateText
  frame.currentText = currentText
  frame.gainedText = gainedText
  frame.gphText = gphText

  self.frame = frame
  self:ApplyPosition()
  self:SetLocked(self.db.locked)
  self:SetVisible(self.db.visible)
end

function HUD:ApplyPosition()
  if not self.frame then
    return
  end

  self.frame:ClearAllPoints()
  self.frame:SetPoint(self.db.point or "CENTER", UIParent, self.db.point or "CENTER", self.db.x or 0, self.db.y or 0)
  self.frame:SetScale(self.db.scale or 1.0)
end

function HUD:SavePosition()
  if not self.frame then
    return
  end

  local point, _, _, x, y = self.frame:GetPoint(1)
  self.db.point = point or "CENTER"
  self.db.x = math.floor((x or 0) + 0.5)
  self.db.y = math.floor((y or 0) + 0.5)
end

function HUD:SetLocked(isLocked)
  self.db.locked = (isLocked == true)
  if self.frame then
    self.frame:EnableMouse(not self.db.locked)
  end
end

function HUD:IsLocked()
  return self.db.locked == true
end

function HUD:SetVisible(visible)
  self.db.visible = (visible == true)
  if not self.frame then
    return
  end

  if self.db.visible then
    self.frame:Show()
  else
    self.frame:Hide()
  end
end

function HUD:Toggle()
  self:SetVisible(not self.db.visible)
end

function HUD:OnMetricsUpdated()
  self:Refresh(false)
end

function HUD:OnSessionStateChanged()
  self:Refresh(false)
end

function HUD:Refresh(forceRecompute)
  if not self.frame then
    return
  end

  local metrics = Addon:GetModule("Metrics")
  local session = Addon:GetModule("SessionManager")
  if not metrics or not session then
    return
  end

  local snapshot = metrics:GetSnapshot(forceRecompute)
  local state = session:GetState() or "UNKNOWN"

  self.frame.stateText:SetText(state)
  self.frame.currentText:SetText("Bags: " .. self.money:FormatCopper(snapshot.currentValueCopper or 0))
  self.frame.gainedText:SetText("Session: " .. self.money:FormatCopper(snapshot.sessionGainedCopper or 0))
  self.frame.gphText:SetText("Gold/hour: " .. self.money:FormatCopper(snapshot.goldPerHourCopper or 0))
end

Addon:RegisterModule("HUD", HUD)
