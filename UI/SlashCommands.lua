local _, Addon = ...

local SlashCommands = {}

local function splitFirstToken(input)
  if not input then
    return "", ""
  end
  local cmd, rest = input:match("^(%S+)%s*(.-)$")
  if not cmd then
    return "", ""
  end
  return cmd, rest
end

function SlashCommands:OnEnable()
  _G.SLASH_XIGOFARMTRACKER1 = "/xft"
  _G.SLASH_XIGOFARMTRACKER2 = "/xigofarmtracker"
  _G.SlashCmdList.XIGOFARMTRACKER = function(msg)
    self:HandleCommand(msg)
  end
end

function SlashCommands:PrintHelp()
  Addon:Print("Commands:")
  Addon:Print("/xft start|pause|resume|stop|reset")
  Addon:Print("/xft add <itemID> [priceGold]")
  Addon:Print("/xft remove <itemID>")
  Addon:Print("/xft price <itemID> <priceGold>")
  Addon:Print("/xft lock|unlock|toggle|show|hide")
  Addon:Print("/xft options")
  Addon:Print("/xft debug on|off")
  Addon:Print("/xft list")
end

function SlashCommands:HandleCommand(message)
  local cmd, rest = splitFirstToken((message or ""):lower())

  if cmd == "" or cmd == "help" then
    self:PrintHelp()
    return
  end

  local session = Addon:GetModule("SessionManager")
  local tracked = Addon:GetModule("TrackedItems")
  local options = Addon:GetModule("OptionsPanel")
  local hud = Addon:GetModule("HUD")
  local money = Addon:GetModule("MoneyUtil")
  local tableUtil = Addon:GetModule("TableUtil")

  if cmd == "start" then
    local ok, err = session:Start()
    Addon:Print(ok and "Session started." or err)
    return
  end
  if cmd == "pause" then
    local ok, err = session:Pause()
    Addon:Print(ok and "Session paused." or err)
    return
  end
  if cmd == "resume" then
    local ok, err = session:Resume()
    Addon:Print(ok and "Session resumed." or err)
    return
  end
  if cmd == "stop" then
    local ok, err = session:Stop()
    Addon:Print(ok and "Session stopped." or err)
    return
  end
  if cmd == "reset" then
    session:Reset()
    Addon:Print("Session reset.")
    return
  end

  if cmd == "options" then
    options:Open()
    return
  end

  if cmd == "lock" then
    hud:SetLocked(true)
    Addon:Print("HUD locked.")
    return
  end
  if cmd == "unlock" then
    hud:SetLocked(false)
    Addon:Print("HUD unlocked.")
    return
  end
  if cmd == "toggle" then
    hud:Toggle()
    return
  end
  if cmd == "show" then
    hud:SetVisible(true)
    return
  end
  if cmd == "hide" then
    hud:SetVisible(false)
    return
  end

  if cmd == "debug" then
    local flag = rest:match("^(%S+)$")
    if flag == "on" then
      Addon.db.global.debug = true
      Addon:Print("Debug enabled.")
    elseif flag == "off" then
      Addon.db.global.debug = false
      Addon:Print("Debug disabled.")
    else
      Addon:Print("Usage: /xft debug on|off")
    end
    return
  end

  if cmd == "add" then
    local itemIDText, priceText = rest:match("^(%S+)%s*(%S*)$")
    if not itemIDText then
      Addon:Print("Usage: /xft add <itemID> [priceGold]")
      return
    end

    local manualPrice
    if priceText and priceText ~= "" then
      manualPrice = money:ParseGoldToCopper(priceText)
      if not manualPrice then
        Addon:Print("Invalid price. Use gold value (example: 12.5)")
        return
      end
    end

    local itemID, err = tracked:Add(itemIDText, manualPrice)
    if not itemID then
      Addon:Print(err)
      return
    end

    Addon:Print("Tracked item %d added/updated.", itemID)
    return
  end

  if cmd == "remove" then
    local itemIDText = rest:match("^(%S+)$")
    if not itemIDText then
      Addon:Print("Usage: /xft remove <itemID>")
      return
    end

    local ok, err = tracked:Remove(itemIDText)
    Addon:Print(ok and "Tracked item removed." or err)
    return
  end

  if cmd == "price" then
    local itemIDText, priceText = rest:match("^(%S+)%s+(%S+)$")
    if not itemIDText or not priceText then
      Addon:Print("Usage: /xft price <itemID> <priceGold>")
      return
    end

    local manualPrice = money:ParseGoldToCopper(priceText)
    if not manualPrice then
      Addon:Print("Invalid price. Use gold value (example: 12.5)")
      return
    end

    local ok, err = tracked:SetManualPrice(itemIDText, manualPrice)
    Addon:Print(ok and "Manual price updated." or err)
    return
  end

  if cmd == "list" then
    local trackedItems = tracked:GetAll()
    local keys = tableUtil:SortedNumericKeys(trackedItems)
    if #keys == 0 then
      Addon:Print("No tracked items.")
      return
    end

    Addon:Print("Tracked items:")
    for i = 1, #keys do
      local itemID = keys[i]
      local entry = trackedItems[itemID]
      local text = "no manual price"
      if entry.manualPriceCopper and entry.manualPriceCopper > 0 then
        text = money:FormatCopper(entry.manualPriceCopper)
      end
      Addon:Print(string.format("- %d (%s)", itemID, text))
    end
    return
  end

  self:PrintHelp()
end

Addon:RegisterModule("SlashCommands", SlashCommands)
