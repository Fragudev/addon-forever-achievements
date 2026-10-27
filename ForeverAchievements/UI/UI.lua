local _, ns = ...

-- Entry point of the interface. Phase 3 calls ns.UI.Start(app) once after login (inside pcall); everything heavy is
-- built lazily: the main window on the first open, the toast on the first toast, the tracker when something is
-- tracked. The controller below is what the frames receive as `ui`.
--   app: { store, bus, catalog, engine, award, account, retro, stats, tracker, settings, guid (function) }
local L = ns.L

local Controller = {}
Controller.__index = Controller

local REFRESH_DELAY = 0.5

-- The controller of one app. Tests build several.
function Controller.New(app)
  return setmetatable({
    app = app,
    state = {
      mode = "character",
      tab = "summary",
      ach = { category = nil, search = "", status = "all", expanded = {} },
    },
    subscriptions = {},
    refreshPending = false,
  }, Controller)
end

local function say(app, text)
  if type(app.Say) == "function" then
    app:Say(text)
  else
    print("|cff33ff99Forever Achievements|r " .. text)
  end
end

-- A table inside settings.ui kept across sessions (window size and position, tracker position).
function Controller:Status(name)
  local settings = self.app.store:Settings()
  if type(settings.ui) ~= "table" then
    settings.ui = {}
  end
  if type(settings.ui[name]) ~= "table" then
    settings.ui[name] = {}
  end
  return settings.ui[name]
end

function Controller:Window()
  if not self.window then
    self.window = ns.MainWindow.New(self)
  end
  return self.window
end

function Controller:Toggle()
  self:Window():Toggle()
end

function Controller:IsOpen()
  return self.window ~= nil and self.window:IsOpen()
end

function Controller:SetMode(mode)
  self.state.mode = mode == "account" and "account" or "character"
  if self.window then
    self.window:ModeChanged()
  end
end

-- Redraws the window if it is open, at most once per REFRESH_DELAY when the client has timers.
function Controller:RequestRefresh()
  if not self:IsOpen() then
    return
  end
  local timer = _G.C_Timer
  if type(timer) ~= "table" or type(timer.After) ~= "function" then
    self.window:Redraw()
    return
  end
  if self.refreshPending then
    return
  end
  self.refreshPending = true
  timer.After(REFRESH_DELAY, function()
    self.refreshPending = false
    if self:IsOpen() then
      self.window:Redraw()
    end
  end)
end

-- Pins or unpins an achievement and says why when it cannot. Returns true when the tracker changed.
function Controller:ToggleTrack(id)
  local app = self.app
  local ach = app.catalog.Get(id)
  local name = ns.ViewModel.Name(app.catalog, id)
  local ok, result = app.tracker:Toggle(id)
  if ok then
    say(app, string.format(result and L["ui.cmd.track_on"] or L["ui.cmd.track_off"], name))
  elseif result == "full" then
    say(app, string.format(L["ui.cmd.track_full"], ns.TrackerService.MAX))
  elseif result == "unknown" or not ach then
    say(app, string.format(L["ui.cmd.track_unknown"], tostring(id)))
  end
  if self.tracker then
    self.tracker:Refresh()
  end
  self:RequestRefresh()
  return ok
end

-- /fach track <id>
function Controller:TrackCommand(rest)
  local app = self.app
  local id = (rest or ""):match("^%s*(%S+)")
  if not id then
    say(app, L["ui.cmd.track_usage"])
    return
  end
  local ach = app.catalog.Get(id)
  if not ach then
    say(app, string.format(L["ui.cmd.track_unknown"], id))
    return
  end
  local guid = ns.ViewModel.Guid(app)
  if app.engine:IsEarned(ach, guid) then
    say(app, string.format(L["ui.cmd.track_earned"], ns.ViewModel.Name(app.catalog, id)))
    return
  end
  self:ToggleTrack(id)
end

function Controller:Subscribe(event, handler)
  local bus = self.app.bus
  self.subscriptions[#self.subscriptions + 1] = { event = event, handler = bus:Subscribe(event, handler) }
end

-- Wires the frames to the bus and the slash commands.
function Controller:Start()
  local app = self.app
  self.toast = ns.Toast.New(self)
  self.tracker = ns.TrackerFrame.New(self)
  self.minimap = ns.MinimapButton.New(self)

  self:Subscribe("achievement.earned", function(event)
    self.toast:OnEarned(event)
    self.tracker:OnEarned(event)
    self:RequestRefresh()
  end)
  self:Subscribe("progress.changed", function()
    self.tracker:Request()
    self:RequestRefresh()
  end)
  self:Subscribe("retro.completed", function()
    self.tracker:Request()
    self:RequestRefresh()
  end)

  if ns.Slash then
    ns.Slash.Register("track", function(rest)
      self:TrackCommand(rest)
    end, L["ui.cmd.track_help"])
    ns.Slash.SetDefault(function()
      self:Toggle()
      return true
    end)
  end
  self.tracker:Refresh()
  return app
end

function Controller:Stop()
  for _, subscription in ipairs(self.subscriptions) do
    self.app.bus:Unsubscribe(subscription.event, subscription.handler)
  end
  self.subscriptions = {}
end

local UI = {}
local current

-- Called once by the boot code. Returns the controller.
function UI.Start(app)
  if current then
    current:Stop()
  end
  current = Controller.New(app)
  current:Start()
  return current
end

-- Opens or closes the main window (the minimap button and the bare /fach use it). Does nothing before Start.
function UI.Toggle()
  if current then
    current:Toggle()
  end
end

function UI.IsOpen()
  return current ~= nil and current:IsOpen()
end

function UI.Controller()
  return current
end

ns.UI = UI
ns.UIController = Controller
