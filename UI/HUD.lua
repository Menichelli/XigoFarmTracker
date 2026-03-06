local _, Addon = ...

local HUD = {}

local FALLBACK_ICON = 134400
local ITEM_ROW_HEIGHT = 20

local function getItemIcon(itemID)
  local icon
  if C_Item and C_Item.GetItemIconByID then
    icon = C_Item.GetItemIconByID(itemID)
  end
  if not icon and GetItemIcon then
    icon = GetItemIcon(itemID)
  end
  return icon or FALLBACK_ICON
end

local function createControlButton(parent, label, callback)
  local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  button:SetSize(64, 22)
  button:SetText(label)
  button:SetScript("OnClick", callback)
  return button
end

local function getTrackedItemsSortMode()
  local db = Addon.db
  local mode = db and db.profile and db.profile.ui and db.profile.ui.options and db.profile.ui.options.trackedItemsSort
  if mode == "ITEM_ID" or mode == "QTY" or mode == "UNIT_PRICE" or mode == "TOTAL_PRICE" then
    return mode
  end
  return "ITEM_ID"
end

function HUD:OnInitialize()
  self.money = Addon:GetModule("MoneyUtil")
  self.constants = Addon:GetModule("Constants")
  self.db = Addon.db.profile.ui.hud
  self.frame = nil
  self.elapsed = 0
  self.rows = {}
end

function HUD:OnEnable()
  self:CreateFrame()
  Addon:RegisterMessage("METRICS_UPDATED", self, "OnDataUpdated")
  Addon:RegisterMessage("SESSION_STATE_CHANGED", self, "OnDataUpdated")
  Addon:RegisterMessage("TRACKED_ITEMS_CHANGED", self, "OnDataUpdated")
  Addon:RegisterMessage("INVENTORY_COUNTS_UPDATED", self, "OnDataUpdated")
  Addon:RegisterMessage("PRICE_SOURCE_CHANGED", self, "OnDataUpdated")
  self:Refresh(true)
end

function HUD:CreateFrame()
  if self.frame then
    return
  end

  local frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
  frame:SetSize(460, 340)
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

  local startButton = createControlButton(frame, "Start", function()
    self:HandleSessionAction("Start")
  end)
  startButton:SetPoint("TOPLEFT", 10, -92)

  local pauseButton = createControlButton(frame, "Pause", function()
    self:HandleSessionAction("Pause")
  end)
  pauseButton:SetPoint("LEFT", startButton, "RIGHT", 6, 0)

  local resumeButton = createControlButton(frame, "Resume", function()
    self:HandleSessionAction("Resume")
  end)
  resumeButton:SetPoint("LEFT", pauseButton, "RIGHT", 6, 0)

  local stopButton = createControlButton(frame, "Stop", function()
    self:HandleSessionAction("Stop")
  end)
  stopButton:SetPoint("LEFT", resumeButton, "RIGHT", 6, 0)

  local resetButton = createControlButton(frame, "Reset", function()
    self:HandleSessionAction("Reset")
  end)
  resetButton:SetPoint("LEFT", stopButton, "RIGHT", 6, 0)

  local headerID = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  headerID:SetPoint("TOPLEFT", 10, -122)
  headerID:SetText("ID")

  local headerIcon = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  headerIcon:SetPoint("TOPLEFT", 70, -122)
  headerIcon:SetText("Icon")

  local headerQty = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  headerQty:SetPoint("TOPLEFT", 102, -122)
  headerQty:SetText("Qty")

  local headerUnit = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  headerUnit:SetPoint("TOPLEFT", 162, -122)
  headerUnit:SetText("Unit price")

  local headerTotal = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  headerTotal:SetPoint("TOPLEFT", 292, -122)
  headerTotal:SetText("Total price")

  local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
  scrollFrame:SetPoint("TOPLEFT", 10, -138)
  scrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)

  local content = CreateFrame("Frame", nil, scrollFrame)
  content:SetSize(420, ITEM_ROW_HEIGHT)
  scrollFrame:SetScrollChild(content)

  local emptyText = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  emptyText:SetPoint("TOPLEFT", 0, -2)
  emptyText:SetText("No tracked items.")

  frame.titleText = title
  frame.stateText = stateText
  frame.currentText = currentText
  frame.gainedText = gainedText
  frame.gphText = gphText
  frame.startButton = startButton
  frame.pauseButton = pauseButton
  frame.resumeButton = resumeButton
  frame.stopButton = stopButton
  frame.resetButton = resetButton
  frame.itemsScrollFrame = scrollFrame
  frame.itemsContent = content
  frame.emptyText = emptyText

  self.frame = frame
  self:ApplyPosition()
  self:SetLocked(self.db.locked)
  self:SetVisible(self.db.visible)
end

function HUD:EnsureRow(index)
  local existing = self.rows[index]
  if existing then
    return existing
  end

  local row = CreateFrame("Frame", nil, self.frame.itemsContent)
  row:SetHeight(ITEM_ROW_HEIGHT)
  row:SetPoint("LEFT", self.frame.itemsContent, "LEFT", 0, 0)
  row:SetPoint("RIGHT", self.frame.itemsContent, "RIGHT", 0, 0)

  if index == 1 then
    row:SetPoint("TOP", self.frame.itemsContent, "TOP", 0, 0)
  else
    row:SetPoint("TOP", self.rows[index - 1], "BOTTOM", 0, 0)
  end

  local idText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  idText:SetPoint("LEFT", 10, 0)
  idText:SetWidth(52)
  idText:SetJustifyH("LEFT")

  local icon = row:CreateTexture(nil, "ARTWORK")
  icon:SetSize(16, 16)
  icon:SetPoint("LEFT", 72, 0)

  local qtyText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  qtyText:SetPoint("LEFT", 100, 0)
  qtyText:SetWidth(45)
  qtyText:SetJustifyH("RIGHT")

  local unitPriceText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  unitPriceText:SetPoint("LEFT", 160, 0)
  unitPriceText:SetWidth(120)
  unitPriceText:SetJustifyH("RIGHT")

  local totalPriceText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  totalPriceText:SetPoint("LEFT", 290, 0)
  totalPriceText:SetWidth(120)
  totalPriceText:SetJustifyH("RIGHT")

  row.idText = idText
  row.icon = icon
  row.qtyText = qtyText
  row.unitPriceText = unitPriceText
  row.totalPriceText = totalPriceText

  self.rows[index] = row
  return row
end

function HUD:HandleSessionAction(methodName)
  local session = Addon:GetModule("SessionManager")
  if not session then
    return
  end

  local method = session[methodName]
  if type(method) ~= "function" then
    return
  end

  local ok, err = method(session)
  if ok == false and err then
    Addon:Print(err)
  end
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

function HUD:OnDataUpdated()
  self:Refresh(false)
end

function HUD:RefreshButtons(state)
  if not self.frame then
    return
  end

  local states = self.constants.SESSION_STATES
  local isRunning = (state == states.RUNNING)
  local isPaused = (state == states.PAUSED)
  local isStopped = (state == states.STOPPED)
  local isIdle = (state == states.IDLE)

  self.frame.startButton:SetEnabled(isStopped or isIdle)
  self.frame.pauseButton:SetEnabled(isRunning)
  self.frame.resumeButton:SetEnabled(isPaused)
  self.frame.stopButton:SetEnabled(isRunning or isPaused)
  self.frame.resetButton:SetEnabled(true)
end

function HUD:RefreshTrackedItems()
  if not self.frame then
    return
  end

  local trackedItems = Addon:GetModule("TrackedItems")
  local inventoryTracker = Addon:GetModule("InventoryTracker")
  local pricingService = Addon:GetModule("PricingService")
  local tableUtil = Addon:GetModule("TableUtil")
  if not trackedItems or not inventoryTracker or not pricingService or not tableUtil then
    return
  end

  local tracked = trackedItems:GetAll()
  local counts = inventoryTracker:GetCurrentCounts() or {}
  local sortedKeys = tableUtil:SortedNumericKeys(tracked)
  local rowsData = {}
  local sortMode = getTrackedItemsSortMode()

  for i = 1, #sortedKeys do
    local itemID = sortedKeys[i]
    local entry = tracked[itemID]
    if entry and entry.enabled ~= false then
      local quantity = counts[itemID] or 0
      local unitPrice = pricingService:GetUnitPrice(itemID) or 0
      rowsData[#rowsData + 1] = {
        itemID = itemID,
        quantity = quantity,
        unitPrice = unitPrice,
        totalPrice = quantity * unitPrice,
      }
    end
  end

  table.sort(rowsData, function(a, b)
    if sortMode == "QTY" then
      if a.quantity ~= b.quantity then
        return a.quantity > b.quantity
      end
    elseif sortMode == "UNIT_PRICE" then
      if a.unitPrice ~= b.unitPrice then
        return a.unitPrice > b.unitPrice
      end
    elseif sortMode == "TOTAL_PRICE" then
      if a.totalPrice ~= b.totalPrice then
        return a.totalPrice > b.totalPrice
      end
    end
    return a.itemID < b.itemID
  end)

  if #rowsData == 0 then
    self.frame.emptyText:Show()
    for i = 1, #self.rows do
      self.rows[i]:Hide()
    end
    self.frame.itemsContent:SetHeight(ITEM_ROW_HEIGHT)
    return
  end

  self.frame.emptyText:Hide()

  for index = 1, #rowsData do
    local rowData = rowsData[index]
    local itemID = rowData.itemID
    local row = self:EnsureRow(index)

    row.idText:SetText(tostring(itemID))
    row.icon:SetTexture(getItemIcon(itemID))
    row.qtyText:SetText(tostring(rowData.quantity))
    row.unitPriceText:SetText(self.money:FormatCopper(rowData.unitPrice))
    row.totalPriceText:SetText(self.money:FormatCopper(rowData.totalPrice))
    row:Show()
  end

  for i = #rowsData + 1, #self.rows do
    self.rows[i]:Hide()
  end

  self.frame.itemsContent:SetHeight(math.max(ITEM_ROW_HEIGHT, #rowsData * ITEM_ROW_HEIGHT))
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

  self:RefreshButtons(state)
  self:RefreshTrackedItems()
end

Addon:RegisterModule("HUD", HUD)
