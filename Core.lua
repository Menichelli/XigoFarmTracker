local ADDON_NAME, Addon = ...

Addon.name = ADDON_NAME
Addon.modules = Addon.modules or {}
Addon.moduleOrder = Addon.moduleOrder or {}
Addon.eventSubscribers = Addon.eventSubscribers or {}
Addon.messageSubscribers = Addon.messageSubscribers or {}
Addon.isLoaded = false
Addon.isEnabled = false

local eventFrame = CreateFrame("Frame")
Addon.eventFrame = eventFrame

local errorHandler = _G.CallErrorHandler
if type(errorHandler) ~= "function" and type(_G.geterrorhandler) == "function" then
  errorHandler = _G.geterrorhandler()
end
if type(errorHandler) ~= "function" then
  errorHandler = function(err)
    return err
  end
end

local function safeCall(context, fn, ...)
  local ok, err = xpcall(fn, errorHandler, ...)
  if not ok then
    print(string.format("|cffff5555%s|r %s: %s", ADDON_NAME, context, tostring(err)))
  end
end

local function deepCopy(value)
  if type(value) ~= "table" then
    return value
  end

  local result = {}
  for k, v in pairs(value) do
    result[k] = deepCopy(v)
  end
  return result
end

local function applyDefaults(target, defaults)
  for key, defaultValue in pairs(defaults) do
    local targetValue = target[key]
    if targetValue == nil then
      target[key] = deepCopy(defaultValue)
    elseif type(defaultValue) == "table" and type(targetValue) == "table" then
      applyDefaults(targetValue, defaultValue)
    end
  end
end

local defaults = {
  schemaVersion = 1,
  global = {
    useTSM = true,
    priceCacheTTLSeconds = 60,
    debug = false,
  },
  profile = {
    trackedItems = {},
    ui = {
      hud = {
        point = "CENTER",
        x = 0,
        y = 0,
        scale = 1.0,
        locked = false,
        visible = true,
      },
      options = {
        minimapButton = false,
      },
    },
    session = {
      state = "IDLE",
      startedAt = 0,
      lastStateChangeAt = 0,
      activeSeconds = 0,
      gainedByItem = {},
      baselineBagCounts = {},
      lastBagCounts = {},
      lastComputed = {
        currentValueCopper = 0,
        sessionGainedCopper = 0,
        goldPerHourCopper = 0,
        activeSeconds = 0,
        updatedAt = 0,
      },
      wasRunningBeforeLogout = false,
    },
    history = {},
  },
}

function Addon:Debug(...)
  local db = self.db
  if not db or not db.global or not db.global.debug then
    return
  end

  print("|cff44ddffXFT|r", ...)
end

function Addon:Print(message, ...)
  if select("#", ...) > 0 then
    message = string.format(message, ...)
  end
  print("|cff44ddffXFT|r " .. tostring(message))
end

function Addon:RegisterModule(name, module)
  assert(type(name) == "string" and name ~= "", "Module name must be a non-empty string.")
  assert(type(module) == "table", "Module must be a table.")
  assert(not self.modules[name], "Module already registered: " .. name)

  module.name = name
  module.addon = self

  self.modules[name] = module
  table.insert(self.moduleOrder, name)
end

function Addon:GetModule(name)
  return self.modules[name]
end

function Addon:RegisterEvent(eventName, target, method)
  assert(type(eventName) == "string" and eventName ~= "", "Event name is required.")

  if not self.eventSubscribers[eventName] then
    self.eventSubscribers[eventName] = {}
    eventFrame:RegisterEvent(eventName)
  end

  local subscribers = self.eventSubscribers[eventName]
  subscribers[#subscribers + 1] = {
    target = target,
    method = method,
  }
end

function Addon:RegisterMessage(messageName, target, method)
  assert(type(messageName) == "string" and messageName ~= "", "Message name is required.")

  if not self.messageSubscribers[messageName] then
    self.messageSubscribers[messageName] = {}
  end

  local subscribers = self.messageSubscribers[messageName]
  subscribers[#subscribers + 1] = {
    target = target,
    method = method,
  }
end

function Addon:SendMessage(messageName, ...)
  local subscribers = self.messageSubscribers[messageName]
  if not subscribers then
    return
  end

  for i = 1, #subscribers do
    local subscriber = subscribers[i]
    local target = subscriber.target
    local method = subscriber.method
    local fn

    if type(method) == "string" and type(target) == "table" then
      fn = target[method]
    elseif type(method) == "function" then
      fn = method
    end

    if type(fn) == "function" then
      if type(target) == "table" then
        safeCall("message " .. messageName, fn, target, messageName, ...)
      else
        safeCall("message " .. messageName, fn, messageName, ...)
      end
    end
  end
end

function Addon:DispatchEvent(eventName, ...)
  local subscribers = self.eventSubscribers[eventName]
  if not subscribers then
    return
  end

  for i = 1, #subscribers do
    local subscriber = subscribers[i]
    local target = subscriber.target
    local method = subscriber.method
    local fn

    if type(method) == "string" and type(target) == "table" then
      fn = target[method]
    elseif type(method) == "function" then
      fn = method
    elseif type(target) == "table" then
      fn = target[eventName]
    end

    if type(fn) == "function" then
      if type(target) == "table" then
        safeCall("event " .. eventName, fn, target, eventName, ...)
      else
        safeCall("event " .. eventName, fn, eventName, ...)
      end
    end
  end
end

function Addon:InitializeDatabase()
  if type(XigoFarmTrackerDB) ~= "table" then
    XigoFarmTrackerDB = {}
  end

  applyDefaults(XigoFarmTrackerDB, defaults)
  self.db = XigoFarmTrackerDB
end

function Addon:InitializeModules()
  if self.modulesInitialized then
    return
  end

  for i = 1, #self.moduleOrder do
    local name = self.moduleOrder[i]
    local module = self.modules[name]
    if type(module.OnInitialize) == "function" then
      safeCall("initialize module " .. name, module.OnInitialize, module)
    end
  end

  self.modulesInitialized = true
end

function Addon:EnableModules()
  if self.isEnabled then
    return
  end

  for i = 1, #self.moduleOrder do
    local name = self.moduleOrder[i]
    local module = self.modules[name]
    if type(module.OnEnable) == "function" then
      safeCall("enable module " .. name, module.OnEnable, module)
    end
  end

  self.isEnabled = true
end

function Addon:DisableModules()
  if not self.isEnabled then
    return
  end

  for i = #self.moduleOrder, 1, -1 do
    local name = self.moduleOrder[i]
    local module = self.modules[name]
    if type(module.OnDisable) == "function" then
      safeCall("disable module " .. name, module.OnDisable, module)
    end
  end

  self.isEnabled = false
end

function Addon:OnAddonLoaded(_, loadedAddonName)
  if loadedAddonName ~= ADDON_NAME then
    return
  end

  self:InitializeDatabase()
  self:InitializeModules()
  self.isLoaded = true
  self:SendMessage("ADDON_READY")
end

function Addon:OnPlayerLogin()
  if not self.isLoaded then
    return
  end

  self:EnableModules()
  self:SendMessage("PLAYER_READY")
end

function Addon:OnPlayerLogout()
  if self.isEnabled then
    self:DisableModules()
  end
end

eventFrame:SetScript("OnEvent", function(_, eventName, ...)
  Addon:DispatchEvent(eventName, ...)
end)

Addon:RegisterEvent("ADDON_LOADED", Addon, "OnAddonLoaded")
Addon:RegisterEvent("PLAYER_LOGIN", Addon, "OnPlayerLogin")
Addon:RegisterEvent("PLAYER_LOGOUT", Addon, "OnPlayerLogout")
