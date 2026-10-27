local _, ns = ...

-- Character snapshot for the account aggregates: { money, played, skills, reps } plus the character info (name,
-- class, race, faction, level). It calls AccountService:Record, which stores them and re-evaluates the account
-- achievements. It runs at login (App.Start), on PLAYER_LOGOUT and whenever another detector hands it a changed
-- field. Each other detector owns its part through SnapshotFields.
--
-- The display name comes from Platform.GetPlayerDisplayName (GetUnitName, then UnitName); identity is always the GUID.
local Detector = ns.Detector
local Snapshot = Detector.Class("Snapshot", { events = { "PLAYER_LOGOUT" } })

-- The character info the Store keeps; a field the client cannot give is left out.
function Snapshot:Info()
  local platform = self.platform
  local _, classToken = platform.GetPlayerClass()
  local race = platform.GetPlayerRace()
  return {
    name = platform.GetPlayerDisplayName(),
    class = classToken,
    race = race,
    faction = (platform.GetPlayerFaction()),
    level = platform.GetPlayerLevel(),
  }
end

-- The snapshot fields of every detector.
function Snapshot:Build()
  local fields = {}
  for _, detector in ipairs(self.app.detectorList or {}) do
    local ok, own = pcall(detector.SnapshotFields, detector)
    if ok and type(own) == "table" then
      for key, value in pairs(own) do
        fields[key] = value
      end
    end
  end
  return fields
end

-- Records the info and the given fields now. `info` overrides fields of the freshly read info (a level-up gives the
-- new level before UnitLevel does). Returns how many achievements the account re-evaluation awarded.
function Snapshot:Update(fields, info)
  local guid = self.app.guid()
  if not guid then
    return 0
  end
  local character = self:Info()
  for key, value in pairs(info or {}) do
    character[key] = value
  end
  return self.app.account:Record(guid, character, fields or {})
end

-- Records the complete snapshot.
function Snapshot:Refresh()
  return self:Update(self:Build())
end

-- Remembers fields and records them after the throttle delay (at once without a client timer).
function Snapshot:Queue(fields)
  self.queued = self.queued or {}
  for key, value in pairs(fields) do
    self.queued[key] = value
  end
  if self.waiting then
    return
  end
  self.waiting = true
  local function flush()
    self.waiting = false
    local ok, err = pcall(self.Flush, self)
    if not ok then
      self.lastError = tostring(err)
    end
  end
  if not self.platform.After(Detector.THROTTLE_SECONDS, flush) then
    flush()
  end
end

-- Records the queued fields, if any.
function Snapshot:Flush()
  local fields = self.queued
  self.queued = nil
  if fields then
    return self:Update(fields)
  end
  return 0
end

function Snapshot:Handle(event)
  if event == "PLAYER_LOGOUT" then
    self.queued = nil
    self:Refresh()
  end
end
