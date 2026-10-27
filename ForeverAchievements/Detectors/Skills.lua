local _, ns = ...

-- Professions. Facts:
--   skill        key = skill line id, value = rank, for the skill lines that the catalog references
--   skill_count  how many professions are at the maximum rank
-- Source (assumed, not measured): GetProfessions with GetProfessionInfo (name, rank, max rank, skill line) and
-- SKILL_LINES_CHANGED, which fires in bursts and is coalesced.
--
-- "At the maximum" means rank >= Skills.MAX_RANK (the Classic cap) because the max rank the client reports is the
-- current tier cap (75, 150, ...), not the final one.
local Detector = ns.Detector
local Skills = Detector.Class(
  "Skills",
  { events = { "SKILL_LINES_CHANGED" }, throttled = { SKILL_LINES_CHANGED = true }, retroType = "skill" }
)

Skills.MAX_RANK = 300

-- Reads the professions. Returns the facts and the { [skillLine] = rank } map of the snapshot.
function Skills:Read()
  local facts, ranks, atMax, readable = {}, {}, 0, false
  local wanted = Detector.ReferencedKeys(self.app.catalog, "skill")
  for _, index in ipairs(self.platform.GetProfessions()) do
    local info = self.platform.GetProfessionInfo(index)
    if info and info.rank then
      readable = true
      if info.rank >= Skills.MAX_RANK then
        atMax = atMax + 1
      end
      if info.skillLine then
        ranks[info.skillLine] = info.rank
        if wanted[info.skillLine] then
          facts[#facts + 1] = { type = "skill", key = info.skillLine, value = info.rank }
        end
      end
    end
  end
  if readable then
    facts[#facts + 1] = { type = "skill_count", value = atMax }
  end
  return facts, ranks
end

function Skills:Facts()
  return (self:Read())
end

function Skills:SnapshotFields()
  local _, ranks = self:Read()
  return { skills = ranks }
end

function Skills:Handle()
  local facts, ranks = self:Read()
  self:Publish(facts)
  self:UpdateSnapshot({ skills = ranks })
end
