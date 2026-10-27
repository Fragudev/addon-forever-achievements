local _, ns = ...

-- Achievements pinned by the player, kept in settings.tracked (a list of ids, oldest first), capped at MAX.
-- deps: settings (Settings instance), catalog.
local Tracker = {}
Tracker.__index = Tracker

Tracker.MAX = 10

function Tracker.New(deps)
  return setmetatable({ settings = deps.settings, catalog = deps.catalog }, Tracker)
end

function Tracker:List()
  return { unpack(self.settings:Get("tracked")) }
end

function Tracker:IsTracked(id)
  for _, tracked in ipairs(self.settings:Get("tracked")) do
    if tracked == id then
      return true
    end
  end
  return false
end

-- Returns true, or false plus "unknown" | "already" | "full".
function Tracker:Track(id)
  if not self.catalog.Get(id) then
    return false, "unknown"
  end
  if self:IsTracked(id) then
    return false, "already"
  end
  local tracked = self.settings:Get("tracked")
  if #tracked >= Tracker.MAX then
    return false, "full"
  end
  tracked[#tracked + 1] = id
  return true
end

-- Returns true when the id was tracked.
function Tracker:Untrack(id)
  local tracked = self.settings:Get("tracked")
  for index, candidate in ipairs(tracked) do
    if candidate == id then
      table.remove(tracked, index)
      return true
    end
  end
  return false
end

-- Tracks or untracks. Returns true plus the new state, or false plus the reason Track gives.
function Tracker:Toggle(id)
  if self:Untrack(id) then
    return true, false
  end
  local ok, reason = self:Track(id)
  if not ok then
    return false, reason
  end
  return true, true
end

ns.TrackerService = Tracker
