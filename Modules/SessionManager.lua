local _, Addon = ...

local SessionManager = {}

local function now()
  return time()
end

local function ensureSessionDefaults(session)
  session.state = session.state or "IDLE"
  session.startedAt = session.startedAt or 0
  session.lastStateChangeAt = session.lastStateChangeAt or 0
  session.activeSeconds = session.activeSeconds or 0
  session.gainedByItem = session.gainedByItem or {}
  session.baselineBagCounts = session.baselineBagCounts or {}
  session.lastBagCounts = session.lastBagCounts or {}
  session.lastComputed = session.lastComputed or {}
  session.lastComputed.currentValueCopper = session.lastComputed.currentValueCopper or 0
  session.lastComputed.sessionGainedCopper = session.lastComputed.sessionGainedCopper or 0
  session.lastComputed.goldPerHourCopper = session.lastComputed.goldPerHourCopper or 0
  session.lastComputed.activeSeconds = session.lastComputed.activeSeconds or 0
  session.lastComputed.updatedAt = session.lastComputed.updatedAt or 0
  session.wasRunningBeforeLogout = session.wasRunningBeforeLogout or false
end

function SessionManager:OnInitialize()
  self.constants = Addon:GetModule("Constants")
  self.db = Addon.db.profile.session
  ensureSessionDefaults(self.db)
end

function SessionManager:OnEnable()
  -- Do not count offline time after relog/reload.
  if self.db.state == self.constants.SESSION_STATES.RUNNING then
    self.db.lastStateChangeAt = now()
  end
end

function SessionManager:OnDisable()
  self.db.activeSeconds = self:GetActiveSeconds()
  self.db.wasRunningBeforeLogout = (self.db.state == self.constants.SESSION_STATES.RUNNING)
  self.db.lastStateChangeAt = now()
end

function SessionManager:GetState()
  return self.db.state
end

function SessionManager:IsRunning()
  return self.db.state == self.constants.SESSION_STATES.RUNNING
end

function SessionManager:IsPaused()
  return self.db.state == self.constants.SESSION_STATES.PAUSED
end

function SessionManager:GetActiveSeconds()
  local activeSeconds = self.db.activeSeconds or 0
  if self.db.state == self.constants.SESSION_STATES.RUNNING then
    local delta = now() - (self.db.lastStateChangeAt or now())
    if delta > 0 then
      activeSeconds = activeSeconds + delta
    end
  end
  return math.max(0, activeSeconds)
end

function SessionManager:AccumulateActiveTime()
  if self.db.state ~= self.constants.SESSION_STATES.RUNNING then
    return
  end

  local current = now()
  local last = self.db.lastStateChangeAt or current
  local delta = current - last
  if delta > 0 then
    self.db.activeSeconds = (self.db.activeSeconds or 0) + delta
  end
  self.db.lastStateChangeAt = current
end

function SessionManager:Start()
  if self.db.state == self.constants.SESSION_STATES.RUNNING then
    return false, "Session already running"
  end

  local current = now()
  self.db.state = self.constants.SESSION_STATES.RUNNING
  self.db.startedAt = current
  self.db.lastStateChangeAt = current
  self.db.activeSeconds = 0
  self.db.gainedByItem = {}
  self.db.lastComputed = {
    currentValueCopper = 0,
    sessionGainedCopper = 0,
    goldPerHourCopper = 0,
    activeSeconds = 0,
    updatedAt = current,
  }
  self.db.wasRunningBeforeLogout = true

  Addon:SendMessage("SESSION_STATE_CHANGED", self.db.state)
  Addon:SendMessage("SESSION_STARTED")
  return true
end

function SessionManager:Pause()
  if self.db.state ~= self.constants.SESSION_STATES.RUNNING then
    return false, "Session is not running"
  end

  self:AccumulateActiveTime()
  self.db.state = self.constants.SESSION_STATES.PAUSED
  self.db.lastStateChangeAt = now()
  self.db.wasRunningBeforeLogout = false

  Addon:SendMessage("SESSION_STATE_CHANGED", self.db.state)
  Addon:SendMessage("SESSION_PAUSED")
  return true
end

function SessionManager:Resume()
  if self.db.state ~= self.constants.SESSION_STATES.PAUSED then
    return false, "Session is not paused"
  end

  self.db.state = self.constants.SESSION_STATES.RUNNING
  self.db.lastStateChangeAt = now()
  self.db.wasRunningBeforeLogout = true

  Addon:SendMessage("SESSION_STATE_CHANGED", self.db.state)
  Addon:SendMessage("SESSION_RESUMED")
  return true
end

function SessionManager:Stop()
  if self.db.state == self.constants.SESSION_STATES.STOPPED or self.db.state == self.constants.SESSION_STATES.IDLE then
    return false, "No active session to stop"
  end

  if self.db.state == self.constants.SESSION_STATES.RUNNING then
    self:AccumulateActiveTime()
  end

  self.db.state = self.constants.SESSION_STATES.STOPPED
  self.db.lastStateChangeAt = now()
  self.db.wasRunningBeforeLogout = false

  Addon:SendMessage("SESSION_STATE_CHANGED", self.db.state)
  Addon:SendMessage("SESSION_STOPPED")
  return true
end

function SessionManager:Reset()
  local current = now()
  self.db.state = self.constants.SESSION_STATES.IDLE
  self.db.startedAt = 0
  self.db.lastStateChangeAt = current
  self.db.activeSeconds = 0
  self.db.gainedByItem = {}
  self.db.baselineBagCounts = {}
  self.db.lastBagCounts = {}
  self.db.lastComputed = {
    currentValueCopper = 0,
    sessionGainedCopper = 0,
    goldPerHourCopper = 0,
    activeSeconds = 0,
    updatedAt = current,
  }
  self.db.wasRunningBeforeLogout = false

  Addon:SendMessage("SESSION_STATE_CHANGED", self.db.state)
  Addon:SendMessage("SESSION_RESET")
  return true
end

function SessionManager:RecordDelta(itemID, deltaCount)
  if self.db.state ~= self.constants.SESSION_STATES.RUNNING then
    return
  end
  if deltaCount <= 0 then
    return
  end

  local gainedByItem = self.db.gainedByItem
  gainedByItem[itemID] = (gainedByItem[itemID] or 0) + deltaCount
  Addon:SendMessage("SESSION_GAIN_UPDATED", itemID, deltaCount, gainedByItem[itemID])
end

Addon:RegisterModule("SessionManager", SessionManager)
