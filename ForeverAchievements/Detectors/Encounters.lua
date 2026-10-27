local _, ns = ...

-- Boss kills. Facts: encounter (key = encounterID, value 1), one per successful kill, with the extra field
-- instanceType ("party", "raid", ...) that the statistics use to split dungeon from raid bosses. Source (assumed, not
-- measured): ENCOUNTER_END (encounterID, encounterName, difficultyID, groupSize, success) with success == 1. The
-- difficulty is ignored by the criteria but logged (the last LOG_SIZE kills, in memory and in
-- ForeverAchievementsDB.debug.encounters) so the launch measurements can show which ids Forever reports.
-- There is no retroactive answer: the client does not list past kills, and the combat log is never used.
local Detector = ns.Detector
local Encounters = Detector.Class("Encounters", { events = { "ENCOUNTER_END" } })

Encounters.LOG_SIZE = 20

local function push(list, entry)
  list[#list + 1] = entry
  while #list > Encounters.LOG_SIZE do
    table.remove(list, 1)
  end
end

function Encounters:Log(entry)
  self.log = self.log or {}
  push(self.log, entry)
  local db = ns.db
  if type(db) == "table" then
    db.debug = type(db.debug) == "table" and db.debug or {}
    db.debug.encounters = type(db.debug.encounters) == "table" and db.debug.encounters or {}
    push(db.debug.encounters, entry)
  end
end

function Encounters:Handle(_, encounterId, _, difficultyId, _, success)
  local id = Detector.Number(encounterId)
  if not id or Detector.Number(success) ~= 1 then
    return
  end
  local _, instanceType = self.platform.IsInInstance()
  self:Log({ encounterID = id, difficultyID = Detector.Number(difficultyId), instanceType = instanceType })
  self:Publish({ { type = "encounter", key = id, value = 1, instanceType = instanceType } })
end
