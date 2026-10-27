local _, ns = ...

-- Character level. Facts: level. Source (assumed, not measured): UnitLevel and PLAYER_LEVEL_UP, whose first
-- argument is the new level (UnitLevel can still give the old one while the event fires).
local Detector = ns.Detector
local Level = Detector.Class("Level", { events = { "PLAYER_LEVEL_UP" }, retroType = "level" })

function Level:Facts()
  local level = self.platform.GetPlayerLevel()
  if not level then
    return {}
  end
  return { { type = "level", value = level } }
end

function Level:Handle(_, newLevel)
  local level = Detector.Number(newLevel) or self.platform.GetPlayerLevel()
  if not level then
    return
  end
  self:Publish({ { type = "level", value = level } })
  if self.app.stats then
    self.app.stats:SetMax("highest_level", level)
  end
  self:UpdateSnapshot({}, { level = level })
end
