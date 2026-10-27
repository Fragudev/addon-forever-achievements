local _, ns = ...

-- Wires the application. Build(deps) creates every service and detector and returns the app table; Start(app) runs
-- the login sequence. Init.lua calls them at PLAYER_LOGIN and keeps the result in `ns.App`; specs build one with
-- fakes. (This module is ns.AppBuilder; ns.App is the app it built.)
--
-- The app table (UI code reads these exact fields):
--   store      Store (opened saved variable)
--   bus        EventBus
--   catalog    the Catalog module (static functions: Get, ByType, ...)
--   engine     CriteriaEngine
--   award      AwardService
--   account    AccountService
--   retro      RetroScan
--   stats      StatisticsService
--   tracker    TrackerService
--   settings   Settings
--   guid       function returning the GUID of the current character (nil until the client gives it)
--   queue      the encounter lockdown queue (Detector.Queue); detectors park their facts in it during an encounter
-- and these extras: platform, detectors ({ [name] = detector }), detectorList (in start order), errors, and the
-- methods Start, FeedRetro and Say.
--
-- deps: store (required); platform, catalog, now (function), guid (function), say (function), slash (Slash module),
-- detectors (list of detector names; default App.DETECTORS), providers (RetroScan providers override), ui.
local App = {}
App.__index = App

local PREFIX = "|cff33ff99Forever Achievements|r"

-- Detectors, in start order. Snapshot is last: it reads the others.
App.DETECTORS = {
  "Level",
  "Money",
  "Played",
  "Quests",
  "Exploration",
  "Reputation",
  "Skills",
  "Collections",
  "PvP",
  "Snapshot",
}

local function defaultNow(platform)
  return function()
    return platform.GetServerTime() or (os and os.time and os.time()) or 0
  end
end

-- Prints one line with the addon prefix.
function App:Say(message)
  self.say(message)
end

local function record(self, where, err)
  self.errors[#self.errors + 1] = { where = where, error = tostring(err) }
end

-- Runs fn, keeping its error instead of raising. Returns ok, result.
local function safe(self, where, fn, ...)
  local ok, result = pcall(fn, ...)
  if not ok then
    record(self, where, result)
  end
  return ok, result
end

-- Feeds facts as retroactive grants (silent) and prints one summary line when any were granted. For state the client
-- answers after the login scan (time played). Returns how many achievements were granted.
function App:FeedRetro(facts)
  local ok, count = safe(self, "FeedRetro", self.award.Silent, self.award, function()
    for _, fact in ipairs(facts) do
      self.engine:Feed(fact)
    end
  end)
  if ok and count > 0 then
    self:Say(ns.RetroScan.Message(count))
  end
  return ok and count or 0
end

local function currentGuid(platform, override)
  if override then
    return override
  end
  local cached
  return function()
    cached = cached or platform.GetPlayerGUID()
    return cached
  end
end

-- /fach forget <name>: the characters whose display name (or exact GUID) is `text`.
local function matches(store, text)
  local found = {}
  local wanted = text:lower()
  for guid, char in pairs(store:Characters()) do
    if guid == text or (type(char.name) == "string" and char.name:lower() == wanted) then
      found[#found + 1] = guid
    end
  end
  table.sort(found)
  return found
end

local function forget(app, text)
  local L = ns.L
  text = (text or ""):match("^%s*(.-)%s*$")
  if text == "" then
    app:Say(L["forget.usage"])
    return
  end
  local found = matches(app.store, text)
  if #found == 0 then
    app:Say(string.format(L["forget.unknown"], text))
  elseif #found > 1 then
    app:Say(string.format(L["forget.ambiguous"], text))
    for _, guid in ipairs(found) do
      print("  " .. guid)
    end
  elseif found[1] == app.guid() then
    app:Say(string.format(L["forget.current"], text))
  else
    app.store:Forget(found[1])
    app:Say(string.format(L["forget.done"], text))
  end
end

function App.Build(deps)
  local platform = deps.platform or ns.Platform
  local catalog = deps.catalog or ns.Catalog
  local store = deps.store
  local now = deps.now or defaultNow(platform)
  local guid = currentGuid(platform, deps.guid)

  local bus = ns.EventBus.New()
  local award = ns.AwardService.New({ store = store, catalog = catalog, bus = bus, now = now, guid = guid })
  local account = ns.AccountService.New({ store = store, catalog = catalog })
  local engine = ns.CriteriaEngine.New({
    store = store,
    catalog = catalog,
    award = award,
    account = account,
    bus = bus,
    guid = guid,
  })
  award:Bind(engine)
  account:Bind(engine)

  local retro = ns.RetroScan.New({
    engine = engine,
    award = award,
    account = account,
    bus = bus,
    providers = deps.providers,
  })
  local stats = ns.StatisticsService.New({ store = store, guid = guid })
  local settings = ns.Settings.New(store)
  local tracker = ns.TrackerService.New({ settings = settings, catalog = catalog })

  local app = setmetatable({
    store = store,
    bus = bus,
    catalog = catalog,
    engine = engine,
    award = award,
    account = account,
    retro = retro,
    stats = stats,
    tracker = tracker,
    settings = settings,
    guid = guid,
    platform = platform,
    queue = ns.Detector.Queue.New({ engine = engine, platform = platform, catalog = catalog }),
    detectors = {},
    detectorList = {},
    errors = {},
    ui = deps.ui,
    say = deps.say or function(message)
      print(PREFIX .. " " .. message)
    end,
  }, App)

  for _, name in ipairs(deps.detectors or App.DETECTORS) do
    local class = ns.Detectors[name]
    if class then
      local detector = class.New(app)
      app.detectors[name] = detector
      app.detectorList[#app.detectorList + 1] = detector
    end
  end

  local slash = deps.slash or ns.Slash
  if slash then
    slash.Register("forget", function(rest)
      forget(app, rest)
    end, "forget <name>   remove a known character (not the current one) and its achievements")
  end
  return app
end

-- The login sequence:
--   1. record the character info and snapshot (silent: whatever it awards predates the addon),
--   2. start the detectors,
--   3. run the retroactive scan and print one summary line when it granted something,
--   4. hand the app to the UI (ns.UI.Start), if there is one.
-- A step that raises is contained and kept in app.errors, so the next ones still run. Returns the number of
-- retroactive grants.
function App:Start()
  local granted = 0
  local snapshot = self.detectors.Snapshot
  if snapshot then
    local ok, count = safe(self, "snapshot", self.award.Silent, self.award, function()
      snapshot:Refresh()
    end)
    granted = granted + (ok and count or 0)
  end

  for _, detector in ipairs(self.detectorList) do
    safe(self, "start:" .. detector.name, detector.Start, detector)
  end

  -- After the detectors, so a fact produced by ENCOUNTER_END is queued before the queue's own handler looks at it.
  safe(self, "queue", self.queue.Start, self.queue)

  local ok, count = safe(self, "retro", self.retro.Run, self.retro)
  granted = granted + (ok and count or 0)
  if granted > 0 then
    self:Say(ns.RetroScan.Message(granted))
  end

  local ui = self.ui or ns.UI
  if type(ui) == "table" and type(ui.Start) == "function" then
    safe(self, "ui", ui.Start, self)
  end
  return granted
end

ns.AppBuilder = App
