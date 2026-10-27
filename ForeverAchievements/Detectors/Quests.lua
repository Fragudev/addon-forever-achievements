local _, ns = ...

-- Completed quests. Facts: quest_count (how many) and quest_id (key = quest id, value 1) for the ids that the catalog
-- references. Source (assumed, not measured): C_QuestLog.GetAllCompletedQuestIDs and QUEST_TURNED_IN.
--
-- zone_quests (quests completed in a zone) is not published: it needs a quest-to-zone table, which belongs to the
-- catalog data of phase 6.
--
-- The completed list is read at login and kept as a set. A turned-in quest that is not in the set adds one to the
-- count; a repeatable quest that is already in it does not. With no readable list the count is unknown, so only the
-- quest_id fact goes out.
local Detector = ns.Detector
local Quests = Detector.Class("Quests", { events = { "QUEST_TURNED_IN" }, retroType = "quest_count" })

-- Reads the completed list. Returns true when it was readable.
function Quests:LoadBaseline()
  local ids = self.platform.ReadCompletedQuestIDs()
  if not ids then
    return false
  end
  local seen, count = {}, 0
  for _, id in ipairs(ids) do
    if type(id) == "number" and not seen[id] then
      seen[id] = true
      count = count + 1
    end
  end
  self.seen, self.count = seen, count
  return true
end

function Quests:OnStart()
  self:LoadBaseline()
end

function Quests:Facts()
  if not self:LoadBaseline() then
    return {}
  end
  local facts = { { type = "quest_count", value = self.count } }
  for id in pairs(Detector.ReferencedKeys(self.app.catalog, "quest_id")) do
    if self.seen[id] then
      facts[#facts + 1] = { type = "quest_id", key = id, value = 1 }
    end
  end
  return facts
end

function Quests:Handle(_, questId)
  questId = Detector.Number(questId)
  if not questId then
    return
  end
  local facts = {}
  if self.seen and not self.seen[questId] then
    self.seen[questId] = true
    self.count = self.count + 1
  end
  if self.seen then
    facts[#facts + 1] = { type = "quest_count", value = self.count }
  end
  if Detector.ReferencedKeys(self.app.catalog, "quest_id")[questId] then
    facts[#facts + 1] = { type = "quest_id", key = questId, value = 1 }
  end
  self:Publish(facts)
  if self.app.stats then
    self.app.stats:Increment("quests_completed")
  end
end
