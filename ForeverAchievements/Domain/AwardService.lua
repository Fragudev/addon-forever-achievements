local _, ns = ...

-- Grants achievements and records when. Character achievements go to the current character, account ones to the
-- account (with the GUID of the character that triggered them in `by`). Granting twice changes nothing.
-- After a grant it publishes `achievement.earned` and asks the engine to cascade (next chain step, metas, account
-- points). Inside Silent(), grants are marked retro and publish nothing: the caller reports one summary instead.
-- deps: store, catalog, bus (optional), now (function), guid (function returning the current GUID).
local Award = {}
Award.__index = Award

function Award.New(deps)
  return setmetatable({
    store = deps.store,
    catalog = deps.catalog,
    bus = deps.bus,
    now = deps.now,
    guid = deps.guid,
    engine = nil,
    silent = 0,
    total = 0,
  }, Award)
end

function Award:Bind(engine)
  self.engine = engine
end

-- True while inside Silent(): the grants are retroactive.
function Award:IsRetro()
  return self.silent > 0
end

-- How many grants happened since the service was created (retro included).
function Award:Total()
  return self.total
end

-- Returns true plus the stored entry, or false plus "unknown" | "already" | "no_character".
-- opts.retro marks the grant as retroactive without silencing it.
function Award:Grant(id, opts)
  local ach = self.catalog.Get(id)
  if not ach then
    return false, "unknown"
  end
  local guid = self.guid()
  local earned
  if ach.scope == "account" then
    earned = self.store:AccountEarned()
  elseif guid then
    earned = self.store:Earned(guid)
  else
    return false, "no_character"
  end
  if earned[id] then
    return false, "already"
  end

  local retro = (opts ~= nil and opts.retro == true) or self.silent > 0
  local entry = { at = self.now(), retro = retro }
  if ach.scope == "account" then
    entry.by = guid
  end
  earned[id] = entry
  self.total = self.total + 1

  if self.silent == 0 and self.bus then
    self.bus:Publish("achievement.earned", {
      id = id,
      scope = ach.scope,
      guid = guid,
      at = entry.at,
      retro = retro,
      points = ach.points,
      feat = ach.feat == true,
      achievement = ach,
    })
  end
  if self.engine then
    self.engine:Cascade(ach, guid)
  end
  return true, entry
end

-- Runs fn with silent retro granting and returns how many achievements were granted meanwhile. Nested calls are
-- fine; an error in fn is re-raised after the mode is restored.
function Award:Silent(fn)
  local before = self.total
  self.silent = self.silent + 1
  local ok, err = pcall(fn)
  self.silent = self.silent - 1
  if not ok then
    error(err, 0)
  end
  return self.total - before
end

ns.AwardService = Award
