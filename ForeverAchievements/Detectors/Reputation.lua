local _, ns = ...

-- Reputation. Facts:
--   reputation        key = faction id, value = the standing value of the bar (cumulative, as the client gives it)
--   reputation_count  how many factions are at Exalted
-- Source (assumed, not measured): C_Reputation.GetFactionDataByID (legacy GetFactionInfoByID) for the factions that
-- the catalog references, and the faction list (GetNumFactions with GetFactionDataByIndex / GetFactionInfo) for the
-- Exalted count. UPDATE_FACTION fires in bursts, so it is coalesced.
--
-- The faction list only has the visible rows (a collapsed header hides its factions) and the addon never expands the
-- headers, so the Exalted count is a lower bound: the visible rows plus the referenced factions.
local Detector = ns.Detector
local Reputation = Detector.Class(
  "Reputation",
  { events = { "UPDATE_FACTION" }, throttled = { UPDATE_FACTION = true }, retroType = "reputation" }
)

-- Standing id of Exalted in the client's standing scale (1 Hated .. 8 Exalted).
Reputation.EXALTED = 8

-- Reads everything. Returns the facts and the { [factionId] = value } map of the snapshot; both are empty when
-- nothing was readable.
function Reputation:Read()
  local facts, reps, exalted, readable = {}, {}, {}, false
  for factionId in pairs(Detector.ReferencedKeys(self.app.catalog, "reputation")) do
    local data = self.platform.GetFactionData(factionId)
    if data and data.barValue then
      facts[#facts + 1] = { type = "reputation", key = factionId, value = data.barValue }
      reps[factionId] = data.barValue
      readable = true
      if data.standingID == Reputation.EXALTED then
        exalted[factionId] = true
      end
    end
  end
  for index = 1, self.platform.GetNumFactions() or 0 do
    local data = self.platform.GetFactionByIndex(index)
    if data then
      readable = true
      if data.factionID and data.standingID == Reputation.EXALTED then
        exalted[data.factionID] = true
      end
    end
  end
  if readable then
    local count = 0
    for _ in pairs(exalted) do
      count = count + 1
    end
    facts[#facts + 1] = { type = "reputation_count", value = count }
  end
  return facts, reps
end

function Reputation:Facts()
  return (self:Read())
end

function Reputation:SnapshotFields()
  local _, reps = self:Read()
  return { reps = reps }
end

function Reputation:Handle()
  local facts, reps = self:Read()
  self:Publish(facts)
  self:UpdateSnapshot({ reps = reps })
end
