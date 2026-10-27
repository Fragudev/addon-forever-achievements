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

-- Feeds facts to the engine; returns how many achievements they awarded.
function Detector:Publish(facts)
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

ns.Detector = Detector
