local _, Addon = ...

local OptionsPanel = {}
local SORT_MODE_ORDER = { "ITEM_ID", "QTY", "UNIT_PRICE", "TOTAL_PRICE" }
local SORT_MODE_LABELS = {
  ITEM_ID = "ItemID",
  QTY = "Quantity",
  UNIT_PRICE = "Unit price",
  TOTAL_PRICE = "Total price",
}

local function setCheckboxText(checkbox, text)
  local label = checkbox.Text or checkbox.text
  if label then
    label:SetText(text)
  end
end

function OptionsPanel:OnInitialize()
  self.panel = nil
  self.categoryID = nil
  self.eventFrame = CreateFrame("Frame")
  self.pendingOpen = false
  self.useTSMCheckbox = nil
  self.debugCheckbox = nil
  self.lockHUDCheckbox = nil
  self.sortDropdown = nil
  self.itemIDEditBox = nil
  self.priceEditBox = nil
  self.trackedItemsText = nil

  self.eventFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_ENABLED" and self.pendingOpen then
      self.pendingOpen = false
      self.eventFrame:UnregisterEvent("PLAYER_REGEN_ENABLED")
      self:Open()
    end
  end)
end

function OptionsPanel:OnEnable()
  self:CreatePanel()
  Addon:RegisterMessage("TRACKED_ITEMS_CHANGED", self, "Refresh")
  Addon:RegisterMessage("PRICE_SOURCE_CHANGED", self, "Refresh")
  Addon:RegisterMessage("SESSION_STATE_CHANGED", self, "Refresh")
end

function OptionsPanel:GetSortMode()
  local mode = Addon.db.profile.ui.options.trackedItemsSort
  if SORT_MODE_LABELS[mode] then
    return mode
  end
  return "ITEM_ID"
end

function OptionsPanel:GetSortModeLabel(mode)
  mode = mode or self:GetSortMode()
  return SORT_MODE_LABELS[mode] or SORT_MODE_LABELS.ITEM_ID
end

function OptionsPanel:RefreshSortDropdown()
  if not self.sortDropdown then
    return
  end

  local mode = self:GetSortMode()

  if UIDropDownMenu_SetSelectedValue then
    UIDropDownMenu_SetSelectedValue(self.sortDropdown, mode)
  end
  if UIDropDownMenu_SetText then
    UIDropDownMenu_SetText(self.sortDropdown, self:GetSortModeLabel(mode))
  end
end

function OptionsPanel:InitializeSortDropdown()
  if not self.sortDropdown or not UIDropDownMenu_Initialize then
    return
  end

  UIDropDownMenu_Initialize(self.sortDropdown, function(_, level)
    if level and level > 1 then
      return
    end

    for i = 1, #SORT_MODE_ORDER do
      local mode = SORT_MODE_ORDER[i]
      local info = UIDropDownMenu_CreateInfo and UIDropDownMenu_CreateInfo()
      if info then
        info.text = self:GetSortModeLabel(mode)
        info.value = mode
        info.checked = (mode == self:GetSortMode())
        info.func = function(button)
          self:SetSortMode(button.value)
        end
        info.isNotRadio = false
        info.keepShownOnClick = false
        UIDropDownMenu_AddButton(info, level)
      end
    end
  end)

  self:RefreshSortDropdown()
end

function OptionsPanel:SetSortMode(mode)
  if not SORT_MODE_LABELS[mode] then
    mode = "ITEM_ID"
  end

  Addon.db.profile.ui.options.trackedItemsSort = mode
  self:RefreshSortDropdown()

  local hud = Addon:GetModule("HUD")
  if hud then
    hud:Refresh(false)
  end

  self:Refresh()
end

function OptionsPanel:CreatePanel()
  if self.panel then
    return
  end

  local panel = CreateFrame("Frame", nil, UIParent)
  panel.name = "XigoFarmTracker"
  panel:SetScript("OnShow", function()
    self:Refresh()
  end)
  self.panel = panel

  local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -16)
  title:SetText("XigoFarmTracker")

  local subtitle = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
  subtitle:SetText("Session controls, pricing mode, and tracked items.")

  local useTSM = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
  useTSM:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", -2, -16)
  setCheckboxText(useTSM, "Use TSM prices when available")
  useTSM:SetScript("OnClick", function(button)
    local pricing = Addon:GetModule("PricingService")
    if pricing then
      pricing:SetTSMEnabled(button:GetChecked())
    end
    self:Refresh()
  end)
  self.useTSMCheckbox = useTSM

  local debug = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
  debug:SetPoint("TOPLEFT", useTSM, "BOTTOMLEFT", 0, -8)
  setCheckboxText(debug, "Enable debug logs")
  debug:SetScript("OnClick", function(button)
    Addon.db.global.debug = button:GetChecked() and true or false
  end)
  self.debugCheckbox = debug

  local lockHUD = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
  lockHUD:SetPoint("TOPLEFT", debug, "BOTTOMLEFT", 0, -8)
  setCheckboxText(lockHUD, "Lock HUD position")
  lockHUD:SetScript("OnClick", function(button)
    local hud = Addon:GetModule("HUD")
    if hud then
      hud:SetLocked(button:GetChecked())
    end
  end)
  self.lockHUDCheckbox = lockHUD

  local sortLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  sortLabel:SetPoint("TOPLEFT", lockHUD, "BOTTOMLEFT", 4, -12)
  sortLabel:SetText("Tracked items sort")

  local sortDropdown = CreateFrame("Frame", "XigoFarmTrackerSortDropdown", panel, "UIDropDownMenuTemplate")
  sortDropdown:SetPoint("TOPLEFT", sortLabel, "BOTTOMLEFT", -16, -2)
  if UIDropDownMenu_SetWidth then
    UIDropDownMenu_SetWidth(sortDropdown, 180)
  end
  if UIDropDownMenu_JustifyText then
    UIDropDownMenu_JustifyText(sortDropdown, "LEFT")
  end
  self.sortDropdown = sortDropdown
  self:InitializeSortDropdown()

  local startButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  startButton:SetSize(70, 22)
  startButton:SetPoint("TOPLEFT", sortDropdown, "BOTTOMLEFT", 16, -8)
  startButton:SetText("Start")
  startButton:SetScript("OnClick", function()
    local session = Addon:GetModule("SessionManager")
    if session then
      local ok, err = session:Start()
      if not ok then
        Addon:Print(err)
      end
    end
  end)

  local pauseButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  pauseButton:SetSize(70, 22)
  pauseButton:SetPoint("LEFT", startButton, "RIGHT", 8, 0)
  pauseButton:SetText("Pause")
  pauseButton:SetScript("OnClick", function()
    local session = Addon:GetModule("SessionManager")
    if session then
      local ok, err = session:Pause()
      if not ok then
        Addon:Print(err)
      end
    end
  end)

  local resumeButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  resumeButton:SetSize(70, 22)
  resumeButton:SetPoint("LEFT", pauseButton, "RIGHT", 8, 0)
  resumeButton:SetText("Resume")
  resumeButton:SetScript("OnClick", function()
    local session = Addon:GetModule("SessionManager")
    if session then
      local ok, err = session:Resume()
      if not ok then
        Addon:Print(err)
      end
    end
  end)

  local stopButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  stopButton:SetSize(70, 22)
  stopButton:SetPoint("TOPLEFT", startButton, "BOTTOMLEFT", 0, -8)
  stopButton:SetText("Stop")
  stopButton:SetScript("OnClick", function()
    local session = Addon:GetModule("SessionManager")
    if session then
      local ok, err = session:Stop()
      if not ok then
        Addon:Print(err)
      end
    end
  end)

  local resetButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  resetButton:SetSize(70, 22)
  resetButton:SetPoint("LEFT", stopButton, "RIGHT", 8, 0)
  resetButton:SetText("Reset")
  resetButton:SetScript("OnClick", function()
    local session = Addon:GetModule("SessionManager")
    if session then
      session:Reset()
    end
  end)

  local itemLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  itemLabel:SetPoint("TOPLEFT", stopButton, "BOTTOMLEFT", 0, -20)
  itemLabel:SetText("Track itemID")

  local itemIDBox = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
  itemIDBox:SetSize(100, 20)
  itemIDBox:SetPoint("TOPLEFT", itemLabel, "BOTTOMLEFT", 0, -4)
  itemIDBox:SetAutoFocus(false)
  itemIDBox:SetNumeric(true)
  self.itemIDEditBox = itemIDBox

  local priceLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  priceLabel:SetPoint("LEFT", itemIDBox, "RIGHT", 12, 0)
  priceLabel:SetText("Manual price (gold)")

  local priceBox = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
  priceBox:SetSize(100, 20)
  priceBox:SetPoint("TOPLEFT", priceLabel, "BOTTOMLEFT", 0, -4)
  priceBox:SetAutoFocus(false)
  self.priceEditBox = priceBox

  local saveItemButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  saveItemButton:SetSize(100, 22)
  saveItemButton:SetPoint("TOPLEFT", itemIDBox, "BOTTOMLEFT", 0, -8)
  saveItemButton:SetText("Add/Update")
  saveItemButton:SetScript("OnClick", function()
    self:SaveTrackedItem()
  end)

  local removeItemButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  removeItemButton:SetSize(100, 22)
  removeItemButton:SetPoint("LEFT", saveItemButton, "RIGHT", 12, 0)
  removeItemButton:SetText("Remove")
  removeItemButton:SetScript("OnClick", function()
    self:RemoveTrackedItem()
  end)

  local listTitle = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  listTitle:SetPoint("TOPLEFT", saveItemButton, "BOTTOMLEFT", 0, -16)
  listTitle:SetText("Tracked items")

  local listText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  listText:SetPoint("TOPLEFT", listTitle, "BOTTOMLEFT", 0, -6)
  listText:SetWidth(520)
  listText:SetJustifyH("LEFT")
  listText:SetJustifyV("TOP")
  listText:SetText("")
  self.trackedItemsText = listText

  if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
    local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name, panel.name)
    Settings.RegisterAddOnCategory(category)
    if category.GetID then
      self.categoryID = category:GetID()
    elseif category.ID then
      self.categoryID = category.ID
    end
  elseif InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory(panel)
  end
end

function OptionsPanel:Open()
  if not self.panel then
    self:CreatePanel()
  end

  if InCombatLockdown and InCombatLockdown() then
    if self.pendingOpen then
      return
    end
    self.pendingOpen = true
    self.eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    Addon:Print("Options cannot be opened in combat. Opening when combat ends.")
    return
  end

  if Settings and Settings.OpenToCategory and self.categoryID then
    Settings.OpenToCategory(self.categoryID)
    return
  end

  if InterfaceOptionsFrame_OpenToCategory then
    InterfaceOptionsFrame_OpenToCategory(self.panel)
    InterfaceOptionsFrame_OpenToCategory(self.panel)
  end
end

function OptionsPanel:SaveTrackedItem()
  local trackedItems = Addon:GetModule("TrackedItems")
  local money = Addon:GetModule("MoneyUtil")
  if not trackedItems or not money then
    return
  end

  local itemIDText = self.itemIDEditBox:GetText()
  local priceText = self.priceEditBox:GetText()
  local manualPriceCopper

  if priceText and priceText ~= "" then
    manualPriceCopper = money:ParseGoldToCopper(priceText)
    if not manualPriceCopper then
      Addon:Print("Invalid manual price. Enter a gold value, e.g. 12.5")
      return
    end
  end

  local itemID, err = trackedItems:Add(itemIDText, manualPriceCopper)
  if not itemID then
    Addon:Print(err)
    return
  end

  self.itemIDEditBox:SetText("")
  self.priceEditBox:SetText("")
  Addon:Print("Tracked item %d updated.", itemID)
  self:Refresh()
end

function OptionsPanel:RemoveTrackedItem()
  local trackedItems = Addon:GetModule("TrackedItems")
  if not trackedItems then
    return
  end

  local itemIDText = self.itemIDEditBox:GetText()
  local ok, err = trackedItems:Remove(itemIDText)
  if not ok then
    Addon:Print(err)
    return
  end

  self.itemIDEditBox:SetText("")
  self.priceEditBox:SetText("")
  Addon:Print("Tracked item removed.")
  self:Refresh()
end

function OptionsPanel:Refresh()
  if not self.panel then
    return
  end

  local pricing = Addon:GetModule("PricingService")
  local hud = Addon:GetModule("HUD")
  local trackedItems = Addon:GetModule("TrackedItems")
  local money = Addon:GetModule("MoneyUtil")
  local tableUtil = Addon:GetModule("TableUtil")

  self.useTSMCheckbox:SetChecked(pricing and pricing:IsTSMEnabled())
  self.debugCheckbox:SetChecked(Addon.db.global.debug == true)
  self.lockHUDCheckbox:SetChecked(hud and hud:IsLocked())
  self:RefreshSortDropdown()

  if not trackedItems or not money or not tableUtil then
    return
  end

  local tracked = trackedItems:GetAll()
  local lines = {}
  local sortedKeys = tableUtil:SortedNumericKeys(tracked)

  for i = 1, #sortedKeys do
    local itemID = sortedKeys[i]
    local entry = tracked[itemID]
    if entry and entry.enabled ~= false then
      local itemName = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(itemID)
      if not itemName then
        itemName = (GetItemInfo and GetItemInfo(itemID)) or ("item:" .. tostring(itemID))
      end

      local priceText = "no manual price"
      if entry.manualPriceCopper and entry.manualPriceCopper > 0 then
        priceText = money:FormatCopper(entry.manualPriceCopper)
      end

      lines[#lines + 1] = string.format("%d - %s (%s)", itemID, itemName, priceText)
    end
  end

  if #lines == 0 then
    lines[1] = "No tracked items yet."
  end

  self.trackedItemsText:SetText(table.concat(lines, "\n"))
end

Addon:RegisterModule("OptionsPanel", OptionsPanel)
