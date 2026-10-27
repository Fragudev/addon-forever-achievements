local _, ns = ...

-- Shared shape of every detector. A detector reads the client through Platform (never directly), publishes facts
-- ({ type, key?, value }) to the criteria engine and answers the retroactive scan with the current state.
--
--   local Level = Detector.Class("Level", { events = { "PLAYER_LEVEL_UP" }, retroType = "level" })
--   function Level:Facts() ... end             -- the current facts, for the login scan
--   function Level:Handle(event, ...) ... end  -- one event; its facts go out through self:Publish(facts)
--
-- Class options:
--   events     events registered on the detector's own frame (Platform refuses the ones the client blocks)
--   throttled  set of events that are coalesced: a burst runs the handler once, without arguments, after
--              Detector.THROTTLE_SECONDS
--   retroType  the criterion type the detector's RetroScan provider is registered under; the provider returns
--              every fact of the detector (Facts)
--
-- Every detector degrades silently: a missing API, an error or a secret value means no fact is published. A handler
-- that raises is contained here and kept in `lastError`.
local Detector = {}
Detector.__index = Detector

-- Delay of the coalescing of noisy events.
Detector.THROTTLE_SECONDS = 0.5

ns.Detectors = ns.Detectors or {}

-- The value when it is a readable number (not a secret, not NaN), else nil.
function Detector.Number(value)
  if type(value) ~= "number" or ns.Platform.IsSecret(value) or value ~= value then
    return nil
  end
  return value
end

-- Set of the keys that the catalog references in the criteria of this type: { [key] = true }.
function Detector.ReferencedKeys(catalog, criterionType)
  local keys = {}
  for _, ach in ipairs(catalog.ByType(criterionType)) do
    for _, criterion in ipairs(ach.criteria or {}) do
      if criterion.type == criterionType and criterion.key ~= nil then
        keys[criterion.key] = true
      end
    end
  end
  return keys
end

-- Defines a detector class. `New(app)` builds an instance; `app` is the wired application (engine, store, catalog,
-- platform, ...).
function Detector.Class(name, options)
  local class = {
    name = name,
    events = options.events or {},
    throttled = options.throttled or {},
    retroType = options.retroType,
  }
  class.__index = class
  setmetatable(class, { __index = Detector })
  function class.New(app)
    return setmetatable({ app = app, platform = app.platform or ns.Platform, pending = {} }, class)
  end
  ns.Detectors[name] = class
  return class
end

-- Default retro answer: nothing known.
Detector.Facts = function()
  return {}
end

-- Default event handler: ignores the event.
Detector.Handle = function() end

-- The part of the character snapshot this detector owns ({ money = ... }), or nil. Snapshot reads it.
Detector.SnapshotFields = function()
  return nil
end

-- Feeds facts to the engine; returns how many achievements they awarded. While an encounter locks the client down the
-- facts wait in the app's queue (see Detector.Queue) and this returns 0.
function Detector:Publish(facts)
  local queue = self.app.queue
  if queue and queue:Locked() then
    for _, fact in ipairs(facts) do
      queue:Add(fact)
    end
    return 0
  end
  local awarded = 0
  for _, fact in ipairs(facts) do
    awarded = awarded + self.app.engine:Feed(fact)
  end
  return awarded
end

-- Asks the Snapshot detector to store these snapshot fields (and refreshed character info) right now.
function Detector:UpdateSnapshot(fields, info)
  local snapshot = self.app.detectors and self.app.detectors.Snapshot
  if snapshot then
    snapshot:Update(fields, info)
  end
end

-- Same, but coalesced: for fields that change in bursts (money).
function Detector:QueueSnapshot(fields)
  local snapshot = self.app.detectors and self.app.detectors.Snapshot
  if snapshot then
    snapshot:Queue(fields)
  end
end

-- Runs the handler of one event; an error is contained. Returns true when it did not raise.
function Detector:Run(event, ...)
  local ok, err = pcall(self.Handle, self, event, ...)
  if not ok then
    self.lastError = tostring(err)
  end
  return ok
end

-- Entry point of every event: throttled ones are coalesced, the rest run at once.
function Detector:Dispatch(event, ...)
  if self.throttled[event] then
    return self:Defer(event)
  end
  return self:Run(event, ...)
end

-- Runs the handler of `event` once after the throttle delay, however many times it is asked meanwhile. Without a
-- client timer it runs at once. Returns false when a run was already waiting.
function Detector:Defer(event)
  if self.pending[event] then
    return false
  end
  self.pending[event] = true
  local function fire()
    self.pending[event] = nil
    self:Run(event)
  end
  if not self.platform.After(Detector.THROTTLE_SECONDS, fire) then
    fire()
  end
  return true
end

-- Registers the events on the detector's own frame and the retro provider. Safe to call twice. Returns
-- { registered = { names }, refused = { names } }; the outcome is kept in `registration`.
function Detector:Start()
  if self.registration then
    return self.registration
  end
  local frame = self.platform.NewFrame()
  local registration = { registered = {}, refused = {} }
  if
    frame and pcall(frame.SetScript, frame, "OnEvent", function(_, event, ...)
      self:Dispatch(event, ...)
    end)
  then
    self.frame = frame
    registration = self.platform.RegisterEvents(frame, self.events)
  else
    for _, event in ipairs(self.events) do
      registration.refused[#registration.refused + 1] = event
    end
  end
  self.registration = registration
  if self.retroType and ns.RetroScan then
    ns.RetroScan.Register(self.retroType, function()
      return self:Facts()
    end)
  end
  if self.OnStart then
    local ok, err = pcall(self.OnStart, self)
    if not ok then
      self.lastError = tostring(err)
    end
  end
  return registration
end

-- Encounter lockdown queue ---------------------------------------------------------------------------------------
-- While a boss encounter runs (C_ChatInfo.InChatMessagingLockdown or IsEncounterInProgress) detectors do not feed the
-- engine: a fact would evaluate achievements and show a toast in the middle of the fight, and the data behind it may
-- be secret. Their facts wait here and are fed when the encounter ends (ENCOUNTER_END) or the player leaves combat
-- (PLAYER_REGEN_ENABLED, only if the lockdown is over).
--
-- Facts of the same type and key are merged so the queue stays bounded by the number of distinct keys: "add" types
-- sum their values, the others keep the highest.
local Queue = {}
Queue.__index = Queue

Queue.EVENTS = { "ENCOUNTER_END", "PLAYER_REGEN_ENABLED" }

-- deps: engine, platform, catalog.
function Queue.New(deps)
  return setmetatable({
    engine = deps.engine,
    platform = deps.platform,
    catalog = deps.catalog,
    facts = {},
    index = {},
  }, Queue)
end

-- true while the client reports a chat lockdown or an encounter in progress.
function Queue:Locked()
  local platform = self.platform
  return platform.IsChatMessagingLockedDown() == true or platform.IsEncounterInProgress() == true
end

function Queue:Pending()
  return #self.facts
end

-- Keeps one fact (a copy). Facts that are not tables with a numeric value are ignored.
function Queue:Add(fact)
  if type(fact) ~= "table" or type(fact.value) ~= "number" then
    return false
  end
  local id = tostring(fact.type) .. ":" .. tostring(fact.key)
  local kept = self.index[id]
  if kept then
    local def = self.catalog and self.catalog.CRITERIA_TYPES[fact.type]
    if def and def.mode == "add" then
      kept.value = kept.value + fact.value
    else
      kept.value = math.max(kept.value, fact.value)
    end
    return true
  end
  kept = {}
  for field, value in pairs(fact) do
    kept[field] = value
  end
  self.index[id] = kept
  self.facts[#self.facts + 1] = kept
  return true
end

-- Feeds the queued facts to the engine, oldest first, and empties the queue. Unless `force`, a queue behind a lockdown
-- stays as it is. A fact that raises is skipped (kept in `lastError`). Returns how many achievements were awarded.
function Queue:Flush(force)
  if #self.facts == 0 or (not force and self:Locked()) then
    return 0
  end
  local facts = self.facts
  self.facts, self.index = {}, {}
  local awarded = 0
  for _, fact in ipairs(facts) do
    local ok, count = pcall(self.engine.Feed, self.engine, fact)
    if ok then
      awarded = awarded + count
    else
      self.lastError = tostring(count)
    end
  end
  return awarded
end

-- Reacts to the end of the encounter or of combat. The ENCOUNTER_END flush waits one throttle delay so that facts
-- produced by the same event (the boss kill) are already queued; without a timer it runs at once.
function Queue:Handle(event)
  if event == "ENCOUNTER_END" then
    local function flush()
      self:Flush(true)
    end
    if not self.platform.After(Detector.THROTTLE_SECONDS, flush) then
      flush()
    end
  else
    self:Flush(false)
  end
end

-- Registers the two events on a frame of its own. Safe to call twice. Returns the registration outcome.
function Queue:Start()
  if self.registration then
    return self.registration
  end
  local frame = self.platform.NewFrame()
  local registration = { registered = {}, refused = {} }
  if frame and pcall(frame.SetScript, frame, "OnEvent", function(_, event)
    self:Handle(event)
  end) then
    self.frame = frame
    registration = self.platform.RegisterEvents(frame, Queue.EVENTS)
  end
  self.registration = registration
  return registration
end

Detector.Queue = Queue

ns.Detector = Detector
